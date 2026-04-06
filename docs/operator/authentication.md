# Operator Authentication

Azure Local Ranger is multi-target and multi-credential by design. Operators should think about authentication as a credential map, not as a single login.

## Target Credential Map

| Target | Typical credential |
|---|---|
| Azure | existing Az context, interactive login, service principal, or managed identity |
| Cluster nodes | domain credential or local administrator credential for WinRM |
| Active Directory | domain credential with read access |
| BMC / iDRAC | local BMC credential |
| Future switch or firewall targets | vendor-specific API, SSH, or SNMP credential |

A valid Azure login does not imply valid WinRM access. A valid cluster credential does not imply BMC access.

## Credential Resolution Order

Ranger should resolve credentials in this order:

1. explicit parameter input
2. Key Vault reference in configuration
3. interactive prompt

That order keeps automation possible while still allowing ad-hoc use.

## Azure Authentication Options

Azure-side discovery should support:

- existing authenticated Az context
- `Connect-AzAccount` interactive login
- service principal with client secret or certificate
- managed identity for Azure-hosted execution environments

The right option depends on whether the run is interactive, scheduled, or hosted inside Azure.

## Key Vault References

The documented secret reference format is:

```text
keyvault://<vault-name>/<secret-name>[/<version>]
```

Examples:

```text
keyvault://kv-ranger/cluster-read
keyvault://kv-ranger/idrac-root
keyvault://kv-ranger/azure-sp-client-secret
```

Ranger should resolve these through Az.KeyVault first and fall back to Azure CLI if required.

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

## Related Pages

- [Operator Prerequisites](prerequisites.md)
- [Operator Configuration](configuration.md)
- [Configuration Model](../architecture/configuration-model.md)
