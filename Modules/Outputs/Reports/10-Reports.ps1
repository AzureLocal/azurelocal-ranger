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

    if ($reportFormats.Count -gt 0) {
        foreach ($artifact in (Write-RangerReportArtifacts -Manifest $Manifest -PackageRoot $PackageRoot -Formats $reportFormats -Mode $Mode)) {
            [void]$artifacts.Add($artifact)
        }
    }

    if ($diagramFormats.Count -gt 0) {
        foreach ($artifact in (Invoke-RangerDiagramGeneration -Manifest $Manifest -PackageRoot $PackageRoot -Formats $diagramFormats -Mode $Mode)) {
            [void]$artifacts.Add($artifact)
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

    foreach ($tier in (Get-RangerReportTierDefinitions)) {
        $content = New-RangerReportPayload -Manifest $Manifest -Tier $tier.Name -Mode $Mode
        [void]$tierPayloads.Add([ordered]@{ Definition = $tier; Content = $content })
        if ('markdown' -in $Formats -or 'md' -in $Formats) {
            $markdownPath = Join-Path -Path $reportsRoot -ChildPath ("{0}-{1}.md" -f $prefix, (Get-RangerSafeName -Value $tier.Title))
            (ConvertTo-RangerMarkdownReport -Report $content) | Set-Content -Path $markdownPath -Encoding UTF8
            [void]$artifacts.Add((New-RangerArtifactRecord -Type 'markdown-report' -RelativePath ([System.IO.Path]::GetRelativePath($PackageRoot, $markdownPath)) -Status generated -Audience $tier.Audience))
        }

        if ('html' -in $Formats) {
            $htmlPath = Join-Path -Path $reportsRoot -ChildPath ("{0}-{1}.html" -f $prefix, (Get-RangerSafeName -Value $tier.Title))
            (ConvertTo-RangerHtmlReport -Report $content) | Set-Content -Path $htmlPath -Encoding UTF8
            [void]$artifacts.Add((New-RangerArtifactRecord -Type 'html-report' -RelativePath ([System.IO.Path]::GetRelativePath($PackageRoot, $htmlPath)) -Status generated -Audience $tier.Audience))
        }

        if ('docx' -in $Formats) {
            $docxPath = Join-Path -Path $reportsRoot -ChildPath ("{0}-{1}.docx" -f $prefix, (Get-RangerSafeName -Value $tier.Title))
            Write-RangerDocxReport -Report $content -Path $docxPath
            [void]$artifacts.Add((New-RangerArtifactRecord -Type 'docx-report' -RelativePath ([System.IO.Path]::GetRelativePath($PackageRoot, $docxPath)) -Status generated -Audience $tier.Audience))
        }

        if ('pdf' -in $Formats) {
            $pdfPath = Join-Path -Path $reportsRoot -ChildPath ("{0}-{1}.pdf" -f $prefix, (Get-RangerSafeName -Value $tier.Title))
            Write-RangerPdfReport -Report $content -Path $pdfPath
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
        "Schema warnings: $(@($Manifest.run.schemaValidation.warnings).Count)"
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

    # Issue #73: Health status section with traffic light indicators (all tiers)
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
            "Licensing: $(if ($Manifest.domains.azureIntegration.costLicensing.subscriptionName) { $Manifest.domains.azureIntegration.costLicensing.subscriptionName } else { 'Not collected' })"
        )
    })

    # Issue #73: Capacity Summary with utilization text (all tiers)
    [void]$sections.Add([ordered]@{
        heading = 'Capacity Summary'
        body    = @(
            "Storage total raw: $([math]::Round($summary.StorageTotalRawGiB / 1024, 2)) TiB",
            "Storage total usable: $([math]::Round($summary.StorageTotalUsableGiB / 1024, 2)) TiB",
            "Storage utilization: $($summary.StorageUtilizationPct)% of usable capacity allocated",
            "vCPU:pCPU overcommit ratio: $(if ($summary.VcpuOvercommitRatio) { $summary.VcpuOvercommitRatio } else { 'Not computed' })",
            "Memory overcommit ratio: $(if ($summary.MemoryOvercommitRatio) { $summary.MemoryOvercommitRatio } else { 'Not computed' })",
            "Average VMs per node: $(if ($summary.AvgVmsPerNode) { $summary.AvgVmsPerNode } else { 'N/A' })"
        )
        _visualStats = [ordered]@{
            bars = @(
                [ordered]@{ label = 'Storage utilization'; percent = $summary.StorageUtilizationPct }
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

        # Issue #73: VM Density Metrics (management + technical)
        [void]$sections.Add([ordered]@{
            heading = 'VM Density Metrics'
            body    = @(
                "VMs per node (average): $(if ($summary.AvgVmsPerNode) { $summary.AvgVmsPerNode } else { 'N/A' })",
                "Highest-density node: $(if ($Manifest.domains.virtualMachines.summary.highestDensityNode) { $Manifest.domains.virtualMachines.summary.highestDensityNode } else { 'N/A' })",
                "vCPU:pCPU overcommit ratio: $(if ($summary.VcpuOvercommitRatio) { $summary.VcpuOvercommitRatio } else { 'Not computed' })",
                "Memory overcommit ratio: $(if ($summary.MemoryOvercommitRatio) { $summary.MemoryOvercommitRatio } else { 'Not computed' })",
                "Arc-connected VMs: $($Manifest.domains.virtualMachines.summary.arcConnectedVms)",
                "Avg CPU utilization (all nodes): $($Manifest.domains.performance.summary.averageCpuUtilizationPercent)%",
                "Avg available memory (all nodes): $([math]::Round([double]$Manifest.domains.performance.summary.averageAvailableMemoryMb / 1024, 1)) GiB"
            )
        })

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

    if ($Tier -eq 'technical') {
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

        [void]$sections.Add([ordered]@{
            heading = 'Technical Domain Deep Dive'
            body    = @(
                "Node manufacturers: $((@($Manifest.domains.clusterNode.nodeSummary.manufacturers | ForEach-Object { '{0} ({1})' -f $_.name, $_.count }) -join ', '))",
                "Storage media types: $((@($Manifest.domains.storage.summary.diskMediaTypes | ForEach-Object { '{0} ({1})' -f $_.name, $_.count }) -join ', '))",
                "Adapter states: $((@($Manifest.domains.networking.summary.adapterStates | ForEach-Object { '{0} ({1})' -f $_.name, $_.count }) -join ', '))",
                "VM generations: $((@($Manifest.domains.virtualMachines.summary.byGeneration | ForEach-Object { '{0} ({1})' -f $_.name, $_.count }) -join ', '))",
                "Azure resource types: $((@($Manifest.domains.azureIntegration.resourceSummary.byType | Select-Object -First 6 | ForEach-Object { '{0} ({1})' -f $_.name, $_.count }) -join ', '))",
                "Monitoring summary: telemetry=$($Manifest.domains.monitoring.summary.telemetryCount), ama=$($Manifest.domains.monitoring.summary.amaCount), dcr=$($Manifest.domains.monitoring.summary.dcrCount)",
                "Performance summary: avg CPU=$($Manifest.domains.performance.summary.averageCpuUtilizationPercent), avg available memory MB=$($Manifest.domains.performance.summary.averageAvailableMemoryMb)"
            )
        })

        # Issue #73: Storage Pool Math (Technical) — raw → usable capacity breakdown
        $storageMathLines = @(
            "Storage resiliency math (approximate — actual usable depends on pool resiliency settings):",
            "  Total raw capacity: $([math]::Round($summary.StorageTotalRawGiB, 0)) GiB ($([math]::Round($summary.StorageTotalRawGiB / 1024, 2)) TiB)",
            "  Total usable capacity (after resiliency): $([math]::Round($summary.StorageTotalUsableGiB, 0)) GiB ($([math]::Round($summary.StorageTotalUsableGiB / 1024, 2)) TiB)",
            "  Overhead ratio: $(if ($summary.StorageTotalRawGiB -gt 0) { [math]::Round((1 - $summary.StorageTotalUsableGiB / $summary.StorageTotalRawGiB) * 100, 1) } else { 'N/A' })% consumed by resiliency"
        )
        foreach ($pool in @($Manifest.domains.storage.pools | Where-Object { $_ -ne $null })) {
            # Use bracket notation: works for both Hashtable and OrderedDictionary regardless of
            # whether pools was a single item or array in the manifest (in-memory or deserialized).
            $rawGiB           = [double]($pool['sizeGiB'] ?? $pool['totalCapacityGiB'] ?? 0)
            $resiliencyName   = [string]($pool['resiliencySettingName'] ?? $pool['resiliencyType'] ?? '')
            $numCopies        = if ($pool['numberOfDataCopies']) { [int]$pool['numberOfDataCopies'] } else { 0 }
            # Build human-readable label: Mirror (3-way), Mirror (2-way), Parity, etc.
            $resiliencyDisplay = if (-not $resiliencyName) { 'unknown' }
                                 elseif ($resiliencyName -ieq 'Mirror' -and $numCopies -gt 0) { "Mirror ($numCopies-way)" }
                                 else { $resiliencyName }
            # Efficiency: Mirror 3-way=33%, Mirror 2-way=50%, Parity~60%, Dual Parity~72%, Simple=100%
            $approxPct = if (-not $resiliencyName)                           { 50 }
                         elseif ($resiliencyName -ieq 'Mirror' -and $numCopies -ge 3) { 33 }
                         elseif ($resiliencyName -ieq 'Mirror')              { 50 }
                         elseif ($resiliencyName -ieq 'Parity')              { 60 }
                         elseif ($resiliencyName -ieq 'DualParity')          { 72 }
                         elseif ($resiliencyName -ieq 'Simple')              { 100 }
                         else                                                 { 50 }
            $approxUsableGiB = [math]::Round($rawGiB * $approxPct / 100, 0)
            $storageMathLines += "  Pool '$($pool['friendlyName'])': $rawGiB GiB raw, resiliency=$resiliencyDisplay, ~$approxUsableGiB GiB usable (~$approxPct% efficiency)"
        }
        [void]$sections.Add([ordered]@{
            heading = 'Storage Pool Math'
            body    = $storageMathLines
        })

        # Issue #73: Event Log Analysis Summary (Technical)
        $eventLogSummaryLines = @(
            "Event logs analyzed per node across $(@($Manifest.domains.performance.eventLogAnalysis).Count) log sources:"
        )
        $topLogEntries = @($Manifest.domains.performance.eventLogAnalysis | Where-Object { $_['eventCount'] -gt 0 } | Sort-Object { [int]($_['eventCount'] ?? 0) } -Descending | Select-Object -First 10)
        if ($topLogEntries.Count -gt 0) {
            foreach ($entry in $topLogEntries) {
                $eventLogSummaryLines += "  Node $($entry['node']): $($entry['logName']) — $($entry['eventCount']) events"
                foreach ($topId in @($entry['topEventIds'] | Select-Object -First 2)) {
                    $eventLogSummaryLines += "    EventId $($topId['eventId']) x$($topId['count']) [$($topId['level'])]: $($topId['sample'])"
                }
            }
        } else {
            $eventLogSummaryLines += "  No events recorded in this collection window."
        }
        [void]$sections.Add([ordered]@{
            heading = 'Event Log Analysis'
            body    = $eventLogSummaryLines
        })

        # Issue #73: Full security audit summary (Technical)
        [void]$sections.Add([ordered]@{
            heading = 'Security Audit'
            body    = @(
                "--- Certificate Inventory ---",
                "Total certificates tracked: $(@($Manifest.domains.identitySecurity.posture.certificates).Count)",
                "Expiring within 90 days: $($Manifest.domains.identitySecurity.summary.certificateExpiringWithin90Days)",
                "--- Policy and Compliance ---",
                "Policy assignments: $($Manifest.domains.azureIntegration.policySummary.assignmentCount)",
                "Policy exemptions: $($Manifest.domains.azureIntegration.policySummary.exemptionCount)",
                "Policy non-compliant: $($Manifest.domains.azureIntegration.policySummary.nonCompliantCount)",
                "--- Identity ---",
                "AD objects: $(@($Manifest.domains.identitySecurity.activeDirectory.adObjects).Count) CNO(s) tracked",
                "RBAC assignments at RG scope: $(@($Manifest.domains.identitySecurity.rbacAssignments).Count)",
                "--- Workload Protection ---",
                "Backup items tracked: $(@($Manifest.domains.azureIntegration.backup.items).Count)",
                "ASR (disaster recovery) items: $(@($Manifest.domains.azureIntegration.asr.protectedItems).Count)",
                "--- Endpoint Protection ---",
                "Defender for Cloud enabled: $(if ($Manifest.domains.identitySecurity.defenderForCloud.enabled) { 'Yes' } else { 'Not confirmed' })",
                "Secured-Core nodes: $($Manifest.domains.identitySecurity.summary.securedCoreNodes) of $($summary.NodeCount)"
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
        $sections.Insert(0, (New-RangerAsBuiltDocumentControlSection -Manifest $Manifest -Tier $Tier))
        if ($Tier -ne 'executive') {
            [void]$sections.Add((New-RangerAsBuiltInstallationRegisterSection -Manifest $Manifest))
        }
        [void]$sections.Add((New-RangerAsBuiltSignOffSection))
    }

    return [ordered]@{
        Title           = ((Get-RangerReportTierDefinitions | Where-Object { $_.Name -eq $Tier } | Select-Object -First 1).Title)
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
        # Issue #73: Visual stats passed to HTML renderer
        VisualStats     = [ordered]@{
            healthLights = @(
                [ordered]@{ label = 'Overall Health';      color = $summary.OverallHealthColor }
                [ordered]@{ label = 'Azure Integration';   color = $summary.AzureIntegrationColor }
                [ordered]@{ label = 'Security Posture';    color = $summary.SecurityPostureColor }
                [ordered]@{ label = 'Monitoring Coverage'; color = if ($summary.MonitoringCoveragePercent -ge 100) { 'green' } elseif ($summary.MonitoringCoveragePercent -gt 0) { 'yellow' } else { 'gray' } }
            )
            capacityBars = @(
                [ordered]@{ label = 'Storage utilization';  percent = $summary.StorageUtilizationPct }
                [ordered]@{ label = 'Monitoring coverage';  percent = $summary.MonitoringCoveragePercent }
                [ordered]@{ label = 'Backup coverage';      percent = $summary.BackupCoveragePercent }
            )
        }
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

    # Issue #73: Monitoring coverage — use nodesWithAmaAgent (OS-level service count) not
    # amaCount (Azure extension records which includes many non-node resources).
    $amaCount             = if ($monitorSummary -and $null -ne $monitorSummary.nodesWithAmaAgent) { [int]$monitorSummary.nodesWithAmaAgent } elseif ($monitorSummary -and $null -ne $monitorSummary.amaCount -and [int]$monitorSummary.amaCount -le $nodeCount) { [int]$monitorSummary.amaCount } else { 0 }
    $monitoringCoveragePct = if ($nodeCount -gt 0) { [math]::Min(100, [math]::Round($amaCount / $nodeCount * 100, 0)) } else { 0 }

    # Issue #73: Backup coverage estimate (backup items / VMs)
    $backupItemCount  = @($Manifest.domains.azureIntegration.backup.items).Count
    $backupCoveragePct = if ($vmCount -gt 0) { [math]::Min(100, [math]::Round($backupItemCount / $vmCount * 100, 0)) } else { 0 }

    # Issue #73: Storage utilization
    $storageTotalRaw    = if ($storageSummary -and $storageSummary.totalRawCapacityGiB)    { [double]$storageSummary.totalRawCapacityGiB }    else { 0 }
    $storageTotalUsable = if ($storageSummary -and $storageSummary.totalUsableCapacityGiB) { [double]$storageSummary.totalUsableCapacityGiB } else { 0 }
    $storageAllocated   = if ($storageSummary -and $storageSummary.totalAllocatedCapacityGiB) { [double]$storageSummary.totalAllocatedCapacityGiB } else { 0 }
    $storageUtilPct     = if ($storageTotalUsable -gt 0) { [math]::Round($storageAllocated / $storageTotalUsable * 100, 1) } else { 0 }

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
        StorageUtilizationPct     = $storageUtilPct
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
        foreach ($entry in @($section.body)) {
            $lines.Add("- $entry")
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

function ConvertTo-RangerHtmlReport {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Report
    )

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
            $items = @(
                foreach ($entry in @($section.body)) {
                    '<li>{0}</li>' -f ([System.Net.WebUtility]::HtmlEncode([string]$entry))
                }
            ) -join [Environment]::NewLine

            @"
<section>
  <h2>$([System.Net.WebUtility]::HtmlEncode($section.heading))</h2>
  <ul>
$items
  </ul>
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

    @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>$([System.Net.WebUtility]::HtmlEncode($Report.Title))</title>
  <style>
        :root { color-scheme: light; }
        body { font-family: Segoe UI, Arial, sans-serif; margin: 0; color: #16202a; background: linear-gradient(180deg, #f8fbff 0%, #eef6fb 100%); }
        .shell { max-width: 1280px; margin: 0 auto; padding: 2rem; }
        header { border-bottom: 2px solid #0e7490; margin-bottom: 1.5rem; padding-bottom: 1rem; }
    h1, h2, h3 { color: #0f172a; }
    .meta { color: #475569; }
        .hero { display: grid; grid-template-columns: 2fr 1fr; gap: 1rem; align-items: start; }
        .panel { background: rgba(255,255,255,0.92); border: 1px solid #dbe7ef; border-radius: 16px; padding: 1rem 1.25rem; box-shadow: 0 12px 30px rgba(15, 23, 42, 0.06); }
        .toc ul, .recommendations ul { margin: 0.5rem 0 0 1rem; }
        .collector-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 0.75rem; margin: 1rem 0 1.5rem; }
        .collector-card { border-radius: 14px; padding: 0.85rem 1rem; background: #ffffff; border: 1px solid #d7e3ed; }
        .collector-card.status-success { border-color: #86efac; }
        .collector-card.status-partial { border-color: #fbbf24; }
        .collector-card.status-failed { border-color: #fca5a5; }
        .collector-card.status-skipped { border-color: #cbd5e1; }
    .finding { border-left: 4px solid #94a3b8; padding: 0.75rem 1rem; margin: 1rem 0; background: #f8fafc; }
    .finding-critical { border-left-color: #b91c1c; }
    .finding-warning { border-left-color: #d97706; }
    .finding-good { border-left-color: #15803d; }
    .finding-informational { border-left-color: #2563eb; }
        section { margin: 1rem 0; background: rgba(255,255,255,0.92); border: 1px solid #dbe7ef; border-radius: 16px; padding: 1rem 1.25rem; }
        @media (max-width: 900px) { .hero { grid-template-columns: 1fr; } }
        /* Issue #73: Stats banner (traffic lights + capacity bars) */
        .stats-banner { display: flex; gap: 2rem; flex-wrap: wrap; background: rgba(255,255,255,0.95); border: 1px solid #dbe7ef; border-radius: 16px; padding: 1rem 1.5rem; margin-bottom: 1rem; align-items: flex-start; }
        .stats-lights { display: flex; gap: 1.25rem; flex-wrap: wrap; align-items: center; }
        .tl-item { display: flex; align-items: center; gap: 6px; font-size: 0.92em; font-weight: 500; white-space: nowrap; }
        .stats-bars { display: flex; flex-direction: column; gap: 0.4rem; }
        .cap-item { display: flex; align-items: center; gap: 8px; font-size: 0.88em; }
        .cap-label { min-width: 160px; color: #475569; }
  </style>
</head>
<body>
    <div class="shell">
        <header>
            <h1>$([System.Net.WebUtility]::HtmlEncode($Report.Title))</h1>
            <p class="meta">Cluster: $([System.Net.WebUtility]::HtmlEncode($Report.ClusterName))</p>
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