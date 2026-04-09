# Roadmap

This page outlines what has shipped, what is next, and where Ranger is heading.
Community contributions are welcome — see [Contributing](../contributor/contributing.md) to get involved.

Ranger supports two outcomes through one discovery engine:

- **Current-state** — recurring operational snapshot of a live Azure Local deployment
- **As-built** — formal documentation package for customer or operational handoff

## Current Release — v0.5.0

Released April 2026. Pre-release ahead of PSGallery `1.0.0`.

| Area | What shipped |
| --- | --- |
| Module architecture | One public module (`AzureLocalRanger.psd1`) with layered orchestration, collectors, shared services, and output generators |
| Manifest-first runtime | Collect once into `audit-manifest.json`; all reports and diagrams render from that cache only |
| Collectors | Six grouped collectors: topology/cluster, Dell/Redfish hardware, storage/networking, workload/identity/Azure, monitoring, management/performance |
| Report generation | Three-tier HTML and Markdown reports (executive, management, technical) from saved manifest |
| Diagram generation | 18 draw.io-compatible diagrams (6 baseline + 12 extended) with variant-aware selection and SVG output |
| Schema contract | Standalone manifest schema v1.1.0-draft with runtime validation and test boundary |
| Authentication | Five methods: existing context, managed identity, device-code, service principal, Azure CLI fallback |
| Key Vault credential refs | `keyvault://` URI pattern resolved at runtime — no secrets in config files |
| `-OutputPath` parameter | User-controlled export destination overrides the config default |
| Testing | 18 Pester tests: schema, degraded scenarios, cached outputs, end-to-end, and 7 simulation tests against a synthetic IIC 3-node fixture |
| Simulation framework | Full output pipeline validated without live connections via `New-RangerSyntheticManifest.ps1` and committed fixture |
| Public documentation | Product, architecture, operator, discovery domain, output, and contributor docs under `docs/` |

## Next Release — v1.0.0 (PSGallery)

Focus: live-estate proof, PSGallery publish, and polish.

