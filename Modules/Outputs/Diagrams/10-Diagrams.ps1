function Invoke-RangerDiagramGeneration {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [string]$PackageRoot,

        [string[]]$Formats = @('svg'),
        [string]$Mode
    )

    $diagramsRoot = Join-Path -Path $PackageRoot -ChildPath 'diagrams'
    New-Item -ItemType Directory -Path $diagramsRoot -Force | Out-Null
    $artifacts = New-Object System.Collections.ArrayList
    $prefix = Get-RangerArtifactPrefix -Manifest $Manifest

    foreach ($definition in (Get-RangerDiagramDefinitions)) {
        if (-not (Test-RangerShouldRenderDiagram -Manifest $Manifest -Definition $definition -Mode $Mode)) {
            [void]$artifacts.Add((New-RangerArtifactRecord -Type 'diagram' -RelativePath (Join-Path 'diagrams' ((Get-RangerSafeName -Value $definition.Name) + '.drawio')) -Status skipped -Audience ($definition.Audience -join ',') -Reason 'Selection rules did not include this diagram for the current manifest.'))
            continue
        }

        if (-not (Test-RangerDiagramHasRequiredData -Manifest $Manifest -Definition $definition)) {
            [void]$artifacts.Add((New-RangerArtifactRecord -Type 'diagram' -RelativePath (Join-Path 'diagrams' ((Get-RangerSafeName -Value $definition.Name) + '.drawio')) -Status skipped -Audience ($definition.Audience -join ',') -Reason 'Required manifest domains were missing.'))
            continue
        }

        $model = Get-RangerDiagramModel -Manifest $Manifest -Definition $definition
        $baseName = "{0}-{1}" -f $prefix, (Get-RangerSafeName -Value $definition.Name)

        $drawIoPath = Join-Path -Path $diagramsRoot -ChildPath ($baseName + '.drawio')
        (ConvertTo-RangerDrawIoXml -Manifest $Manifest -Definition $definition -Model $model) | Set-Content -Path $drawIoPath -Encoding UTF8
        [void]$artifacts.Add((New-RangerArtifactRecord -Type 'diagram-drawio' -RelativePath ([System.IO.Path]::GetRelativePath($PackageRoot, $drawIoPath)) -Status generated -Audience ($definition.Audience -join ',')))

        if ('svg' -in $Formats) {
            $svgContent = ConvertTo-RangerSvgDiagram -Manifest $Manifest -Definition $definition -Model $model
            if ($null -ne $svgContent) {
                $svgPath = Join-Path -Path $diagramsRoot -ChildPath ($baseName + '.svg')
                $svgContent | Set-Content -Path $svgPath -Encoding UTF8
                [void]$artifacts.Add((New-RangerArtifactRecord -Type 'diagram-svg' -RelativePath ([System.IO.Path]::GetRelativePath($PackageRoot, $svgPath)) -Status generated -Audience ($definition.Audience -join ',')))
            } else {
                [void]$artifacts.Add((New-RangerArtifactRecord -Type 'diagram-svg' -RelativePath (Join-Path 'diagrams' ($baseName + '.svg')) -Status skipped -Audience ($definition.Audience -join ',') -Reason 'Insufficient data to produce a useful diagram.'))
            }
        }
    }

    return @($artifacts)
}

function Test-RangerShouldRenderDiagram {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [object]$Definition,

        [string]$Mode
    )

    if ($Definition.Tier -eq 'baseline') {
        return $true
    }

    if ($Mode -eq 'as-built') {
        return $true
    }

    $name = $Definition.Name
    switch ($name) {
        'topology-variant-map' { return $Manifest.topology.deploymentType -in @('rack-aware', 'multi-rack', 'switchless') }
        'identity-secret-flow' { return $Manifest.topology.identityMode -eq 'local-key-vault' }
        'monitoring-telemetry-flow' { return Test-RangerDomainPopulated -Value $Manifest.domains.monitoring }
        'connectivity-dependency-map' { return Test-RangerDomainPopulated -Value $Manifest.domains.networking.proxy }
        'identity-access-surface' { return Test-RangerDomainPopulated -Value $Manifest.domains.identitySecurity }
        'monitoring-health-heatmap' { return @($Manifest.findings | Where-Object { $_.severity -in @('critical', 'warning') }).Count -gt 0 }
        'oem-firmware-posture' { return Test-RangerDomainPopulated -Value $Manifest.domains.hardware }
        'backup-recovery-map' { return @($Manifest.domains.azureIntegration.backup).Count -gt 0 }
        'management-plane-tooling' { return Test-RangerDomainPopulated -Value $Manifest.domains.managementTools }
        'workload-family-placement' { return @($Manifest.domains.virtualMachines.workloadFamilies).Count -gt 0 }
        'fabric-map' { return $Manifest.topology.deploymentType -eq 'rack-aware' }
        'disconnected-control-plane' { return $Manifest.topology.controlPlaneMode -eq 'disconnected' }
        default { return $false }
    }
}

