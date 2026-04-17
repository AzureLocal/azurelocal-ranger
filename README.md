# Azure Local Ranger

![Azure Local Ranger — Know your ground truth.](docs/assets/images/azurelocalranger-banner.svg)

[![Azure Local](https://img.shields.io/badge/Azure%20Local-azurelocal.cloud-0078D4?logo=microsoft-azure)](https://azurelocal.cloud)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Docs: MkDocs Material](https://img.shields.io/badge/docs-MkDocs%20Material-0f766e)](docs/index.md)
[![PowerShell: 7.x](https://img.shields.io/badge/PowerShell-7.x-3b82f6)](https://github.com/PowerShell/PowerShell)

Documentation: [azurelocal.cloud](https://azurelocal.cloud) | Solutions: [Azure Local Solutions](https://azurelocal.cloud)

> *Know your ground truth.*

Azure Local Ranger is a read-only discovery, documentation, audit, and reporting solution for Azure Local. It builds a manifest-first view of one deployment: the physical platform, the cluster fabric, hosted workloads, and the Azure resources that represent, manage, monitor, or extend that environment.

AzureLocalRanger `1.2.0` is the current release. Install from PSGallery or import from source while developing locally.

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

### From source today

```powershell
git clone https://github.com/AzureLocal/azurelocal-ranger.git
Set-Location .\azurelocal-ranger
Import-Module .\AzureLocalRanger.psd1 -Force
```

### From PSGallery

```powershell
Install-Module AzureLocalRanger -Scope CurrentUser
Import-Module AzureLocalRanger
```

## Quick Start

1. Review the [prerequisites guide](docs/prerequisites.md).
2. Validate the runner with `Test-AzureLocalRangerPrerequisites`.
3. Generate a starter config with `New-AzureLocalRangerConfig -Path .\ranger.yml`.
4. Fill in the fields marked `[REQUIRED]`.
5. Run the assessment with `Invoke-AzureLocalRanger -ConfigPath .\ranger.yml`.

Reports are written under `C:\AzureLocalRanger\<environment>-<mode>-<timestamp>\` by default.

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
