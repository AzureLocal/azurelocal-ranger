# Command Reference

AzureLocalRanger exports twelve public commands:

- `Invoke-AzureLocalRanger` — main entry point (pass `-Wizard` for the guided first-run)
- `Invoke-RangerWizard` — standalone wrapper around the wizard, equivalent to `-Wizard`
- `New-AzureLocalRangerConfig` — generate an annotated config scaffold
- `Export-AzureLocalRangerReport` — re-render reports from a saved manifest
- `Test-AzureLocalRangerPrerequisites` — validate the execution environment
- `Test-RangerPermissions` — pre-run RBAC / provider-registration audit
- `Export-RangerWafConfig` / `Import-RangerWafConfig` — v2.0.0 WAF rule config hot-swap
- `Get-RangerRemediation` — v2.2.0 emit a copy-pasteable remediation script or runbook from a manifest
- `Publish-RangerRun` — v2.3.0 push a run package to Azure Blob and stream telemetry to Log Analytics
- `Invoke-AzureLocalRangerEstate` — v2.5.0 run Ranger across a multi-cluster estate config
- `Import-RangerManualEvidence` — v2.5.0 merge hand-collected evidence into an existing manifest

## Input Resolution Precedence

```text
Parameter  ->  Config file  ->  Arc auto-discovery  ->  Interactive prompt  ->  Default  ->  Error
```

In interactive sessions, two prompts fire automatically when their values are not already resolved:

- **Cluster selection** — when only `tenantId` + `subscriptionId` are supplied, `Select-RangerCluster` enumerates HCI clusters and auto-selects a singleton; multiples show a numbered menu.
- **Run mode** — when `-OutputMode` is not on the CLI, a short menu asks whether this is a `current-state` or `as-built` run before the run starts. The prompt defaults to whatever `output.mode` is in the config (or `current-state` if unset). Omit `-OutputMode as-built` on the CLI to always be prompted; set it in the config file or pass it as a parameter to skip the prompt.

