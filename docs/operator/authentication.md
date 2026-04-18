# Operator Authentication

Azure Local Ranger is multi-target and multi-credential by design. Operators should think about authentication as a credential map, not as a single login.

## Target Credential Map

| Target | Typical credential |
| --- | --- |
| Azure | one of six methods — see [Azure Authentication Options](#azure-authentication-options) below |
| Cluster nodes | domain credential or local administrator credential for WinRM |
| Active Directory | domain read credential — reuses the cluster credential automatically when `credentials.domain` is unconfigured (v2.6.5 #304) |
| BMC / iDRAC | local BMC credential |
| Future switch or firewall targets | vendor-specific API, SSH, or SNMP credential |

A valid Azure login does not imply valid WinRM access. A valid cluster credential does not imply BMC access.

## Domain-To-Credential Routing

Operators should expect Ranger to route credentials according to the domains being run.

| Domain area | Required credential posture |
| --- | --- |
| Cluster, storage, networking, virtual machines, management tools, performance | Cluster WinRM credential |
| Identity and security | Cluster WinRM credential and, when AD discovery is needed, domain read credential |
| Azure integration and Azure-side monitoring or policy overlays | Azure credential |
| Hardware and OEM integration | BMC / Redfish credential |
| Future switch or firewall interrogation | Device-specific credential supplied explicitly by the operator |

If a domain can run with one credential and enrich with another, Ranger should run the base domain first and mark the enrichment layer `partial` or `skipped` when the supporting credential is absent.

## Credential Resolution Order

Ranger should resolve credentials in this order:

1. explicit parameter input
2. Key Vault reference in configuration
3. interactive prompt

That order keeps automation possible while still allowing ad-hoc use.

## Azure Authentication Options

Azure-side discovery supports six methods, all selectable via the wizard (`Invoke-AzureLocalRanger -Wizard`) or the `credentials.azure.method` field in a config file:

| # | Method value | Strategy | When to use |
| --- | --- | --- | --- |
| 1 | `existing-context` | Current Az context | Interactive runs after `Connect-AzAccount` |
| 2 | `existing-context` (+ `promptForMissingCredentials: true`) | Runtime prompt for cluster / domain creds | First run, or when the Az context account lacks cluster WinRM access |
| 3 | `service-principal` | Client ID + client secret (or `keyvault://` ref) / cert | CI / scheduled runs with a non-user identity |
| 4 | `managed-identity` | System- or user-assigned managed identity | Runners hosted on an Azure VM or Arc-enabled machine |
| 5 | `device-code` | Browser-based Entra sign-in on a separate device | Runners without a browser (or disconnected shells) |
| 6 | `azure-cli` | `az login` session | Cross-platform runners where `az` is the established auth pattern |

The right option depends on whether the run is interactive, scheduled, or hosted inside Azure.

!!! tip "tenantId is auto-filled from your Az session"
    Since v2.6.5 (#317), `Invoke-RangerAzureAutoDiscovery` reads `(Get-AzContext).Tenant.Id` after cluster discovery succeeds and sets `targets.azure.tenantId` automatically. You will not be prompted for `tenantId` on an `existing-context` run if you are already signed into the correct tenant.

## Key Vault References

The documented secret reference format is:

```text
keyvault://<vault-name>/<secret-name>[/<version>]
```

!!! note
    `kv-ranger` in the examples below is a **placeholder vault name**, not a vault Ranger creates or requires. Substitute your actual Key Vault name. (In v2.6.3, fake `keyvault://kv-ranger/*` placeholders were removed from the default config — see issue [#292](https://github.com/AzureLocal/azurelocal-ranger/issues/292) — so an empty config no longer dies resolving a vault the operator never configured.)

Examples:

```text
keyvault://kv-ranger/cluster-read
keyvault://kv-ranger/idrac-root
keyvault://kv-ranger/azure-sp-client-secret
```

Ranger should resolve these through Az.KeyVault first and fall back to Azure CLI if required.

If the secret reference includes a version, Ranger should resolve that exact version. If the version is omitted, Ranger should resolve the latest enabled version.

If Key Vault resolution fails:

- required core domains should fail clearly when prompting is disabled
- optional domains should be skipped with a reason when prompting is disabled
- interactive runs may prompt for replacement credentials when prompting is enabled

## Local Identity with Azure Key Vault

In the Azure Local local-identity model, Key Vault is not just an operator convenience. It is part of the Azure Local operating model.

Current Microsoft documentation describes:

- one Key Vault per cluster for backup secrets
- managed identity access to Key Vault for secret backup and retrieval
- Key Vault Secrets Officer role assignment requirements
- `ADAware = 2` for a local-identity cluster
- RecoveryAdmin recovery-secret handling through Key Vault

That means Ranger should both use Key Vault for its own secret resolution patterns and document the cluster’s Key Vault posture when that variant is detected.

## Security Guidance

Operators should avoid:

- storing plaintext secrets in committed config files
- reusing highly privileged credentials unnecessarily across all target types
- assuming optional domains are harmless to enable without confirming network and credential scope

A read-only product still handles sensitive credentials and should be operated accordingly.

## Expected Prompts

If a required credential is missing and prompting is enabled, Ranger should prompt with a clear label such as:

- Azure subscription access credential
- Cluster WinRM credential
- Active Directory read credential
- Dell iDRAC credential

Prompts should identify the target and the reason the credential is needed.

## Arc Run Command Transport (v1.2.0+)

When `behavior.transport` is set to `arc` or `auto`, Ranger routes WinRM workloads through the Azure Arc Run Command API instead of direct TCP connections. This path has its own credential requirements.

**Azure identity requirements for Arc transport:**

- an active Az PowerShell context (`Get-AzContext`) authenticated to the subscription containing the Arc-enabled servers
- the calling identity must have `Microsoft.HybridCompute/machines/runCommands/action` on the Arc-enabled machine resources — this is included in the `Azure Connected Machine Resource Manager` role
- the `Az.ConnectedMachine` module must be installed (`Install-Module Az.ConnectedMachine`)

Arc transport does not replace or substitute the cluster WinRM credential for tasks that still require interactive credentials on the node. It is a transport alternative — the Azure identity authorizes the Arc Run Command delivery, and any credential-dependent operations within the script block still require the credential to be passed.

In `auto` mode, Ranger falls back to Arc transport only when all WinRM targets are confirmed unreachable. The Azure credential that was already in use for Azure-side discovery is reused for the Arc transport path.

## Related Pages

- [Operator Prerequisites](prerequisites.md)
- [Operator Configuration](configuration.md)
- [Configuration Model](../architecture/configuration-model.md)
