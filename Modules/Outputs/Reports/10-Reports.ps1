function Invoke-RangerOutputGeneration {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [string]$PackageRoot,

        [string[]]$Formats = @('html', 'markdown', 'svg'),
        [string]$Mode
    )

    $artifacts = New-Object System.Collections.ArrayList
    $normalizedFormats = @($Formats | ForEach-Object { $_.ToLowerInvariant() } | Select-Object -Unique)
    $reportFormats = @($normalizedFormats | Where-Object { $_ -in @('html', 'markdown', 'md', 'docx', 'xlsx', 'pdf') })
    $diagramFormats = @($normalizedFormats | Where-Object { $_ -in @('svg', 'drawio', 'xml') })

    # v1.5.0 (#192): render diagrams first so HTML reports can inline the SVGs.
    if ($diagramFormats.Count -gt 0) {
        foreach ($artifact in (Invoke-RangerDiagramGeneration -Manifest $Manifest -PackageRoot $PackageRoot -Formats $diagramFormats -Mode $Mode)) {
            [void]$artifacts.Add($artifact)
        }
    }

    if ($reportFormats.Count -gt 0) {
        foreach ($artifact in (Write-RangerReportArtifacts -Manifest $Manifest -PackageRoot $PackageRoot -Formats $reportFormats -Mode $Mode)) {
            [void]$artifacts.Add($artifact)
        }
    }

    # v2.0.0 (#229): JSON evidence — raw inventory only, no scoring/run metadata.
    if ('json-evidence' -in $normalizedFormats -and (Get-Command -Name 'Write-RangerJsonEvidenceExport' -ErrorAction SilentlyContinue)) {
        try {
            $jeArtifact = Write-RangerJsonEvidenceExport -Manifest $Manifest -PackageRoot $PackageRoot
            if ($jeArtifact) {
                [void]$artifacts.Add((New-RangerArtifactRecord -Type 'json-evidence' -RelativePath $jeArtifact.relativePath -Status generated -Audience 'all'))
            }
        } catch {
            Write-RangerLog -Level warn -Message "JSON evidence export failed: $($_.Exception.Message)"
        }
    }

    # v2.5.0 (#80): PowerPoint deck output.
    if ('pptx' -in $normalizedFormats -and (Get-Command -Name 'New-RangerPptxDeck' -ErrorAction SilentlyContinue)) {
        try {
            $reportsRoot = Join-Path -Path $PackageRoot -ChildPath 'reports'
            New-Item -ItemType Directory -Path $reportsRoot -Force | Out-Null
            $prefix = Get-RangerArtifactPrefix -Manifest $Manifest
            $pptxPath = Join-Path $reportsRoot ("$prefix-executive.pptx")
            $null = New-RangerPptxDeck -Manifest $Manifest -OutputPath $pptxPath
            [void]$artifacts.Add((New-RangerArtifactRecord -Type 'pptx' -RelativePath ([System.IO.Path]::GetRelativePath($PackageRoot, $pptxPath)) -Status generated -Audience 'management'))
        } catch {
            Write-RangerLog -Level warn -Message "PPTX export failed: $($_.Exception.Message)"
        }
    }

    # v1.6.0 (#210): Power BI CSV + star-schema bundle.
    if ('powerbi' -in $normalizedFormats) {
        $pbiRoot = Join-Path -Path $PackageRoot -ChildPath 'powerbi'
        try {
            Invoke-RangerPowerBiExport -Manifest $Manifest -OutputRoot $pbiRoot | Out-Null
            foreach ($f in @(Get-ChildItem -Path $pbiRoot -File -ErrorAction SilentlyContinue)) {
                [void]$artifacts.Add((New-RangerArtifactRecord -Type 'powerbi-bundle' -RelativePath ([System.IO.Path]::GetRelativePath($PackageRoot, $f.FullName)) -Status generated -Audience 'technical'))
            }
        } catch {
            Write-RangerLog -Level warn -Message "Power BI export failed: $($_.Exception.Message)"
        }
    }

    $readmePath = Write-RangerPackageReadme -Manifest $Manifest -PackageRoot $PackageRoot
    [void]$artifacts.Add((New-RangerArtifactRecord -Type 'package-readme' -RelativePath ([System.IO.Path]::GetRelativePath($PackageRoot, $readmePath)) -Status generated -Audience 'all'))

    return [ordered]@{
        Artifacts = @($artifacts)
    }
}

function Write-RangerReportArtifacts {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [string]$PackageRoot,

        [Parameter(Mandatory = $true)]
        [string[]]$Formats,

        [string]$Mode
    )

    $reportsRoot = Join-Path -Path $PackageRoot -ChildPath 'reports'
    New-Item -ItemType Directory -Path $reportsRoot -Force | Out-Null
    $prefix = Get-RangerArtifactPrefix -Manifest $Manifest
    $artifacts = New-Object System.Collections.ArrayList
    $tierPayloads = New-Object System.Collections.ArrayList

    foreach ($tier in (Get-RangerReportTierDefinitions -Mode $Mode)) {
        $content = New-RangerReportPayload -Manifest $Manifest -Tier $tier.Name -Mode $Mode
        [void]$tierPayloads.Add([ordered]@{ Definition = $tier; Content = $content })
        if ('markdown' -in $Formats -or 'md' -in $Formats) {
            $markdownPath = Join-Path -Path $reportsRoot -ChildPath ("{0}-{1}.md" -f $prefix, (Get-RangerSafeName -Value $tier.Title))
            (ConvertTo-RangerMarkdownReport -Report $content) | Set-Content -Path $markdownPath -Encoding UTF8
            [void]$artifacts.Add((New-RangerArtifactRecord -Type 'markdown-report' -RelativePath ([System.IO.Path]::GetRelativePath($PackageRoot, $markdownPath)) -Status generated -Audience $tier.Audience))
        }

        if ('html' -in $Formats) {
            $htmlPath = Join-Path -Path $reportsRoot -ChildPath ("{0}-{1}.html" -f $prefix, (Get-RangerSafeName -Value $tier.Title))
            $diagramsPath = Join-Path -Path $PackageRoot -ChildPath 'diagrams'
            (ConvertTo-RangerHtmlReport -Report $content -DiagramsPath $diagramsPath) | Set-Content -Path $htmlPath -Encoding UTF8
            [void]$artifacts.Add((New-RangerArtifactRecord -Type 'html-report' -RelativePath ([System.IO.Path]::GetRelativePath($PackageRoot, $htmlPath)) -Status generated -Audience $tier.Audience))
        }

        if ('docx' -in $Formats) {
            $docxPath = Join-Path -Path $reportsRoot -ChildPath ("{0}-{1}.docx" -f $prefix, (Get-RangerSafeName -Value $tier.Title))
            Write-RangerDocxReport -Report $content -Path $docxPath
            [void]$artifacts.Add((New-RangerArtifactRecord -Type 'docx-report' -RelativePath ([System.IO.Path]::GetRelativePath($PackageRoot, $docxPath)) -Status generated -Audience $tier.Audience))
        }

        if ('pdf' -in $Formats) {
            $pdfPath = Join-Path -Path $reportsRoot -ChildPath ("{0}-{1}.pdf" -f $prefix, (Get-RangerSafeName -Value $tier.Title))
            # v1.6.0 (#207): prefer headless Edge / Chrome for a high-fidelity PDF
            # rendered from the HTML report. Fall back to the plain-text writer
            # when no browser is available.
            $renderedViaBrowser = $false
            if ('html' -in $Formats) {
                $htmlSrc = Join-Path -Path $reportsRoot -ChildPath ("{0}-{1}.html" -f $prefix, (Get-RangerSafeName -Value $tier.Title))
                if (Test-Path -Path $htmlSrc -PathType Leaf) {
                    $renderedViaBrowser = Invoke-RangerHeadlessPdf -HtmlPath $htmlSrc -OutputPath $pdfPath
                }
            }
            if (-not $renderedViaBrowser) {
                Write-RangerPdfReport -Report $content -Path $pdfPath
            }
            [void]$artifacts.Add((New-RangerArtifactRecord -Type 'pdf-report' -RelativePath ([System.IO.Path]::GetRelativePath($PackageRoot, $pdfPath)) -Status generated -Audience $tier.Audience))
        }
    }

    if ('xlsx' -in $Formats) {
        $workbookPath = Join-Path -Path $reportsRoot -ChildPath ("{0}-delivery-registers.xlsx" -f $prefix)
        Write-RangerExcelWorkbook -Manifest $Manifest -Path $workbookPath
        [void]$artifacts.Add((New-RangerArtifactRecord -Type 'xlsx-workbook' -RelativePath ([System.IO.Path]::GetRelativePath($PackageRoot, $workbookPath)) -Status generated -Audience 'technical'))
    }

    return @($artifacts)
}

# Issue #73: Inline SVG traffic light indicator (green/yellow/red/gray)
function New-RangerTrafficLightSvg {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('green', 'yellow', 'red', 'gray')]
        [string]$Color,
        [int]$Size = 16
    )
    $fill = switch ($Color) {
        'green'  { '#22c55e' }
        'yellow' { '#f59e0b' }
        'red'    { '#ef4444' }
        default  { '#94a3b8' }
    }
    $cx = [int][math]::Round($Size / 2); $r = [int][math]::Round($Size / 2 - 1)
    "<svg xmlns='http://www.w3.org/2000/svg' width='$Size' height='$Size' style='display:inline-block;vertical-align:middle'><circle cx='$cx' cy='$cx' r='$r' fill='$fill'/></svg>"
}

# Issue #73: Inline SVG horizontal capacity bar
function New-RangerCapacityBarSvg {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [double]$Percent,
        [int]$Width = 160,
        [int]$Height = 12
    )
    $pct = [math]::Max(0, [math]::Min(100, [double]$Percent))
    $fill = if ($pct -ge 85) { '#ef4444' } elseif ($pct -ge 70) { '#f59e0b' } else { '#3b82f6' }
    $barW = [int][math]::Round($pct / 100 * $Width)
    "<svg xmlns='http://www.w3.org/2000/svg' width='$Width' height='$Height' style='vertical-align:middle;margin-right:6px'><rect width='$Width' height='$Height' rx='2' fill='#e2e8f0'/><rect width='$barW' height='$Height' rx='2' fill='$fill'/></svg>$([math]::Round($pct,1))%"
}

