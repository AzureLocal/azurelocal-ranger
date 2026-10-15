#Requires -Version 7.0
<#
.SYNOPSIS
    Builds an Azure Local Ranger configuration from the deploy automation environment file, so one variable file drives deployment and discovery.
.DESCRIPTION
    Reads the environment YAML (the azure-local.environment schema used by the NIC deploy automation) and writes a ranger.yml (or
    ranger.json) with the cluster, node names, FQDNs, Azure scope and BMC endpoints already filled in. It only reads the environment
    file; it never connects to Azure or to a cluster, and it never writes a secret: credentials stay in the Ranger credentials block
    (prompted at run time or referenced from Key Vault).

    Mapping (environment key -> ranger.yml key):
      cluster_name                                  -> environment.clusterName, environment.name (when -EnvironmentName is not given)
      cluster_name + '.' + identity.dns_zone        -> targets.cluster.fqdn   (ip_plan.dns_zone when identity.dns_zone is absent)
      nodes[].name + '.' + identity.dns_zone        -> targets.cluster.nodes[] (FQDNs; short names when there is no zone)
      subscription_id                               -> targets.azure.subscriptionId
      -TenantId, else $env:AZURE_TENANT_ID           -> targets.azure.tenantId   (the environment file does not carry a tenant)
      -ResourceGroup                                -> targets.azure.resourceGroup (optional; Ranger discovers it from Arc when blank)
      nodes[].bmc_ip / bmc_name  (with -IncludeBmc) -> targets.bmc.endpoints[] { host, node }
    Anything else in the environment file is ignored.
.PARAMETER EnvironmentPath
    The environment file (YAML or JSON).
.PARAMETER OutputPath
    Where to write the Ranger configuration. The format follows the extension (.yml, .yaml or .json). Without it the configuration is returned as an object only.
.PARAMETER TenantId
    Entra tenant ID. Falls back to $env:AZURE_TENANT_ID, then to blank (Ranger fills it from the Az context).
.PARAMETER ResourceGroup
    Resource group of the Azure Local cluster resource, when you want it fixed instead of discovered.
.PARAMETER EnvironmentName
    Label used in report and package names. Defaults to cluster_name.
.PARAMETER Mode
    current-state (default) or as-built.
.PARAMETER IncludeBmc
    Add the nodes' BMC addresses as hardware collector endpoints (needs a BMC credential at run time).
.EXAMPLE
    ./ranger.from-environment.ps1 -EnvironmentPath ./environment.azure-local.yml -OutputPath ./ranger.yml -TenantId <tenant-guid>
    Invoke-AzureLocalRanger -ConfigPath ./ranger.yml
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EnvironmentPath,
    [string]$OutputPath,
    [string]$TenantId,
    [string]$ResourceGroup,
    [string]$EnvironmentName,
    [ValidateSet('current-state', 'as-built')][string]$Mode = 'current-state',
    [switch]$IncludeBmc
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $EnvironmentPath -PathType Leaf)) { throw "Environment file not found: $EnvironmentPath" }
$raw = Get-Content -LiteralPath $EnvironmentPath -Raw
$envDoc = if ($EnvironmentPath -match '\.(ya?ml)$') {
    if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) { Import-Module powershell-yaml -ErrorAction Stop }
    ConvertFrom-Yaml $raw
}
else { $raw | ConvertFrom-Json -AsHashtable -Depth 50 }

function Get-Key($Object, [string[]]$Path) {
    $cur = $Object
    foreach ($p in $Path) { if ($cur -is [System.Collections.IDictionary] -and $cur.Contains($p)) { $cur = $cur[$p] } else { return $null } }
    $cur
}

$cluster = [string](Get-Key $envDoc @('cluster_name'))
if ([string]::IsNullOrWhiteSpace($cluster)) { throw "The environment file has no cluster_name." }
$zone = [string](Get-Key $envDoc @('identity', 'dns_zone'))
if ([string]::IsNullOrWhiteSpace($zone)) { $zone = [string](Get-Key $envDoc @('ip_plan', 'dns_zone')) }
$fqdn = { param($name) if ($zone) { "$name.$zone" } else { $name } }

$nodes = @(@(Get-Key $envDoc @('nodes')) | Where-Object { $_ })
$nodeNames = @($nodes | ForEach-Object { & $fqdn ([string]$_['name']) })
$tenant = if ($TenantId) { $TenantId } elseif ($env:AZURE_TENANT_ID) { $env:AZURE_TENANT_ID } else { '' }

$config = [ordered]@{
    environment = [ordered]@{
        name        = $(if ($EnvironmentName) { $EnvironmentName } else { $cluster })
        clusterName = $cluster
        description = 'Generated from the deploy automation environment file'
    }
    targets     = [ordered]@{
        cluster = [ordered]@{ fqdn = (& $fqdn $cluster); nodes = $nodeNames }
        azure   = [ordered]@{
            subscriptionId = [string](Get-Key $envDoc @('subscription_id'))
            tenantId       = $tenant
            resourceGroup  = $ResourceGroup
        }
        bmc     = [ordered]@{ endpoints = @() }
    }
    output      = [ordered]@{ mode = $Mode }
}
if ($IncludeBmc) {
    $config.targets.bmc.endpoints = @($nodes | Where-Object { $_['bmc_ip'] } | ForEach-Object { [ordered]@{ host = [string]$_['bmc_ip']; node = (& $fqdn ([string]$_['name'])) } })
}

if ($OutputPath) {
    $dir = Split-Path -Parent ([System.IO.Path]::GetFullPath($OutputPath))
    if ($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if ($OutputPath -match '\.json$') { $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8 }
    else {
        if (-not (Get-Command ConvertTo-Yaml -ErrorAction SilentlyContinue)) { Import-Module powershell-yaml -ErrorAction Stop }
        $header = "# Generated from $([System.IO.Path]::GetFileName($EnvironmentPath)) by ranger.from-environment.ps1. Credentials are not stored here.`n# Docs: https://azurelocal.cloud/azurelocal-ranger/operator/nic-environment-bridge`n"
        ($header + (ConvertTo-Yaml $config)) | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    }
}
$config
