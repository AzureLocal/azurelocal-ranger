#Requires -Version 7.0

<#
.SYNOPSIS
    v2.5.0 multi-cluster estate orchestration (#129) and manual evidence import (#32).
#>

function Invoke-AzureLocalRangerEstate {
    <#
    .SYNOPSIS
        v2.5.0 (#129): run Ranger against multiple clusters and produce an estate rollup.
    .DESCRIPTION
        Accepts an array of per-cluster configuration blocks (or a single config file
        containing an `estate.targets` list). Runs `Invoke-AzureLocalRanger` per target
        sequentially, then emits `estate-rollup.json` + `estate-summary.html` +
        `powerbi/estate-*.csv` summarising node count, VM count, WAF scores, AHB posture,
        and capacity headroom across the estate.
    .PARAMETER ConfigPath
        Path to a JSON/YAML config file with an `estate` block listing targets.
    .PARAMETER Targets
        Inline array of target config hashtables. Each must include `clusterName`
        and a `configPath` or inline collector settings.
    .PARAMETER OutputRoot
        Root folder for per-cluster packages + estate rollup. Default: current directory.
    .EXAMPLE
        Invoke-AzureLocalRangerEstate -ConfigPath ranger-estate.json
    #>
    [CmdletBinding(DefaultParameterSetName = 'Config')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Config')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $true, ParameterSetName = 'Inline')]
        [object[]]$Targets,

        [string]$OutputRoot = (Get-Location).Path,

        [switch]$FixtureMode,

        [switch]$ContinueOnClusterError
    )

    if ($PSCmdlet.ParameterSetName -eq 'Config') {
        if (-not (Test-Path -Path $ConfigPath -PathType Leaf)) {
            throw "Estate config not found: $ConfigPath"
        }
        $raw = Get-Content -Path $ConfigPath -Raw
        $cfg = if ($ConfigPath -like '*.yml' -or $ConfigPath -like '*.yaml') {
            if (-not (Get-Module -ListAvailable -Name powershell-yaml)) { throw 'powershell-yaml module required for YAML estate configs.' }
            Import-Module powershell-yaml -Force
            $raw | ConvertFrom-Yaml
        } else {
            $raw | ConvertFrom-Json -AsHashtable -Depth 20
        }
        $Targets = @($cfg.estate.targets)
    }

    if (-not $Targets -or $Targets.Count -eq 0) {
        throw 'No estate targets provided.'
    }

    $estateStart = Get-Date
    $runId = (Get-Date -Format 'yyyyMMddHHmmss')
    $estateDir = Join-Path $OutputRoot ("estate-$runId")
    New-Item -ItemType Directory -Path $estateDir -Force | Out-Null

    $clusterResults = New-Object System.Collections.ArrayList
    foreach ($t in $Targets) {
        $clusterName = [string]$t.clusterName
        if ([string]::IsNullOrWhiteSpace($clusterName)) { $clusterName = 'unknown' }
        Write-Host "[estate] Running against cluster '$clusterName'..."

        $perOut = Join-Path $estateDir $clusterName
        New-Item -ItemType Directory -Path $perOut -Force | Out-Null

        try {
            $params = @{ OutputPath = $perOut }
            if ($t.configPath)   { $params['ConfigPath'] = [string]$t.configPath }
            if ($FixtureMode)    { $params['FixtureMode'] = $true }

            $result = if (Get-Command -Name Invoke-AzureLocalRanger -ErrorAction SilentlyContinue) {
                Invoke-AzureLocalRanger @params
            } else { $null }

            $manifestPath = Join-Path $perOut 'audit-manifest.json'
            $m = $null
            if (Test-Path -Path $manifestPath -PathType Leaf) {
                $m = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json -AsHashtable -Depth 50
            }

            [void]$clusterResults.Add([ordered]@{
                cluster         = $clusterName
                outputPath      = $perOut
                manifestPath    = $manifestPath
                status          = if ($m) { 'ok' } else { 'failed' }
                manifest        = $m
            })
        } catch {
            Write-Warning "[estate] $clusterName failed: $($_.Exception.Message)"
            [void]$clusterResults.Add([ordered]@{
                cluster      = $clusterName
                outputPath   = $perOut
                status       = 'failed'
                error        = $_.Exception.Message
            })
            if (-not $ContinueOnClusterError) { throw }
        }
    }

    # Build the estate rollup
    $rollup = New-RangerEstateRollup -ClusterResults $clusterResults -RunId $runId -StartTime $estateStart
    $rollupPath = Join-Path $estateDir 'estate-rollup.json'
    $rollup | ConvertTo-Json -Depth 20 | Set-Content -Path $rollupPath -Encoding UTF8

    # Power BI CSVs
    $pbiDir = Join-Path $estateDir 'powerbi'
    New-Item -ItemType Directory -Path $pbiDir -Force | Out-Null
    $rollup.clusters | ForEach-Object {
        [PSCustomObject]@{
            Cluster            = $_.cluster
            NodeCount          = $_.nodeCount
            VmCount            = $_.vmCount
            WafScore           = $_.wafScore
            WafStatus          = $_.wafStatus
            AhbAdoptionPct     = $_.ahbAdoptionPct
            StorageUsedPct     = $_.storageUsedPct
            CapacityStatus     = $_.capacityStatus
        }
    } | Export-Csv -Path (Join-Path $pbiDir 'estate-clusters.csv') -NoTypeInformation -Encoding UTF8

    $summaryPath = Join-Path $estateDir 'estate-summary.html'
    New-RangerEstateSummaryHtml -Rollup $rollup -OutputPath $summaryPath

    Write-Host "[estate] Rollup: $rollupPath"
    return [ordered]@{
        estateDir       = $estateDir
        rollupPath      = $rollupPath
        summaryPath     = $summaryPath
        clusterCount    = $clusterResults.Count
        clusters        = @($clusterResults | ForEach-Object { [ordered]@{ cluster = $_.cluster; status = $_.status } })
    }
}

function New-RangerEstateRollup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IEnumerable]$ClusterResults,
        [Parameter(Mandatory = $true)] [string]$RunId,
        [Parameter(Mandatory = $true)] [datetime]$StartTime
    )

    $clusters = New-Object System.Collections.ArrayList
    $totalNodes = 0; $totalVms = 0
    $scoreSum = 0.0; $scoreCount = 0
    $ahbSum = 0.0; $ahbCount = 0

    foreach ($c in $ClusterResults) {
        $m = $c.manifest
        if (-not $m) {
            [void]$clusters.Add([ordered]@{ cluster = $c.cluster; status = $c.status; error = $c.error })
            continue
        }
        $nodes = @($m.domains.clusterNode.nodes).Count
        $vms   = @($m.domains.virtualMachines.inventory).Count
        $waf   = $m.domains.wafAssessment.summary
        $ahb   = $m.domains.azureIntegration.costLicensing.summary
        $cap   = $m.domains.capacityAnalysis.summary
        $totalNodes += $nodes
        $totalVms += $vms
        if ($waf -and $waf.overallScore) { $scoreSum += [double]$waf.overallScore; $scoreCount++ }
        if ($ahb -and $null -ne $ahb.ahbAdoptionPct) { $ahbSum += [double]$ahb.ahbAdoptionPct; $ahbCount++ }

        [void]$clusters.Add([ordered]@{
            cluster        = $c.cluster
            status         = 'ok'
            nodeCount      = $nodes
            vmCount        = $vms
            wafScore       = if ($waf) { [int]$waf.overallScore } else { 0 }
            wafStatus      = if ($waf) { [string]$waf.status } else { 'unknown' }
            ahbAdoptionPct = if ($ahb) { [double]$ahb.ahbAdoptionPct } else { 0 }
            storageUsedPct = if ($cap) { [double]$cap.storageUtilizationPct } else { 0 }
            capacityStatus = if ($cap) { [string]$cap.storageStatus } else { 'unknown' }
            manifestPath   = $c.manifestPath
        })
    }

    return [ordered]@{
        schemaVersion       = '1.0'
        runId               = $RunId
        generatedAtUtc      = (Get-Date).ToUniversalTime().ToString('o')
        clusterCount        = $clusters.Count
        totalNodes          = $totalNodes
        totalVms            = $totalVms
        averageWafScore     = if ($scoreCount -gt 0) { [int][Math]::Round($scoreSum / $scoreCount) } else { 0 }
        averageAhbAdoption  = if ($ahbCount -gt 0) { [Math]::Round($ahbSum / $ahbCount, 1) } else { 0 }
        clusters            = @($clusters)
    }
}

