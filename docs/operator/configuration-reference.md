# Configuration Reference

Complete reference for every key in `ranger-config.yml`.

> **Looking for a full example to copy?** See [Example `ranger.yml`](example-config.md) — the complete annotated config with minimal, scheduled, and cloud-publishing variants.

For the practical how-to, see [Configuration](configuration.md). For the formal schema spec, see [Configuration Model](../architecture/configuration-model.md).

---

## `environment`

| Key | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `environment.name` | string | **Yes** | — | Short label used in output folder names and report filenames. Alphanumeric and hyphens recommended. |
| `environment.clusterName` | string | No | Same as `name` | Display name shown in report headers and diagrams. |
| `environment.description` | string | No | — | Free-text description included in report metadata. |

```yaml
environment:
  name: tplabs-prod-01
  clusterName: tplabs-prod-01
  description: "4-node Dell AX-760 production cluster"
```

---

## `targets.cluster`

| Key | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `targets.cluster.fqdn` | string | One of `fqdn` / `nodes` | — | Cluster FQDN or NetBIOS name. Resolved at runtime for WinRM connections. |
| `targets.cluster.nodes` | string[] | One of `fqdn` / `nodes` | Resolved from Arc | List of individual node FQDNs. Used when the cluster name does not resolve or when direct node addressing is preferred. |

```yaml
targets:
  cluster:
    fqdn: tplabs-clus01.contoso.com
    nodes:
      - tplabs-01-n01.contoso.com
      - tplabs-01-n02.contoso.com
```

If both are omitted, Ranger attempts to resolve nodes from Azure Arc resource properties. This requires an active Az context and valid Azure target metadata.

---

## `targets.azure`

| Key | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `targets.azure.subscriptionId` | string (GUID) | No | — | Azure subscription containing the cluster's Arc and resource group. Required for Azure-side collectors. |
| `targets.azure.tenantId` | string (GUID) | No | — | Azure AD tenant. Required when the subscription is in a different tenant than the default Az context. |
| `targets.azure.resourceGroup` | string | No | — | Resource group name containing the Arc cluster and related resources. |

```yaml
targets:
  azure:
    subscriptionId: 00000000-0000-0000-0000-000000000000
    tenantId: 11111111-1111-1111-1111-111111111111
    resourceGroup: rg-azlocal-prod-01
```

Omitting the entire `targets.azure` section skips all Azure-side collectors gracefully.

---

## `targets.bmc`

| Key | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `targets.bmc.endpoints` | object[] | No | `[]` | List of BMC/Redfish endpoint objects. Required for hardware domain discovery. |
| `targets.bmc.endpoints[].host` | string | Yes (per entry) | — | BMC hostname or IP address (e.g., `idrac-node-01.contoso.com`). |

```yaml
targets:
  bmc:
    endpoints:
      - host: idrac-node-01.contoso.com
      - host: idrac-node-02.contoso.com
      - host: idrac-node-03.contoso.com
      - host: idrac-node-04.contoso.com
```

Omitting `targets.bmc` or providing an empty `endpoints` list means hardware discovery runs without Redfish data. The hardware collector will still collect what it can over WinRM.

---

## `credentials`

### `credentials.azure`

| Key | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `credentials.azure.method` | string | No | `existing-context` | How Ranger authenticates to Azure. See values below. |

Valid values for `method`:

| Value | Behaviour |
| --- | --- |
| `existing-context` | Uses the current `Get-AzContext` session. Requires `Connect-AzAccount` before running. |
| `managed-identity` | Uses the managed identity of the execution host. For Azure-hosted runners. |
| `device-code` | Prompts for device-code interactive authentication. |
| `service-principal` | Uses `credentials.azure.clientId` + `credentials.azure.clientSecretRef`. |
| `azure-cli` | Falls back to Azure CLI (`az login`) context. |

For service principal:

```yaml
credentials:
  azure:
    method: service-principal
    clientId: 22222222-2222-2222-2222-222222222222
    clientSecretRef: keyvault://kv-ranger/sp-secret
    tenantId: 11111111-1111-1111-1111-111111111111
```

