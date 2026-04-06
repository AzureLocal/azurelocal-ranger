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

    $sections = New-Object System.Collections.ArrayList
    [void]$sections.Add([ordered]@{
        heading = 'Run Summary'
        body    = @(
            "Mode: $Mode",
            "Generated: $($Manifest.run.endTimeUtc)",
            "Cluster: $($summary.ClusterName)",
            "Nodes: $($summary.NodeCount)",
            "Collectors: $($summary.SuccessfulCollectors)/$($summary.TotalCollectors) successful"
        )
    })

    [void]$sections.Add([ordered]@{
        heading = 'Environment Overview'
        body    = @(
            "Deployment type: $($summary.DeploymentType)",
            "Identity mode: $($summary.IdentityMode)",
            "Connectivity mode: $($summary.ControlPlaneMode)",
            "VMs discovered: $($summary.VmCount)",
            "Azure resources discovered: $($summary.AzureResourceCount)"
        )
    })

    if ($Tier -ne 'executive') {
        [void]$sections.Add([ordered]@{
            heading = 'Collector Status'
            body    = @(
                $Manifest.collectors.Keys | Sort-Object | ForEach-Object {
                    "{0}: {1}" -f $_, $Manifest.collectors[$_].status
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
                "Monitoring components: $(@($Manifest.domains.monitoring.telemetry).Count + @($Manifest.domains.monitoring.ama).Count + @($Manifest.domains.monitoring.dcr).Count)"
            )
        })
    }

    return [ordered]@{
        Title       = ((Get-RangerReportTierDefinitions | Where-Object { $_.Name -eq $Tier } | Select-Object -First 1).Title)
        Tier        = $Tier
        ClusterName = $summary.ClusterName
        Mode        = $Mode
        Summary     = $summary
        Findings    = @($findings)
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
    $lines.Add('')

    foreach ($section in $Report.Sections) {
        $lines.Add("## $($section.heading)")
        $lines.Add('')
        foreach ($entry in @($section.body)) {
            $lines.Add("- $entry")
        }
        $lines.Add('')
    }

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
    body { font-family: Segoe UI, Arial, sans-serif; margin: 2rem; color: #16202a; }
    header { border-bottom: 2px solid #0e7490; margin-bottom: 1.5rem; padding-bottom: 1rem; }
    h1, h2, h3 { color: #0f172a; }
    .meta { color: #475569; }
    .finding { border-left: 4px solid #94a3b8; padding: 0.75rem 1rem; margin: 1rem 0; background: #f8fafc; }
    .finding-critical { border-left-color: #b91c1c; }
    .finding-warning { border-left-color: #d97706; }
    .finding-good { border-left-color: #15803d; }
    .finding-informational { border-left-color: #2563eb; }
  </style>
</head>
<body>
  <header>
    <h1>$([System.Net.WebUtility]::HtmlEncode($Report.Title))</h1>
    <p class="meta">Cluster: $([System.Net.WebUtility]::HtmlEncode($Report.ClusterName))</p>
    <p class="meta">Mode: $([System.Net.WebUtility]::HtmlEncode($Report.Mode)) | Ranger Version: $([System.Net.WebUtility]::HtmlEncode($Report.Version)) | Generated: $([System.Net.WebUtility]::HtmlEncode($Report.GeneratedAt))</p>
  </header>
  $sectionHtml
  <section>
    <h2>Findings</h2>
    $findingHtml
  </section>
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
        '',
        'Artifacts in this package were rendered from the saved Ranger manifest. No live discovery is required to rerender reports or diagrams.'
    ) -join [Environment]::NewLine | Set-Content -Path $path -Encoding UTF8

    return $path
}