function New-RangerEstateSummaryHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary]$Rollup,
        [Parameter(Mandatory = $true)] [string]$OutputPath
    )

    $rows = foreach ($c in $Rollup.clusters) {
        "<tr><td>$([System.Web.HttpUtility]::HtmlEncode($c.cluster))</td><td>$($c.status)</td><td>$($c.nodeCount)</td><td>$($c.vmCount)</td><td>$($c.wafScore)% ($($c.wafStatus))</td><td>$($c.ahbAdoptionPct)%</td><td>$($c.storageUsedPct)% ($($c.capacityStatus))</td></tr>"
    }
    $rowsHtml = ($rows -join [Environment]::NewLine)

    $html = @"
<!DOCTYPE html>
<html><head><meta charset='utf-8'><title>Ranger Estate Rollup — $($Rollup.runId)</title>
<style>body{font-family:Segoe UI,Arial,sans-serif;margin:24px} table{border-collapse:collapse;width:100%} th,td{border:1px solid #ccc;padding:6px 10px;text-align:left} th{background:#f5f5f5}</style>
</head><body>
<h1>Azure Local Ranger — Estate Rollup</h1>
<p>Run $($Rollup.runId) — $($Rollup.clusterCount) cluster(s), $($Rollup.totalNodes) nodes, $($Rollup.totalVms) VMs. Average WAF score: $($Rollup.averageWafScore)%. Average AHB adoption: $($Rollup.averageAhbAdoption)%.</p>
<table>
<tr><th>Cluster</th><th>Status</th><th>Nodes</th><th>VMs</th><th>WAF</th><th>AHB</th><th>Storage</th></tr>
$rowsHtml
</table>
</body></html>
"@
    [System.IO.File]::WriteAllText($OutputPath, $html, [System.Text.Encoding]::UTF8)
}

