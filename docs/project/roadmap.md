# Roadmap

This page outlines what has shipped, what is next, and where Ranger is heading.
Community contributions are welcome — see [Contributing](../contributor/contributing.md) to get involved.

Ranger supports two outcomes through one discovery engine:

- **Current-state** — recurring operational snapshot of a live Azure Local deployment
- **As-built** — formal documentation package for customer or operational handoff

## Current Release — v1.3.0

Released April 2026. Operator Experience milestone delivering full config parameter coverage and five new operator guide pages.

| Area | What shipped |
| --- | --- |
| Full config parameter coverage (#171) | Every `behavior.*`, `output.*`, and `credentials.azure.*` config key is now a direct runtime parameter on `Invoke-AzureLocalRanger`; parameters take precedence over config file values |
| First Run guide (#174) | Six-step linear guide from install to output with no decisions |
| Wizard guide (#175) | Full `Invoke-RangerWizard` walkthrough with example inputs and generated YAML |
| Command reference scenarios (#176) | Nine copy-paste examples and parameter precedence documentation |
| Configuration reference (#177) | Every config key with type, default, required/optional, and Key Vault syntax |
| Understanding output (#178) | Output directory tree, role-based reading path, collector status interpretation |
| Discovery domain enhancements (#179) | All 10 domain pages include example manifest data, common findings, partial status guidance, and domain dependencies |

## Previous Release — v1.2.1

Released April 2026. Patch release fixing four regressions in the v1.2.0 UX & Transport milestone.

| Area | What shipped |
| --- | --- |
| Redfish 404 retry (#172) | 4xx responses from Redfish endpoints no longer trigger retries; `Invoke-RangerRetry` extended with `-ShouldRetry` scriptblock |
| Hardware partial status (#173) | Hardware collector status is `partial` rather than `success` when any Redfish endpoint returns a 404; warning finding added |
| ShowProgress default-on (#170) | Progress display enabled by default without any config key or `-ShowProgress` switch; opt out with `output.showProgress: false` |
| Prerequisite output (#169) | `Test-AzureLocalRangerPrerequisites` renders a colour-coded table (Pass/Warn/FAIL) for interactive use; optional checks for `Az.ConnectedMachine` and `PwshSpectreConsole` added |

## Previous Release — v1.2.0

Released April 2026. UX & Transport milestone delivering Arc Run Command transport, disconnected discovery, Spectre.Console TUI progress, and interactive configuration wizard.

| Area | What shipped |
| --- | --- |
| Arc Run Command transport (#26) | WinRM workloads automatically fall back to Arc Run Command when ports 5985/5986 are blocked; `behavior.transport: auto/winrm/arc` config control |
| Disconnected discovery (#30) | Pre-run connectivity matrix classifies posture (connected / semi-connected / disconnected); unreachable collectors skip gracefully; matrix stored in manifest |
| Spectre TUI progress (#76) | Live per-collector progress bars via PwshSpectreConsole; falls back to Write-Progress; `-ShowProgress` parameter and `output.showProgress` config key |
| Interactive wizard (#75) | `Invoke-RangerWizard` guided prompts for cluster/nodes/Azure/credentials/scope; saves YAML config or launches run immediately |

## Previous Release — v1.1.2

Released April 2026. Patch release fixing 6 runtime regressions introduced in v1.1.0/v1.1.1, plus 20 new Pester unit tests and live Trailhead field validation on the tplabs cluster.

| Area | What shipped |
| --- | --- |
| Schema contract | Inline hashtable replaces file-path lookup — PSGallery installs no longer throw `FileNotFoundException` |
| Tool version accuracy | `toolVersion` in every manifest now reflects the installed module version dynamically |
| Redfish retry metadata | BMC retry log entries carry label and target URI for actionable troubleshooting |
| Debug output isolation | `DebugPreference` no longer set to `Continue` — eliminates MSAL/Az SDK debug flood at debug log level |
| Null message filtering | Null entries stripped from collector message arrays before manifest and report assembly |
| Credential ordering | Domain credential probed before cluster credential — eliminates redundant WinRM auth retries |
| Unit test coverage | 20 Pester tests in `tests/maproom/unit/Execution.Tests.ps1` covering all 9 regression bugs (#157–#165) |
| Field validation | Trailhead OPORD-1.1.2 closed on live tplabs (4-node Dell AX-760): all 6 collectors succeeded, zero auth retries, schema valid |

## Previous Release — v1.1.1

Released April 2026. Post-release patch for the no-config prerequisite-check regression.

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
| Testing | Focused milestone-close suite passing on final code plus live tplabs validation with all 6 collectors successful |
| Simulation framework | Full output pipeline validated without live connections via `New-RangerSyntheticManifest.ps1` and committed fixture |
| Public documentation | Product, architecture, operator, discovery domain, output, and contributor docs under `docs/` |
| Patch hardening | `Test-AzureLocalRangerPrerequisites` no longer throws when run without a config object or path |

## Next Release — v1.4.0

Focus: Report Quality — handoff-quality HTML reports, improved diagram engine, and PDF output for all report formats.

| Item | Detail | Issue |
| --- | --- | --- |
| HTML report rebuild (#168) | Rebuild the HTML report renderer and diagram engine to produce handoff-quality as-built documentation suitable for customer delivery | [#168](https://github.com/AzureLocal/azurelocal-ranger/issues/168) |
| Diagram engine quality (#140) | Improve the generated draw.io diagram engine so Ranger packages produce polished, handoff-quality outputs | [#140](https://github.com/AzureLocal/azurelocal-ranger/issues/140) |
| PDF output (#96) | PDF rendering for all report formats | [#96](https://github.com/AzureLocal/azurelocal-ranger/issues/96) |
| WAF Assessment integration (#94) | Integrate Azure Well-Architected Framework assessment data into Ranger reports | [#94](https://github.com/AzureLocal/azurelocal-ranger/issues/94) |

## Backlog

Open features tracked as GitHub issues. All are implementation targets — no item in this list is permanently deferred or off the table.

| Item | Detail | Issue |
| --- | --- | --- |
| Direct switch interrogation | SSH/RESTCONF/NETCONF collection from Dell OS10, Arista EOS, Cisco Nexus, and other ToR switches | [#27](https://github.com/AzureLocal/azurelocal-ranger/issues/27) |
| Direct firewall interrogation | Collect firewall policy directly from Palo Alto, FortiGate, Cisco ASA, pfSense, and other appliances | [#28](https://github.com/AzureLocal/azurelocal-ranger/issues/28) |
| Non-Dell OEM hardware support | Hardware inventory collectors for HPE iLO, Lenovo XClarity, and DataON via Redfish | [#29](https://github.com/AzureLocal/azurelocal-ranger/issues/29) |
| Multi-rack Azure Local discovery | Rack topology, SAN storage, compute rack correlation, northbound connectivity for rack-scale deployments | [#31](https://github.com/AzureLocal/azurelocal-ranger/issues/31) |
| Azure-hosted automation worker | Run Ranger from an Azure Automation account or hosted runner without a local PowerShell session | [#25](https://github.com/AzureLocal/azurelocal-ranger/issues/25) |
| Manual import workflows | Accept externally gathered data for environments where automated collection is not authorized | [#32](https://github.com/AzureLocal/azurelocal-ranger/issues/32) |
| Windows PowerShell 5.1 compatibility | Assess and implement compatibility without distorting the PowerShell 7 architecture | [#33](https://github.com/AzureLocal/azurelocal-ranger/issues/33) |
| Baseline comparison and drift detection | Compare a new discovery run against a previous manifest; surface added, removed, and changed findings | [#123](https://github.com/AzureLocal/azurelocal-ranger/issues/123) |
| Scheduled and automated recurring discovery | Task Scheduler XML template, GitHub Actions sample, and unattended invocation mode for recurring runs | [#124](https://github.com/AzureLocal/azurelocal-ranger/issues/124) |
| Incremental document update mode (research) | Design a supported update mode so teams can refresh an existing as-built or current-state package rather than generating net-new documents on every run | [#131](https://github.com/AzureLocal/azurelocal-ranger/issues/131) |
| ESU eligibility and enrollment detection | Flag VMs running WS2012/2016/2019 on Azure Local that qualify for free Arc Extended Security Updates but are not yet enrolled | [#132](https://github.com/AzureLocal/azurelocal-ranger/issues/132) |
| Resource Bridge and Arc VM inventory | Inventory Arc-provisioned VMs via Resource Bridge, classify VM provisioning model, and surface the Arc VM billing model distinct from bare-metal cluster billing | [#133](https://github.com/AzureLocal/azurelocal-ranger/issues/133) |
| VM IP addresses via Arc agent network profile | Collect guest VM IPs from the Arc agent network profile as a fallback when WinRM to the guest is unavailable | [#134](https://github.com/AzureLocal/azurelocal-ranger/issues/134) |
| Arc VM Logical Networks | Collect ARM-managed logical network resources (subnet, VLAN ID, DNS, VM switch association) used by Arc VM provisioning | [#135](https://github.com/AzureLocal/azurelocal-ranger/issues/135) |
| Arc VM Storage Paths | Collect ARM-managed storage container/path resources used by Arc VM provisioning, distinct from S2D pools and CSVs | [#136](https://github.com/AzureLocal/azurelocal-ranger/issues/136) |
| Gallery and Marketplace Image inventory | Collect custom gallery images and marketplace gallery images downloaded to the cluster for Arc VM provisioning | [#137](https://github.com/AzureLocal/azurelocal-ranger/issues/137) |
| Arc Gateway inventory | Collect Arc Gateway configuration and connectivity status for clusters using Arc Gateway as outbound proxy | [#138](https://github.com/AzureLocal/azurelocal-ranger/issues/138) |
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
