# Prerequisites

This is the canonical prerequisites guide for AzureLocalRanger. It covers required permissions, modules, viewers, network access, and a quick-check script you can run before the first scan.

## Required Permissions

- Local administrator on the execution host when you need Ranger to auto-install prerequisites.
- Read-capable WinRM access to the Azure Local nodes.
- Active Directory read permissions when the environment is domain-joined.
- Azure RBAC Reader on the subscription or resource group being scanned.
- Azure Key Vault secret-read access when `passwordRef` values use `keyvault://` URIs.

## Required Modules and Tools

| Item | Required | Notes |
|---|---|---|
| PowerShell 7.x | Yes | Ranger targets PowerShell 7 and `CompatiblePSEditions = Core` |
| `Az.Accounts` | Yes | Azure authentication |
| `Az.Resources` | Yes | Azure resource inventory |
| RSAT ActiveDirectory | When AD queries are needed | Required for domain-backed identity collection |
| GroupPolicy tools | Optional | Used when GPO posture is collected |
| Azure CLI | Optional | Fallback when `useAzureCliFallback` is enabled |
| ImportExcel | No | Not required; XLSX output is generated without Excel automation |

## Viewer and Consumer Tools

| Item | Required | Notes |
|---|---|---|
| Web browser | Yes | View HTML reports and SVG diagrams |
| draw.io desktop | Optional | Recommended for editing packaged diagram source |
| Microsoft Word / LibreOffice Writer | Optional | View `.docx` narrative reports |
| Microsoft Excel / LibreOffice Calc | Optional | View `.xlsx` inventory workbooks |
| PDF reader | Optional | View fixed-layout handoff reports |
| VS Code | Optional | Review JSON manifests and YAML config files |

## Network Requirements

- WinRM: TCP `5985` or `5986` to cluster nodes.
- LDAP or LDAPS: TCP `389` or `636` to at least one domain controller when AD collection is required.
- HTTPS: TCP `443` to Azure Resource Manager, Azure Arc, Key Vault, and monitoring endpoints.
- No requirement to reach switches, firewalls, or OpenGear devices from the execution host unless you explicitly opt into those targets.

## Quick-Check Script

Run this from the repo root or after importing the module:

```powershell
$checks = [ordered]@{
  PowerShell7 = $PSVersionTable.PSVersion.Major -ge 7
  AzAccounts  = [bool](Get-Module -ListAvailable -Name Az.Accounts)
  AzResources = [bool](Get-Module -ListAvailable -Name Az.Resources)
  AzureCli    = [bool](Get-Command az -ErrorAction SilentlyContinue)
  WinRM       = [bool](Get-Command Invoke-Command -ErrorAction SilentlyContinue)
  ActiveDirectory = [bool](Get-Module -ListAvailable -Name ActiveDirectory)
}

$checks.GetEnumerator() | ForEach-Object {
  [pscustomobject]@{
    Check  = $_.Key
    Passed = $_.Value
  }
} | Format-Table -AutoSize

Test-AzureLocalRangerPrerequisites
```

## First-Run Path

1. Import the module from source or a published release.
2. Run `Test-AzureLocalRangerPrerequisites`.
3. Generate a config with `New-AzureLocalRangerConfig -Path .\ranger.yml`.
4. Fill in the `[REQUIRED]` values.
5. Run `Invoke-AzureLocalRanger -ConfigPath .\ranger.yml`.

## Related Pages

- [Quickstart](operator/quickstart.md)
- [Installation and First Run](operator/prerequisites.md)
- [Command Reference](operator/command-reference.md)