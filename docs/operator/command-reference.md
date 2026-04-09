# Command Reference

AzureLocalRanger exports four public commands.

## Input Resolution Precedence

```text
Parameter  ->  Config file  ->  Interactive prompt  ->  Default  ->  Error
```

## Invoke-AzureLocalRanger

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-ConfigPath` | `string` | One of `ConfigPath` / `ConfigObject` | Path to a YAML or JSON config file |
| `-ConfigObject` | `hashtable` / object | One of `ConfigPath` / `ConfigObject` | In-memory config for automation or testing |
| `-OutputPath` | `string` | No | Override `output.rootPath` |
| `-IncludeDomain` | `string[]` | No | Restrict to named data domains; not an AD domain filter |
| `-ExcludeDomain` | `string[]` | No | Exclude named data domains from an otherwise full run |
| `-ClusterCredential` | `PSCredential` | No | Override `credentials.cluster` |
| `-DomainCredential` | `PSCredential` | No | Override `credentials.domain` |
| `-BmcCredential` | `PSCredential` | No | Override `credentials.bmc` |
| `-NoRender` | `switch` | No | Collect only and skip report generation |
| `-ClusterFqdn` | `string` | No | Override `targets.cluster.fqdn` |
| `-ClusterNodes` | `string[]` | No | Override `targets.cluster.nodes` |
| `-EnvironmentName` | `string` | No | Override `environment.name` |
| `-SubscriptionId` | `string` | No | Override `targets.azure.subscriptionId` |
| `-TenantId` | `string` | No | Override `targets.azure.tenantId` |
| `-ResourceGroup` | `string` | No | Override `targets.azure.resourceGroup` |

## Data Domain Names

| Canonical name | Aliases | What it collects |
|---|---|---|
| `cluster` | `topology`, `cluster` | Cluster identity, nodes, quorum, CAU, Arc cluster posture |
| `storage-networking` | `storage`, `networking` | Pools, disks, volumes, cluster networks, adapters, RDMA, ATC |
| `identity-security` | `identity`, `security` | Identity, certificates, BitLocker, WDAC, Defender, RBAC |
| `azure-integration` | `azure` | Arc, policy, monitoring, updates, backup, ASR, and resource-bridge overlays |
| `hardware` | `hardware`, `oem` | Redfish hardware, firmware, disks, memory, GPUs, and BMC posture |
| `management-performance` | `management`, `performance` | WAC, agents, performance counters, and event or management signals |

## New-AzureLocalRangerConfig

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-Path` | `string` | Yes | Output path for the generated config |
| `-Format` | `string` | No | `yaml` or `json`; default is `yaml` |
| `-Force` | `switch` | No | Overwrite an existing file |

## Export-AzureLocalRangerReport

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-ManifestPath` | `string` | Yes | Path to an existing `audit-manifest.json` |
| `-OutputPath` | `string` | No | Destination folder; defaults to the manifest folder |
| `-Formats` | `string[]` | No | Any of `html`, `markdown`, `docx`, `xlsx`, `pdf`, `svg`, `drawio` |

## Test-AzureLocalRangerPrerequisites

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-ConfigPath` | `string` | No | Validate a config file as part of the check |
| `-ConfigObject` | `hashtable` / object | No | Validate an in-memory config |
| `-InstallPrerequisites` | `switch` | No | Install missing prerequisites in an elevated session |
| `-ClusterFqdn` | `string` | No | Structural override for validation |
| `-ClusterNodes` | `string[]` | No | Structural override for validation |
| `-EnvironmentName` | `string` | No | Structural override for validation |
| `-SubscriptionId` | `string` | No | Structural override for validation |
| `-TenantId` | `string` | No | Structural override for validation |
| `-ResourceGroup` | `string` | No | Structural override for validation |

## Related Pages

- [Quickstart](quickstart.md)
- [Prerequisites](../prerequisites.md)
- [Configuration](configuration.md)