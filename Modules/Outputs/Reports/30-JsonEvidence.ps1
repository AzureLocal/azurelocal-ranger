function Write-RangerJsonEvidenceExport {
    <#
    .SYNOPSIS
        v2.0.0 (#229): export a resource-only JSON evidence payload.
    .DESCRIPTION
        Strips assessment, scoring, pipeline metadata, and schema validation
        fields from the manifest, leaving only the raw collected inventory
        plus a small `_metadata` envelope. Intended for downstream tools
        (Power BI, CMDBs, custom scripts) that shouldn't have to parse around
        findings / WAF scoring / run metadata.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [string]$PackageRoot,

        [string]$FileName
    )

    $target  = $Manifest.target
    $run     = $Manifest.run
    $runId   = if ($run -and $run.runId) {
        [string]$run.runId
    } elseif ($run -and $run.startTimeUtc) {
        # Strip every character except digits so the id is filesystem-safe
        # regardless of the timestamp format (ISO-8601, compact, etc).
        $digits = ([string]$run.startTimeUtc) -replace '[^\d]',''
        if ($digits.Length -ge 14) { $digits.Substring(0,14) } else { $digits.PadRight(14, '0') }
    } else {
        (Get-Date).ToString('yyyyMMddHHmmss')
    }

    $getDomain = {
        param($name)
        try { return $Manifest.domains.$name } catch { return $null }
    }
    $ai = & $getDomain 'azureIntegration'
    $storage = & $getDomain 'storage'
    $networking = & $getDomain 'networking'
    $cluster = & $getDomain 'clusterNode'
    $vms = & $getDomain 'virtualMachines'

    $payload = [ordered]@{
        _metadata = [ordered]@{
            exportVersion = '1.0'
            generatedAt   = (Get-Date).ToUniversalTime().ToString('o')
            rangerVersion = [string]$run.toolVersion
            clusterName   = [string]$target.clusterName
            runId         = $runId
        }
        nodes            = if ($cluster) { @($cluster.nodes) } else { @() }
        storagePools     = if ($storage) { @($storage.pools) } else { @() }
        volumes          = if ($storage) { @($storage.volumes) } else { @() }
        logicalNetworks  = if ($networking -and $networking.logicalNetworks) { @($networking.logicalNetworks) } else { @() }
        storagePaths     = if ($storage -and $storage.storagePaths) { @($storage.storagePaths) } else { @() }
        virtualMachines  = if ($vms) { @($vms.inventory) } else { @() }
        arcExtensions    = if ($ai -and $ai.arcExtensionsDetail -and $ai.arcExtensionsDetail.byNode) { @($ai.arcExtensionsDetail.byNode) } else { @() }
        arcResourceBridges = if ($ai -and $ai.resourceBridgeDetail) { @($ai.resourceBridgeDetail) } else { @() }
        customLocations  = if ($ai -and $ai.customLocationsDetail) { @($ai.customLocationsDetail) } else { @() }
        arcGateways      = if ($ai -and $ai.arcGateways) { @($ai.arcGateways) } else { @() }
        marketplaceImages = if ($ai -and $ai.marketplaceImages) { @($ai.marketplaceImages) } else { @() }
        galleryImages    = if ($ai -and $ai.galleryImages) { @($ai.galleryImages) } else { @() }
        costLicensing    = if ($ai -and $ai.costLicensing) { $ai.costLicensing } else { $null }
    }

    $reportsDir = Join-Path $PackageRoot 'reports'
    if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }
    $name = if ($FileName) { $FileName } else { "$runId-evidence.json" }
    $destPath = Join-Path $reportsDir $name
    $payload | ConvertTo-Json -Depth 30 | Set-Content -Path $destPath -Encoding UTF8

    return [ordered]@{
        type         = 'json-evidence'
        relativePath = [System.IO.Path]::GetRelativePath($PackageRoot, $destPath)
        status       = 'generated'
        audience     = 'all'
    }
}
