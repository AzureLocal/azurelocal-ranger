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
    $reportFormats = @($normalizedFormats | Where-Object { $_ -in @('html', 'markdown', 'md') })
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

    foreach ($tier in (Get-RangerReportTierDefinitions)) {
        $content = New-RangerReportPayload -Manifest $Manifest -Tier $tier.Name -Mode $Mode
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
    }

    return @($artifacts)
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
    }

    if ($Mode -eq 'as-built') {
        $sections.Insert(0, (New-RangerAsBuiltDocumentControlSection -Manifest $Manifest -Tier $Tier))
        if ($Tier -ne 'executive') {
            [void]$sections.Add((New-RangerAsBuiltInstallationRegisterSection -Manifest $Manifest))
        }
        [void]$sections.Add((New-RangerAsBuiltSignOffSection))
    }

    return [ordered]@{
        Title       = ((Get-RangerReportTierDefinitions | Where-Object { $_.Name -eq $Tier } | Select-Object -First 1).Title)
        Tier        = $Tier
        ClusterName = $summary.ClusterName
        Mode        = $Mode
        Summary     = $summary
        Findings    = @($findings)
        Recommendations = @($recommendations)
        CollectorCards = @($collectorCards)
        TableOfContents = @($sections | ForEach-Object { $_.heading })
        Sections    = @($sections)
        Version     = $Manifest.run.toolVersion
        GeneratedAt = $Manifest.run.endTimeUtc
    }
}

function Get-RangerManifestSummary {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $collectorStatuses = @($Manifest.collectors.Values)
    [ordered]@{
        ClusterName          = if (-not [string]::IsNullOrWhiteSpace($Manifest.target.clusterName)) { $Manifest.target.clusterName } else { $Manifest.target.environmentLabel }
        NodeCount            = @($Manifest.domains.clusterNode.nodes).Count
        VmCount              = @($Manifest.domains.virtualMachines.inventory).Count
        AzureResourceCount   = @($Manifest.domains.azureIntegration.resources).Count
        DeploymentType       = $Manifest.topology.deploymentType
        IdentityMode         = $Manifest.topology.identityMode
        ControlPlaneMode     = $Manifest.topology.controlPlaneMode
        TotalCollectors      = $collectorStatuses.Count
        SuccessfulCollectors = @($collectorStatuses | Where-Object { $_.status -eq 'success' }).Count
        PartialCollectors    = @($collectorStatuses | Where-Object { $_.status -eq 'partial' }).Count
        FailedCollectors     = @($collectorStatuses | Where-Object { $_.status -eq 'failed' }).Count
        FindingsBySeverity   = [ordered]@{
            critical      = @($Manifest.findings | Where-Object { $_.severity -eq 'critical' }).Count
            warning       = @($Manifest.findings | Where-Object { $_.severity -eq 'warning' }).Count
            informational = @($Manifest.findings | Where-Object { $_.severity -eq 'informational' }).Count
            good          = @($Manifest.findings | Where-Object { $_.severity -eq 'good' }).Count
        }
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
  </style>
</head>
<body>
    <div class="shell">
        <header>
            <h1>$([System.Net.WebUtility]::HtmlEncode($Report.Title))</h1>
            <p class="meta">Cluster: $([System.Net.WebUtility]::HtmlEncode($Report.ClusterName))</p>
            <p class="meta">Mode: $([System.Net.WebUtility]::HtmlEncode($Report.Mode)) | Ranger Version: $([System.Net.WebUtility]::HtmlEncode($Report.Version)) | Generated: $([System.Net.WebUtility]::HtmlEncode($Report.GeneratedAt))</p>
        </header>
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