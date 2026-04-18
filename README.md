# Azure Local Ranger

![Azure Local Ranger — Know your ground truth.](docs/assets/images/azurelocalranger-banner.svg)

[![Azure Local](https://img.shields.io/badge/Azure%20Local-azurelocal.cloud-0078D4?logo=microsoft-azure)](https://azurelocal.cloud)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Docs: MkDocs Material](https://img.shields.io/badge/docs-MkDocs%20Material-0f766e)](docs/index.md)
[![PowerShell: 7.x](https://img.shields.io/badge/PowerShell-7.x-3b82f6)](https://github.com/PowerShell/PowerShell)

Documentation: [azurelocal.cloud](https://azurelocal.cloud) | Solutions: [Azure Local Solutions](https://azurelocal.cloud)

> *Know your ground truth.*

Azure Local Ranger is a read-only discovery, documentation, audit, and reporting solution for Azure Local. It builds a manifest-first view of one deployment: the physical platform, the cluster fabric, hosted workloads, and the Azure resources that represent, manage, monitor, or extend that environment.

AzureLocalRanger `2.6.4` is the current release. Install from PSGallery or import from source while developing locally.

## What Ranger Covers

| Layer | What Ranger Covers |
|-------|-------------------|
| Physical platform | Nodes, hardware, firmware, BMC, NICs, disks, GPUs, TPM |
| Cluster and fabric | Cluster identity, quorum, fault domains, update posture, registration |
| Storage | S2D, pools, volumes, CSVs, storage health, QoS, and replication |
| Networking | Virtual switches, host vNICs, RDMA, ATC, SDN, DNS, proxy, and firewall posture |
| Workloads | VM inventory, placement, density, Arc VM overlays, and workload-family detection |
| Identity and security | AD or local identity, certificates, BitLocker, WDAC, Defender, and audit posture |
| Azure resources | Arc registration, resource bridge, custom locations, policy, monitoring, update, backup, and recovery |
| OEM and management | OEM tooling, WAC, SCVMM, SCOM, and operational agents |
| Operational state | Health, performance baseline, event patterns, and maintenance posture |

## Installation

```powershell
Install-Module AzureLocalRanger -Scope CurrentUser -Force
Import-Module AzureLocalRanger
Connect-AzAccount                 # once per session
```

## Quick Start

Three ways to run Ranger, ranked. Pick the one that matches how thorough you want to be.

### Path 1 — Guided wizard (recommended for first runs)

```powershell
Invoke-AzureLocalRanger -Wizard
```

The wizard walks every question it needs (environment, cluster, Azure auth, optional BMC, output, scope), validates GUIDs inline, shows a review screen before anything runs, and saves a reusable YAML config for next time. Supports all six Azure auth methods: `existing-context`, runtime prompt, `service-principal`, `managed-identity`, `device-code`, and `azure-cli`.

### Path 2 — Config file + run

```powershell
New-AzureLocalRangerConfig -Path .\ranger.yml
# edit .\ranger.yml in your editor
Invoke-AzureLocalRanger -ConfigPath .\ranger.yml
```

Best for version-controlled configs, CI / scheduled runs, and team-standard deployments.

### Path 3 — Parameters or zero-config

```powershell
# Minimum: 2 fields — Ranger lists HCI clusters in the subscription and picks one
Invoke-AzureLocalRanger -TenantId <guid> -SubscriptionId <guid>

# Named cluster: skip the selection prompt
Invoke-AzureLocalRanger -TenantId <guid> -SubscriptionId <guid> -ClusterName <name>

# Bare: prompts interactively for whatever is missing
Invoke-AzureLocalRanger
```

Fastest for ad-hoc runs. Azure Arc auto-discovery fills in the resource group, cluster FQDN, nodes, and AD domain.

Reports land under `C:\AzureLocalRanger\<environment>-<mode>-<timestamp>\` by default.

### For contributors — import from source

```powershell
git clone https://github.com/AzureLocal/azurelocal-ranger.git
Set-Location .\azurelocal-ranger
Import-Module .\AzureLocalRanger.psd1 -Force
```

## Commands

| Command | Purpose |
|---|---|
| `Invoke-AzureLocalRanger` | Main entry point. Runs discovery, builds the manifest, and renders the requested outputs. Pass `-Wizard` for the guided first-run experience |
| `Invoke-RangerWizard` | Standalone wrapper around the same wizard — kept for script compatibility. New code should prefer `Invoke-AzureLocalRanger -Wizard` |
| `New-AzureLocalRangerConfig` | Generate an annotated YAML or JSON config scaffold |
| `Export-AzureLocalRangerReport` | Re-render reports and diagrams from a saved manifest without live access |
| `Test-AzureLocalRangerPrerequisites` | Validate the execution environment and optionally install missing prerequisites |
| `Test-RangerPermissions` | Dedicated pre-run RBAC and provider-registration audit (#202) |
| `Export-RangerWafConfig` / `Import-RangerWafConfig` | v2.0.0 (#226) hot-swap WAF rule config |

## Output Model

Ranger produces a normalized audit manifest first and generates all outputs from that cached data:

- HTML and Markdown narrative reports
- DOCX and PDF handoff reports
- XLSX delivery workbooks for inventories and findings
- SVG and draw.io diagrams
- a saved manifest and package index for offline re-rendering

## Start Here

| Audience | Start Here |
|----------|------------|
| Operators | [Prerequisites Guide](docs/prerequisites.md) |
| Operators | [Quick Start](docs/operator/quickstart.md) |
| Operators | [Command Reference](docs/operator/command-reference.md) |
| Everyone | [What Ranger Is](docs/what-ranger-is.md) |
| Everyone | [Ranger vs Scout](docs/ranger-vs-scout.md) |
| Everyone | [Scope Boundary](docs/scope-boundary.md) |
| Everyone | [Deployment Variants](docs/deployment-variants.md) |
| Architects and operators | [Architecture Overview](docs/architecture/system-overview.md) |
| Architects and operators | [Discovery Domain Pages](docs/discovery-domains/cluster-and-node.md) |
| Contributors | [Getting Started](docs/contributor/getting-started.md) |
| All | [Roadmap](docs/project/roadmap.md) |

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
