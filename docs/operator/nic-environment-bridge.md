# Drive Ranger from the deploy automation environment file

If you deploy with the NIC deploy automation, the same environment file can configure Ranger, so cluster name, node FQDNs and subscription are typed once.

```powershell
./samples/configs/ranger.from-environment.ps1 `
    -EnvironmentPath ./environment.azure-local.yml `
    -OutputPath ./ranger.yml `
    -TenantId <tenant-guid> `
    -IncludeBmc

Invoke-AzureLocalRanger -ConfigPath ./ranger.yml
```

The script only reads the environment file. It needs the `powershell-yaml` module for YAML input and output (JSON works without it).

| Environment key | ranger.yml key |
| --- | --- |
| `cluster_name` | `environment.clusterName`, `environment.name` |
| `cluster_name` + `identity.dns_zone` (else `ip_plan.dns_zone`) | `targets.cluster.fqdn` |
| `nodes[].name` + the zone | `targets.cluster.nodes[]` |
| `subscription_id` | `targets.azure.subscriptionId` |
| `-TenantId`, else `$env:AZURE_TENANT_ID` | `targets.azure.tenantId` (the environment file has no tenant) |
| `-ResourceGroup` | `targets.azure.resourceGroup` (optional; Ranger discovers it from Arc when blank) |
| `nodes[].bmc_ip` (with `-IncludeBmc`) | `targets.bmc.endpoints[]` |

Credentials are never written; Ranger prompts for them or reads Key Vault references from its own credentials block. To check the finished build against the same file, use [Compare-RangerDesign](../reference/design-vs-as-built.md).