function Test-RangerDiagramHasRequiredData {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [object]$Definition
    )

    foreach ($required in @($Definition.Required)) {
        if (-not (Test-RangerDomainPopulated -Value $Manifest.domains[$required])) {
            return $false
        }
    }

    return $true
}

function Get-RangerDiagramModel {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [object]$Definition
    )

    $nodes = New-Object System.Collections.ArrayList
    $edges = New-Object System.Collections.ArrayList
    $clusterName = if (-not [string]::IsNullOrWhiteSpace($Manifest.target.clusterName)) { $Manifest.target.clusterName } else { $Manifest.target.environmentLabel }
    [void]$nodes.Add([ordered]@{ id = 'cluster'; label = $clusterName; kind = 'cluster'; detail = $Manifest.topology.deploymentType; group = 'platform' })

    switch ($Definition.Name) {
        'physical-architecture' {
            foreach ($node in @($Manifest.domains.clusterNode.nodes)) {
                $nodeId = 'node-' + (Get-RangerSafeName -Value $node.name)
                [void]$nodes.Add([ordered]@{ id = $nodeId; label = $node.name; kind = 'node'; detail = ('{0} | {1}' -f $node.state, $node.model); group = 'platform' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $nodeId; label = $node.state })
            }

            foreach ($endpoint in @($Manifest.domains.oemIntegration.endpoints)) {
                $endpointId = 'bmc-' + (Get-RangerSafeName -Value $endpoint.host)
                [void]$nodes.Add([ordered]@{ id = $endpointId; label = $endpoint.host; kind = 'bmc'; detail = $endpoint.node; group = 'management' })
                [void]$edges.Add([ordered]@{ source = $endpointId; target = ('node-' + (Get-RangerSafeName -Value $endpoint.node)); label = 'manages' })
            }
        }
        'logical-network-topology' {
            foreach ($network in @($Manifest.domains.clusterNode.networks)) {
                $networkId = 'network-' + (Get-RangerSafeName -Value $network.name)
                [void]$nodes.Add([ordered]@{ id = $networkId; label = $network.name; kind = 'network'; detail = ('role {0}' -f $network.role); group = 'network' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $networkId; label = $network.role })
            }

            foreach ($adapter in @($Manifest.domains.networking.adapters | Select-Object -First 10)) {
                $adapterId = 'adapter-' + (Get-RangerSafeName -Value $adapter.name)
                [void]$nodes.Add([ordered]@{ id = $adapterId; label = $adapter.name; kind = 'adapter'; detail = ('{0} | {1}' -f $adapter.status, $adapter.linkSpeed); group = 'network' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $adapterId; label = 'adapter' })
            }
        }
        'storage-architecture' {
            foreach ($pool in @($Manifest.domains.storage.pools)) {
                $poolId = 'pool-' + (Get-RangerSafeName -Value $pool.friendlyName)
                [void]$nodes.Add([ordered]@{ id = $poolId; label = $pool.friendlyName; kind = 'storage'; detail = ('{0} | {1} GiB' -f $pool.healthStatus, [math]::Round(($pool.size / 1GB), 2)); group = 'storage' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $poolId; label = $pool.healthStatus })
            }
            foreach ($csv in @($Manifest.domains.storage.csvs)) {
                $csvId = 'csv-' + (Get-RangerSafeName -Value $csv.name)
                [void]$nodes.Add([ordered]@{ id = $csvId; label = $csv.name; kind = 'volume'; detail = $csv.state; group = 'storage' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $csvId; label = $csv.state })
            }
            foreach ($disk in @($Manifest.domains.storage.physicalDisks | Select-Object -First 8)) {
                $diskId = 'disk-' + (Get-RangerSafeName -Value $disk.friendlyName)
                [void]$nodes.Add([ordered]@{ id = $diskId; label = $disk.friendlyName; kind = 'disk'; detail = ('{0} | {1}' -f $disk.mediaType, $disk.healthStatus); group = 'storage' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $diskId; label = 'physical disk' })
            }
        }
        'vm-placement-map' {
            foreach ($vm in @($Manifest.domains.virtualMachines.inventory)) {
                $vmId = 'vm-' + (Get-RangerSafeName -Value $vm.name)
                [void]$nodes.Add([ordered]@{ id = $vmId; label = $vm.name; kind = 'vm'; detail = ('{0} | {1} MB' -f $vm.state, $vm.memoryAssignedMb); group = 'workload' })
                [void]$edges.Add([ordered]@{ source = ('node-' + (Get-RangerSafeName -Value $vm.hostNode)); target = $vmId; label = $vm.state })
            }
        }
        'azure-arc-integration' {
            foreach ($resource in @($Manifest.domains.azureIntegration.resources | Select-Object -First 10)) {
                $resourceId = 'az-' + (Get-RangerSafeName -Value $resource.name)
                [void]$nodes.Add([ordered]@{ id = $resourceId; label = $resource.name; kind = 'azure'; detail = ('{0} | {1}' -f $resource.resourceType, $resource.location); group = 'azure' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $resourceId; label = $resource.resourceType })
            }
        }
        'workload-services-map' {
            foreach ($family in @($Manifest.domains.virtualMachines.workloadFamilies)) {
                $familyId = 'workload-' + (Get-RangerSafeName -Value $family.name)
                [void]$nodes.Add([ordered]@{ id = $familyId; label = $family.name; kind = 'workload'; detail = ('count {0}' -f $family.count); group = 'workload' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $familyId; label = $family.count })
            }
            foreach ($service in @($Manifest.domains.azureIntegration.services | Select-Object -First 8)) {
                $serviceId = 'service-' + (Get-RangerSafeName -Value $service.name)
                [void]$nodes.Add([ordered]@{ id = $serviceId; label = $service.name; kind = 'service'; detail = ('count {0}' -f $service.count); group = 'azure' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $serviceId; label = $service.category })
            }
        }
        'topology-variant-map' {
            foreach ($marker in @($Manifest.topology.variantMarkers | Select-Object -Unique)) {
                $markerId = 'variant-' + (Get-RangerSafeName -Value $marker)
                [void]$nodes.Add([ordered]@{ id = $markerId; label = $marker; kind = 'variant'; detail = 'applies'; group = 'platform' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $markerId; label = 'variant' })
            }
        }
        'identity-secret-flow' {
            foreach ($node in @($Manifest.domains.identitySecurity.nodes)) {
                $identityId = 'identity-' + (Get-RangerSafeName -Value $node.node)
                [void]$nodes.Add([ordered]@{ id = $identityId; label = $node.node; kind = 'identity'; detail = ('domain joined: {0}' -f $node.partOfDomain); group = 'identity' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $identityId; label = 'trust' })
            }
            foreach ($policy in @($Manifest.domains.azureIntegration.policy | Select-Object -First 5)) {
                $policyId = 'policy-' + (Get-RangerSafeName -Value $policy.name)
                [void]$nodes.Add([ordered]@{ id = $policyId; label = $policy.name; kind = 'policy'; detail = $policy.enforcementMode; group = 'azure' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $policyId; label = 'policy' })
            }
        }
        'monitoring-telemetry-flow' {
            $monitoringResources = @(@($Manifest.domains.monitoring.ama) + @($Manifest.domains.monitoring.dcr) + @($Manifest.domains.monitoring.alerts) | Select-Object -First 12)
            foreach ($resource in $monitoringResources) {
                $resourceId = 'monitor-' + (Get-RangerSafeName -Value $resource.name)
                [void]$nodes.Add([ordered]@{ id = $resourceId; label = $resource.name; kind = 'monitor'; detail = $resource.resourceType; group = 'management' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $resourceId; label = 'telemetry' })
            }
        }
        'connectivity-dependency-map' {
            foreach ($proxy in @($Manifest.domains.networking.proxy | Select-Object -First 10)) {
                $proxyId = 'proxy-' + (Get-RangerSafeName -Value $proxy.node)
                [void]$nodes.Add([ordered]@{ id = $proxyId; label = $proxy.node; kind = 'connectivity'; detail = $proxy.value; group = 'network' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $proxyId; label = 'proxy path' })
            }
            foreach ($fwProfile in @($Manifest.domains.networking.firewall | Select-Object -First 10)) {
                $profileId = 'fw-' + (Get-RangerSafeName -Value $fwProfile.node)
                [void]$nodes.Add([ordered]@{ id = $profileId; label = $fwProfile.node; kind = 'firewall'; detail = ('profiles {0}' -f @($fwProfile.profiles).Count); group = 'network' })
                [void]$edges.Add([ordered]@{ source = $profileId; target = 'cluster'; label = 'host firewall' })
            }
        }
        'identity-access-surface' {
            foreach ($adminSet in @($Manifest.domains.identitySecurity.localAdmins | Select-Object -First 10)) {
                $adminId = 'admins-' + (Get-RangerSafeName -Value $adminSet.node)
                [void]$nodes.Add([ordered]@{ id = $adminId; label = $adminSet.node; kind = 'identity'; detail = ('admin members {0}' -f @($adminSet.members).Count); group = 'identity' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $adminId; label = 'local admin surface' })
            }
        }
        'monitoring-health-heatmap' {
            foreach ($node in @($Manifest.domains.clusterNode.nodes)) {
                $findingCount = @($Manifest.findings | Where-Object { @($_.affectedComponents) -contains $node.name }).Count
                [void]$nodes.Add([ordered]@{ id = 'heat-' + (Get-RangerSafeName -Value $node.name); label = $node.name; kind = 'heat'; detail = ('findings {0}' -f $findingCount); group = 'management'; severity = if ($findingCount -gt 1) { 'warning' } else { 'good' } })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = ('heat-' + (Get-RangerSafeName -Value $node.name)); label = 'health' })
            }
        }
        'oem-firmware-posture' {
            foreach ($node in @($Manifest.domains.hardware.nodes)) {
                $hardwareId = 'hw-' + (Get-RangerSafeName -Value $node.node)
                [void]$nodes.Add([ordered]@{ id = $hardwareId; label = $node.node; kind = 'hardware'; detail = ('bios {0}' -f $node.biosVersion); group = 'hardware' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $hardwareId; label = 'hardware' })
            }
            foreach ($mgmt in @($Manifest.domains.oemIntegration.managementPosture | Select-Object -First 10)) {
                $mgmtId = 'oem-' + (Get-RangerSafeName -Value $mgmt.node)
                [void]$nodes.Add([ordered]@{ id = $mgmtId; label = $mgmt.node; kind = 'bmc'; detail = $mgmt.managerFirmwareVersion; group = 'hardware' })
                [void]$edges.Add([ordered]@{ source = $mgmtId; target = ('hw-' + (Get-RangerSafeName -Value $mgmt.node)); label = 'firmware posture' })
            }
        }
        'backup-recovery-map' {
            $recoveryResources = @(@($Manifest.domains.azureIntegration.backup) + @($Manifest.domains.azureIntegration.update) | Select-Object -First 10)
            foreach ($resource in $recoveryResources) {
                $resourceId = 'recover-' + (Get-RangerSafeName -Value $resource.name)
                [void]$nodes.Add([ordered]@{ id = $resourceId; label = $resource.name; kind = 'recovery'; detail = $resource.resourceType; group = 'azure' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $resourceId; label = 'continuity' })
            }
        }
        'management-plane-tooling' {
            foreach ($tool in @($Manifest.domains.managementTools.tools | Select-Object -First 10)) {
                $toolId = 'tool-' + (Get-RangerSafeName -Value $tool.name)
                [void]$nodes.Add([ordered]@{ id = $toolId; label = $tool.name; kind = 'management'; detail = $tool.status; group = 'management' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $toolId; label = 'management' })
            }
        }
        'workload-family-placement' {
            foreach ($family in @($Manifest.domains.virtualMachines.workloadFamilies)) {
                $familyId = 'family-' + (Get-RangerSafeName -Value $family.name)
                [void]$nodes.Add([ordered]@{ id = $familyId; label = $family.name; kind = 'workload'; detail = ('family count {0}' -f $family.count); group = 'workload' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $familyId; label = 'family' })
            }
            foreach ($placement in @($Manifest.domains.virtualMachines.placement | Select-Object -First 10)) {
                $placementNode = 'place-' + (Get-RangerSafeName -Value $placement.vm)
                [void]$nodes.Add([ordered]@{ id = $placementNode; label = $placement.vm; kind = 'vm'; detail = $placement.hostNode; group = 'workload' })
                [void]$edges.Add([ordered]@{ source = ('family-' + (Get-RangerSafeName -Value (($Manifest.domains.virtualMachines.workloadFamilies | Select-Object -First 1).name))); target = $placementNode; label = $placement.state })
            }
        }
        'fabric-map' {
            foreach ($faultDomain in @($Manifest.domains.clusterNode.faultDomains | Select-Object -First 10)) {
                $faultId = 'fd-' + (Get-RangerSafeName -Value $faultDomain.name)
                [void]$nodes.Add([ordered]@{ id = $faultId; label = $faultDomain.name; kind = 'fabric'; detail = $faultDomain.location; group = 'network' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $faultId; label = $faultDomain.faultDomainType })
            }
        }
        'disconnected-control-plane' {
            [void]$nodes.Add([ordered]@{ id = 'ops'; label = 'Disconnected operations'; kind = 'control'; detail = 'local control plane'; group = 'management' })
            [void]$edges.Add([ordered]@{ source = 'cluster'; target = 'ops'; label = 'operates' })
            foreach ($node in @($Manifest.domains.identitySecurity.nodes | Select-Object -First 10)) {
                $nodeId = 'local-' + (Get-RangerSafeName -Value $node.node)
                [void]$nodes.Add([ordered]@{ id = $nodeId; label = $node.node; kind = 'identity'; detail = ('domain joined: {0}' -f $node.partOfDomain); group = 'identity' })
                [void]$edges.Add([ordered]@{ source = 'ops'; target = $nodeId; label = 'trust boundary' })
            }
        }
        default {
            foreach ($required in @($Definition.Required)) {
                $requiredId = 'domain-' + (Get-RangerSafeName -Value $required)
                [void]$nodes.Add([ordered]@{ id = $requiredId; label = $required; kind = 'domain'; detail = $Definition.Title; group = 'platform' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $requiredId; label = $Definition.Title })
            }
        }
    }

    return [ordered]@{
        nodes = @($nodes)
        edges = @($edges)
    }
}

