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
        'fabric-map' { return $Manifest.topology.deploymentType -in @('rack-aware', 'multi-rack') }
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
    [void]$nodes.Add([ordered]@{ id = 'cluster'; label = $clusterName; kind = 'cluster' })

    switch ($Definition.Name) {
        'physical-architecture' {
            foreach ($node in @($Manifest.domains.clusterNode.nodes)) {
                $nodeId = 'node-' + (Get-RangerSafeName -Value $node.name)
                [void]$nodes.Add([ordered]@{ id = $nodeId; label = $node.name; kind = 'node' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $nodeId; label = $node.state })
            }
        }
        'logical-network-topology' {
            foreach ($network in @($Manifest.domains.clusterNode.networks)) {
                $networkId = 'network-' + (Get-RangerSafeName -Value $network.name)
                [void]$nodes.Add([ordered]@{ id = $networkId; label = $network.name; kind = 'network' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $networkId; label = $network.role })
            }
        }
        'storage-architecture' {
            foreach ($pool in @($Manifest.domains.storage.pools)) {
                $poolId = 'pool-' + (Get-RangerSafeName -Value $pool.friendlyName)
                [void]$nodes.Add([ordered]@{ id = $poolId; label = $pool.friendlyName; kind = 'storage' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $poolId; label = $pool.healthStatus })
            }
            foreach ($csv in @($Manifest.domains.storage.csvs)) {
                $csvId = 'csv-' + (Get-RangerSafeName -Value $csv.name)
                [void]$nodes.Add([ordered]@{ id = $csvId; label = $csv.name; kind = 'volume' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $csvId; label = $csv.state })
            }
        }
        'vm-placement-map' {
            foreach ($vm in @($Manifest.domains.virtualMachines.inventory)) {
                $vmId = 'vm-' + (Get-RangerSafeName -Value $vm.name)
                [void]$nodes.Add([ordered]@{ id = $vmId; label = $vm.name; kind = 'vm' })
                [void]$edges.Add([ordered]@{ source = ('node-' + (Get-RangerSafeName -Value $vm.hostNode)); target = $vmId; label = $vm.state })
            }
        }
        'azure-arc-integration' {
            foreach ($resource in @($Manifest.domains.azureIntegration.resources | Select-Object -First 10)) {
                $resourceId = 'az-' + (Get-RangerSafeName -Value $resource.name)
                [void]$nodes.Add([ordered]@{ id = $resourceId; label = $resource.name; kind = 'azure' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $resourceId; label = $resource.resourceType })
            }
        }
        'workload-services-map' {
            foreach ($family in @($Manifest.domains.virtualMachines.workloadFamilies)) {
                $familyId = 'workload-' + (Get-RangerSafeName -Value $family.name)
                [void]$nodes.Add([ordered]@{ id = $familyId; label = $family.name; kind = 'workload' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $familyId; label = $family.count })
            }
            foreach ($service in @($Manifest.domains.azureIntegration.services | Select-Object -First 8)) {
                $serviceId = 'service-' + (Get-RangerSafeName -Value $service.name)
                [void]$nodes.Add([ordered]@{ id = $serviceId; label = $service.name; kind = 'service' })
                [void]$edges.Add([ordered]@{ source = 'cluster'; target = $serviceId; label = $service.category })
            }
        }
        default {
            foreach ($required in @($Definition.Required)) {
                $requiredId = 'domain-' + (Get-RangerSafeName -Value $required)
                [void]$nodes.Add([ordered]@{ id = $requiredId; label = $required; kind = 'domain' })
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

    $x = 40
    $y = 40
    foreach ($node in @($Model.nodes)) {
        $label = [System.Security.SecurityElement]::Escape([string]$node.label)
        $style = switch ($node.kind) {
            'cluster' { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#dbeafe;strokeColor=#2563eb;' }
            'node' { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#dcfce7;strokeColor=#16a34a;' }
            'azure' { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#cffafe;strokeColor=#0f766e;' }
            default { 'rounded=1;whiteSpace=wrap;html=1;fillColor=#f8fafc;strokeColor=#64748b;' }
        }

        $cells.Add(('<mxCell id="{0}" value="{1}" style="{2}" vertex="1" parent="1"><mxGeometry x="{3}" y="{4}" width="180" height="60" as="geometry" /></mxCell>' -f $node.id, $label, $style, $x, $y))
        $y += 90
        if ($y -gt 520) {
            $y = 40
            $x += 240
        }
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
    $x = 20
    $y = 70
    $positions = @{}
    foreach ($node in @($Model.nodes)) {
        $positions[$node.id] = [ordered]@{ x = $x; y = $y }
        $fill = switch ($node.kind) {
            'cluster' { '#dbeafe' }
            'node' { '#dcfce7' }
            'azure' { '#cffafe' }
            'vm' { '#fef3c7' }
            default { '#f8fafc' }
        }

        $boxes.Add(('<rect x="{0}" y="{1}" width="220" height="56" rx="10" fill="{2}" stroke="#334155" />' -f $x, $y, $fill))
        $boxes.Add(('<text x="{0}" y="{1}" font-family="Segoe UI, Arial" font-size="14" fill="#0f172a">{2}</text>' -f ($x + 12), ($y + 30), [System.Security.SecurityElement]::Escape([string]$node.label)))
        $y += 86
        if ($y -gt 560) {
            $y = 70
            $x += 280
        }
    }

    foreach ($edge in @($Model.edges)) {
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
    }

    @"
<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900" viewBox="0 0 1600 900">
  <rect width="1600" height="900" fill="#ffffff" />
  <text x="20" y="36" font-family="Segoe UI, Arial" font-size="24" fill="#0f172a">$([System.Security.SecurityElement]::Escape($Definition.Title))</text>
  <text x="20" y="56" font-family="Segoe UI, Arial" font-size="12" fill="#475569">$([System.Security.SecurityElement]::Escape($Manifest.target.environmentLabel)) | Generated $([System.Security.SecurityElement]::Escape($Manifest.run.endTimeUtc)) | Ranger $([System.Security.SecurityElement]::Escape($Manifest.run.toolVersion))</text>
  $($lines -join [Environment]::NewLine)
  $($boxes -join [Environment]::NewLine)
</svg>
"@
}