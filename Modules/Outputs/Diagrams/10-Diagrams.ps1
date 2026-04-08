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
            $svgPath = Join-Path -Path $diagramsRoot -ChildPath ($baseName + '.svg')
            (ConvertTo-RangerSvgDiagram -Manifest $Manifest -Definition $definition -Model $model) | Set-Content -Path $svgPath -Encoding UTF8
            [void]$artifacts.Add((New-RangerArtifactRecord -Type 'diagram-svg' -RelativePath ([System.IO.Path]::GetRelativePath($PackageRoot, $svgPath)) -Status generated -Audience ($definition.Audience -join ',')))
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
            foreach ($profile in @($Manifest.domains.networking.firewall | Select-Object -First 10)) {
                $profileId = 'fw-' + (Get-RangerSafeName -Value $profile.node)
                [void]$nodes.Add([ordered]@{ id = $profileId; label = $profile.node; kind = 'firewall'; detail = ('profiles {0}' -f @($profile.profiles).Count); group = 'network' })
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

    $cells = New-Object System.Collections.Generic.List[string]
    $cells.Add('<mxCell id="0" />')
    $cells.Add('<mxCell id="1" parent="0" />')

    $groupColumns = [ordered]@{ platform = 40; storage = 320; network = 600; workload = 880; azure = 1160; management = 1440; identity = 1720; hardware = 2000 }
    $groupOffsets = @{}
    foreach ($node in @($Model.nodes)) {
        $labelText = if ($node.detail) { '{0}&#xa;{1}' -f $node.label, $node.detail } else { [string]$node.label }
        $label = [System.Security.SecurityElement]::Escape($labelText)
        $style = switch ($node.kind) {
            'cluster' { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#dbeafe;strokeColor=#2563eb;' }
            'node' { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#dcfce7;strokeColor=#16a34a;' }
            'azure' { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#cffafe;strokeColor=#0f766e;' }
            'storage' { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#e2e8f0;strokeColor=#475569;' }
            'network' { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#fde68a;strokeColor=#ca8a04;' }
            'vm' { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#fef3c7;strokeColor=#d97706;' }
            'management' { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#ede9fe;strokeColor=#7c3aed;' }
            'identity' { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#fee2e2;strokeColor=#dc2626;' }
            default { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#f8fafc;strokeColor=#64748b;' }
        }

        $group = if ($node.group) { [string]$node.group } else { 'platform' }
        if (-not $groupColumns.Contains($group)) {
            $group = 'platform'
        }
        if (-not $groupOffsets.ContainsKey($group)) {
            $groupOffsets[$group] = 40
        }
        $x = $groupColumns[$group]
        $y = $groupOffsets[$group]

        $cells.Add(('<mxCell id="{0}" value="{1}" style="{2}" vertex="1" parent="1"><mxGeometry x="{3}" y="{4}" width="180" height="60" as="geometry" /></mxCell>' -f $node.id, $label, $style, $x, $y))
        $groupOffsets[$group] = $y + 90
    }

    $edgeIndex = 0
    foreach ($edge in @($Model.edges)) {
        $edgeIndex++
        $cells.Add(('<mxCell id="edge-{0}" value="{1}" style="endArrow=block;html=1;rounded=0;" edge="1" parent="1" source="{2}" target="{3}"><mxGeometry relative="1" as="geometry" /></mxCell>' -f $edgeIndex, [System.Security.SecurityElement]::Escape([string]$edge.label), $edge.source, $edge.target))
    }

    @"
<mxfile host="app.diagrams.net" modified="$($Manifest.run.endTimeUtc)" agent="AzureLocalRanger" version="$($Manifest.run.toolVersion)">
  <diagram name="$([System.Security.SecurityElement]::Escape($Definition.Title))">
    <mxGraphModel dx="1330" dy="844" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1600" pageHeight="900" math="0" shadow="0">
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

    $boxes = New-Object System.Collections.Generic.List[string]
    $lines = New-Object System.Collections.Generic.List[string]
    $labels = New-Object System.Collections.Generic.List[string]
    $groupColumns = [ordered]@{ platform = 20; storage = 280; network = 540; workload = 800; azure = 1060; management = 1320; identity = 1580; hardware = 1840 }
    $groupOffsets = @{}
    $positions = @{}
    foreach ($node in @($Model.nodes)) {
        if ([string]::IsNullOrWhiteSpace($node.id)) { continue }
        $group = if ($node.group) { [string]$node.group } else { 'platform' }
        if (-not $groupColumns.Contains($group)) {
            $group = 'platform'
        }
        if (-not $groupOffsets.ContainsKey($group)) {
            $groupOffsets[$group] = 70
        }
        $x = $groupColumns[$group]
        $y = $groupOffsets[$group]
        $positions[$node.id] = [ordered]@{ x = $x; y = $y }
        $fill = switch ($node.kind) {
            'cluster' { '#dbeafe' }
            'node' { '#dcfce7' }
            'azure' { '#cffafe' }
            'vm' { '#fef3c7' }
            'storage' { '#e2e8f0' }
            'network' { '#fde68a' }
            'management' { '#ede9fe' }
            'identity' { '#fee2e2' }
            'heat' { if ($node.severity -eq 'warning') { '#fed7aa' } else { '#dcfce7' } }
            default { '#f8fafc' }
        }

        $boxes.Add(('<rect x="{0}" y="{1}" width="220" height="56" rx="10" fill="{2}" stroke="#334155" />' -f $x, $y, $fill))
        $labels.Add(('<text x="{0}" y="{1}" font-family="Segoe UI, Arial" font-size="14" fill="#0f172a">{2}</text>' -f ($x + 12), ($y + 25), [System.Security.SecurityElement]::Escape([string]$node.label)))
        if ($node.detail) {
            $labels.Add(('<text x="{0}" y="{1}" font-family="Segoe UI, Arial" font-size="11" fill="#475569">{2}</text>' -f ($x + 12), ($y + 42), [System.Security.SecurityElement]::Escape([string]$node.detail)))
        }

        $groupOffsets[$group] = $y + 86
    }

    foreach ($edge in @($Model.edges)) {
        if ([string]::IsNullOrWhiteSpace($edge.source) -or [string]::IsNullOrWhiteSpace($edge.target)) { continue }
        if (-not $positions.Contains($edge.source) -or -not $positions.Contains($edge.target)) {
            continue
        }

        $source = $positions[$edge.source]
        $target = $positions[$edge.target]
        $x1 = $source.x + 220
        $y1 = $source.y + 28
        $x2 = $target.x
        $y2 = $target.y + 28
        $lines.Add(('<line x1="{0}" y1="{1}" x2="{2}" y2="{3}" stroke="#64748b" stroke-width="2" />' -f $x1, $y1, $x2, $y2))
                if ($edge.label) {
                        $labels.Add(('<text x="{0}" y="{1}" font-family="Segoe UI, Arial" font-size="10" fill="#334155">{2}</text>' -f ([math]::Round((($x1 + $x2) / 2), 0)), ([math]::Round((($y1 + $y2) / 2) - 4, 0)), [System.Security.SecurityElement]::Escape([string]$edge.label)))
                }
    }

    @"
<svg xmlns="http://www.w3.org/2000/svg" width="2200" height="900" viewBox="0 0 2200 900">
    <rect width="2200" height="900" fill="#ffffff" />
  <text x="20" y="36" font-family="Segoe UI, Arial" font-size="24" fill="#0f172a">$([System.Security.SecurityElement]::Escape($Definition.Title))</text>
  <text x="20" y="56" font-family="Segoe UI, Arial" font-size="12" fill="#475569">$([System.Security.SecurityElement]::Escape($Manifest.target.environmentLabel)) | Generated $([System.Security.SecurityElement]::Escape($Manifest.run.endTimeUtc)) | Ranger $([System.Security.SecurityElement]::Escape($Manifest.run.toolVersion))</text>
  $($lines -join [Environment]::NewLine)
  $($boxes -join [Environment]::NewLine)
    $($labels -join [Environment]::NewLine)
</svg>
"@
}