function New-RangerReportPayload {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [ValidateSet('executive', 'management', 'technical')]
        [string]$Tier,

        [string]$Mode
    )

    $summary = Get-RangerManifestSummary -Manifest $Manifest
    $allFindings = @($Manifest.findings)
    $findings = switch ($Tier) {
        'executive' { @($allFindings | Where-Object { $_.severity -in @('critical', 'warning') } | Select-Object -First 8) }
        'management' { @($allFindings | Select-Object -First 15) }
        default { $allFindings }
    }

    $recommendations = @(
        $findings |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.recommendation) } |
            Select-Object -First 8 |
            ForEach-Object {
                [ordered]@{
                    title          = $_.title
                    severity       = $_.severity
                    recommendation = $_.recommendation
                }
            }
    )

    $collectorCards = @(
        $Manifest.collectors.Keys |
            Sort-Object |
            ForEach-Object {
                [ordered]@{
                    collector = $_
                    status    = $Manifest.collectors[$_].status
                    targets   = @($Manifest.collectors[$_].targetScope) -join ', '
                }
            }
    )

    $topologyBody = @(
        "Deployment type: $($summary.DeploymentType)",
        "Identity mode: $($summary.IdentityMode)",
        "Connectivity mode: $($summary.ControlPlaneMode)",
        "Storage architecture: $($Manifest.topology.storageArchitecture)",
        "Network architecture: $($Manifest.topology.networkArchitecture)",
        "Variant markers: $((@($Manifest.topology.variantMarkers) -join ', '))"
    )

    $collectorStatusLines = @(
        $collectorCards | ForEach-Object {
            '{0}: {1} ({2})' -f $_.collector, $_.status, $_.targets
        }
    )

    $readinessBody = @(
        "Schema validation: $(if ($Manifest.run.schemaValidation.isValid) { 'passed' } elseif ($null -eq $Manifest.run.schemaValidation.isValid) { 'not recorded' } else { 'failed' })",
        "Critical findings: $($summary.FindingsBySeverity.critical)",
        "Warning findings: $($summary.FindingsBySeverity.warning)",
        "Informational findings: $($summary.FindingsBySeverity.informational)",
        "Successful collectors: $($summary.SuccessfulCollectors) of $($summary.TotalCollectors)",
        "Partial or failed collectors: $($summary.PartialCollectors + $summary.FailedCollectors)"
    )

    $domainCoverageBody = @(
        "Cluster nodes: $($summary.NodeCount)",
        "Cluster roles: $(@($Manifest.domains.clusterNode.roles).Count)",
        "Storage pools: $(@($Manifest.domains.storage.pools).Count)",
        "Physical disks: $(@($Manifest.domains.storage.physicalDisks).Count)",
        "Network adapters: $(@($Manifest.domains.networking.adapters).Count)",
        "VMs discovered: $($summary.VmCount)",
        "Azure resources: $($summary.AzureResourceCount)",
        "Alerting resources: $(@($Manifest.domains.monitoring.alerts).Count)",
        "Management services: $(@($Manifest.domains.managementTools.tools).Count)"
    )

    $operationalRiskBody = @(
        "Nodes not healthy: $($Manifest.domains.clusterNode.healthSummary.unhealthy)",
        "Unhealthy disks: $($Manifest.domains.storage.summary.unhealthyDisks)",
        "High CPU nodes: $($Manifest.domains.performance.summary.highCpuNodes)",
        "Certificates expiring within 90 days: $($Manifest.domains.identitySecurity.summary.certificateExpiringWithin90Days)",
        "Azure Policy assignments: $($Manifest.domains.azureIntegration.policySummary.assignmentCount)",
        "Schema warnings: $(@($Manifest.run.schemaValidation.warnings).Count)",
        "Azure Advisor recommendations: $($Manifest.domains.wafAssessment.summary.totalAdvisorRecommendations) total, $($Manifest.domains.wafAssessment.summary.highImpactCount) high-impact"
    )

    $sections = New-Object System.Collections.ArrayList
    [void]$sections.Add([ordered]@{
        heading = 'Run Summary'
        body    = @(
            "Mode: $Mode",
            "Generated: $($Manifest.run.endTimeUtc)",
            "Cluster: $($summary.ClusterName)",
            "Nodes: $($summary.NodeCount)",
            "Collectors: $($summary.SuccessfulCollectors)/$($summary.TotalCollectors) successful",
            "Artifacts currently recorded: $(@($Manifest.artifacts).Count)"
        )
    })

    [void]$sections.Add([ordered]@{
        heading = 'Readiness Snapshot'
        body    = $readinessBody
    })

    # Issue #73: Health status section with traffic light indicators (current-state only —
    # as-built is a deployment record, not a live health dashboard). See #194.
    if ($Mode -ne 'as-built') {
    [void]$sections.Add([ordered]@{
        heading = 'Health Status'
        body    = @(
            "Overall health: $($summary.OverallHealthColor.ToUpperInvariant()) ($criticalCount critical, $warningCount warning findings)",
            "Azure integration: $($summary.AzureIntegrationColor.ToUpperInvariant()) ($($summary.AzureResourceCount) Azure resources discovered)",
            "Security posture: $($summary.SecurityPostureColor.ToUpperInvariant()) (Secured-Core enabled on $($Manifest.domains.identitySecurity.summary.securedCoreNodes) node(s))",
            "Monitoring coverage: $(if ($summary.MonitoringCoveragePercent -ge 100) { 'GREEN' } elseif ($summary.MonitoringCoveragePercent -gt 0) { 'YELLOW' } else { 'GRAY' }) ($($summary.MonitoringCoveragePercent)% of nodes have Azure Monitor Agent)"
        )
        _visualStats = [ordered]@{
            lights = @(
                [ordered]@{ label = 'Overall Health';       color = $summary.OverallHealthColor }
                [ordered]@{ label = 'Azure Integration';    color = $summary.AzureIntegrationColor }
                [ordered]@{ label = 'Security Posture';     color = $summary.SecurityPostureColor }
                [ordered]@{ label = 'Monitoring Coverage';  color = if ($summary.MonitoringCoveragePercent -ge 100) { 'green' } elseif ($summary.MonitoringCoveragePercent -gt 0) { 'yellow' } else { 'gray' } }
            )
        }
    })
    }

    [void]$sections.Add([ordered]@{
        heading = 'Environment Overview'
        body    = @(
            "VMs discovered: $($summary.VmCount)",
            "Azure resources discovered: $($summary.AzureResourceCount)",
            "Connected Azure auth method: $($Manifest.domains.azureIntegration.auth.method)",
            "Monitoring resources: $(@($Manifest.domains.monitoring.telemetry).Count + @($Manifest.domains.monitoring.ama).Count + @($Manifest.domains.monitoring.dcr).Count)",
            "Management services running: $($Manifest.domains.managementTools.summary.runningServices)"
        )
    })

    [void]$sections.Add([ordered]@{
        heading = 'Topology and Operating Model'
        body    = $topologyBody
    })

    [void]$sections.Add([ordered]@{
        heading = 'Domain Coverage'
        body    = $domainCoverageBody
    })

    # Node inventory table — management + technical (#168)
    if ($Tier -ne 'executive') {
        $nodeRows = @(
            @($Manifest.domains.clusterNode.nodes) | ForEach-Object {
                $n = $_
                $name    = if ($n.name)  { $n.name  } elseif ($n.NodeName) { $n.NodeName } else { '—' }
                $state   = if ($n.state) { $n.state } elseif ($n.NodeState) { $n.NodeState } else { '—' }
                $model   = if ($n.model) { $n.model } else { '—' }
                # Accept the canonical Arc / Get-ComputerInfo field names as
                # well as the legacy short aliases so all known manifest shapes
                # surface in the Node Inventory table.
                $os      = if ($n.osCaption) { $n.osCaption } elseif ($n.operatingSystem) { $n.operatingSystem } elseif ($n.os) { $n.os } else { '—' }
                $build   = if ($n.osVersion) { $n.osVersion } elseif ($n.osBuildNumber) { $n.osBuildNumber } elseif ($n.buildNumber) { $n.buildNumber } else { '—' }
                $cpus    = if ($null -ne $n.logicalProcessorCount) { [string]$n.logicalProcessorCount } elseif ($null -ne $n.processorCount) { [string]$n.processorCount } elseif ($null -ne $n.cpuSocketCount) { [string]$n.cpuSocketCount } else { '—' }
                $ramGiB  = if ($null -ne $n.totalMemoryGiB) { [string][math]::Round([double]$n.totalMemoryGiB, 0) } elseif ($null -ne $n.memoryGiB) { [string][math]::Round([double]$n.memoryGiB, 0) } else { '—' }
                ,@($name, $model, $state, $os, $build, $cpus, $ramGiB)
            }
        )
        [void]$sections.Add([ordered]@{
            heading = 'Node Inventory'
            type    = 'table'
            headers = @('Node', 'Model', 'State', 'OS', 'OS Version / Build', 'Logical CPUs', 'RAM (GiB)')
            rows    = $nodeRows
        })
    }

    if ($Tier -ne 'executive') {
        [void]$sections.Add([ordered]@{
            heading = 'Collector Status'
            body    = $collectorStatusLines
        })
    }

    [void]$sections.Add([ordered]@{
        heading = 'Operational Risk Summary'
        body    = $operationalRiskBody
    })

    # Issue #73: Workload Summary (executive + management + technical)
    [void]$sections.Add([ordered]@{
        heading = 'Workload Summary'
        body    = @(
            "Total VMs: $($summary.VmCount)",
            "Total nodes: $($summary.NodeCount)",
            "AKS clusters: $(@($Manifest.domains.azureIntegration.aksClusters).Count)",
            "Arc-connected machines: $(@($Manifest.domains.azureIntegration.arcMachineDetail).Count)",
            "Update compliance: $(if ($Manifest.domains.azureIntegration.summary.updateCount -gt 0) { "$($Manifest.domains.azureIntegration.summary.updateCount) update resource(s) tracked" } else { 'No update resources tracked' })",
            "Licensing: $(if ($Manifest.domains.azureIntegration.costLicensing.subscriptionName) { $Manifest.domains.azureIntegration.costLicensing.subscriptionName } else { 'Not collected' })",
            "VMs using Arc IP fallback: $(if ($Manifest.domains.virtualMachines.summary.vmsUsingArcIpFallback -ge 0) { $Manifest.domains.virtualMachines.summary.vmsUsingArcIpFallback } else { 'Not collected' })"
        )
    })

    # Issue #73: Capacity Summary with utilization text (all tiers)
    [void]$sections.Add([ordered]@{
        heading = 'Capacity Summary'
        body    = @(
            "Storage total raw: $([math]::Round($summary.StorageTotalRawGiB / 1024, 2)) TiB",
            "Storage total usable: $([math]::Round($summary.StorageTotalUsableGiB / 1024, 2)) TiB",
            "Storage used by workloads: $([math]::Round($summary.StorageUsedUsableGiB / 1024, 2)) TiB ($($summary.StorageUtilizationPct)% of usable)",
            "Storage reserve target: $([math]::Round($summary.StorageReserveTargetGiB / 1024, 2)) TiB ($($summary.StorageReservePercent)% of usable)",
            "Storage free usable: $([math]::Round($summary.StorageFreeUsableGiB / 1024, 2)) TiB",
            "Projected safe allocatable: $([math]::Round($summary.StorageSafeAllocatableGiB / 1024, 2)) TiB",
            "Thin provisioning ratio: $(if ($null -ne $summary.StorageThinProvisioningRatio) { "$($summary.StorageThinProvisioningRatio)x" } else { 'Not computed' })",
            "vCPU:pCPU overcommit ratio: $(if ($summary.VcpuOvercommitRatio) { $summary.VcpuOvercommitRatio } else { 'Not computed' })",
            "Memory overcommit ratio: $(if ($summary.MemoryOvercommitRatio) { $summary.MemoryOvercommitRatio } else { 'Not computed' })",
            "Average VMs per node: $(if ($summary.AvgVmsPerNode) { $summary.AvgVmsPerNode } else { 'N/A' })"
        )
        _visualStats = [ordered]@{
            bars = @(
                [ordered]@{ label = 'Storage used'; percent = $summary.StorageUtilizationPct }
                [ordered]@{ label = 'Storage reserve target'; percent = $summary.StorageReservePercent }
                [ordered]@{ label = 'Safe allocatable headroom'; percent = $summary.StorageSafePercent }
            )
        }
    })

    if ($Tier -eq 'management' -or $Tier -eq 'technical') {
        [void]$sections.Add([ordered]@{
            heading = 'Priority Recommendations'
            body    = @(
                if ($recommendations.Count -gt 0) {
                    $recommendations | ForEach-Object {
                        '[{0}] {1}: {2}' -f $_.severity.ToUpperInvariant(), $_.title, $_.recommendation
                    }
                }
                else {
                    'No recommendation-bearing findings were recorded for this manifest.'
                }
            )
        })

        # VM inventory table — management + technical (#168)
        $vmInventory = @($Manifest.domains.virtualMachines.inventory)
        if ($vmInventory.Count -gt 0) {
            $vmLimit = if ($Tier -eq 'technical') { 100 } else { 30 }
            $vmRows = @($vmInventory | Select-Object -First $vmLimit | ForEach-Object {
                $v = $_
                $vcpu   = if ($null -ne $v.processorCount) { [string]$v.processorCount } elseif ($null -ne $v.vCPU) { [string]$v.vCPU } else { '—' }
                $ramGiB = if ($null -ne $v.memoryAssignedMb) { [string][math]::Round([double]$v.memoryAssignedMb / 1024, 1) } else { '—' }
                $hostNode = if ($v.hostNode) { [string]$v.hostNode } else { '—' }
                $gen    = if ($v.generation) { [string]$v.generation } else { '—' }
                @([string]($v.name ?? '—'), [string]($v.state ?? '—'), $vcpu, $ramGiB, $hostNode, $gen)
            })
            $vmCaption = if ($vmInventory.Count -gt $vmLimit) { "Showing first $vmLimit of $($vmInventory.Count) VMs. Full inventory in audit-manifest.json." } else { $null }
            [void]$sections.Add([ordered]@{
                heading = 'VM Inventory'
                type    = 'table'
                headers = @('Name', 'State', 'vCPU', 'RAM (GiB)', 'Host Node', 'Generation')
                rows    = $vmRows
                caption = $vmCaption
            })
        }

        # VM Density Metrics (management + technical)
        [void]$sections.Add([ordered]@{
            heading = 'VM Density Metrics'
            body    = @(
                "VMs per node (average): $(if ($summary.AvgVmsPerNode) { $summary.AvgVmsPerNode } else { 'N/A' })",
                "Highest-density node: $(if ($Manifest.domains.virtualMachines.summary.highestDensityNode) { $Manifest.domains.virtualMachines.summary.highestDensityNode } else { 'N/A' })",
                "vCPU:pCPU overcommit ratio: $(if ($summary.VcpuOvercommitRatio) { $summary.VcpuOvercommitRatio } else { 'Not computed' })",
                "Memory overcommit ratio: $(if ($summary.MemoryOvercommitRatio) { $summary.MemoryOvercommitRatio } else { 'Not computed' })",
                "Arc-connected VMs: $($Manifest.domains.virtualMachines.summary.arcConnectedVms)",
                "VMs using Arc IP fallback: $($Manifest.domains.virtualMachines.summary.vmsUsingArcIpFallback)",
                "Avg CPU utilization (all nodes): $($Manifest.domains.performance.summary.averageCpuUtilizationPercent)%",
                "Avg available memory (all nodes): $([math]::Round([double]$Manifest.domains.performance.summary.averageAvailableMemoryMb / 1024, 1)) GiB"
            )
        })

        $poolAnalysis = @($Manifest.domains.storage.poolAnalysis)
        if ($poolAnalysis.Count -gt 0) {
            $poolRows = @($poolAnalysis | ForEach-Object {
                $p = $_
                @(
                    [string]($p.friendlyName ?? '—'),
                    [string][math]::Round([double]($p.rawCapacityGiB ?? 0), 0),
                    [string][math]::Round([double]($p.usableCapacityGiB ?? 0), 0),
                    [string][math]::Round([double]($p.usedUsableCapacityGiB ?? 0), 0),
                    [string][math]::Round([double]($p.recommendedReserveGiB ?? 0), 0),
                    [string][math]::Round([double]($p.projectedSafeAllocatableCapacityGiB ?? 0), 0),
                    [string]($p.posture ?? '—')
                )
            })
            [void]$sections.Add([ordered]@{
                heading = 'Storage Pool Capacity'
                type    = 'table'
                headers = @('Pool', 'Raw (GiB)', 'Usable (GiB)', 'Used (GiB)', 'Reserve (GiB)', 'Safe Alloc (GiB)', 'Posture')
                rows    = $poolRows
            })
        }

        $esuInventory = @($Manifest.domains.azureIntegration.costAnalysis.esuInventory)
        if ($esuInventory.Count -gt 0) {
            [void]$sections.Add([ordered]@{
                heading = 'ESU Enrollment'
                body    = @(
                    "Eligible Arc-connected VMs: $($Manifest.domains.azureIntegration.costAnalysis.summary.eligibleVmCount)",
                    "Enrolled in ESU: $($Manifest.domains.azureIntegration.costAnalysis.summary.enrolledVmCount)",
                    "Not enrolled in ESU: $($Manifest.domains.azureIntegration.costAnalysis.summary.notEnrolledVmCount)",
                    "Ineligible: $($Manifest.domains.azureIntegration.costAnalysis.summary.ineligibleVmCount)",
                    @($esuInventory | Select-Object -First 10 | ForEach-Object {
                        "- $($_.name): $(if ($_.detectedOs) { $_.detectedOs } else { $_.osName }) | eligibility=$($_.esuEligibility) | profile=$($_.esuProfileStatus)"
                    })
                )
            })
        }

        # Issue #73: Coverage Assessment (management + technical)
        [void]$sections.Add([ordered]@{
            heading = 'Coverage Assessment'
            body    = @(
                "Monitoring coverage (AMA): $($summary.MonitoringCoveragePercent)% ($($summary.AmaNodeCount) of $($summary.NodeCount) nodes have Azure Monitor Agent)",
                "Backup coverage estimate: $($summary.BackupCoveragePercent)% (based on backup items vs VM count)",
                "Defender for Cloud: $(if ($Manifest.domains.identitySecurity.defenderForCloud.enabled) { 'Enabled' } else { 'Not confirmed or not collected' })",
                "WDAC policy: $(if ($Manifest.domains.identitySecurity.security.wdacPolicy) { $Manifest.domains.identitySecurity.security.wdacPolicy } else { 'Not collected' })",
                "BitLocker status: $(if ($Manifest.domains.identitySecurity.security.bitlockerEnabled -eq $true) { 'Enabled' } elseif ($Manifest.domains.identitySecurity.security.bitlockerEnabled -eq $false) { 'Disabled' } else { 'Not collected' })",
                "Certificates expiring in <90 days: $($Manifest.domains.identitySecurity.summary.certificateExpiringWithin90Days)"
            )
            _visualStats = [ordered]@{
                bars = @(
                    [ordered]@{ label = 'Monitoring coverage (AMA)'; percent = $summary.MonitoringCoveragePercent }
                    [ordered]@{ label = 'Backup coverage'; percent = $summary.BackupCoveragePercent }
                )
            }
        })

        # Issue #73: Security Posture Summary (management + technical)
        [void]$sections.Add([ordered]@{
            heading = 'Security Posture Summary'
            body    = @(
                "Secured-Core enabled nodes: $($Manifest.domains.identitySecurity.summary.securedCoreNodes) of $($summary.NodeCount)",
                "Syslog forwarding nodes: $($Manifest.domains.identitySecurity.summary.syslogForwardingNodes)",
                "RBAC assignments at resource group: $(@($Manifest.domains.identitySecurity.rbacAssignments).Count)",
                "Policy assignments tracked: $($Manifest.domains.azureIntegration.policySummary.assignmentCount)",
                "Policy exemptions: $($Manifest.domains.azureIntegration.policySummary.exemptionCount)",
                "Active Directory site: $(if ($Manifest.domains.identitySecurity.activeDirectory.adSite) { $Manifest.domains.identitySecurity.activeDirectory.adSite } else { 'Not collected' })"
            )
        })

        # Issue #73: Management Tool Coverage (management + technical)
        [void]$sections.Add([ordered]@{
            heading = 'Management Tool Coverage'
            body    = @(
                "WAC installed nodes: $($Manifest.domains.managementTools.summary.wacInstalled) of $($summary.NodeCount)",
                "SCVMM agent nodes: $($Manifest.domains.managementTools.summary.scvmmNodes)",
                "SCOM agent nodes: $($Manifest.domains.managementTools.summary.scomNodes)",
                "Running management services: $($Manifest.domains.managementTools.summary.runningServices)",
                "Third-party agent types: $((@($Manifest.domains.managementTools.summary.thirdPartyTypes) | ForEach-Object { '{0} ({1})' -f $_.name, $_.count }) -join ', ')"
            )
        })
    }

    # v2.0.0 (#222, #228): Cost & Licensing with AHB + pricing footer (management + technical).
    if ($Tier -ne 'executive') {
        $cost = $Manifest.domains.azureIntegration.costLicensing
        if ($cost -and $cost.summary -and $null -ne $cost.summary.totalPhysicalCores) {
            $s = $cost.summary
            $priceDate = if ($cost.pricingReference -and $cost.pricingReference.asOfDate) { [string]$cost.pricingReference.asOfDate } else { (Get-Date).ToString('yyyy-MM-dd') }
            $priceUrl  = if ($cost.pricingReference -and $cost.pricingReference.url) { [string]$cost.pricingReference.url } else { 'https://azure.microsoft.com/en-us/pricing/details/azure-local/' }
            $costCurrency = if ($s.currency) { [string]$s.currency } else { 'USD' }
            [void]$sections.Add([ordered]@{
                heading = 'Cost & Licensing'
                body    = @(
                    "AHB status: $($cost.ahbStatus)",
                    "Total physical cores: $($s.totalPhysicalCores)  |  AHB-covered: $($s.coresWithAhb)  |  Unenrolled: $($s.coresWithoutAhb)",
                    "Current monthly cost: $([math]::Round([double]$s.currentMonthlyCostUsd, 2)) $costCurrency @ $([math]::Round([double]$s.costPerCoreUsd, 2))/core/month",
                    "AHB adoption: $($s.ahbAdoptionPct)%",
                    "Potential monthly savings (if remaining cores enrolled in AHB): $([math]::Round([double]$s.potentialMonthlySavingsUsd, 2)) $costCurrency",
                    "Pricing based on Azure Local public pricing ($([math]::Round([double]$s.costPerCoreUsd, 2)) $costCurrency/physical core/month) as of $priceDate.",
                    "For current rates, see: $priceUrl"
                )
                _visualStats = [ordered]@{
                    bars = @(
                        [ordered]@{ label = 'AHB adoption'; percent = [int][math]::Round([double]$s.ahbAdoptionPct) }
                    )
                }
            })

            if ($cost.perNode -and @($cost.perNode).Count -gt 0) {
                $perNodeRows = @($cost.perNode | ForEach-Object {
                    ,@(
                        [string]$_.node,
                        [string]$_.physicalCores,
                        $(if ($_.ahbEnabled) { 'Yes' } else { 'No' }),
                        [string][math]::Round([double]$_.monthlyCostUsd, 2),
                        [string][math]::Round([double]$_.monthlySavingUsd, 2)
                    )
                })
                [void]$sections.Add([ordered]@{
                    heading = 'Cost & Licensing — Per Node'
                    type    = 'table'
                    headers = @('Node', 'Physical Cores', 'AHB Enabled', "Monthly Cost ($costCurrency)", "Monthly Saving ($costCurrency)")
                    rows    = $perNodeRows
                    caption = "Pricing as of $priceDate — $priceUrl"
                })
            }
        }
    }

    # v2.0.0 (#215): Arc Extensions per node (technical-tier deep dive; summary in management).
    if ($Tier -ne 'executive') {
        $extDetail = $Manifest.domains.azureIntegration.arcExtensionsDetail
        if ($extDetail -and $extDetail.byNode) {
            $extRows = New-Object System.Collections.ArrayList
            foreach ($nodeBlock in @($extDetail.byNode)) {
                $nName = [string]$nodeBlock.node
                foreach ($e in @($nodeBlock.extensions)) {
                    [void]$extRows.Add(@(
                        $nName,
                        [string]($e.name ?? '—'),
                        [string]($e.type ?? '—'),
                        [string]($e.publisher ?? '—'),
                        [string]($e.typeHandlerVersion ?? '—'),
                        [string]($e.provisioningState ?? '—')
                    ))
                }
            }
            $caption = if ($extDetail.summary) { "AMA coverage: $($extDetail.summary.amaCoveragePct)% of nodes. Failed extensions: $($extDetail.summary.failedExtensionCount)." } else { $null }
            [void]$sections.Add([ordered]@{
                heading = 'Arc Extensions by Node'
                type    = 'table'
                headers = @('Node', 'Name', 'Type', 'Publisher', 'Version', 'State')
                rows    = @($extRows)
                caption = $caption
                _layout = 'landscape'
            })
        }
    }

    # v2.0.0 (#216): Logical Networks + subnet detail.
    if ($Tier -ne 'executive') {
        $lnets = @($Manifest.domains.networking.logicalNetworks | Where-Object { $_ })
        if ($lnets.Count -gt 0) {
            $lnetRows = @($lnets | ForEach-Object {
                ,@(
                    [string]$_.name,
                    [string]($_.vmSwitchName ?? '—'),
                    $(if ($_.dhcpEnabled) { 'Yes' } else { 'No' }),
                    [string](@($_.subnets).Count),
                    [string]($_.provisioningState ?? '—')
                )
            })
            [void]$sections.Add([ordered]@{
                heading = 'Logical Networks'
                type    = 'table'
                headers = @('Name', 'VM Switch', 'DHCP', 'Subnets', 'State')
                rows    = $lnetRows
            })
            # Subnets (flatten)
            $subnetRows = New-Object System.Collections.ArrayList
            foreach ($ln in $lnets) {
                foreach ($sn in @($ln.subnets)) {
                    [void]$subnetRows.Add(@(
                        [string]$ln.name,
                        [string]($sn.name ?? '—'),
                        [string]($sn.addressPrefix ?? '—'),
                        [string]($sn.vlan ?? '—'),
                        [string]($sn.ipPoolCount ?? '0')
                    ))
                }
            }
            if ($subnetRows.Count -gt 0) {
                [void]$sections.Add([ordered]@{
                    heading = 'Logical Network Subnets'
                    type    = 'table'
                    headers = @('Network', 'Subnet', 'Address Prefix', 'VLAN', 'IP Pools')
                    rows    = @($subnetRows)
                    _layout = 'landscape'
                })
            }
        }
    }

    # v2.0.0 (#217): Storage paths.
    if ($Tier -ne 'executive') {
        $sps = @($Manifest.domains.storage.storagePaths | Where-Object { $_ })
        if ($sps.Count -gt 0) {
            $spRows = @($sps | ForEach-Object {
                ,@(
                    [string]$_.name,
                    [string]($_.path ?? '—'),
                    [string]($_.availableSizeGB ?? '—'),
                    [string]($_.fileSystemType ?? '—'),
                    [string]($_.provisioningState ?? '—')
                )
            })
            [void]$sections.Add([ordered]@{
                heading = 'Storage Paths'
                type    = 'table'
                headers = @('Name', 'Path', 'Available (GB)', 'File System', 'State')
                rows    = $spRows
            })
        }
    }

    # v2.0.0 (#219, #218): Arc Resource Bridge + Custom Locations.
    if ($Tier -ne 'executive') {
        $rbs = @($Manifest.domains.azureIntegration.resourceBridgeDetail | Where-Object { $_ })
        if ($rbs.Count -gt 0) {
            $rbRows = @($rbs | ForEach-Object {
                ,@(
                    [string]$_.name,
                    [string]($_.status ?? '—'),
                    [string]($_.version ?? '—'),
                    [string]($_.distro ?? '—'),
                    [string]($_.provisioningState ?? '—')
                )
            })
            [void]$sections.Add([ordered]@{
                heading = 'Arc Resource Bridge'
                type    = 'table'
                headers = @('Name', 'Status', 'Version', 'Distro', 'Provisioning')
                rows    = $rbRows
            })
        }
        $cls = @($Manifest.domains.azureIntegration.customLocationsDetail | Where-Object { $_ })
        if ($cls.Count -gt 0) {
            $clRows = @($cls | ForEach-Object {
                ,@(
                    [string]$_.name,
                    [string]($_.namespace ?? '—'),
                    [string]($_.location ?? '—'),
                    [string]($_.provisioningState ?? '—')
                )
            })
            [void]$sections.Add([ordered]@{
                heading = 'Custom Locations'
                type    = 'table'
                headers = @('Name', 'Namespace', 'Location', 'State')
                rows    = $clRows
            })
        }
    }

    # v2.0.0 (#220): Arc Gateways.
    if ($Tier -ne 'executive') {
        $gws = @($Manifest.domains.azureIntegration.arcGateways | Where-Object { $_ })
        if ($gws.Count -gt 0) {
            $gwRows = @($gws | ForEach-Object {
                ,@(
                    [string]$_.name,
                    [string]($_.gatewayEndpoint ?? '—'),
                    [string](@($_.allowedFeatures) -join ', '),
                    [string]($_.provisioningState ?? '—')
                )
            })
            [void]$sections.Add([ordered]@{
                heading = 'Arc Gateways'
                type    = 'table'
                headers = @('Name', 'Endpoint', 'Allowed Features', 'State')
                rows    = $gwRows
            })
        }
    }

    # v2.0.0 (#221): Marketplace + Custom Gallery Images.
    if ($Tier -ne 'executive') {
        $mis = @(@($Manifest.domains.azureIntegration.marketplaceImages) + @($Manifest.domains.azureIntegration.galleryImages) | Where-Object { $_ })
        if ($mis.Count -gt 0) {
            $miRows = @($mis | ForEach-Object {
                ,@(
                    [string]$_.name,
                    [string]($_.imageType ?? '—'),
                    [string]($_.osType ?? '—'),
                    [string]($_.version ?? '—'),
                    [string]($_.sizeGB ?? '—'),
                    [string]($_.provisioningState ?? '—')
                )
            })
            [void]$sections.Add([ordered]@{
                heading = 'Marketplace & Custom Images'
                type    = 'table'
                headers = @('Name', 'Type', 'OS', 'Version', 'Size (GB)', 'State')
                rows    = $miRows
            })
        }
    }

    # v2.0.0 (#224): Arc agent version grouping.
    if ($Tier -ne 'executive') {
        $avGroups = @($Manifest.domains.clusterNode.nodeSummary.arcAgentVersionGroups | Where-Object { $_ })
        if ($avGroups.Count -gt 0) {
            $avRows = @($avGroups | ForEach-Object {
                ,@(
                    [string]$_.version,
                    [string]$_.nodeCount,
                    (@($_.nodeNames) -join ', ')
                )
            })
            $drift = $Manifest.domains.clusterNode.nodeSummary.agentVersionDrift
            $avCaption = if ($drift) { "Drift status: $($drift.status). Latest: $($drift.latestVersion). Max behind: $($drift.maxBehind)." } else { $null }
            [void]$sections.Add([ordered]@{
                heading = 'Arc Agent Versions'
                type    = 'table'
                headers = @('Version', 'Node Count', 'Nodes')
                rows    = $avRows
                caption = $avCaption
            })
        }
    }

    # v2.0.0 (#223): VM distribution balance.
    if ($Tier -ne 'executive') {
        $vmSummary = $Manifest.domains.virtualMachines.summary
        $dist = @($vmSummary.vmDistribution | Where-Object { $_ })
        if ($dist.Count -gt 0) {
            $distRows = @($dist | ForEach-Object { ,@([string]$_.node, [string]$_.vmCount) })
            $distCaption = "Balance: $(if ($vmSummary.vmDistributionBalanced) { 'balanced' } else { 'imbalanced' })  |  CV: $([math]::Round([double]$vmSummary.vmDistributionCv, 3))  |  Status: $($vmSummary.vmDistributionStatus)"
            [void]$sections.Add([ordered]@{
                heading = 'VM Distribution by Node'
                type    = 'table'
                headers = @('Node', 'VM Count')
                rows    = $distRows
                caption = $distCaption
            })
        }
    }

    # WAF Assessment scorecard — management + technical (#94). Suppressed in as-built mode,
    # which is a deployment record rather than an operational posture assessment (#194).
    if ($Tier -ne 'executive' -and $Mode -ne 'as-built') {
        $wafEval = Invoke-RangerWafRuleEvaluation -Manifest $Manifest
        $wafPillarRows = @($wafEval.pillarScores | ForEach-Object {
            @(
                [string]$_.pillar,
                "$($_.score)%",
                [string]$_.status,
                "$($_.passing) / $($_.total)",
                [string]$_.topFinding
            )
        })
        if ($wafPillarRows.Count -gt 0) {
            [void]$sections.Add([ordered]@{
                heading = 'WAF Assessment — Scorecard'
                type    = 'table'
                headers = @('Pillar', 'Score', 'Status', 'Rules Passing', 'Top Finding')
                rows    = $wafPillarRows
                caption = "Overall WAF score: $($wafEval.summary.overallScore)% ($($wafEval.summary.passingRules) of $($wafEval.summary.totalRules) rules passing). Evaluated from saved manifest — no re-collection required."
            })
        }

        # v2.2.0 (#242): Gap-to-Goal projection panel — management + technical, current-state only.
        if ($wafEval.gapToGoal -and @($wafEval.gapToGoal.fixPlan).Count -gt 0) {
            $g = $wafEval.gapToGoal
            $planLines = @($g.fixPlan | ForEach-Object { "  {0,-10} -> +{1,-4}  (cum {2}%)   effort: {3}" -f $_.ruleId, $_.deltaScore, $_.cumulativeScore, $_.effort })
            [void]$sections.Add([ordered]@{
                heading = 'WAF Gap to Goal'
                body    = @(
                    "Current WAF posture:  $($g.currentScore)% ($($g.currentStatus))",
                    "Projected posture:    $($g.projectedScore)% ($($g.projectedStatus)) — by fixing $(@($g.fixPlan).Count) findings",
                    '',
                    'Fix plan (greedy, by score impact per effort):'
                ) + $planLines
            })
        } elseif ($wafEval.gapToGoal -and $wafEval.gapToGoal.message) {
            [void]$sections.Add([ordered]@{
                heading = 'WAF Gap to Goal'
                body    = @($wafEval.gapToGoal.message)
            })
        }

        # v2.2.0 (#241): Compliance Roadmap — Now/Next/Later bucketing, technical tier only.
        if ($Tier -eq 'technical' -and @($wafEval.roadmap).Count -gt 0) {
            $roadmapRows = @($wafEval.roadmap | ForEach-Object {
                @(
                    [string]$_.bucket,
                    [string]$_.id,
                    [string]$_.pillar,
                    [string]$_.severity,
                    [string]$_.weight,
                    [string]$_.effort,
                    [string]$_.impact,
                    [string]$_.priorityScore,
                    [string]$_.firstStep
                )
            })
            [void]$sections.Add([ordered]@{
                heading = 'WAF Compliance Roadmap'
                type    = 'table'
                headers = @('Bucket', 'Rule', 'Pillar', 'Severity', 'Weight', 'Effort', 'Impact', 'Priority', 'First Step')
                rows    = $roadmapRows
                caption = 'Failing rules ranked by priorityScore = (weight * severity * impact) / effort. Start with Now-bucket items for highest score gain per hour of work.'
            })
        }

        # WAF failing rules detail — technical only. v2.2.0 (#236): Next Step column + remediation detail.
        if ($Tier -eq 'technical') {
            $wafFailingRows = @($wafEval.ruleResults | Where-Object { $_.pass -eq $false } | Sort-Object { $_.pillar }, { switch ($_.severity) { 'warning' { 0 } 'informational' { 1 } default { 2 } } } | ForEach-Object {
                $rr = $_
                $nextStep = if ($rr.remediation -and @($rr.remediation.steps).Count -gt 0) { [string]@($rr.remediation.steps)[0] } else { [string]$rr.recommendation }
                @(
                    [string]$rr.id,
                    [string]$rr.pillar,
                    [string]$rr.severity,
                    [string]$rr.title,
                    $nextStep
                )
            })
            if ($wafFailingRows.Count -gt 0) {
                [void]$sections.Add([ordered]@{
                    heading = 'WAF Assessment — Findings'
                    type    = 'table'
                    headers = @('Rule', 'Pillar', 'Severity', 'Finding', 'Next Step')
                    rows    = $wafFailingRows
                    caption = 'Full remediation detail (rationale, steps, sample PowerShell, docs) is in the Remediation Detail section.'
                })

                # v2.2.0 (#236): structured Remediation Detail section — one subsection per failing rule.
                $remediationItems = @($wafEval.ruleResults | Where-Object { $_.pass -eq $false -and $_.remediation } | Sort-Object { -[double]$_.priorityScore })
                if ($remediationItems.Count -gt 0) {
                    $remedBody = New-Object System.Collections.ArrayList
                    foreach ($rr in $remediationItems) {
                        $rem = $rr.remediation
                        [void]$remedBody.Add("--- $($rr.id): $($rr.title)  (effort: $($rr.estimatedEffort), impact: $($rr.estimatedImpact), priority: $($rr.priorityScore)) ---")
                        if ($rem.rationale)     { [void]$remedBody.Add("Rationale: $($rem.rationale)") }
                        if (@($rem.steps).Count -gt 0) {
                            [void]$remedBody.Add('Steps:')
                            $stepIdx = 1
                            foreach ($s in @($rem.steps)) { [void]$remedBody.Add("  $stepIdx. $s"); $stepIdx++ }
                        }
                        if ($rem.samplePowerShell) {
                            [void]$remedBody.Add('Sample PowerShell:')
                            foreach ($line in ([string]$rem.samplePowerShell -split "`n")) { [void]$remedBody.Add("    $line") }
                        }
                        if (@($rem.dependencies).Count -gt 0) { [void]$remedBody.Add("Dependencies: $((@($rem.dependencies)) -join ', ')") }
                        if ($rem.docsUrl)       { [void]$remedBody.Add("Docs: $($rem.docsUrl)") }
                        [void]$remedBody.Add('')
                    }
                    [void]$sections.Add([ordered]@{
                        heading = 'WAF Remediation Detail'
                        body    = @($remedBody)
                    })
                }
            }

            # v2.2.0 (#238): Per-pillar WAF Compliance Checklist — one subsection per pillar.
            foreach ($pillar in @('Reliability','Security','Cost Optimization','Operational Excellence','Performance Efficiency')) {
                $pillarRules = @($wafEval.ruleResults | Where-Object { $_.pillar -eq $pillar })
                if ($pillarRules.Count -eq 0) { continue }
                $passing = @($pillarRules | Where-Object { $_.pass -eq $true }).Count
                $checklistRows = @($pillarRules | ForEach-Object {
                    $rr = $_
                    $status = if ($rr.pass) { 'Pass' } else { 'Fail' }
                    $nextStep = if (-not $rr.pass -and $rr.remediation -and @($rr.remediation.steps).Count -gt 0) { [string]@($rr.remediation.steps)[0] } elseif (-not $rr.pass) { [string]$rr.recommendation } else { '—' }
                    $effort = if (-not $rr.pass) { [string]$rr.estimatedEffort } else { '—' }
                    @([string]$rr.id, [string]$rr.title, $status, [string]$rr.weight, $effort, $nextStep, '[ ]')
                })
                [void]$sections.Add([ordered]@{
                    heading = "WAF Compliance Checklist — $pillar ($passing / $($pillarRules.Count) passing)"
                    type    = 'table'
                    headers = @('Rule', 'Title', 'Status', 'Weight', 'Effort', 'Next Step', 'Signed Off')
                    rows    = $checklistRows
                })
            }
        }

        # WAF Advisor findings (if any were collected)
        $advisorRecs = @($Manifest.domains.wafAssessment.advisorRecommendations | Where-Object { $_ -ne $null })
        if ($advisorRecs.Count -gt 0) {
            $advisorRows = @($advisorRecs | Sort-Object { switch ([string]$_.impact) { 'High' { 0 } 'Medium' { 1 } default { 2 } } } | Select-Object -First 20 | ForEach-Object {
                $a = $_
                @(
                    [string]($a.wafPillar ?? '—'),
                    [string]($a.impact ?? '—'),
                    [string]($a.shortDescription ?? '—'),
                    [string]($a.remediation ?? '—')
                )
            })
            [void]$sections.Add([ordered]@{
                heading = 'WAF Assessment — Azure Advisor Recommendations'
                type    = 'table'
                headers = @('Pillar', 'Impact', 'Finding', 'Recommendation')
                rows    = $advisorRows
                caption = if ($advisorRecs.Count -gt 20) { "Showing top 20 of $($advisorRecs.Count) Advisor recommendations. Full list in audit-manifest.json." } else { $null }
            })
        }
    }

    if ($Tier -eq 'technical') {
        if ($Manifest.run.drift -and $Manifest.run.drift.status -ne 'not-requested') {
            $driftDomainCounts = @($Manifest.run.drift.summary.domainCounts)
            [void]$sections.Add([ordered]@{
                heading = 'Drift Analysis'
                body    = @(
                    "Drift status: $($Manifest.run.drift.status)",
                    $(if ($Manifest.run.drift.status -eq 'generated') { "Total detected changes: $($summary.DriftChangeCount)" } else { "Skip reason: $($Manifest.run.drift.skippedReason)" }),
                    $(if ($driftDomainCounts.Count -gt 0) { @($driftDomainCounts | ForEach-Object { "- $($_.domain): total=$($_.total), added=$($_.added), removed=$($_.removed), changed=$($_.changed)" }) } else { '- No domain-level drift counts were recorded.' })
                )
            })
        }

        [void]$sections.Add([ordered]@{
            heading = 'Domain Inventory'
            body    = @(
                "Storage pools: $(@($Manifest.domains.storage.pools).Count)",
                "Virtual disks: $(@($Manifest.domains.storage.virtualDisks).Count)",
                "Cluster networks: $(@($Manifest.domains.clusterNode.networks).Count)",
                "Management tools: $(@($Manifest.domains.managementTools.tools).Count)",
                "Monitoring components: $(@($Manifest.domains.monitoring.telemetry).Count + @($Manifest.domains.monitoring.ama).Count + @($Manifest.domains.monitoring.dcr).Count)",
                "Cluster roles: $(@($Manifest.domains.clusterNode.roles).Count)",
                "Replication entries: $(@($Manifest.domains.virtualMachines.replication).Count)",
                "Update resources: $(@($Manifest.domains.azureIntegration.update).Count)"
            )
        })

        # Physical disk inventory table — technical only (#168)
        $physicalDisks = @($Manifest.domains.storage.physicalDisks)
        if ($physicalDisks.Count -gt 0) {
            $diskRows = @($physicalDisks | Select-Object -First 200 | ForEach-Object {
                $d = $_
                $sizeGiB = if ($null -ne $d.size) { [string][math]::Round([double]$d.size / 1GB, 0) } elseif ($null -ne $d.sizeGiB) { [string][math]::Round([double]$d.sizeGiB, 0) } else { '—' }
                @(
                    [string]($d.node ?? $d.usageType ?? '—'),
                    [string]($d.friendlyName ?? $d.model ?? '—'),
                    [string]($d.mediaType ?? '—'),
                    $sizeGiB,
                    [string]($d.healthStatus ?? $d.operationalStatus ?? '—'),
                    [string]($d.firmwareVersion ?? '—')
                )
            })
            $diskCaption = if ($physicalDisks.Count -gt 200) { "Showing first 200 of $($physicalDisks.Count) disks." } else { $null }
            [void]$sections.Add([ordered]@{
                heading = 'Physical Disk Inventory'
                type    = 'table'
                headers = @('Node', 'Model', 'Media Type', 'Size (GiB)', 'Health', 'Firmware')
                rows    = $diskRows
                caption = $diskCaption
            })
        }

        # Network adapter inventory table — technical only (#168)
        $netAdapters = @($Manifest.domains.networking.adapters)
        if ($netAdapters.Count -gt 0) {
            $adapterRows = @($netAdapters | Select-Object -First 150 | ForEach-Object {
                $a = $_
                @(
                    [string]($a.node ?? '—'),
                    [string]($a.name ?? '—'),
                    [string]($a.linkSpeed ?? $a.speed ?? '—'),
                    [string]($a.status ?? $a.interfaceOperationalStatus ?? '—'),
                    [string]($a.macAddress ?? '—'),
                    [string]($a.driverProvider ?? '—')
                )
            })
            [void]$sections.Add([ordered]@{
                heading = 'Network Adapter Inventory'
                type    = 'table'
                headers = @('Node', 'Adapter', 'Link Speed', 'Status', 'MAC Address', 'Driver')
                rows    = $adapterRows
            })
        }

        # Domain summary (counts) — retained as bullets, replaces Technical Domain Deep Dive
        [void]$sections.Add([ordered]@{
            heading = 'Domain Summary'
            body    = @(
                "Node manufacturers: $((@($Manifest.domains.clusterNode.nodeSummary.manufacturers | ForEach-Object { '{0} ({1})' -f $_.name, $_.count }) -join ', '))",
                "Storage media types: $((@($Manifest.domains.storage.summary.diskMediaTypes | ForEach-Object { '{0} ({1})' -f $_.name, $_.count }) -join ', '))",
                "Adapter states: $((@($Manifest.domains.networking.summary.adapterStates | ForEach-Object { '{0} ({1})' -f $_.name, $_.count }) -join ', '))",
                "VM generations: $((@($Manifest.domains.virtualMachines.summary.byGeneration | ForEach-Object { '{0} ({1})' -f $_.name, $_.count }) -join ', '))",
                "Azure resource types: $((@($Manifest.domains.azureIntegration.resourceSummary.byType | Select-Object -First 6 | ForEach-Object { '{0} ({1})' -f $_.name, $_.count }) -join ', '))",
                "Monitoring: telemetry=$($Manifest.domains.monitoring.summary.telemetryCount), AMA=$($Manifest.domains.monitoring.summary.amaCount), DCR=$($Manifest.domains.monitoring.summary.dcrCount)",
                "Performance: avg CPU=$($Manifest.domains.performance.summary.averageCpuUtilizationPercent)%, avg available memory=$([math]::Round([double]$Manifest.domains.performance.summary.averageAvailableMemoryMb / 1024, 1)) GiB",
                "ESU: eligible=$($Manifest.domains.azureIntegration.costAnalysis.summary.eligibleVmCount), enrolled=$($Manifest.domains.azureIntegration.costAnalysis.summary.enrolledVmCount), not enrolled=$($Manifest.domains.azureIntegration.costAnalysis.summary.notEnrolledVmCount)"
            )
        })

        # Storage resiliency summary — kept as bullets
        [void]$sections.Add([ordered]@{
            heading = 'Storage Resiliency'
            body    = @(
                "Total raw: $([math]::Round($summary.StorageTotalRawGiB, 0)) GiB ($([math]::Round($summary.StorageTotalRawGiB / 1024, 2)) TiB)",
                "Total usable (after resiliency): $([math]::Round($summary.StorageTotalUsableGiB, 0)) GiB ($([math]::Round($summary.StorageTotalUsableGiB / 1024, 2)) TiB)",
                "Resiliency overhead: $(if ($summary.StorageTotalRawGiB -gt 0) { [math]::Round((1 - $summary.StorageTotalUsableGiB / $summary.StorageTotalRawGiB) * 100, 1) } else { 'N/A' })% of raw",
                "Reserve target: $([math]::Round($summary.StorageReserveTargetGiB, 0)) GiB  |  Safe allocatable: $([math]::Round($summary.StorageSafeAllocatableGiB, 0)) GiB"
            )
        })

        # Event log summary table — replaces raw dump (#168)
        $eventLogEntries = @($Manifest.domains.performance.eventLogAnalysis | Where-Object { $_ -ne $null -and $_['eventCount'] -gt 0 } | Sort-Object { [int]($_['eventCount'] ?? 0) } -Descending | Select-Object -First 20)
        if ($eventLogEntries.Count -gt 0) {
            $eventRows = @($eventLogEntries | ForEach-Object {
                $e = $_
                $topIds = (@($e['topEventIds'] | Select-Object -First 3 | ForEach-Object { "$($_.eventId)×$($_.count)" }) -join ', ')
                @(
                    [string]($e['node'] ?? '—'),
                    [string]($e['logName'] ?? '—'),
                    [string]($e['eventCount'] ?? '0'),
                    [string]($topIds)
                )
            })
            [void]$sections.Add([ordered]@{
                heading = 'Event Log Summary'
                type    = 'table'
                headers = @('Node', 'Log Source', 'Event Count', 'Top Event IDs (×count)')
                rows    = $eventRows
            })
        } else {
            [void]$sections.Add([ordered]@{
                heading = 'Event Log Summary'
                body    = @('No events recorded in this collection window.')
            })
        }

        # Security audit — structured table sections (#168)
        $certCount    = @($Manifest.domains.identitySecurity.posture.certificates).Count
        $rbacCount    = @($Manifest.domains.identitySecurity.rbacAssignments).Count
        $backupCount  = @($Manifest.domains.azureIntegration.backup.items).Count
        $asrCount     = @($Manifest.domains.azureIntegration.asr.protectedItems).Count
        [void]$sections.Add([ordered]@{
            heading = 'Security Audit'
            type    = 'table'
            headers = @('Area', 'Item', 'Value')
            rows    = @(
                @('Certificates',        'Total tracked',                       [string]$certCount),
                @('Certificates',        'Expiring within 90 days',             [string]$Manifest.domains.identitySecurity.summary.certificateExpiringWithin90Days),
                @('Policy',              'Assignments',                         [string]$Manifest.domains.azureIntegration.policySummary.assignmentCount),
                @('Policy',              'Exemptions',                          [string]$Manifest.domains.azureIntegration.policySummary.exemptionCount),
                @('Policy',              'Non-compliant',                       [string]$Manifest.domains.azureIntegration.policySummary.nonCompliantCount),
                @('Identity',            'AD CNO objects tracked',              [string]@($Manifest.domains.identitySecurity.activeDirectory.adObjects).Count),
                @('Identity',            'RBAC assignments at RG scope',        [string]$rbacCount),
                @('Workload Protection', 'Backup items tracked',                [string]$backupCount),
                @('Workload Protection', 'ASR protected items',                 [string]$asrCount),
                @('Endpoint',            'Defender for Cloud enabled',          $(if ($Manifest.domains.identitySecurity.defenderForCloud.enabled) { 'Yes' } else { 'Not confirmed' })),
                @('Endpoint',            'Secured-Core enabled nodes',          "$($Manifest.domains.identitySecurity.summary.securedCoreNodes) of $($summary.NodeCount)"),
                @('Endpoint',            'WDAC policy',                         [string]($Manifest.domains.identitySecurity.security.wdacPolicy ?? 'Not collected')),
                @('Endpoint',            'BitLocker',                           $(if ($Manifest.domains.identitySecurity.security.bitlockerEnabled -eq $true) { 'Enabled' } elseif ($Manifest.domains.identitySecurity.security.bitlockerEnabled -eq $false) { 'Disabled' } else { 'Not collected' }))
            )
        })

        # Issue #73: Raw Data Appendix (Technical)
        [void]$sections.Add([ordered]@{
            heading = 'Raw Data Appendix'
            body    = @(
                "The complete collection manifest (ranger-manifest.json) is included in this package.",
                "It contains the full raw evidence from all collectors, including every data point used to generate this report.",
                "To regenerate reports from the saved manifest without re-running discovery, use:",
                "  Invoke-AzureLocalRanger -ManifestPath <path-to-manifest.json> -OutputPath <output-folder>",
                "Manifest schema version: $($Manifest.run.schemaVersion)",
                "Collection completed: $($Manifest.run.endTimeUtc)",
                "Ranger version: $($Manifest.run.toolVersion)"
            )
        })
    }

    if ($Mode -eq 'as-built') {
        # #193/#194: Formal as-built document structure.
        # Document Control is always first; management + technical tiers add BOM,
        # per-node/network/storage/Azure/identity records, validation, deviations, sign-off.
        $sections.Insert(0, (New-RangerAsBuiltDocumentControlSection -Manifest $Manifest -Tier $Tier))

        if ($Tier -ne 'executive') {
            [void]$sections.Add((New-RangerAsBuiltInstallationRegisterSection        -Manifest $Manifest))
            [void]$sections.Add((New-RangerAsBuiltNodeConfigurationSection           -Manifest $Manifest))
            [void]$sections.Add((New-RangerAsBuiltNetworkAllocationSection           -Manifest $Manifest))
            [void]$sections.Add((New-RangerAsBuiltStorageConfigurationSection        -Manifest $Manifest))
            [void]$sections.Add((New-RangerAsBuiltIdentitySecuritySection            -Manifest $Manifest))
            [void]$sections.Add((New-RangerAsBuiltAzureIntegrationSection            -Manifest $Manifest))
            [void]$sections.Add((New-RangerAsBuiltValidationRecordSection            -Manifest $Manifest))
            [void]$sections.Add((New-RangerAsBuiltDeviationsSection                  -Manifest $Manifest))
        }

        [void]$sections.Add((New-RangerAsBuiltSignOffSection))
    }

    return [ordered]@{
        Title           = ((Get-RangerReportTierDefinitions -Mode $Mode | Where-Object { $_.Name -eq $Tier } | Select-Object -First 1).Title)
        Tier            = $Tier
        ClusterName     = $summary.ClusterName
        Mode            = $Mode
        Summary         = $summary
        Findings        = @($findings)
        Recommendations = @($recommendations)
        CollectorCards  = @($collectorCards)
        TableOfContents = @($sections | ForEach-Object { $_.heading })
        Sections        = @($sections)
        Version         = $Manifest.run.toolVersion
        GeneratedAt     = $Manifest.run.endTimeUtc
        # Issue #73: Visual stats passed to HTML renderer (current-state only — #194).
        VisualStats     = if ($Mode -eq 'as-built') { $null } else { [ordered]@{
            healthLights = @(
                [ordered]@{ label = 'Overall Health';      color = $summary.OverallHealthColor }
                [ordered]@{ label = 'Azure Integration';   color = $summary.AzureIntegrationColor }
                [ordered]@{ label = 'Security Posture';    color = $summary.SecurityPostureColor }
                [ordered]@{ label = 'Monitoring Coverage'; color = if ($summary.MonitoringCoveragePercent -ge 100) { 'green' } elseif ($summary.MonitoringCoveragePercent -gt 0) { 'yellow' } else { 'gray' } }
            )
            capacityBars = @(
                [ordered]@{ label = 'Storage used';         percent = $summary.StorageUtilizationPct }
                [ordered]@{ label = 'Storage reserve';      percent = $summary.StorageReservePercent }
                [ordered]@{ label = 'Safe allocatable';     percent = $summary.StorageSafePercent }
                [ordered]@{ label = 'Monitoring coverage';  percent = $summary.MonitoringCoveragePercent }
                [ordered]@{ label = 'Backup coverage';      percent = $summary.BackupCoveragePercent }
            )
        } }
    }
}