function ConvertTo-RangerDrawIoXml {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [object]$Definition,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Model
    )

    $cells    = New-Object System.Collections.Generic.List[string]
    $cells.Add('<mxCell id="0" />')
    $cells.Add('<mxCell id="1" parent="0" />')

    # Group layout with labelled swim-lane containers (#140)
    $groupColumns = [ordered]@{ platform = 40; storage = 320; network = 600; workload = 880; azure = 1160; management = 1440; identity = 1720; hardware = 2000 }
    $groupTitles  = @{ platform = 'Platform'; storage = 'Storage'; network = 'Network'; workload = 'Workload'; azure = 'Azure'; management = 'Management'; identity = 'Identity'; hardware = 'Hardware' }
    $groupFills   = @{ platform = '#f0f9ff'; storage = '#f1f5f9'; network = '#fffbeb'; workload = '#fefce8'; azure = '#ecfeff'; management = '#f5f3ff'; identity = '#fff1f2'; hardware = '#f0fdf4' }
    $groupStrokes = @{ platform = '#bae6fd'; storage = '#cbd5e1'; network = '#fde68a'; workload = '#fef08a'; azure = '#a5f3fc'; management = '#ddd6fe'; identity = '#fecdd3'; hardware = '#bbf7d0' }
    $groupOffsets = @{}
    $nodePositions = @{}
    $containerIds  = @{}
    $containerIndex = 100

    # First pass: assign positions
    foreach ($node in @($Model.nodes)) {
        if ([string]::IsNullOrWhiteSpace($node.id)) { continue }
        $grp = if ($node.group -and $groupColumns.Contains([string]$node.group)) { [string]$node.group } else { 'platform' }
        if (-not $groupOffsets.ContainsKey($grp)) { $groupOffsets[$grp] = 50 }
        $nodePositions[$node.id] = [ordered]@{ x = $groupColumns[$grp]; y = $groupOffsets[$grp]; group = $grp }
        $groupOffsets[$grp] += 90
    }

    # Emit group container cells
    foreach ($grp in $groupColumns.Keys) {
        $grpNodes = @($nodePositions.Values | Where-Object { $_.group -eq $grp })
        if ($grpNodes.Count -eq 0) { continue }
        $minY  = ($grpNodes | Measure-Object -Property y -Minimum).Minimum - 30
        $maxY  = ($grpNodes | Measure-Object -Property y -Maximum).Maximum + 80
        $cid   = "container-$grp"
        $containerIds[$grp] = $cid
        $containerIndex++
        $fill   = if ($groupFills.ContainsKey($grp))   { $groupFills[$grp] }   else { '#f8fafc' }
        $stroke = if ($groupStrokes.ContainsKey($grp)) { $groupStrokes[$grp] } else { '#e2e8f0' }
        $title  = if ($groupTitles.ContainsKey($grp))  { $groupTitles[$grp] }  else { $grp }
        $cells.Add(('<mxCell id="{0}" value="{1}" style="swimlane;startSize=24;fillColor={2};strokeColor={3};fontStyle=1;fontSize=11;rounded=1;" vertex="1" parent="1"><mxGeometry x="{4}" y="{5}" width="240" height="{6}" as="geometry" /></mxCell>' -f $cid, [System.Security.SecurityElement]::Escape($title), $fill, $stroke, ($groupColumns[$grp] - 8), $minY, ($maxY - $minY)))
    }

    # Emit node cells (parented to their container)
    foreach ($node in @($Model.nodes)) {
        if ([string]::IsNullOrWhiteSpace($node.id) -or -not $nodePositions.ContainsKey($node.id)) { continue }
        $pos   = $nodePositions[$node.id]
        $grp   = $pos.group
        $relX  = 8
        $relY  = $pos.y - (($nodePositions.Values | Where-Object { $_.group -eq $grp } | Measure-Object -Property y -Minimum).Minimum - 30) + 24

        $labelText = if ($node.detail) { '{0}&#xa;{1}' -f $node.label, $node.detail } else { [string]$node.label }
        $lbl   = [System.Security.SecurityElement]::Escape($labelText)
        $style = switch ($node.kind) {
            'cluster'    { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#dbeafe;strokeColor=#2563eb;fontStyle=1;' }
            'node'       { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#dcfce7;strokeColor=#16a34a;' }
            'azure'      { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#cffafe;strokeColor=#0f766e;' }
            'storage'    { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#e2e8f0;strokeColor=#475569;' }
            'volume'     { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#f1f5f9;strokeColor=#64748b;' }
            'disk'       { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#f1f5f9;strokeColor=#94a3b8;' }
            'network'    { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#fde68a;strokeColor=#ca8a04;' }
            'adapter'    { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#fefce8;strokeColor=#a16207;' }
            'vm'         { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#fef3c7;strokeColor=#d97706;' }
            'workload'   { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#fefce8;strokeColor=#ca8a04;' }
            'management' { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#ede9fe;strokeColor=#7c3aed;' }
            'identity'   { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#fee2e2;strokeColor=#dc2626;' }
            'policy'     { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#fce7f3;strokeColor=#db2777;' }
            'bmc'        { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#e0f2fe;strokeColor=#0369a1;' }
            'hardware'   { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#f0fdf4;strokeColor=#15803d;' }
            'monitor'    { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#ecfdf5;strokeColor=#059669;' }
            'heat'       { if ($node.severity -eq 'warning') { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#fed7aa;strokeColor=#c2410c;' } else { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#dcfce7;strokeColor=#16a34a;' } }
            default      { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#f8fafc;strokeColor=#64748b;' }
        }
        $parentId = if ($containerIds.ContainsKey($grp)) { $containerIds[$grp] } else { '1' }
        $cells.Add(('<mxCell id="{0}" value="{1}" style="{2}" vertex="1" parent="{3}"><mxGeometry x="{4}" y="{5}" width="224" height="62" as="geometry" /></mxCell>' -f $node.id, $lbl, $style, $parentId, $relX, $relY))
    }

    # Emit edges (always parented to root)
    $edgeIndex = 0
    foreach ($edge in @($Model.edges)) {
        $edgeIndex++
        $edgeLbl = [System.Security.SecurityElement]::Escape([string]$edge.label)
        $cells.Add(('<mxCell id="edge-{0}" value="{1}" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;exitX=1;exitY=0.5;exitDx=0;exitDy=0;entryX=0;entryY=0.5;entryDx=0;entryDy=0;endArrow=block;endFill=1;strokeColor=#94a3b8;" edge="1" parent="1" source="{2}" target="{3}"><mxGeometry relative="1" as="geometry" /></mxCell>' -f $edgeIndex, $edgeLbl, $edge.source, $edge.target))
    }

    @"
<mxfile host="app.diagrams.net" modified="$($Manifest.run.endTimeUtc)" agent="AzureLocalRanger" version="$($Manifest.run.toolVersion)">
  <diagram name="$([System.Security.SecurityElement]::Escape($Definition.Title))">
    <mxGraphModel dx="1330" dy="844" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1700" pageHeight="1100" math="0" shadow="0">
      <root>
        $($cells -join [Environment]::NewLine)
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
"@
}

function ConvertTo-RangerSvgDiagram {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [object]$Definition,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Model
    )

    # Skip near-empty diagrams — fewer than 2 non-root nodes produces no useful output (#140)
    $nonRootNodes = @($Model.nodes | Where-Object { $_.id -ne 'cluster' })
    if ($nonRootNodes.Count -lt 1) {
        return $null
    }

    $boxes      = New-Object System.Collections.Generic.List[string]
    $connLines  = New-Object System.Collections.Generic.List[string]
    $labels     = New-Object System.Collections.Generic.List[string]
    $containers = New-Object System.Collections.Generic.List[string]

    # Group layout: each group gets a labelled container background (#140)
    $groupColumns = [ordered]@{ platform = 20; storage = 280; network = 540; workload = 800; azure = 1060; management = 1320; identity = 1580; hardware = 1840 }
    $groupLabels  = @{ platform = 'Platform'; storage = 'Storage'; network = 'Network'; workload = 'Workload'; azure = 'Azure'; management = 'Management'; identity = 'Identity'; hardware = 'Hardware' }
    $groupColors  = @{ platform = '#f0f9ff'; storage = '#f1f5f9'; network = '#fffbeb'; workload = '#fefce8'; azure = '#ecfeff'; management = '#f5f3ff'; identity = '#fff1f2'; hardware = '#f8fafc' }
    $groupBorder  = @{ platform = '#bae6fd'; storage = '#cbd5e1'; network = '#fde68a'; workload = '#fef08a'; azure = '#a5f3fc'; management = '#ddd6fe'; identity = '#fecdd3'; hardware = '#e2e8f0' }
    $groupOffsets = @{}
    $positions    = @{}

    # First pass: assign positions
    foreach ($node in @($Model.nodes)) {
        if ([string]::IsNullOrWhiteSpace($node.id)) { continue }
        $grp = if ($node.group -and $groupColumns.Contains([string]$node.group)) { [string]$node.group } else { 'platform' }
        if (-not $groupOffsets.ContainsKey($grp)) { $groupOffsets[$grp] = 80 }
        $positions[$node.id] = [ordered]@{ x = $groupColumns[$grp]; y = $groupOffsets[$grp]; group = $grp }
        $groupOffsets[$grp] += 86
    }

    # Draw group containers (sized to fit their contents)
    foreach ($grp in $groupColumns.Keys) {
        $grpNodes = @($positions.Values | Where-Object { $_.group -eq $grp })
        if ($grpNodes.Count -eq 0) { continue }
        $minY = ($grpNodes | Measure-Object -Property y -Minimum).Minimum - 10
        $maxY = ($grpNodes | Measure-Object -Property y -Maximum).Maximum + 76
        $cx = $groupColumns[$grp] - 8
        $cy = $minY
        $cw = 240
        $ch = $maxY - $minY
        $fill   = if ($groupColors.ContainsKey($grp)) { $groupColors[$grp] } else { '#f8fafc' }
        $stroke = if ($groupBorder.ContainsKey($grp)) { $groupBorder[$grp] } else { '#e2e8f0' }
        $glabel = if ($groupLabels.ContainsKey($grp)) { $groupLabels[$grp] } else { $grp }
        $containers.Add(("<rect x='$cx' y='$cy' width='$cw' height='$ch' rx='12' fill='$fill' stroke='$stroke' stroke-dasharray='4 2' />"))
        $containers.Add(("<text x='$($cx + 8)' y='$($cy + 16)' font-family=""Segoe UI, Arial"" font-size=""11"" font-weight=""600"" fill=""#64748b"">$([System.Security.SecurityElement]::Escape($glabel))</text>"))
    }

    # Draw nodes
    foreach ($node in @($Model.nodes)) {
        if ([string]::IsNullOrWhiteSpace($node.id) -or -not $positions.ContainsKey($node.id)) { continue }
        $pos  = $positions[$node.id]
        $x    = $pos.x
        $y    = $pos.y
        $fill = switch ($node.kind) {
            'cluster'     { '#dbeafe' }
            'node'        { '#dcfce7' }
            'azure'       { '#cffafe' }
            'vm'          { '#fef3c7' }
            'storage'     { '#e2e8f0' }
            'volume'      { '#f1f5f9' }
            'disk'        { '#f1f5f9' }
            'network'     { '#fde68a' }
            'adapter'     { '#fefce8' }
            'management'  { '#ede9fe' }
            'identity'    { '#fee2e2' }
            'policy'      { '#fce7f3' }
            'bmc'         { '#e0f2fe' }
            'hardware'    { '#f0fdf4' }
            'heat'        { if ($node.severity -eq 'warning') { '#fed7aa' } else { '#dcfce7' } }
            'monitor'     { '#ecfdf5' }
            'workload'    { '#fefce8' }
            'service'     { '#cffafe' }
            default       { '#f8fafc' }
        }
        $stroke = switch ($node.kind) {
            'cluster'  { '#2563eb' }
            'node'     { '#16a34a' }
            'azure'    { '#0f766e' }
            'storage'  { '#475569' }
            'network'  { '#ca8a04' }
            'vm'       { '#d97706' }
            'identity' { '#dc2626' }
            'bmc'      { '#0369a1' }
            'hardware' { '#15803d' }
            default    { '#64748b' }
        }
        $strokeW = if ($node.kind -eq 'cluster') { '2' } else { '1.5' }
        $boxes.Add(("<rect x='$x' y='$y' width='224' height='58' rx='10' fill='$fill' stroke='$stroke' stroke-width='$strokeW' />"))
        $labels.Add(("<text x='$($x + 10)' y='$($y + 24)' font-family=""Segoe UI, Arial"" font-size=""13"" font-weight=""600"" fill=""#0f172a"">$([System.Security.SecurityElement]::Escape([string]$node.label))</text>"))
        if ($node.detail) {
            $detailText = [string]$node.detail
            if ($detailText.Length -gt 34) { $detailText = $detailText.Substring(0, 31) + '…' }
            $labels.Add(("<text x='$($x + 10)' y='$($y + 42)' font-family=""Segoe UI, Arial"" font-size=""11"" fill=""#475569"">$([System.Security.SecurityElement]::Escape($detailText))</text>"))
        }
    }

    # Draw edges
    foreach ($edge in @($Model.edges)) {
        if ([string]::IsNullOrWhiteSpace($edge.source) -or [string]::IsNullOrWhiteSpace($edge.target)) { continue }
        if (-not $positions.ContainsKey($edge.source) -or -not $positions.ContainsKey($edge.target)) { continue }
        $src = $positions[$edge.source]
        $tgt = $positions[$edge.target]
        $x1  = $src.x + 224
        $y1  = $src.y + 29
        $x2  = $tgt.x
        $y2  = $tgt.y + 29
        # Use a mid-point curve for cleaner routing
        $mx  = [math]::Round(($x1 + $x2) / 2, 0)
        $connLines.Add(("<path d='M $x1 $y1 C $mx $y1 $mx $y2 $x2 $y2' fill='none' stroke='#94a3b8' stroke-width='1.5' marker-end='url(#arrow)' />"))
        if ($edge.label) {
            $edgeLabelX = [math]::Round(($x1 + $x2) / 2, 0)
            $edgeLabelY = [math]::Round(($y1 + $y2) / 2 - 5, 0)
            $labels.Add(("<text x='$edgeLabelX' y='$edgeLabelY' font-family=""Segoe UI, Arial"" font-size=""10"" fill=""#64748b"" text-anchor=""middle"">$([System.Security.SecurityElement]::Escape([string]$edge.label))</text>"))
        }
    }

    # Calculate canvas height dynamically
    $maxY = 900
    if ($groupOffsets.Count -gt 0) {
        $maxGroupY = ($groupOffsets.Values | Measure-Object -Maximum).Maximum
        $maxY = [math]::Max(900, $maxGroupY + 60)
    }
    $canvasW = 2080

    @"
<svg xmlns="http://www.w3.org/2000/svg" width="$canvasW" height="$maxY" viewBox="0 0 $canvasW $maxY">
  <defs>
    <marker id="arrow" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
      <polygon points="0 0, 8 3, 0 6" fill="#94a3b8" />
    </marker>
  </defs>
  <rect width="$canvasW" height="$maxY" fill="#f8fafc" />
  <rect x="0" y="0" width="$canvasW" height="62" fill="#1e3a5f" />
  <text x="20" y="34" font-family="Segoe UI, Arial" font-size="20" font-weight="700" fill="#ffffff">$([System.Security.SecurityElement]::Escape($Definition.Title))</text>
  <text x="20" y="54" font-family="Segoe UI, Arial" font-size="11" fill="#93c5fd">$([System.Security.SecurityElement]::Escape($Manifest.target.environmentLabel)) | $([System.Security.SecurityElement]::Escape($Manifest.run.endTimeUtc)) | Ranger $([System.Security.SecurityElement]::Escape($Manifest.run.toolVersion))</text>
  $($containers -join [Environment]::NewLine)
  $($connLines -join [Environment]::NewLine)
  $($boxes -join [Environment]::NewLine)
  $($labels -join [Environment]::NewLine)
</svg>
"@
}