| Item | Detail | Status |
| --- | --- | --- |
| Live environment validation | Run Ranger against a real Azure Local cluster and reconcile generated package against known facts ([#34](https://github.com/AzureLocal/azurelocal-ranger/issues/34)) | 🔵 In progress |
| PSGallery publish | Publish `AzureLocalRanger` module to PowerShell Gallery at `1.0.0` | 🔵 Planned |
| As-built mode report differentiation | Mode-specific report sections so `as-built` output differs meaningfully from `current-state` | 🔵 Planned |
| Topology collector summary fields | Compute `csvSummary`, `updatePosture`, and `eventSummary` objects currently collected as raw evidence only | 🔵 Planned |
| Network device config import ([#36](https://github.com/AzureLocal/azurelocal-ranger/issues/36)) | Import switch and firewall config from external sources for environments where direct interrogation is not possible | 🔵 Planned |
| Output template improvements ([#38](https://github.com/AzureLocal/azurelocal-ranger/issues/38)) | Richer output template definitions aligned to full collector data inventory | 🔵 Planned |
| Docs audit ([#37](https://github.com/AzureLocal/azurelocal-ranger/issues/37)) | Verify all public docs reflect the current implementation and remove any planning-era stale content | 🔵 Planned |

## Backlog

Open features tracked as GitHub issues. All are implementation targets — no item in this list is permanently deferred or off the table.

| Item | Detail | Issue |
| --- | --- | --- |
| Arc Run Command transport | Use Azure Arc Run Command as an alternate collection channel for environments where WinRM is blocked | [#26](https://github.com/AzureLocal/azurelocal-ranger/issues/26) |
| Direct switch interrogation | SSH/RESTCONF/NETCONF collection from Dell OS10, Arista EOS, Cisco Nexus, and other ToR switches | [#27](https://github.com/AzureLocal/azurelocal-ranger/issues/27) |
| Direct firewall interrogation | Collect firewall policy directly from Palo Alto, FortiGate, Cisco ASA, pfSense, and other appliances | [#28](https://github.com/AzureLocal/azurelocal-ranger/issues/28) |
| Non-Dell OEM hardware support | Hardware inventory collectors for HPE iLO, Lenovo XClarity, and DataON via Redfish | [#29](https://github.com/AzureLocal/azurelocal-ranger/issues/29) |
| Disconnected / semi-connected discovery | Graceful degradation and enriched collection for environments with limited or no Azure connectivity | [#30](https://github.com/AzureLocal/azurelocal-ranger/issues/30) |
| Multi-rack Azure Local discovery | Rack topology, SAN storage, compute rack correlation, northbound connectivity for rack-scale deployments | [#31](https://github.com/AzureLocal/azurelocal-ranger/issues/31) |
| Azure-hosted automation worker | Run Ranger from an Azure Automation account or hosted runner without a local PowerShell session | [#25](https://github.com/AzureLocal/azurelocal-ranger/issues/25) |
| Manual import workflows | Accept externally gathered data for environments where automated collection is not authorized | [#32](https://github.com/AzureLocal/azurelocal-ranger/issues/32) |
| Windows PowerShell 5.1 compatibility | Assess and implement compatibility without distorting the PowerShell 7 architecture | [#33](https://github.com/AzureLocal/azurelocal-ranger/issues/33) |
| Interactive configuration wizard | Guided terminal wizard (`Invoke-RangerWizard`) with domain selection, presets, and full parameter passthrough for headless use | [#75](https://github.com/AzureLocal/azurelocal-ranger/issues/75) |
| Terminal TUI scan progress | Rich live progress display while collection runs — per-collector bars, spinner, real-time findings count, ANSI fallback for CI | [#76](https://github.com/AzureLocal/azurelocal-ranger/issues/76) |
| Terminal TUI library survey | Evaluate Spectre.Console, Terminal.Gui/ConsoleGuiTools, Sharprompt, and alternatives before committing to #76 | [#77](https://github.com/AzureLocal/azurelocal-ranger/issues/77) |
| Baseline comparison and drift detection | Compare a new discovery run against a previous manifest; surface added, removed, and changed findings | [#123](https://github.com/AzureLocal/azurelocal-ranger/issues/123) |
| Scheduled and automated recurring discovery | Task Scheduler XML template, GitHub Actions sample, and unattended invocation mode for recurring runs | [#124](https://github.com/AzureLocal/azurelocal-ranger/issues/124) |
| Incremental document update mode (research) | Design a supported update mode so teams can refresh an existing as-built or current-state package rather than generating net-new documents on every run | [#131](https://github.com/AzureLocal/azurelocal-ranger/issues/131) |
| ESU eligibility and enrollment detection | Flag VMs running WS2012/2016/2019 on Azure Local that qualify for free Arc Extended Security Updates but are not yet enrolled | [#132](https://github.com/AzureLocal/azurelocal-ranger/issues/132) |
| Resource Bridge and Arc VM inventory | Inventory Arc-provisioned VMs via Resource Bridge, classify VM provisioning model, and surface the Arc VM billing model distinct from bare-metal cluster billing | [#133](https://github.com/AzureLocal/azurelocal-ranger/issues/133) |
| Idle and underutilized VM detection | Surface VMs with low CPU/memory utilization and surface rightsizing recommendations in the cost section | [#125](https://github.com/AzureLocal/azurelocal-ranger/issues/125) |
| Storage efficiency analysis | Deduplication ratios, thin-provisioning coverage gaps, and storage waste identification across volumes and pools | [#126](https://github.com/AzureLocal/azurelocal-ranger/issues/126) |
| SQL Server and Windows Server license inventory | Edition, core count, and AHB cross-reference per VM for license compliance reporting | [#127](https://github.com/AzureLocal/azurelocal-ranger/issues/127) |
| Cluster capacity headroom analysis | Compute, memory, and storage utilization percentages with configurable warning thresholds and trend-based runway | [#128](https://github.com/AzureLocal/azurelocal-ranger/issues/128) |
| Multi-cluster inventory rollup | Discover multiple Azure Local clusters in one run and produce per-cluster packages plus an estate summary report | [#129](https://github.com/AzureLocal/azurelocal-ranger/issues/129) |
| CMDB and ITSM structured export | `Export-AzureLocalRangerCmdb` producing ServiceNow, CSV, and JSON CI records from the audit manifest | [#130](https://github.com/AzureLocal/azurelocal-ranger/issues/130) |

## Long-term Vision

Azure Local Ranger aims to be the definitive open-source documentation and audit tool for Azure Local deployments — useful to:

- **Platform engineers** who need a reliable, repeatable record of how a deployment is built and configured
- **Operations teams** who need a fast current-state snapshot before changes or incidents
- **Architects** designing expansions, migrations, or new workloads on top of an existing environment
- **Managed service providers** who need consistent, client-ready as-built packages across multiple customer sites

The tool will remain open-source, PowerShell-native, and output-friendly — no agents, no portals, no licensing fees.

## Suggest a Feature

Open an issue at [github.com/AzureLocal/azurelocal-ranger/issues](https://github.com/AzureLocal/azurelocal-ranger/issues) with the label `enhancement`.

Pull requests are welcome — see [Contributing](../contributor/contributing.md) for guidelines.

## Read Next

- [Versioning](versioning.md)
- [Repository Structure](repository-structure.md)
- [Getting Started](../contributor/getting-started.md)
- [Changelog](changelog.md)