function Get-RangerManifestSummary {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $collectorStatuses = @($Manifest.collectors.Values)
    $nodeCount  = @($Manifest.domains.clusterNode.nodes).Count
    $vmCount    = @($Manifest.domains.virtualMachines.inventory).Count
    $vmSummary  = $Manifest.domains.virtualMachines.summary
    $storageSummary = $Manifest.domains.storage.summary
    $monitorSummary = $Manifest.domains.monitoring.summary
    $driftSummary = $Manifest.run.drift

    # Issue #73: Monitoring coverage — use nodesWithAmaAgent (OS-level service count) not
    # amaCount (Azure extension records which includes many non-node resources).
    $amaCount             = if ($monitorSummary -and $null -ne $monitorSummary.nodesWithAmaAgent) { [int]$monitorSummary.nodesWithAmaAgent } elseif ($monitorSummary -and $null -ne $monitorSummary.amaCount -and [int]$monitorSummary.amaCount -le $nodeCount) { [int]$monitorSummary.amaCount } else { 0 }
    $monitoringCoveragePct = if ($nodeCount -gt 0) { [math]::Min(100, [math]::Round($amaCount / $nodeCount * 100, 0)) } else { 0 }

    # Issue #73: Backup coverage estimate (backup items / VMs)
    $backupItemCount  = @($Manifest.domains.azureIntegration.backup.items).Count
    $backupCoveragePct = if ($vmCount -gt 0) { [math]::Min(100, [math]::Round($backupItemCount / $vmCount * 100, 0)) } else { 0 }

    # Issue #73: Storage utilization
    $storageTotalRaw    = if ($storageSummary -and $storageSummary.totalRawCapacityGiB) { [double]$storageSummary.totalRawCapacityGiB } else { 0 }
    $storageTotalUsable = if ($storageSummary -and $storageSummary.totalUsableCapacityGiB) { [double]$storageSummary.totalUsableCapacityGiB } else { 0 }
    $storageAllocated   = if ($storageSummary -and $storageSummary.totalAllocatedCapacityGiB) { [double]$storageSummary.totalAllocatedCapacityGiB } else { 0 }
    $storageUsed        = if ($storageSummary -and $storageSummary.totalUsedUsableCapacityGiB) { [double]$storageSummary.totalUsedUsableCapacityGiB } else { $storageAllocated }
    $storageFree        = if ($storageSummary -and $storageSummary.totalFreeUsableCapacityGiB) { [double]$storageSummary.totalFreeUsableCapacityGiB } else { [math]::Max($storageTotalUsable - $storageUsed, 0) }
    $storageReserve     = if ($storageSummary -and $storageSummary.totalReserveTargetGiB) { [double]$storageSummary.totalReserveTargetGiB } else { 0 }
    $storageSafeAlloc   = if ($storageSummary -and $storageSummary.totalSafeAllocatableCapacityGiB) { [double]$storageSummary.totalSafeAllocatableCapacityGiB } else { [math]::Max($storageFree - $storageReserve, 0) }
    $storageUtilPct     = if ($storageTotalUsable -gt 0) { [math]::Round($storageUsed / $storageTotalUsable * 100, 1) } else { 0 }
    $storageReservePct  = if ($storageTotalUsable -gt 0) { [math]::Round($storageReserve / $storageTotalUsable * 100, 1) } else { 0 }
    $storageSafePct     = if ($storageTotalUsable -gt 0) { [math]::Round($storageSafeAlloc / $storageTotalUsable * 100, 1) } else { 0 }

    # Issue #73: Overall health color (red=any critical, yellow=>2 warnings, green=clean)
    $criticalCount  = @($Manifest.findings | Where-Object { $_.severity -eq 'critical' }).Count
    $warningCount   = @($Manifest.findings | Where-Object { $_.severity -eq 'warning'  }).Count
    $overallColor   = if ($criticalCount -gt 0) { 'red' } elseif ($warningCount -gt 2) { 'yellow' } else { 'green' }

    # Issue #73: Azure integration status color
    $arcResources  = @($Manifest.domains.azureIntegration.resources).Count
    $azureColor    = if ($arcResources -gt 0) { 'green' } else { 'yellow' }

    # Issue #73: Security posture color (Secured-Core coverage of nodes)
    $securedCoreNodes = if ($Manifest.domains.identitySecurity.summary.securedCoreNodes) { [int]$Manifest.domains.identitySecurity.summary.securedCoreNodes } else { 0 }
    $securityColor    = if ($nodeCount -gt 0 -and $securedCoreNodes -ge $nodeCount) { 'green' } elseif ($securedCoreNodes -gt 0) { 'yellow' } else { 'gray' }

    [ordered]@{
        ClusterName               = if (-not [string]::IsNullOrWhiteSpace($Manifest.target.clusterName)) { $Manifest.target.clusterName } else { $Manifest.target.environmentLabel }
        NodeCount                 = $nodeCount
        VmCount                   = $vmCount
        AzureResourceCount        = @($Manifest.domains.azureIntegration.resources).Count
        DeploymentType            = $Manifest.topology.deploymentType
        IdentityMode              = $Manifest.topology.identityMode
        ControlPlaneMode          = $Manifest.topology.controlPlaneMode
        TotalCollectors           = $collectorStatuses.Count
        SuccessfulCollectors      = @($collectorStatuses | Where-Object { $_.status -eq 'success' }).Count
        PartialCollectors         = @($collectorStatuses | Where-Object { $_.status -eq 'partial' }).Count
        FailedCollectors          = @($collectorStatuses | Where-Object { $_.status -eq 'failed' }).Count
        FindingsBySeverity        = [ordered]@{
            critical      = $criticalCount
            warning       = $warningCount
            informational = @($Manifest.findings | Where-Object { $_.severity -eq 'informational' }).Count
            good          = @($Manifest.findings | Where-Object { $_.severity -eq 'good' }).Count
        }
        # Issue #73: Density and overcommit metrics
        VcpuOvercommitRatio       = if ($vmSummary -and $null -ne $vmSummary.vcpuOvercommitRatio)   { $vmSummary.vcpuOvercommitRatio }   else { $null }
        MemoryOvercommitRatio     = if ($vmSummary -and $null -ne $vmSummary.memoryOvercommitRatio) { $vmSummary.memoryOvercommitRatio } else { $null }
        AvgVmsPerNode             = if ($vmSummary -and $null -ne $vmSummary.avgVmsPerNode)         { $vmSummary.avgVmsPerNode }         else { $null }
        # Issue #73: Coverage metrics
        MonitoringCoveragePercent = $monitoringCoveragePct
        AmaNodeCount              = $amaCount
        BackupCoveragePercent     = $backupCoveragePct
        # Issue #73: Storage capacity
        StorageTotalRawGiB        = $storageTotalRaw
        StorageTotalUsableGiB     = $storageTotalUsable
        StorageUsedUsableGiB      = $storageUsed
        StorageFreeUsableGiB      = $storageFree
        StorageReserveTargetGiB   = $storageReserve
        StorageSafeAllocatableGiB = $storageSafeAlloc
        StorageUtilizationPct     = $storageUtilPct
        StorageReservePercent     = $storageReservePct
        StorageSafePercent        = $storageSafePct
        StorageThinProvisioningRatio = if ($storageSummary -and $null -ne $storageSummary.thinProvisioningRatio) { $storageSummary.thinProvisioningRatio } else { $null }
        DriftStatus               = if ($driftSummary) { $driftSummary.status } else { 'not-requested' }
        DriftChangeCount          = if ($driftSummary -and $driftSummary.summary -and $null -ne $driftSummary.summary.totalChanges) { [int]$driftSummary.summary.totalChanges } else { 0 }
        # Issue #73: Health status colors (for traffic lights)
        OverallHealthColor        = $overallColor
        AzureIntegrationColor     = $azureColor
        SecurityPostureColor      = $securityColor
    }
}

