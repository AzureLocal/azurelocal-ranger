#Requires -Version 7.0
<#
.SYNOPSIS
    Generates docs/reference/collectors/*.md from the collector definitions and the fixture manifest.
.DESCRIPTION
    One page per collector, built from Get-RangerCollectorDefinitions (id, function, class, targets, credential, domain payloads),
    the payload keys seen in tests/maproom/Fixtures/synthetic-manifest.json, and the notes table below. A Pester test regenerates the
    pages and fails when the checked-in files are out of date, so the pages cannot drift from the code.
.PARAMETER OutputPath
    Folder for the generated pages. Defaults to docs/reference/collectors.
.PARAMETER Check
    Do not write; return the list of pages that differ from what is on disk.
#>
[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$OutputPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path 'docs\reference\collectors'),
    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $Root 'AzureLocalRanger.psd1') -Force
$module = Get-Module AzureLocalRanger
$definitions = & $module { Get-RangerCollectorDefinitions }
$fixture = Get-Content (Join-Path $Root 'tests\maproom\Fixtures\synthetic-manifest.json') -Raw | ConvertFrom-Json -AsHashtable

$notes = @{
    'topology-cluster' = @{
        Title = 'Topology and cluster collector'
        Access = 'WinRM (or Arc Run Command) to the cluster nodes with a cluster credential that can read Failover Clustering, CIM and the Solution Update cmdlets. Read-only.'
        Skips = 'Skipped when no cluster transport is reachable (connectivity matrix) and the collector is optional; otherwise the run fails because every other collector needs the node list.'
        New2609 = @(
            @('Rack aware cluster zones', 'domains.clusterNode.rackAware', 'https://learn.microsoft.com/azure/azure-local/concepts/rack-aware-cluster-reference-architecture'),
            @('SBE / OEM update detail', 'domains.clusterNode.solutionUpdateDetail', 'https://learn.microsoft.com/azure/azure-local/update/solution-builder-extension')
        )
    }
    'hardware' = @{
        Title = 'Hardware collector'
        Access = 'Redfish over HTTPS to each BMC (iDRAC, iLO, XClarity or compatible) with a BMC credential; WinRM for the matching node when reachable. Read-only.'
        Skips = 'Auto-deselected when no BMC endpoints are configured; skipped when the BMC network is unreachable. A BMC that answers with 401 or 403 is reported per endpoint and the rest continue.'
        New2609 = @()
    }
    'storage-networking' = @{
        Title = 'Storage and networking collector'
        Access = 'WinRM to the nodes (Storage, NetAdapter, Hyper-V, Network ATC, DCB cmdlets). Optional offline switch or firewall configuration files. Read-only.'
        Skips = 'Core collector: it fails the run when no storage or network data can be read from any node. Individual reads that fail are listed in the collector degradations.'
        New2609 = @(,
            @('Disaggregated / SAN indicators', 'domains.storage.architectureIndicators', 'https://learn.microsoft.com/azure/well-architected/service-guides/azure-local')
        )
    }
    'workload-identity-azure' = @{
        Title = 'Workload, identity and Azure collector'
        Access = 'WinRM to the nodes for VMs, certificates, BitLocker, Defender and Active Directory; Azure Resource Manager and Resource Graph with at least Reader on the cluster resource group. Read-only.'
        Skips = 'Azure reads degrade (not fail) when ARM returns 403, 404 or throttling: the item is listed in manifest.run.skippedResources and in the collector degradations.'
        New2609 = @(
            @('Arc gateway resources and per-node routing', 'domains.azureIntegration.arcGateways, arcGatewayNodeRouting', 'https://learn.microsoft.com/azure/azure-local/deploy/deployment-azure-arc-gateway-overview'),
            @('Security baseline compliance score', 'domains.azureIntegration.securityBaseline', 'https://learn.microsoft.com/azure/azure-local/manage/manage-secure-baseline'),
            @('Secure Boot 2023 certificate status', 'domains.identitySecurity.secureBootCertificates', 'https://learn.microsoft.com/azure/azure-local/manage/manage-secure-boot-updates'),
            @('Backup key vault candidates (automatic key backup, preview)', 'domains.azureIntegration.keyBackup', 'https://learn.microsoft.com/azure/azure-local/manage/trusted-launch-vm-overview'),
            @('Local identity with Key Vault and internal DNS (preview)', 'domains.identitySecurity.localIdentity', 'https://learn.microsoft.com/azure/azure-local/deploy/deployment-local-identity-with-key-vault'),
            @('Private path network indicators', 'domains.azureIntegration.privatePath', 'https://learn.microsoft.com/azure/azure-local/concepts/private-path-network-overview')
        )
    }
    'monitoring-observability' = @{
        Title = 'Monitoring and observability collector'
        Access = 'Azure Resource Manager (Reader) for Azure Monitor, Log Analytics, data collection rules and endpoints, and Azure Update Manager. Read-only.'
        Skips = 'Skipped when Azure is not reachable or no Azure credential is configured.'
        New2609 = @()
    }
    'management-performance' = @{
        Title = 'Management tools and performance collector'
        Access = 'WinRM to the nodes for services, installed management agents and a short performance sample. Read-only.'
        Skips = 'Registry reads for optional agents (for example Operations Manager) that are absent are not errors; other failed reads are listed in the collector degradations.'
        New2609 = @()
    }
    'waf-assessment' = @{
        Title = 'Well-Architected assessment collector'
        Access = 'Evaluates the manifest with the rule engine and reads Azure Advisor recommendations (Reader). No node access.'
        Skips = 'Optional: skipped when Azure is not reachable; the rule engine part still runs from the manifest.'
        New2609 = @()
    }
}

$pages = [ordered]@{}
foreach ($id in $definitions.Keys) {
    $d = $definitions[$id]
    $n = $notes[$id]
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# $($n.Title)")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('> Generated by `scripts/docs/New-CollectorReferencePages.ps1` from the collector definitions. Do not edit by hand.')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Property | Value |')
    [void]$sb.AppendLine('| --- | --- |')
    [void]$sb.AppendLine("| Id | ``$($d.Id)`` |")
    [void]$sb.AppendLine("| Function | ``$($d.FunctionName)`` |")
    [void]$sb.AppendLine("| Class | $($d.Class) |")
    [void]$sb.AppendLine("| Covers | $(@($d.Covers) -join ', ') |")
    [void]$sb.AppendLine("| Required target | $(@($d.RequiredTargets) -join ', ') |")
    [void]$sb.AppendLine("| Required credential | $($d.RequiredCredential) |")
    $domainText = (@($d.DomainPayloads | ForEach-Object { '`domains.' + $_ + '`' }) -join ', ')
    [void]$sb.AppendLine("| Manifest domains | $domainText |")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## Access and permissions')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine($n.Access)
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## Output')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('Top-level keys of each domain, as seen in the fixture manifest (`tests/maproom/Fixtures/synthetic-manifest.json`). Collectors can add keys between releases; the manifest schema keeps domain payloads open.')
    [void]$sb.AppendLine()
    foreach ($domain in @($d.DomainPayloads)) {
        $payload = $fixture.domains[$domain]
        if ($payload -is [System.Collections.IDictionary]) {
            [void]$sb.AppendLine("### ``domains.$domain``")
            [void]$sb.AppendLine()
            [void]$sb.AppendLine((@($payload.Keys | Sort-Object | ForEach-Object { "``$_``" }) -join ', '))
            [void]$sb.AppendLine()
        }
    }
    [void]$sb.AppendLine('## When it is skipped, degraded or failed')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine($n.Skips)
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('The collector status in the manifest is one of `success`, `partial`, `failed`, `skipped` or `not-applicable`. Since v2.7.0 the entry also carries `degraded`, `degradationCount` and `degradations` (source and message of every non-fatal read that failed), and a degraded collector adds an informational finding. Debug-level detail is in `ranger.log`.')
    [void]$sb.AppendLine()
    if (@($n.New2609).Count -gt 0) {
        [void]$sb.AppendLine('## Azure Local 12.2609 (latest) coverage')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('| Item | Manifest path | Microsoft Learn |')
        [void]$sb.AppendLine('| --- | --- | --- |')
        foreach ($row in $n.New2609) { [void]$sb.AppendLine("| $($row[0]) | ``$($row[1])`` | [$($row[2])]($($row[2])) |") }
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('Details: [Platform evidence for 12.2609](../platform-2609-evidence.md).')
    }
    $pages["$id.md"] = ($sb.ToString().Replace("`r`n", "`n").TrimEnd() + "`n")
}

$index = [System.Text.StringBuilder]::new()
[void]$index.AppendLine('# Collector reference')
[void]$index.AppendLine()
[void]$index.AppendLine('> Generated by `scripts/docs/New-CollectorReferencePages.ps1`. Do not edit by hand.')
[void]$index.AppendLine()
[void]$index.AppendLine('One page per collector: what it needs, what it writes into the manifest, and when it is skipped or degraded.')
[void]$index.AppendLine()
[void]$index.AppendLine('| Collector | Class | Credential | Domains |')
[void]$index.AppendLine('| --- | --- | --- | --- |')
foreach ($id in $definitions.Keys) {
    $d = $definitions[$id]
    [void]$index.AppendLine("| [$($notes[$id].Title)]($id.md) | $($d.Class) | $($d.RequiredCredential) | $(@($d.DomainPayloads) -join ', ') |")
}
$pages['index.md'] = ($index.ToString().Replace("`r`n", "`n").TrimEnd() + "`n")

if ($Check) {
    foreach ($name in $pages.Keys) {
        $path = Join-Path $OutputPath $name
        $onDisk = if (Test-Path -LiteralPath $path) { [System.IO.File]::ReadAllText($path).Replace("`r`n", "`n") } else { $null }
        if ($onDisk -ne $pages[$name]) { $name }
    }
    return
}
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
foreach ($name in $pages.Keys) { [System.IO.File]::WriteAllText((Join-Path $OutputPath $name), $pages[$name], [System.Text.UTF8Encoding]::new($false)) }
$pages.Keys