function Import-RangerManualEvidence {
    <#
    .SYNOPSIS
        v2.5.0 (#32): merge externally collected evidence into an existing Ranger manifest.
    .DESCRIPTION
        Operators can hand-collect data from systems Ranger cannot reach (air-gapped
        network devices, externally managed firewalls, paper inventories) and merge
        the result into an existing audit-manifest.json with provenance labels.
    .PARAMETER ManifestPath
        Path to the existing audit-manifest.json to enrich.
    .PARAMETER EvidencePath
        Path to the manual-evidence JSON file. Must contain `domain` (string) and
        `data` (object/array) at the root, plus optional `provenance` metadata.
    .PARAMETER Source
        Label describing the data source (e.g. 'manual-network-inventory'). Recorded
        in `manifest.run.manualImports` so downstream consumers can distinguish
        machine-collected from manually supplied data.
    .PARAMETER OutputPath
        Optional alternate output path. Defaults to overwriting the source manifest.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$ManifestPath,
        [Parameter(Mandatory = $true)] [string]$EvidencePath,
        [Parameter(Mandatory = $true)] [string]$Source,
        [string]$OutputPath
    )

    if (-not (Test-Path -Path $ManifestPath -PathType Leaf)) { throw "Manifest not found: $ManifestPath" }
    if (-not (Test-Path -Path $EvidencePath -PathType Leaf)) { throw "Evidence not found: $EvidencePath" }

    $manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json -AsHashtable -Depth 50
    $evidence = Get-Content -Path $EvidencePath -Raw | ConvertFrom-Json -AsHashtable -Depth 50

    $domain = [string]$evidence.domain
    if ([string]::IsNullOrWhiteSpace($domain)) { throw "Evidence file must include a top-level 'domain' key." }
    if (-not $evidence.Contains('data')) { throw "Evidence file must include a top-level 'data' key." }

    if (-not $manifest.domains) { $manifest.domains = [ordered]@{} }
    if (-not $manifest.domains.Contains($domain)) { $manifest.domains[$domain] = [ordered]@{} }

    # Namespace the imported data so it doesn't clobber machine-collected fields.
    $manifest.domains[$domain].manualImport = [ordered]@{
        source         = $Source
        importedAtUtc  = (Get-Date).ToUniversalTime().ToString('o')
        provenance     = if ($evidence.provenance) { $evidence.provenance } else { @{} }
        data           = $evidence.data
    }

    if (-not $manifest.run) { $manifest.run = [ordered]@{} }
    if (-not $manifest.run.manualImports) { $manifest.run.manualImports = @() }
    $manifest.run.manualImports = @($manifest.run.manualImports) + @([ordered]@{
        source         = $Source
        domain         = $domain
        importedAtUtc  = (Get-Date).ToUniversalTime().ToString('o')
        evidenceFile   = (Resolve-Path -Path $EvidencePath).Path
    })

    $target = if ($OutputPath) { $OutputPath } else { $ManifestPath }
    $manifest | ConvertTo-Json -Depth 50 | Set-Content -Path $target -Encoding UTF8

    return [ordered]@{
        status         = 'ok'
        manifestPath   = $target
        domain         = $domain
        source         = $Source
        importCount    = @($manifest.run.manualImports).Count
    }
}