function ConvertTo-RangerMarkdownReport {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Report
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# $($Report.Title)")
    $lines.Add('')
    $lines.Add("- Cluster: $($Report.ClusterName)")
    $lines.Add("- Mode: $($Report.Mode)")
    $lines.Add("- Ranger Version: $($Report.Version)")
    $lines.Add("- Generated: $($Report.GeneratedAt)")
    $lines.Add("- Schema validation: $(if ($Report.Summary -and $Report.Summary.Contains('FindingsBySeverity')) { if ($Report.Findings | Where-Object { $_.title -eq 'Manifest schema validation failed' }) { 'failed' } else { 'passed or warnings only' } } else { 'unknown' })")
    $lines.Add('')

    # Issue #73: Traffic light health status block
    if ($Report.VisualStats -and $Report.VisualStats.healthLights) {
        $lines.Add('## At-a-Glance Health Status')
        $lines.Add('')
        foreach ($light in @($Report.VisualStats.healthLights)) {
            $indicator = switch ($light.color) {
                'green'  { '● GREEN' }
                'yellow' { '▲ YELLOW' }
                'red'    { '■ RED' }
                default  { '○ UNKNOWN' }
            }
            $lines.Add("- $indicator — $($light.label)")
        }
        $lines.Add('')
    }

    $lines.Add('## Table of Contents')
    $lines.Add('')
    foreach ($heading in @($Report.TableOfContents)) {
        $lines.Add("- $heading")
    }
    $lines.Add('')

    foreach ($section in $Report.Sections) {
        $lines.Add("## $($section.heading)")
        $lines.Add('')
        switch ($section.type) {
            'table' {
                $tblRows = ConvertTo-RangerTableRowArray -Rows @($section.rows) -ColumnCount @($section.headers).Count
                if ($tblRows.Count -gt 0) {
                    $lines.Add(('| ' + ($section.headers -join ' | ') + ' |'))
                    $lines.Add(('| ' + ($section.headers | ForEach-Object { '---' }) -join ' | ') + ' |')
                    foreach ($row in $tblRows) {
                        $cells = @($row) | ForEach-Object { [string]($_ -replace '\|', '&#124;') }
                        $lines.Add('| ' + ($cells -join ' | ') + ' |')
                    }
                    if ($section.caption) { $lines.Add('') ; $lines.Add("_$($section.caption)_") }
                } else {
                    $lines.Add('_No data available._')
                }
            }
            'kv' {
                foreach ($pair in @($section.rows)) {
                    $lines.Add("**$([string]$pair[0])**: $([string]$pair[1])")
                }
            }
            'sign-off' {
                $lines.Add('| Role | Name | Date | Signature |')
                $lines.Add('| --- | --- | --- | --- |')
                $lines.Add('| Implementation Engineer | | | |')
                $lines.Add('| Technical Reviewer | | | |')
                $lines.Add('| Customer Representative | | | |')
            }
            default {
                foreach ($entry in @($section.body)) {
                    $lines.Add("- $entry")
                }
            }
        }
        $lines.Add('')
    }


    $lines.Add('## Recommendations')
    $lines.Add('')
    if (@($Report.Recommendations).Count -eq 0) {
        $lines.Add('- No recommendations were surfaced for this output tier.')
    }
    else {
        foreach ($recommendation in @($Report.Recommendations)) {
            $lines.Add(('- [{0}] {1}: {2}' -f $recommendation.severity.ToUpperInvariant(), $recommendation.title, $recommendation.recommendation))
        }
    }
    $lines.Add('')
    $lines.Add('## Findings')
    $lines.Add('')
    if (@($Report.Findings).Count -eq 0) {
        $lines.Add('- No findings were recorded for this output tier.')
    }
    else {
        foreach ($finding in $Report.Findings) {
            $lines.Add(("### [{0}] {1}" -f $finding.severity.ToUpperInvariant(), $finding.title))
            $lines.Add($finding.description)
            if ($finding.currentState) {
                $lines.Add('')
                $lines.Add(("Current state: {0}" -f $finding.currentState))
            }
            if ($finding.recommendation) {
                $lines.Add(("Recommendation: {0}" -f $finding.recommendation))
            }
            if (@($finding.affectedComponents).Count -gt 0) {
                $lines.Add(("Affected components: {0}" -f (@($finding.affectedComponents) -join ', ')))
            }
            $lines.Add('')
        }
    }

    return ($lines -join [Environment]::NewLine)
}

