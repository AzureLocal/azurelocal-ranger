# Operator Configuration

This page shows how an operator should think about configuration in practice.

The formal model is defined in [Configuration Model](../architecture/configuration-model.md). This page focuses on how to use it.

## What To Configure

Operators generally configure five things:

1. the Azure Local deployment being targeted
2. the credentials for each target type
3. the domains to include or exclude
4. the output mode and destination
5. any variant hints needed for unusual environments

## Practical Example

```yaml
environment:
  name: prod-azlocal-01
  clusterName: azlocal-prod-01

targets:
  cluster:
    fqdn: azlocal-prod-01.contoso.com
  azure:
    subscriptionId: 00000000-0000-0000-0000-000000000000
    resourceGroup: rg-azlocal-prod-01
  bmc:
    endpoints:
      - host: idrac-node-01.contoso.com
      - host: idrac-node-02.contoso.com

credentials:
  azure:
    method: existing-context
  cluster:
    username: CONTOSO\\ranger-read
    passwordRef: keyvault://kv-ranger/cluster-read
  domain:
    username: CONTOSO\\ranger-read
    passwordRef: keyvault://kv-ranger/domain-read
  bmc:
    username: root
    passwordRef: keyvault://kv-ranger/idrac-root

domains:
  include:
    - topology
    - cluster
    - hardware
    - storage
    - networking
    - virtual-machines
    - identity-security
    - azure-integration
    - management-tools
    - performance

output:
  mode: as-built
  formats: [html, markdown, docx, xlsx, pdf, svg]
  rootPath: C:\AzureLocalRanger

## Input Resolution Precedence

Ranger resolves structural input in this order:

```text
Parameter  ->  Config file  ->  Interactive prompt  ->  Default  ->  Error
```

That rule applies to environment name, cluster addressing, and Azure target metadata. Credentials follow the same broad shape, but can also be resolved through `passwordRef` URIs.

## v1.2.0 Config Keys

Three new keys were added in v1.2.0:

```yaml
behavior:
  # Transport mode for cluster WinRM workloads.
  # auto   — try WinRM first; fall back to Arc Run Command when all nodes are unreachable
  # winrm  — force WinRM only (fail if unreachable)
  # arc    — force Arc Run Command only (requires Az.ConnectedMachine and active Az context)
  transport: auto

  # How to handle collectors whose required transport is confirmed unreachable.
  # graceful — skip the collector with status: skipped (default)
  # strict   — fail the run when any core collector cannot reach its target
  degradationMode: graceful

output:
  # Show a live per-collector progress display during collection.
  # Requires PwshSpectreConsole; falls back to Write-Progress if absent.
  # Automatically suppressed in CI environments and when -Unattended is set.
  showProgress: true
```

The `-ShowProgress` switch on `Invoke-AzureLocalRanger` overrides `output.showProgress` at runtime.

## Runtime Parameter Overrides

The public commands support a parameter-first operating model. These parameters override config-file values when provided:

- `-OutputPath`
- `-IncludeDomain`
- `-ExcludeDomain`
- `-ClusterCredential`
- `-DomainCredential`
- `-BmcCredential`
- `-NoRender`
- `-ShowProgress`
- `-ClusterFqdn`
- `-ClusterNodes`
- `-EnvironmentName`
- `-SubscriptionId`
- `-TenantId`
- `-ResourceGroup`

Example:

```powershell
$clusterCred = Get-Credential
Invoke-AzureLocalRanger \
  -ConfigPath .\ranger.yml \
  -ClusterCredential $clusterCred \
  -ClusterFqdn tplabs-clus01.contoso.com \
  -ClusterNodes tplabs-01-n01,tplabs-01-n02
```

## Domain Filters

`-IncludeDomain` and `-ExcludeDomain` filter **data collection topics**, not Active Directory domains.

Canonical names and common aliases are:

| Canonical name | Aliases | Purpose |
|---|---|---|
| `cluster` | `topology`, `cluster` | Cluster identity, nodes, quorum, CAU, Arc cluster posture |
| `storage-networking` | `storage`, `networking` | Storage pools, disks, volumes, QoS, vSwitches, host adapters, RDMA, and ATC |
| `identity-security` | `identity`, `security` | AD or workgroup identity, BitLocker, WDAC, Defender, certificates, and RBAC |
| `azure-integration` | `azure` | Arc, policy, monitoring, updates, backup, ASR, AKS, and resource bridge overlays |
| `hardware` | `hardware`, `oem` | BMC and Redfish hardware, firmware, disks, GPUs, memory, and security posture |
| `management-performance` | `management`, `performance` | WAC, third-party tools, performance counters, event digest, and management agents |

## Prompting Behavior

Two behavior flags govern interactive prompting:

- `behavior.promptForMissingCredentials` controls whether Ranger will prompt for unresolved cluster, domain, or BMC credentials.
- `behavior.promptForMissingRequired` controls whether Ranger will prompt for missing required structural values such as environment name or cluster FQDN.

If prompting is disabled or unavailable, missing required values cause validation failure.
```

## Include and Exclude Rules

Use `include` when you want a focused run.

Use `exclude` when you want a broad run with a few domains intentionally skipped.

Good examples:

- quick operational run: `cluster`, `storage`, `networking`, `azure-integration`
- documentation-heavy run: all core domains plus `hardware`, `management-tools`, and `performance`
- limited-permission run: exclude `hardware` when no BMC access exists

## Optional Domains

Optional and future domains should stay off unless you explicitly configure them.

Examples:

- direct switch interrogation
- direct firewall interrogation
- variant-specific future collectors for disconnected or multi-rack deep inspection

## Output Mode

`current-state` is for operational understanding.

`as-built` is for formal handoff output. It should include richer report rendering and diagram selection, but it still renders from the same cached manifest.

## Variant Hints

Variant hints are allowed when the environment shape is known ahead of time or difficult to infer reliably.

Example:

```yaml
domains:
  hints:
    topology: local-key-vault
    controlPlaneMode: disconnected
```

Hints should guide validation and wording, not overwrite observed facts silently.

## What Not To Put In Config

Avoid putting these in a committed configuration file:

- plaintext secrets
- ad-hoc notes that belong in documentation rather than machine-readable settings
- environment-specific assumptions that Ranger can discover directly

## If Something Is Missing

If a required value is missing, the desired behavior is:

- fail early for invalid configuration
- prompt for credentials when interactive prompting is enabled
- prompt for required structural fields when interactive prompting is enabled
- skip optional domains when targets or credentials are absent

## Related Pages

- [Quickstart](quickstart.md)
- [Command Reference](command-reference.md)
- [Prerequisites](../prerequisites.md)
- [Operator Prerequisites](prerequisites.md)
- [Operator Authentication](authentication.md)
- [Operator Troubleshooting](troubleshooting.md)