!!! note
    `kv-ranger` in these examples is a **placeholder vault name**, not a vault Ranger creates or requires. Substitute your actual Key Vault. v2.6.3 ([#292](https://github.com/AzureLocal/azurelocal-ranger/issues/292)) removed the fake `keyvault://kv-ranger/*` placeholders from the default config so a bare invocation no longer dies resolving a vault the operator never configured.

### `credentials.cluster`

| Key | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `credentials.cluster.username` | string | No | — | WinRM username in `DOMAIN\user` or `user@domain` format. |
| `credentials.cluster.password` | string | No | — | Plaintext password. **Not recommended** — use `passwordRef` instead. |
| `credentials.cluster.passwordRef` | string | No | — | Key Vault secret URI. See [Key Vault References](#key-vault-references). |

### `credentials.domain`

Same keys as `credentials.cluster`. Used for domain-joined operations when the domain credential differs from the cluster WinRM credential. Omit to use the cluster credential for both.

### `credentials.bmc`

Same keys as `credentials.cluster`. Used for BMC/Redfish authentication. Required when `targets.bmc.endpoints` is populated.

```yaml
credentials:
  azure:
    method: existing-context
  cluster:
    username: CONTOSO\ranger-read
    passwordRef: keyvault://kv-ranger/cluster-read
  domain:
    username: CONTOSO\ranger-read
    passwordRef: keyvault://kv-ranger/domain-read
  bmc:
    username: root
    passwordRef: keyvault://kv-ranger/idrac-root
```

---

## `domains`

| Key | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `domains.include` | string[] | No | All domains | Collect only these named domains. Overrides `exclude` when both are set. |
| `domains.exclude` | string[] | No | None | Skip these named domains from an otherwise full run. |
| `domains.hints` | object | No | — | Variant hints passed to collectors. See below. |

Valid domain names:

| Name | Aliases | Collects |
| --- | --- | --- |
| `cluster` | `topology` | Cluster identity, nodes, quorum, update posture |
| `storage-networking` | `storage`, `networking` | S2D pools, CSVs, vSwitches, RDMA, ATC |
| `identity-security` | `identity`, `security` | AD/workgroup, BitLocker, WDAC, Defender, RBAC |
| `azure-integration` | `azure` | Arc, policy, monitoring, backup, ASR, AKS |
| `hardware` | `oem` | Redfish, firmware, disks, memory, GPUs, BMC posture |
| `management-performance` | `management`, `performance` | WAC, agents, counters, event digest |
| `waf-assessment` | — | WAF rule scoring, pillar results, roadmap, advisor recommendations |

The following domains are computed by v2.5.0 analyzers after collection and do not require separate configuration — they are always included when the underlying collector data is available:

| Analyzer domain | Source data | Output |
| --- | --- | --- |
| `capacityAnalysis` | cluster + storage | Per-node + cluster vCPU/memory/storage/pool headroom with Healthy/Warning/Critical status |
| `vmUtilization` | virtualMachines | Idle/underutilized VM classification with rightsizing proposals and freed-resource savings |
| `storageEfficiency` | storage-networking | Per-volume dedup state, dedup ratio, saved GiB, thin-provisioning coverage, waste class tag |
| `licenseInventory` | azure-integration + virtualMachines | Guest SQL instances (edition, version, cores, license model, AHB eligibility) and Windows Server instances |

```yaml
domains:
  include: []    # empty = all
  exclude:
    - hardware   # skip if no BMC access
```

### Variant Hints

```yaml
domains:
  hints:
    topology: local-key-vault       # cluster uses local identity with Key Vault
    controlPlaneMode: disconnected  # cluster is in disconnected operations mode
```

Hints guide collector behaviour and report wording. They do not override observed facts.

---

## `output`

| Key | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `output.mode` | string | No | `current-state` | `current-state` for operational snapshots; `as-built` for formal handoff packages. |
| `output.formats` | string[] | No | `[html, markdown, json, svg]` | Report formats to render. |
| `output.rootPath` | string | No | `C:\AzureLocalRanger` | Root directory where Ranger creates the timestamped output folder. |
| `output.showProgress` | bool | No | `true` | Show a live per-collector progress display. Requires `PwshSpectreConsole`; falls back to `Write-Progress` if absent. Suppressed in CI and `-Unattended` mode. |

Valid format values:

| Value | Output |
| --- | --- |
| `html` | HTML report (all tiers) |
| `markdown` | Markdown report |
| `json` | Raw manifest export |
| `json-evidence` | Raw resource-only inventory JSON with `_metadata` envelope; no scoring or run metadata (v2.0.0) |
| `svg` | SVG diagrams |
| `drawio` | draw.io XML diagrams |
| `docx` | Word document |
| `xlsx` | Excel workbook (inventory + findings) |
| `pdf` | PDF (rendered from HTML) |
| `pptx` | PowerPoint executive presentation built via `System.IO.Packaging`; no Office dependency (v2.5.0) |
| `powerbi` | Power BI CSV star-schema exports under a `powerbi/` folder (v2.0.0) |

```yaml
output:
  mode: as-built
  formats: [html, markdown, docx, xlsx, pdf, svg]
  rootPath: C:\AzureLocalRanger
  showProgress: true
```

---

## `behavior`

| Key | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `behavior.transport` | string | No | `auto` | WinRM transport mode. `auto` tries WinRM first; falls back to Arc Run Command when nodes are unreachable. `winrm` forces WinRM only. `arc` forces Arc Run Command only. |
| `behavior.degradationMode` | string | No | `graceful` | How to handle collectors whose transport is confirmed unreachable. `graceful` skips with `status: skipped`. `strict` fails the entire run. |
| `behavior.promptForMissingCredentials` | bool | No | `true` | Prompt interactively for unresolved cluster, domain, or BMC credentials. |
| `behavior.promptForMissingRequired` | bool | No | `true` | Prompt interactively for missing required structural fields (environment name, cluster FQDN, etc.). |
| `behavior.retryCount` | int | No | `2` | Number of WinRM retry attempts per operation before marking a collector as failed. |
| `behavior.timeoutSeconds` | int | No | `30` | WinRM operation timeout in seconds. |
| `behavior.skipUnavailableOptionalDomains` | bool | No | `true` | Skip optional collectors silently when their required resources are absent. |

```yaml
behavior:
  transport: auto
  degradationMode: graceful
  promptForMissingCredentials: true
  promptForMissingRequired: true
  retryCount: 2
  timeoutSeconds: 30
```

---

## Key Vault References

Any `password`, `clientSecret`, or similar credential field can be replaced with a Key Vault reference URI:

```text
keyvault://<vault-name>/<secret-name>
```

Ranger resolves the reference at runtime using the current Azure identity. The vault must be accessible from the execution machine.

```yaml
credentials:
  cluster:
    username: CONTOSO\ranger-read
    passwordRef: keyvault://kv-ranger/cluster-read-password
```

**Requirements:**

- An active Az context with `Get-AzKeyVaultSecret` access to the vault
- The vault name must match an existing Key Vault in the configured subscription
- The secret must exist and not be disabled or expired

---

## What Happens When Keys Are Omitted

| Omitted key | Behaviour |
| --- | --- |
| `targets.cluster.fqdn` and `targets.cluster.nodes` | Ranger attempts Arc-based node resolution; fails if no Azure context or cluster not Arc-registered |
| `targets.azure` (entire section) | All Azure-side collectors skip gracefully |
| `targets.bmc` (entire section) | Redfish hardware collection skipped; WinRM-based hardware facts still collected |
| `credentials.cluster` | Ranger uses current Windows identity; prompts if `promptForMissingCredentials: true` |
| `credentials.azure` | Defaults to `existing-context` |
| `domains.include` (empty) | All domains collected |
| `behavior` (entire section) | All defaults apply (`transport: auto`, `degradationMode: graceful`, etc.) |
| `output.showProgress` | Defaults to `true` (progress display on) |

---

## Related Pages

- [Configuration](configuration.md) — practical how-to with examples
- [Configuration Model](../architecture/configuration-model.md) — formal schema specification
- [Authentication](authentication.md) — credential methods in detail
- [Command Reference](command-reference.md) — runtime parameter overrides