# --- HTML component helpers (#168) ---

function ConvertTo-RangerTableRowArray {
    <#
    .SYNOPSIS
        Normalize section.rows back to an array of per-row arrays.
    .DESCRIPTION
        PowerShell flattens 2D arrays when the payload builder uses
        `@( ... | ForEach-Object { @(cell1, cell2) } )` — the outer @()
        unrolls each row into the outer array. This helper detects the
        flattened shape and regroups by column count, so all renderers
        (HTML / Markdown / DOCX / PDF) get a consistent 2D structure.
    #>
    param(
        [object[]]$Rows,
        [int]$ColumnCount
    )

    if ($null -eq $Rows -or $Rows.Count -eq 0) { return @() }

    $first = $null
    foreach ($r in $Rows) { if ($null -ne $r) { $first = $r; break } }
    $is2D = $null -ne $first -and ($first -is [System.Collections.IList] -and $first -isnot [string])

    if ($is2D -or $ColumnCount -le 0) {
        return @($Rows)
    }

    $out = New-Object System.Collections.ArrayList
    $total = [int]$Rows.Count
    $cols  = [int]$ColumnCount
    for ($i = 0; $i -lt $total; $i += $cols) {
        $end = [math]::Min($i + $cols - 1, $total - 1)
        [void]$out.Add(@($Rows[$i..$end]))
    }
    return ,@($out.ToArray())
}