## Invoke-AzureLocalRanger

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `-ConfigPath` | `string` | One of `ConfigPath` / `ConfigObject` | Path to a YAML or JSON config file |
| `-ConfigObject` | `hashtable` / object | One of `ConfigPath` / `ConfigObject` | In-memory config for automation or testing |
| `-OutputPath` | `string` | No | Override `output.rootPath` |
| `-IncludeDomain` | `string[]` | No | Restrict to named data domains; not an AD domain filter |
| `-ExcludeDomain` | `string[]` | No | Exclude named data domains from an otherwise full run |
| `-ClusterCredential` | `PSCredential` | No | Override `credentials.cluster` |
| `-DomainCredential` | `PSCredential` | No | Override `credentials.domain` |
| `-BmcCredential` | `PSCredential` | No | Override `credentials.bmc` |
| `-NoRender` | `switch` | No | Collect only and skip report generation |
| `-Unattended` | `switch` | No | Disable interactive prompts and return a non-zero process exit when collectors fail |
| `-BaselineManifestPath` | `string` | No | Compare the new run with a previous `audit-manifest.json` and emit `drift-report.json` |
| `-ClusterFqdn` | `string` | No | Override `targets.cluster.fqdn` |
| `-ClusterNodes` | `string[]` | No | Override `targets.cluster.nodes` |
| `-EnvironmentName` | `string` | No | Override `environment.name` |
| `-SubscriptionId` | `string` | No | Override `targets.azure.subscriptionId` |
| `-TenantId` | `string` | No | Override `targets.azure.tenantId` |
| `-ResourceGroup` | `string` | No | Override `targets.azure.resourceGroup` |
| `-ShowProgress` | `switch` | No | Show live per-collector progress bars (requires `PwshSpectreConsole`; suppressed in CI and `-Unattended`) |
| `-OutputMode` | `string` | No | `current-state` or `as-built`. Overrides `output.mode` |
| `-OutputFormats` | `string[]` | No | Formats to render: `html`, `markdown`, `docx`, `xlsx`, `pdf`, `svg`, `drawio`, `powerbi` (#210), `json-evidence` (#229). Overrides `output.formats` |
| `-Transport` | `string` | No | `auto`, `winrm`, or `arc`. Overrides `behavior.transport` |
| `-DegradationMode` | `string` | No | `graceful` or `strict`. Overrides `behavior.degradationMode` |
| `-RetryCount` | `int` | No | WinRM retry attempts. Overrides `behavior.retryCount` |
| `-TimeoutSeconds` | `int` | No | WinRM operation timeout in seconds. Overrides `behavior.timeoutSeconds` |
| `-AzureMethod` | `string` | No | Azure auth method: `existing-context`, `managed-identity`, `device-code`, `service-principal`, `service-principal-cert`, `azure-cli`. Overrides `credentials.azure.method` |
| `-ClusterName` | `string` | No | Display name used in reports. Overrides `environment.clusterName` |
| `-Wizard` | `switch` | No | v1.6.0 (#211). Dispatch to the interactive wizard (same as `Invoke-RangerWizard`) |
| `-OutputConfigPath` | `string` | No | With `-Wizard`: pre-fill the save path for the generated config |
| `-SkipRun` | `switch` | No | With `-Wizard`: save only, do not launch a run |
| `-SkipPreCheck` | `switch` | No | v1.6.0 (#212). Skip the pre-run RBAC / provider audit |
| `-SkipModuleUpdate` | `switch` | No | v2.0.0 (#231). Skip the required-module install/update validation on startup (air-gapped environments) |
| `-PublishToStorage` | `switch` | No | v2.3.0 (#244). Push the run package to Azure Blob after the run completes. Requires `output.remoteStorage` config block |
| `-PublishToLogAnalytics` | `switch` | No | v2.3.0 (#247). Stream `RangerRun_CL` + `RangerFinding_CL` rows to Log Analytics after the run. Requires `output.logAnalytics` config block |
| `-NetworkDeviceConfigs` | `string[]` | No | v2.6.5 (#314). Path(s) to switch or firewall running-config export files. Directories are recursively expanded to `.txt`, `.cfg`, `.conf`, `.log` files. Populates `domains.hints.networkDeviceConfigs` |

## Invoke-AzureLocalRanger -Wizard (recommended)

Since v1.6.0 (#211) the interactive wizard is reachable as an inline switch on
the main command. This is the recommended first-run path.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `-Wizard` | `switch` | Yes | Dispatch to the interactive wizard |
| `-OutputConfigPath` | `string` | No | Pre-fill the save path for the generated config file |
| `-SkipRun` | `switch` | No | Save the config but skip launching a run regardless of wizard choice |

The wizard walks through:

1. Environment name and cluster display name
2. Cluster FQDN and node FQDNs (leave blank to auto-discover from Arc)
3. Azure subscription ID, tenant ID, and resource group (GUIDs validated inline)
4. Credential strategy — one of six: `existing-context`, runtime `prompt`, `service-principal`, `managed-identity`, `device-code`, `azure-cli`
5. BMC / iDRAC — optional endpoint IPs for hardware and OEM collection
6. Output — run mode (`current-state` or `as-built`), root path, report formats
7. Scope — include or exclude specific data domains

At the end it prints a full review screen with the resulting YAML config. Press Enter to continue, or type `N` to cancel without saving. Then it offers: **[S]** save only, **[R]** run immediately without saving, or **[B]** save and run.

```powershell
# Launch the wizard
Invoke-AzureLocalRanger -Wizard

# Pre-fill the save path
Invoke-AzureLocalRanger -Wizard -OutputConfigPath C:\ranger\tplabs.yml

# Save only, no run
Invoke-AzureLocalRanger -Wizard -SkipRun
```

## Invoke-RangerWizard (standalone; equivalent to `-Wizard`)

Kept exported for scripts that already depend on it. Identical behaviour to
`Invoke-AzureLocalRanger -Wizard` — accepts the same `-OutputConfigPath` and
`-SkipRun` parameters. New code should prefer the `-Wizard` switch so every
entry into Ranger starts from the same command.

Requires an interactive host — throws `InvalidOperationException` in
non-interactive sessions.

## Scheduled Runs

Use `-Unattended` for Task Scheduler, GitHub Actions, and other non-interactive runners.

Recommended pattern:

- store Azure secrets in Key Vault and reference them through `keyvault://<vault>/<secret>`
- use a service principal, managed identity, or existing Az context for Azure authentication
- keep cluster, domain, and BMC credentials pre-resolved in config or injected by the scheduler
- set `-OutputPath` to a central share or artifact folder when multiple runs must be retained

Example:

```powershell
Invoke-AzureLocalRanger `
  -ConfigPath .\ranger.yml `
  -Unattended `
  -OutputPath \\fileserver\AzureLocalRanger `
  -BaselineManifestPath .\baseline\audit-manifest.json
```

Ranger writes `run-status.json` for scheduler monitoring and `manifest\drift-report.json` when a baseline manifest is supplied. Sample scheduler templates live under `samples/`.

## Data Domain Names

| Canonical name | Aliases | What it collects |
| --- | --- | --- |
| `cluster` | `topology`, `cluster` | Cluster identity, nodes, quorum, CAU, Arc cluster posture |
| `storage-networking` | `storage`, `networking` | Pools, disks, volumes, cluster networks, adapters, RDMA, ATC |
| `identity-security` | `identity`, `security` | Identity, certificates, BitLocker, WDAC, Defender, RBAC |
| `azure-integration` | `azure` | Arc, policy, monitoring, updates, backup, ASR, and resource-bridge overlays |
| `hardware` | `hardware`, `oem` | Redfish hardware, firmware, disks, memory, GPUs, and BMC posture |
| `management-performance` | `management`, `performance` | WAC, agents, performance counters, and event or management signals |

## New-AzureLocalRangerConfig

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `-Path` | `string` | Yes | Output path for the generated config |
| `-Format` | `string` | No | `yaml` or `json`; default is `yaml` |
| `-Force` | `switch` | No | Overwrite an existing file |

## Export-AzureLocalRangerReport

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `-ManifestPath` | `string` | Yes | Path to an existing `audit-manifest.json` |
| `-OutputPath` | `string` | No | Destination folder; defaults to the manifest folder |
| `-Formats` | `string[]` | No | Any of `html`, `markdown`, `docx`, `xlsx`, `pdf`, `svg`, `drawio`, `pptx`, `powerbi`, `json-evidence` |

## Get-RangerRemediation

v2.2.0 (#243). Reads an existing manifest, evaluates WAF rules, and emits a copy-pasteable remediation script or markdown runbook. Does not require cluster or Azure connectivity — operates entirely from the saved manifest.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `-ManifestPath` | `string` | Yes | Path to an existing `audit-manifest.json` |
| `-FindingId` | `string[]` | No | One or more WAF rule IDs to include; omit for all failing rules |
| `-OutputPath` | `string` | No | Destination file; defaults to `ranger-remediation-<timestamp>.<ext>` in the current directory |
| `-Format` | `string` | No | `ps1` (default), `md`, or `checklist` |
| `-Commit` | `switch` | No | Emit live cmdlets instead of dry-run previews |
| `-IncludeDependencies` | `switch` | No | Expand prerequisite rules ahead of their dependents |

```powershell
# Markdown runbook for all failing rules
Get-RangerRemediation -ManifestPath .\audit-manifest.json -Format md

# Dry-run PowerShell script for a specific rule
Get-RangerRemediation -ManifestPath .\audit-manifest.json -FindingId SEC-001,OPS-003

# Live script with dependency expansion
Get-RangerRemediation -ManifestPath .\audit-manifest.json -Commit -IncludeDependencies
```

## Publish-RangerRun

v2.3.0 (#244). Push an already-written Ranger run package to Azure Blob Storage and update the per-cluster catalog and account-level index blob. Optionally streams `RangerRun_CL` and `RangerFinding_CL` telemetry to a Log Analytics Workspace via DCE/DCR. See [Cloud Publishing](cloud-publishing.md) for full setup.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `-PackagePath` | `string` | Yes | Root folder of the Ranger run package to publish |
| `-StorageAccount` | `string` | Yes | Azure Storage account name |
| `-Container` | `string` | No | Blob container name; default `ranger-runs` |
| `-LogAnalyticsWorkspaceId` | `string` | No | Workspace ID for Log Analytics telemetry |
| `-DcrImmutableId` | `string` | No | DCR immutable ID for Log Analytics ingestion |
| `-DceEndpoint` | `string` | No | Data Collection Endpoint URL |
| `-Offline` | `switch` | No | Skip upload; validate and report only |

```powershell
# Publish the most recent run
Publish-RangerRun -PackagePath C:\AzureLocalRanger\tplabs-current-state-20260417T044502Z -StorageAccount saranger01
```

## Invoke-AzureLocalRangerEstate

v2.5.0 (#129). Run Ranger across every cluster in an estate config file and emit a cross-cluster rollup. Outputs `estate-rollup.json`, `estate-summary.html`, and `powerbi/estate-clusters.csv` to the configured root path.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `-ConfigPath` | `string` | One of `ConfigPath` / `ConfigObject` | Path to an estate config YAML or JSON file |
| `-ConfigObject` | `hashtable` | One of `ConfigPath` / `ConfigObject` | In-memory estate config |
| `-OutputPath` | `string` | No | Override `output.rootPath` from the estate config |
| `-ClusterCredential` | `PSCredential` | No | Shared cluster WinRM credential applied to all clusters |
| `-DomainCredential` | `PSCredential` | No | Shared domain credential |
| `-Unattended` | `switch` | No | Suppress interactive prompts |

```powershell
# Run estate rollup
Invoke-AzureLocalRangerEstate -ConfigPath C:\ranger\estate.yml

# Unattended with shared credential
$cred = Get-Credential
Invoke-AzureLocalRangerEstate -ConfigPath C:\ranger\estate.yml -ClusterCredential $cred -Unattended
```

Estate config structure:

```yaml
estate:
  name: contoso-production
  clusters:
    - name: tplabs-clus01
      configPath: C:\ranger\tplabs-clus01.yml
    - name: tplabs-clus02
      configPath: C:\ranger\tplabs-clus02.yml
output:
  rootPath: C:\AzureLocalRanger\estate
```

## Import-RangerManualEvidence

v2.5.0 (#32). Merge hand-collected evidence — network device configs, firewall exports, paper inventories — into an existing `audit-manifest.json` with provenance labels. The evidence is recorded under `manifest.domains.<domain>.manualImport` and tracked in `manifest.run.manualImports`.

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `-ManifestPath` | `string` | Yes | Path to an existing `audit-manifest.json` to enrich |
| `-EvidencePath` | `string` | Yes | Path to a JSON file with `domain` (string) and `data` (object/array) keys |
| `-Source` | `string` | Yes | Label describing the data origin (e.g. `manual-network-inventory`) |
| `-OutputPath` | `string` | No | Optional alternate output path; defaults to overwriting the source manifest |

Evidence file format:

```json
{
  "domain": "networkDeviceEvidence",
  "provenance": { "collectedBy": "ops-team", "collectedAt": "2026-04-17T00:00:00Z" },
  "data": {
    "switches": [ { "name": "tor-sw-01", "model": "Dell S5248F-ON" } ],
    "firewalls": [ { "name": "fw-edge-01", "platform": "FortiGate" } ]
  }
}
```

```powershell
Import-RangerManualEvidence `
  -ManifestPath .\audit-manifest.json `
  -EvidencePath .\network-inventory.json `
  -Source 'manual-network-inventory'
```

## Test-AzureLocalRangerPrerequisites

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `-ConfigPath` | `string` | No | Validate a config file as part of the check |
| `-ConfigObject` | `hashtable` / object | No | Validate an in-memory config |
| `-InstallPrerequisites` | `switch` | No | Install missing prerequisites in an elevated session |
| `-ClusterFqdn` | `string` | No | Structural override for validation |
| `-ClusterNodes` | `string[]` | No | Structural override for validation |
| `-EnvironmentName` | `string` | No | Structural override for validation |
| `-SubscriptionId` | `string` | No | Structural override for validation |
| `-TenantId` | `string` | No | Structural override for validation |
| `-ResourceGroup` | `string` | No | Structural override for validation |

## Common Scenarios

Complete, copy-paste examples for the most frequent use cases.

### One-off run — no config file

```powershell
Invoke-AzureLocalRanger `
  -ClusterFqdn tplabs-clus01.contoso.com `
  -SubscriptionId 00000000-0000-0000-0000-000000000000 `
  -TenantId 11111111-1111-1111-1111-111111111111 `
  -ResourceGroup rg-azlocal-prod-01 `
  -EnvironmentName tplabs-prod-01
```

### Run from a saved config file

```powershell
Invoke-AzureLocalRanger -ConfigPath C:\ranger\tplabs.yml
```

### Override a single config value at runtime

```powershell
Invoke-AzureLocalRanger -ConfigPath C:\ranger\tplabs.yml -OutputPath D:\ranger-archive
```

### Collect specific domains only (focused run)

```powershell
Invoke-AzureLocalRanger -ConfigPath C:\ranger\tplabs.yml `
  -IncludeDomain cluster,storage-networking,azure-integration
```

### Skip specific domains (broad run minus slow collectors)

```powershell
Invoke-AzureLocalRanger -ConfigPath C:\ranger\tplabs.yml `
  -ExcludeDomain hardware,management-performance
```

### Unattended / scheduled run with drift detection

```powershell
Invoke-AzureLocalRanger `
  -ConfigPath C:\ranger\tplabs.yml `
  -Unattended `
  -OutputPath \\fileserver\AzureLocalRanger `
  -BaselineManifestPath C:\ranger\baseline\audit-manifest.json
```

### Collect only — skip report rendering

```powershell
Invoke-AzureLocalRanger -ConfigPath C:\ranger\tplabs.yml -NoRender
```

Useful when you want to inspect the raw manifest before rendering or when rendering will be done later.

### Re-render reports from an existing manifest

```powershell
Export-AzureLocalRangerReport `
  -ManifestPath C:\AzureLocalRanger\tplabs-current-state-20260416T044502Z\manifest\audit-manifest.json `
  -Formats html,docx,xlsx,pdf,svg
```

No cluster or Azure connectivity required — renders entirely from the saved manifest.

### Check prerequisites before running

```powershell
# Check only
Test-AzureLocalRangerPrerequisites

# Check and auto-install missing modules (elevated session required)
Test-AzureLocalRangerPrerequisites -InstallPrerequisites
```

### Generate a new config scaffold

```powershell
New-AzureLocalRangerConfig -Path C:\ranger\new-cluster.yml
```

Opens YAML with inline comments and `[REQUIRED]` markers on mandatory fields.

### Pass explicit credentials at runtime

```powershell
$clusterCred = Get-Credential -Message "Cluster WinRM credential"
$bmcCred     = Get-Credential -Message "iDRAC credential"

Invoke-AzureLocalRanger `
  -ConfigPath C:\ranger\tplabs.yml `
  -ClusterCredential $clusterCred `
  -BmcCredential $bmcCred
```

---

## Parameter Precedence

When the same value can come from multiple sources, Ranger resolves in this order — first match wins:

```text
Runtime parameter  →  Config file value  →  Interactive prompt  →  Built-in default  →  Error
```

**Example:** if your config file sets `output.rootPath: C:\AzureLocalRanger` but you pass `-OutputPath D:\archive`, Ranger writes to `D:\archive` for that run without touching the config file.

This applies to all structural values: environment name, cluster addressing, Azure target metadata, output path, and domain filters. Credentials follow the same shape but can also resolve through `passwordRef` URIs evaluated after the config file step.

---

## Related Pages

- [First Run](first-run.md)
- [Quickstart](quickstart.md)
- [Configuration Reference](configuration-reference.md)
- [Prerequisites](../prerequisites.md)
- [Configuration](configuration.md)