function Get-RangerStatusBadgeClass {
    <#
    .SYNOPSIS
        v2.0.0 (#227): map a status/severity string to a badge CSS class.
    .DESCRIPTION
        Returns 'badge-healthy' | 'badge-warning' | 'badge-critical' | 'badge-unknown'
        or '' when the value is not a known status token. Used by the HTML table
        renderer to color status cells automatically.
    #>
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    switch -Regex ($Value) {
        '^(Healthy|Succeeded|Connected|Running|Up|Enabled|Yes|Online|pass|OK)$'                { return 'status-Healthy' }
        '^(Warning|Updating|Degraded|Partial|warning)$'                                         { return 'status-Warning' }
        '^(Failed|Critical|Disconnected|Error|Down|Disabled|No|fail|NotReady)$'                 { return 'status-Failed' }
        '^(Unknown|N/A|—|Not\s*collected)$'                                                      { return 'badge-unknown' }
        default                                                                                   { return '' }
    }
}

function New-RangerHtmlTable {
    [OutputType([string])]
    param(
        [string[]]$Headers,
        [object[]]$Rows,
        [string]$Caption
    )
    if ($null -eq $Rows -or $Rows.Count -eq 0) {
        return '<p class="data-unavailable">No data available.</p>'
    }
    $arrayRows = ConvertTo-RangerTableRowArray -Rows $Rows -ColumnCount $Headers.Count

    $captionHtml = if ($Caption) { "<caption>$([System.Net.WebUtility]::HtmlEncode($Caption))</caption>" } else { '' }
    $headerHtml  = ($Headers | ForEach-Object { "<th>$([System.Net.WebUtility]::HtmlEncode([string]$_))</th>" }) -join ''
    $rowsHtml    = ($arrayRows | ForEach-Object {
        $cells = (@($_) | ForEach-Object {
            $v = [string]$_
            $cls = Get-RangerStatusBadgeClass -Value $v
            if ($cls) {
                "<td class='$cls'>$([System.Net.WebUtility]::HtmlEncode($v))</td>"
            } else {
                "<td>$([System.Net.WebUtility]::HtmlEncode($v))</td>"
            }
        }) -join ''
        "<tr>$cells</tr>"
    }) -join [Environment]::NewLine
    "<div class='table-wrapper'><table class='data-table'>$captionHtml<thead><tr>$headerHtml</tr></thead><tbody>$rowsHtml</tbody></table></div>"
}

function New-RangerHtmlKeyValueGrid {
    [OutputType([string])]
    param([object[][]]$Pairs)
    if ($null -eq $Pairs -or $Pairs.Count -eq 0) { return '' }
    $rowsHtml = ($Pairs | ForEach-Object {
        "<tr><th scope='row'>$([System.Net.WebUtility]::HtmlEncode([string]$_[0]))</th><td>$([System.Net.WebUtility]::HtmlEncode([string]$_[1]))</td></tr>"
    }) -join [Environment]::NewLine
    "<table class='kv-table'><tbody>$rowsHtml</tbody></table>"
}

function New-RangerHtmlSignOffTable {
    [OutputType([string])]
    param()
    @"
<p class="sign-off-note">This as-built package was generated from the Ranger discovery run on the date shown in the Document Control section. Review all findings before accepting this package as the formal handoff record.</p>
<table class="data-table sign-off-table">
  <thead><tr><th>Role</th><th>Name</th><th>Date</th><th>Signature</th></tr></thead>
  <tbody>
    <tr><td>Implementation Engineer</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>
    <tr><td>Technical Reviewer</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>
    <tr><td>Customer Representative</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>
  </tbody>
</table>
"@
}

function ConvertTo-RangerHtmlReport {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Report,

        # v1.5.0 (#192): when provided, SVG diagrams from this folder are
        # embedded inline in an Architecture Diagrams section.
        [string]$DiagramsPath
    )

    $isAsBuilt = ($Report.Mode -eq 'as-built')
    $modeSubtitle = if ($isAsBuilt) { 'Post-Deployment As-Built Package' } else { 'Live Discovery Report' }
    $classification = if ($isAsBuilt) { 'CONFIDENTIAL — CUSTOMER DELIVERABLE' } else { 'INTERNAL — DISCOVERY REPORT' }
    $bodyClass = if ($isAsBuilt) { 'mode-as-built' } else { 'mode-current-state' }

    $tocHtml = @(
        foreach ($heading in @($Report.TableOfContents)) {
            '<li>{0}</li>' -f ([System.Net.WebUtility]::HtmlEncode([string]$heading))
        }
    ) -join [Environment]::NewLine

    $cardHtml = @(
        foreach ($card in @($Report.CollectorCards)) {
            @"
<article class="collector-card status-$($card.status)">
  <h3>$([System.Net.WebUtility]::HtmlEncode($card.collector))</h3>
  <p><strong>Status:</strong> $([System.Net.WebUtility]::HtmlEncode($card.status))</p>
  <p><strong>Targets:</strong> $([System.Net.WebUtility]::HtmlEncode([string]$card.targets))</p>
</article>
"@
        }
    ) -join [Environment]::NewLine

    # Issue #73: Build visual stats banner (traffic lights + capacity bars)
    $statsBannerHtml = ''
    if ($Report.VisualStats) {
        $lightsRowHtml = @(
            foreach ($light in @($Report.VisualStats.healthLights)) {
                $svg = New-RangerTrafficLightSvg -Color $light.color -Size 20
                "<div class='tl-item'>$svg <span class='tl-label'>$([System.Net.WebUtility]::HtmlEncode($light.label))</span></div>"
            }
        ) -join ''
        $barsRowHtml = @(
            foreach ($bar in @($Report.VisualStats.capacityBars)) {
                $svg = New-RangerCapacityBarSvg -Percent $bar.percent -Width 160
                "<div class='cap-item'><span class='cap-label'>$([System.Net.WebUtility]::HtmlEncode($bar.label)):</span> $svg</div>"
            }
        ) -join ''
        $statsBannerHtml = @"
<section class="stats-banner">
  <div class="stats-lights">$lightsRowHtml</div>
  <div class="stats-bars">$barsRowHtml</div>
</section>
"@
    }

    $sectionHtml = @(
        foreach ($section in $Report.Sections) {
            $sectionBody = switch ($section.type) {
                'table' {
                    New-RangerHtmlTable -Headers $section.headers -Rows $section.rows -Caption $section.caption
                }
                'kv' {
                    New-RangerHtmlKeyValueGrid -Pairs $section.rows
                }
                'sign-off' {
                    New-RangerHtmlSignOffTable
                }
                default {
                    $items = @(
                        foreach ($entry in @($section.body)) {
                            '<li>{0}</li>' -f ([System.Net.WebUtility]::HtmlEncode([string]$entry))
                        }
                    ) -join [Environment]::NewLine
                    "<ul>$items</ul>"
                }
            }
            # v2.0.0 (#227): wide sections (arc extensions, subnet detail) set _layout='landscape'
            # so the PDF renderer switches page orientation via CSS @page rules.
            $sectionClass = if ($section._layout -eq 'landscape') { ' class="page-landscape"' } else { '' }
            @"
<section$sectionClass>
  <h2>$([System.Net.WebUtility]::HtmlEncode($section.heading))</h2>
  $sectionBody
</section>
"@
        }
    ) -join [Environment]::NewLine

    $recommendationHtml = if (@($Report.Recommendations).Count -eq 0) {
        '<p>No recommendations were surfaced for this output tier.</p>'
    }
    else {
        @(
            foreach ($recommendation in @($Report.Recommendations)) {
                @"
<li><strong>[$([System.Net.WebUtility]::HtmlEncode($recommendation.severity.ToUpperInvariant()))]</strong> $([System.Net.WebUtility]::HtmlEncode($recommendation.title))<br />$([System.Net.WebUtility]::HtmlEncode($recommendation.recommendation))</li>
"@
            }
        ) -join [Environment]::NewLine
    }

    $findingHtml = if (@($Report.Findings).Count -eq 0) {
        '<p>No findings were recorded for this output tier.</p>'
    }
    else {
        @(
            foreach ($finding in $Report.Findings) {
                @"
<article class="finding finding-$($finding.severity)">
  <h3>[$([System.Net.WebUtility]::HtmlEncode($finding.severity.ToUpperInvariant()))] $([System.Net.WebUtility]::HtmlEncode($finding.title))</h3>
  <p>$([System.Net.WebUtility]::HtmlEncode($finding.description))</p>
  <p><strong>Current state:</strong> $([System.Net.WebUtility]::HtmlEncode([string]$finding.currentState))</p>
  <p><strong>Recommendation:</strong> $([System.Net.WebUtility]::HtmlEncode([string]$finding.recommendation))</p>
</article>
"@
            }
        ) -join [Environment]::NewLine
    }

    # v1.5.0 (#192): inline architecture diagrams when SVG files are present.
    $diagramsHtml = ''
    if ($DiagramsPath -and (Test-Path -Path $DiagramsPath)) {
        $svgFiles = @(Get-ChildItem -Path $DiagramsPath -Filter '*.svg' -File -ErrorAction SilentlyContinue | Sort-Object Name)
        if ($svgFiles.Count -gt 0) {
            $diagramBlocks = @(
                foreach ($svg in $svgFiles) {
                    $title = ($svg.BaseName -replace '^[^-]+-(?:[^-]+-)*\d+T\d+Z-', '') -replace '-', ' '
                    $title = (Get-Culture).TextInfo.ToTitleCase($title)
                    try {
                        $raw = Get-Content -Path $svg.FullName -Raw -ErrorAction Stop
                        $clean = ($raw -replace '<\?xml[^?]*\?>', '') -replace '<!DOCTYPE[^>]*>', ''
                    } catch {
                        continue
                    }
                    @"
<figure class="diagram">
  <figcaption>$([System.Net.WebUtility]::HtmlEncode($title))</figcaption>
  <div class="diagram-body">$clean</div>
</figure>
"@
                }
            ) -join [Environment]::NewLine

            if ($diagramBlocks.Trim().Length -gt 0) {
                $diagramsHtml = @"
<section class="diagrams">
  <h2>Architecture Diagrams</h2>
  $diagramBlocks
</section>
"@
            }
        }
    }

    # Strengthen finding callouts (#192): each severity gets its own styled box.
    $findingHtml = if (@($Report.Findings).Count -eq 0) {
        '<p class="data-unavailable">No findings were recorded for this output tier.</p>'
    }
    else {
        @(
            foreach ($finding in $Report.Findings) {
                $sev = [string]$finding.severity
                @"
<article class="callout callout-$sev">
  <header class="callout-head">
    <span class="callout-badge">$([System.Net.WebUtility]::HtmlEncode($sev.ToUpperInvariant()))</span>
    <h3>$([System.Net.WebUtility]::HtmlEncode([string]$finding.title))</h3>
  </header>
  <p>$([System.Net.WebUtility]::HtmlEncode([string]$finding.description))</p>
  <p><strong>Current state:</strong> $([System.Net.WebUtility]::HtmlEncode([string]$finding.currentState))</p>
  <p><strong>Recommendation:</strong> $([System.Net.WebUtility]::HtmlEncode([string]$finding.recommendation))</p>
</article>
"@
            }
        ) -join [Environment]::NewLine
    }

    @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>$([System.Net.WebUtility]::HtmlEncode($Report.Title))</title>
  <style>
        :root { color-scheme: light; --page-max: 1280px; }
        * { box-sizing: border-box; }
        html, body { margin: 0; padding: 0; }
        body { font-family: Segoe UI, Arial, sans-serif; color: #16202a; background: #f4f7fb; }
        body.mode-as-built { background: #ffffff; }
        .shell { max-width: var(--page-max); margin: 0 auto; padding: 2rem; }
        .banner { font-size: 0.72rem; letter-spacing: 0.14em; font-weight: 700; text-transform: uppercase; padding: 0.4rem 1rem; border-radius: 4px; display: inline-block; margin-bottom: 0.75rem; }
        .banner-as-built { background: #0f172a; color: #f8fafc; }
        .banner-current-state { background: #eff6ff; color: #1e40af; border: 1px solid #bfdbfe; }
        header.report-head { border-bottom: 2px solid #0f172a; margin-bottom: 1.5rem; padding-bottom: 1rem; }
        body.mode-as-built header.report-head { border-bottom-color: #0f172a; }
        h1 { margin: 0.25rem 0 0.15rem; font-size: 1.9rem; color: #0f172a; }
        h1 .subtitle { display: block; font-size: 0.95rem; font-weight: 500; color: #475569; margin-top: 0.3rem; }
        h2 { color: #0f172a; margin-top: 0; border-bottom: 1px solid #e2e8f0; padding-bottom: 0.35rem; font-size: 1.25rem; }
        h3 { color: #0f172a; margin: 0.25rem 0 0.5rem; font-size: 1.05rem; }
        .meta { color: #475569; margin: 0.15rem 0; font-size: 0.9rem; }
        .hero { display: grid; grid-template-columns: 2fr 1fr; gap: 1rem; align-items: start; }
        .panel { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 1rem 1.25rem; }
        .toc ul, .recommendations ul { margin: 0.5rem 0 0 1rem; }
        .collector-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 0.75rem; margin: 1rem 0 1.5rem; }
        .collector-card { border-radius: 8px; padding: 0.75rem 1rem; background: #ffffff; border: 1px solid #e2e8f0; border-left: 4px solid #94a3b8; }
        .collector-card.status-success { border-left-color: #16a34a; }
        .collector-card.status-partial { border-left-color: #d97706; }
        .collector-card.status-failed  { border-left-color: #dc2626; }
        .collector-card.status-skipped { border-left-color: #94a3b8; }
        section { margin: 1rem 0; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 1rem 1.25rem; }
        body.mode-as-built section, body.mode-as-built .panel { border-radius: 4px; }
        @media (max-width: 900px) { .hero { grid-template-columns: 1fr; } }

        /* Stats banner (traffic lights + capacity bars) — current-state only */
        .stats-banner { display: flex; gap: 2rem; flex-wrap: wrap; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 1rem 1.5rem; margin-bottom: 1rem; align-items: flex-start; }
        .stats-lights { display: flex; gap: 1.25rem; flex-wrap: wrap; align-items: center; }
        .tl-item { display: flex; align-items: center; gap: 6px; font-size: 0.92em; font-weight: 500; white-space: nowrap; }
        .stats-bars { display: flex; flex-direction: column; gap: 0.4rem; }
        .cap-item { display: flex; align-items: center; gap: 8px; font-size: 0.88em; }
        .cap-label { min-width: 160px; color: #475569; }

        /* Data tables — fixed layout, constrained widths (#192) */
        .table-wrapper { overflow-x: auto; margin: 0.75rem 0; }
        .data-table { width: 100%; table-layout: fixed; border-collapse: collapse; font-size: 0.875em; word-wrap: break-word; overflow-wrap: anywhere; }
        .data-table caption { text-align: left; font-size: 0.85em; color: #64748b; padding-bottom: 0.4rem; caption-side: bottom; font-style: italic; }
        .data-table thead th { background: #1e3a5f; color: #ffffff; padding: 0.5rem 0.75rem; text-align: left; font-weight: 600; border-bottom: 2px solid #0f172a; }
        body.mode-as-built .data-table thead th { background: #0f172a; }
        .data-table tbody td { padding: 0.45rem 0.75rem; border-bottom: 1px solid #e2e8f0; vertical-align: top; }
        .data-table tbody tr:nth-child(even) { background: #f8fafc; }

        /* Key-value grid (#192): fixed key column width */
        .kv-table { border-collapse: collapse; font-size: 0.9em; width: 100%; max-width: 760px; table-layout: fixed; }
        .kv-table th { color: #475569; font-weight: 600; padding: 0.35rem 1.5rem 0.35rem 0; width: 240px; vertical-align: top; text-align: left; border-bottom: 1px solid #f1f5f9; }
        .kv-table td { padding: 0.35rem 0; color: #0f172a; border-bottom: 1px solid #f1f5f9; word-wrap: break-word; }

        /* Findings as callouts (#192) */
        .callout { border-left: 4px solid #94a3b8; padding: 0.85rem 1rem; margin: 0.9rem 0; background: #f8fafc; border-radius: 0 6px 6px 0; }
        .callout-head { display: flex; align-items: baseline; gap: 0.6rem; }
        .callout-head h3 { margin: 0; font-size: 1rem; }
        .callout-badge { font-size: 0.7rem; letter-spacing: 0.08em; font-weight: 700; padding: 0.15rem 0.5rem; border-radius: 3px; background: #cbd5e1; color: #0f172a; }
        .callout-critical      { background: #fef2f2; border-left-color: #b91c1c; }
        .callout-critical      .callout-badge { background: #b91c1c; color: #fff; }
        .callout-warning       { background: #fff7ed; border-left-color: #d97706; }
        .callout-warning       .callout-badge { background: #d97706; color: #fff; }
        .callout-informational { background: #eff6ff; border-left-color: #2563eb; }
        .callout-informational .callout-badge { background: #2563eb; color: #fff; }
        .callout-good          { background: #f0fdf4; border-left-color: #15803d; }
        .callout-good          .callout-badge { background: #15803d; color: #fff; }

        /* Sign-off table (#192): visible signature lines */
        .sign-off-note { color: #64748b; font-size: 0.9em; margin-bottom: 1rem; }
        .sign-off-table { table-layout: fixed; }
        .sign-off-table td { height: 48px; border-bottom: 1px solid #475569; }
        .data-unavailable { color: #94a3b8; font-style: italic; padding: 0.4rem 0; font-size: 0.9em; }

        /* Diagrams section (#192): inline SVG figures */
        .diagrams figure.diagram { margin: 0 0 1.25rem; border: 1px solid #e2e8f0; border-radius: 6px; padding: 0.75rem; background: #fafbfc; page-break-inside: avoid; }
        .diagrams figure.diagram figcaption { font-weight: 600; color: #334155; margin-bottom: 0.5rem; font-size: 0.95rem; }
        .diagrams .diagram-body svg { max-width: 100%; height: auto; display: block; }

        /* WAF RAG coloring on score cells (#192) */
        .waf-score-red   { background: #fee2e2 !important; color: #991b1b; font-weight: 600; }
        .waf-score-amber { background: #fef3c7 !important; color: #92400e; font-weight: 600; }
        .waf-score-green { background: #dcfce7 !important; color: #166534; font-weight: 600; }

        /* Print CSS (#192) */
        @media print {
            body { background: #ffffff; }
            .shell { max-width: none; padding: 0.75in; }
            section, .panel, .stats-banner, .callout, .diagrams figure.diagram { break-inside: avoid; box-shadow: none; }
            header.report-head { break-after: avoid; }
            h2 { break-after: avoid; }
            .data-table { font-size: 0.78em; }
            .collector-grid { grid-template-columns: repeat(2, 1fr); }
            a { color: inherit; text-decoration: none; }

            /* v2.0.0 (#227): portrait default, landscape for wide sections */
            @page              { size: A4 portrait;  margin: 15mm; }
            @page landscape-pg { size: A4 landscape; margin: 12mm; }
            .page-landscape    { page: landscape-pg; page-break-before: always; }
        }

        /* v2.0.0 (#227): conditional status badge classes — used in status/severity columns. */
        .badge            { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 0.78em; font-weight: 600; line-height: 1.4; }
        .badge-healthy    { background: #dcfce7; color: #166534; }
        .badge-warning    { background: #fef3c7; color: #92400e; }
        .badge-critical   { background: #fee2e2; color: #991b1b; }
        .badge-unknown    { background: #e2e8f0; color: #334155; }
        /* Shading inside cells when .status-cell applied */
        .data-table td.status-Healthy,
        .data-table td.status-Succeeded,
        .data-table td.status-Connected,
        .data-table td.status-Running,
        .data-table td.status-Up,
        .data-table td.status-Enabled,
        .data-table td.status-Yes { background: #dcfce7 !important; color: #166534; font-weight: 600; }
        .data-table td.status-Warning,
        .data-table td.status-Updating,
        .data-table td.status-Degraded,
        .data-table td.status-Partial,
        .data-table td.status-warning { background: #fef3c7 !important; color: #92400e; font-weight: 600; }
        .data-table td.status-Failed,
        .data-table td.status-Critical,
        .data-table td.status-Disconnected,
        .data-table td.status-Error,
        .data-table td.status-Down,
        .data-table td.status-Disabled,
        .data-table td.status-No,
        .data-table td.status-fail { background: #fee2e2 !important; color: #991b1b; font-weight: 600; }
  </style>
</head>
<body class="$bodyClass">
    <div class="shell">
        <header class="report-head">
            <span class="banner banner-$(if ($isAsBuilt) { 'as-built' } else { 'current-state' })">$([System.Net.WebUtility]::HtmlEncode($classification))</span>
            <h1>$([System.Net.WebUtility]::HtmlEncode($Report.Title))<span class="subtitle">$([System.Net.WebUtility]::HtmlEncode($modeSubtitle)) — $([System.Net.WebUtility]::HtmlEncode($Report.ClusterName))</span></h1>
            <p class="meta">Mode: $([System.Net.WebUtility]::HtmlEncode($Report.Mode)) | Ranger Version: $([System.Net.WebUtility]::HtmlEncode($Report.Version)) | Generated: $([System.Net.WebUtility]::HtmlEncode($Report.GeneratedAt))</p>
        </header>
        $statsBannerHtml
        <div class="hero">
            <section class="panel toc">
                <h2>Table of Contents</h2>
                <ul>
                    $tocHtml
                </ul>
            </section>
            <section class="panel recommendations">
                <h2>Priority Recommendations</h2>
                <ul>
                    $recommendationHtml
                </ul>
            </section>
        </div>
        <section>
            <h2>Collector Overview</h2>
            <div class="collector-grid">
                $cardHtml
            </div>
        </section>
        $sectionHtml
        $diagramsHtml
        <section>
            <h2>Findings</h2>
            $findingHtml
        </section>
    </div>
</body>
</html>
"@
}

function Write-RangerPackageReadme {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [string]$PackageRoot
    )

    $summary = Get-RangerManifestSummary -Manifest $Manifest
    $path = Join-Path -Path $PackageRoot -ChildPath 'README.md'
    @(
        "# Azure Local Ranger Package",
        '',
        "- Cluster: $($summary.ClusterName)",
        "- Mode: $($Manifest.run.mode)",
        "- Generated: $($Manifest.run.endTimeUtc)",
        "- Nodes: $($summary.NodeCount)",
        "- VMs: $($summary.VmCount)",
        "- Azure resources: $($summary.AzureResourceCount)",
        "- Collectors: $($summary.SuccessfulCollectors)/$($summary.TotalCollectors) successful, $($summary.PartialCollectors) partial, $($summary.FailedCollectors) failed",
        "- Schema validation: $(if ($Manifest.run.schemaValidation.isValid) { 'passed' } elseif ($null -eq $Manifest.run.schemaValidation.isValid) { 'not recorded' } else { 'failed' })",
        '',
        '## Top Recommendations',
        '',
        $(if (@($Manifest.findings).Count -gt 0) { @($Manifest.findings | Where-Object { -not [string]::IsNullOrWhiteSpace($_.recommendation) } | Select-Object -First 5 | ForEach-Object { "- [$($_.severity.ToUpperInvariant())] $($_.title): $($_.recommendation)" }) } else { '- No recommendations were recorded.' }),
        '',
        '## Package Notes',
        '',
        'Artifacts in this package were rendered from the saved Ranger manifest. No live discovery is required to rerender reports or diagrams.'
    ) -join [Environment]::NewLine | Set-Content -Path $path -Encoding UTF8

    return $path
}