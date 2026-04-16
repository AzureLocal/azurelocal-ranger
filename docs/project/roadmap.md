# Roadmap

This page outlines what has shipped, what is next, and where Ranger is heading.
Community contributions are welcome — see [Contributing](../contributor/contributing.md) to get involved.

Ranger supports two outcomes through one discovery engine:

- **Current-state** — recurring operational snapshot of a live Azure Local deployment
- **As-built** — formal documentation package for customer or operational handoff

## Next Release — v1.5.0 — Document Quality

Stabilisation milestone. Fixes broken report output, crashes, and incorrect defaults in the current product before any new capability is added.

| Item | Detail | Issue |
| --- | --- | --- |
| HTML reports — quality overhaul (#192) | Fix misaligned tables, embed diagrams correctly, and raise overall visual quality to handoff standard | [#192](https://github.com/AzureLocal/azurelocal-ranger/issues/192) |
| as-built report redesign (#193) | Redesign as-built report structure to reflect a real as-built document — current structure does not match the format | [#193](https://github.com/AzureLocal/azurelocal-ranger/issues/193) |
| as-built vs current-state differentiation (#194) | Make the two output modes visually distinct — today they are effectively identical | [#194](https://github.com/AzureLocal/azurelocal-ranger/issues/194) |
| Wizard format list bug (#195) | Fix wizard default format list — `json` is invalid and `docx`/`xlsx`/`pdf` are missing | [#195](https://github.com/AzureLocal/azurelocal-ranger/issues/195) |
| Key Vault DNS crash (#198) | Replace hard crash on Key Vault DNS failure with a graceful fallback and actionable error | [#198](https://github.com/AzureLocal/azurelocal-ranger/issues/198) |

## v1.6.0 — Platform Intelligence

Auth, connectivity, discovery, and output format uplift. Establishes the engine foundations that all subsequent collector and WAF work depends on.

### Auth & Connectivity

| Item | Detail | Issue |
| --- | --- | --- |
| Multi-method Azure auth chain (#200) | SPN cert, SPN secret, Managed Identity, Device Code, and existing context — automatic fallback chain | [#200](https://github.com/AzureLocal/azurelocal-ranger/issues/200) |
| Save-AzContext for background runspaces (#201) | Propagate Azure context into background collection runspaces so Azure collectors work in parallel | [#201](https://github.com/AzureLocal/azurelocal-ranger/issues/201) |
| Pre-run RBAC and resource provider audit (#202) | `Test-RangerPermissions` surfaces missing roles and unregistered providers before collection starts | [#202](https://github.com/AzureLocal/azurelocal-ranger/issues/202) |
| WinRM TrustedHosts + DNS fallback chain (#203) | Resolve node addresses via FQDN, IP, and DNS fallback before failing — removes most pre-Arc connectivity errors | [#203](https://github.com/AzureLocal/azurelocal-ranger/issues/203) |
| Node and VM cross-resource-group fallback (#204) | Find nodes and VMs whose ARM resources are in a different resource group from the cluster | [#204](https://github.com/AzureLocal/azurelocal-ranger/issues/204) |
| Azure Resource Graph single-query discovery (#205) | Replace per-type `Get-AzResource` loops with a single Resource Graph query — faster and more reliable at scale | [#205](https://github.com/AzureLocal/azurelocal-ranger/issues/205) |
| Graceful degradation on partial Azure permissions (#206) | Per-subscription try/catch/continue — partial permissions produce partial results, not a crash | [#206](https://github.com/AzureLocal/azurelocal-ranger/issues/206) |

### Discovery

| Item | Detail | Issue |
| --- | --- | --- |
| Auto-discover resource group (#196) | Derive resource group from subscription + cluster name — removes required prompt when Azure credentials are present | [#196](https://github.com/AzureLocal/azurelocal-ranger/issues/196) |
| Auto-discover cluster FQDN from Arc (#197) | Derive cluster FQDN from Arc machine resources — removes required prompt when Azure credentials are present | [#197](https://github.com/AzureLocal/azurelocal-ranger/issues/197) |

### Output Formats

| Item | Detail | Issue |
| --- | --- | --- |
| PDF output (#207) | Headless Edge/Chrome `--print-to-pdf` — zero library dependency, no Office required | [#207](https://github.com/AzureLocal/azurelocal-ranger/issues/207) |
| Word (DOCX) output (#208) | OOXML ZIP construction — no Office, no COM dependency | [#208](https://github.com/AzureLocal/azurelocal-ranger/issues/208) |
| XLSX output (#209) | ImportExcel module — no COM, no Office, multi-tab workbook per report tier | [#209](https://github.com/AzureLocal/azurelocal-ranger/issues/209) |
| Power BI CSV export (#210) | Star-schema CSV + manifest for direct Power BI import | [#210](https://github.com/AzureLocal/azurelocal-ranger/issues/210) |

### Engine

| Item | Detail | Issue |
| --- | --- | --- |
| `-Wizard` as inline parameter (#211) | Move wizard into `Invoke-AzureLocalRanger -Wizard` — eliminates the separate `Invoke-RangerWizard` entry point | [#211](https://github.com/AzureLocal/azurelocal-ranger/issues/211) |
| `-SkipPreCheck` flag (#212) | Permission audit runs by default; opt out with `-SkipPreCheck` | [#212](https://github.com/AzureLocal/azurelocal-ranger/issues/212) |
| File-based progress IPC (#213) | Write per-collector progress to temp files so background runspaces can report status to the foreground session | [#213](https://github.com/AzureLocal/azurelocal-ranger/issues/213) |
| Graduated threshold WAF scoring (#214) | Weight 1–3 per check with named calculation references in `waf-rules.json` | [#214](https://github.com/AzureLocal/azurelocal-ranger/issues/214) |

## v2.0.0 — Extended Collectors & WAF Intelligence

Second wave of ARM collectors covering the full Arc VM infrastructure surface, weighted WAF scoring, AHB cost analysis, and operational robustness patterns.

### Arc VM Infrastructure

| Item | Detail | Issue |
| --- | --- | --- |
| Logical networks and subnet detail (#216) | Collect `Microsoft.AzureStackHCI/logicalNetworks` — subnets, VLANs, IP pools, DHCP, VM switch association | [#216](https://github.com/AzureLocal/azurelocal-ranger/issues/216) |
| Storage paths collector (#217) | Collect `Microsoft.AzureStackHCI/storageContainers` with CSV cross-reference and orphaned container detection | [#217](https://github.com/AzureLocal/azurelocal-ranger/issues/217) |
| Arc Resource Bridge and Arc VM collector (#219) | Collect `Microsoft.ResourceConnector/appliances` and `virtualMachineInstances`; classify VMs as native Hyper-V vs Arc-provisioned | [#219](https://github.com/AzureLocal/azurelocal-ranger/issues/219) |
| Custom locations collector (#218) | Collect `Microsoft.ExtendedLocation/customLocations` associated with Arc infrastructure | [#218](https://github.com/AzureLocal/azurelocal-ranger/issues/218) |
| Marketplace and custom image collector (#221) | Collect `marketplaceGalleryImages` and `galleryImages` with storagePathId cross-reference | [#221](https://github.com/AzureLocal/azurelocal-ranger/issues/221) |
| Arc Gateway collector (#220) | Collect `Microsoft.HybridCompute/gateways` with per-node routing detection and mixed-routing findings | [#220](https://github.com/AzureLocal/azurelocal-ranger/issues/220) |
| Arc machine extension collection (#215) | Inventory installed Arc extensions per node — version, status, and configuration | [#215](https://github.com/AzureLocal/azurelocal-ranger/issues/215) |

### WAF & Cost

| Item | Detail | Issue |
| --- | --- | --- |
| Weighted WAF scoring (#225) | Weight 1–3 per check; warnings count as 0.5× weight — replaces flat pass/fail scoring | [#225](https://github.com/AzureLocal/azurelocal-ranger/issues/225) |
| WAF config download and hot-swap (#226) | Download and upload `waf-rules.json` via CLI without re-running collection | [#226](https://github.com/AzureLocal/azurelocal-ranger/issues/226) |
| AHB and cost analysis (#222) | Cluster-level AHB detection, per-core cost calculation, KPI cards, WAF Cost Optimization check, savings banner | [#222](https://github.com/AzureLocal/azurelocal-ranger/issues/222) |

### Report & Output

| Item | Detail | Issue |
| --- | --- | --- |
| JSON evidence export (#229) | Raw collected data export — no scoring or assessment metadata, for downstream tooling | [#229](https://github.com/AzureLocal/azurelocal-ranger/issues/229) |
| Portrait/landscape switching and cell coloring in PDF (#227) | Conditional page orientation and colour-coded cells in PDF output | [#227](https://github.com/AzureLocal/azurelocal-ranger/issues/227) |
| Pricing footer with dated reference (#228) | Pricing footnote with dated URL reference in PDF and HTML reports | [#228](https://github.com/AzureLocal/azurelocal-ranger/issues/228) |
| Agent version grouping and software version report (#224) | Group nodes by Arc agent version; surface version skew as a finding | [#224](https://github.com/AzureLocal/azurelocal-ranger/issues/224) |
| VM distribution balance analysis (#223) | Detect VM distribution imbalance across cluster nodes | [#223](https://github.com/AzureLocal/azurelocal-ranger/issues/223) |

### Robustness

| Item | Detail | Issue |
| --- | --- | --- |
| Module auto-install and auto-update on startup (#231) | Validate, install, and update required modules at startup with `-SkipModuleUpdate` opt-out | [#231](https://github.com/AzureLocal/azurelocal-ranger/issues/231) |
| Concurrent collection guard and empty-data safeguard (#230) | Prevent overlapping collection runs; handle empty collector results without report failures | [#230](https://github.com/AzureLocal/azurelocal-ranger/issues/230) |

## v2.5.0 — Extended Platform Coverage

Extended hardware and protocol coverage, deep workload analysis, and long-horizon output formats.

### Workload & Cost Analysis

| Item | Detail | Issue |
| --- | --- | --- |
| Idle and underutilized VM detection (#125) | Surface VMs with low CPU/memory utilization and rightsizing recommendations | [#125](https://github.com/AzureLocal/azurelocal-ranger/issues/125) |
| Storage efficiency analysis (#126) | Deduplication ratios, thin-provisioning coverage gaps, and storage waste identification across volumes and pools | [#126](https://github.com/AzureLocal/azurelocal-ranger/issues/126) |
| SQL Server and Windows Server license inventory (#127) | Edition, core count, and AHB cross-reference per VM for license compliance reporting | [#127](https://github.com/AzureLocal/azurelocal-ranger/issues/127) |
| Cluster capacity headroom analysis (#128) | Compute, memory, and storage utilization percentages with configurable warning thresholds and trend-based runway | [#128](https://github.com/AzureLocal/azurelocal-ranger/issues/128) |

### Multi-Cluster & Output Formats

| Item | Detail | Issue |
| --- | --- | --- |
| Multi-cluster inventory rollup (#129) | Discover multiple Azure Local clusters in one run; produce per-cluster packages plus an estate summary report | [#129](https://github.com/AzureLocal/azurelocal-ranger/issues/129) |
| PowerPoint presentation output (#80) | Executive environment overview deck generated from the audit manifest | [#80](https://github.com/AzureLocal/azurelocal-ranger/issues/80) |
| Manual import workflows (#32) | Accept externally gathered data for environments where automated collection is not authorized | [#32](https://github.com/AzureLocal/azurelocal-ranger/issues/32) |

## v3.0.0 — Enterprise & OEM Integration

Enterprise integrations, specialized hardware protocols, and advanced topology coverage beyond single-cluster HCI deployments.

| Item | Detail | Issue |
| --- | --- | --- |
| Direct switch interrogation (#27) | SSH/RESTCONF/NETCONF collection from Dell OS10, Arista EOS, Cisco Nexus, and other ToR switches | [#27](https://github.com/AzureLocal/azurelocal-ranger/issues/27) |
| Direct firewall interrogation (#28) | Collect firewall policy from Palo Alto, FortiGate, Cisco ASA, pfSense, and other appliances | [#28](https://github.com/AzureLocal/azurelocal-ranger/issues/28) |
| Non-Dell OEM hardware support (#29) | Hardware inventory collectors for HPE iLO, Lenovo XClarity, and DataON via Redfish | [#29](https://github.com/AzureLocal/azurelocal-ranger/issues/29) |
| Multi-rack Azure Local discovery (#31) | Rack topology, SAN storage, compute rack correlation, northbound connectivity for rack-scale deployments | [#31](https://github.com/AzureLocal/azurelocal-ranger/issues/31) |
| CMDB and ITSM structured export (#130) | `Export-AzureLocalRangerCmdb` producing ServiceNow, CSV, and JSON CI records from the audit manifest | [#130](https://github.com/AzureLocal/azurelocal-ranger/issues/130) |

## Current Release — v1.4.2

Released April 2026. TRAILHEAD field validation patch — test config fixes for tplabs environment and docs deploy trigger correction.

| Area | What shipped |
| --- | --- |
| TRAILHEAD test configs | Added `credentials.domain` section and `svg`/`drawio` output formats to `tplabs-current-state.yml` and `tplabs-as-built.yml` test configs |
| Field test cycle script | Removed `SupportsShouldProcess` from `New-RangerFieldTestCycle.ps1` to eliminate `-WhatIf` parameter conflict |
| Docs deploy workflow | Removed `release: [published]` trigger — GitHub Pages environment protection only allows deployments from `main` |
| Operation TRAILHEAD v1.4.2 | Full 8-phase field validation against live tplabs-clus01 (4-node Dell AX-760). All 7 collectors succeeded; all output formats generated (HTML, Markdown, JSON, XLSX, PDF, 13×SVG, 13×draw.io). Pester 76/76 passing. |

## Previous Release — v1.4.1

Released April 2026. Wizard interactive-gate regression fix.

| Area | What shipped |
| --- | --- |
| Wizard interactive gate (#180) | `Test-RangerInteractivePromptAvailable` now gates on `[Environment]::UserInteractive` only; no longer falsely fails in VS Code terminal or Windows Terminal when a real user is present |

## Previous Release — v1.4.0

Released April 2026. Report Quality milestone delivering handoff-quality HTML reports, improved diagram engine, PDF cover pages, and WAF Assessment integration with an external rule engine.

| Area | What shipped |
| --- | --- |
| HTML report rebuild (#168) | Type-aware section rendering (table, kv-grid, sign-off) with Node, VM, Storage Pool, Physical Disk, Network Adapter, Event Log, and Security Audit inventory tables. Markdown report updated with pipe-delimited tables and sign-off placeholder rows. |
| Diagram engine quality (#140) | SVG rebuilt with group containers, color-coded per-node-kind fills, cubic bezier edges, and dark header bar. draw.io XML rebuilt with swim-lane containers and per-kind node styles. Near-empty diagrams skip gracefully. |
| PDF output (#96) | Cover page prepended to all PDF reports with title, cluster, mode, version, date, and confidentiality notice. Plain-text PDF renderer updated with type-aware section output. |
| WAF Assessment integration (#94) | New optional collector queries Azure Advisor. Rule engine (`Invoke-RangerWafRuleEvaluation`) evaluates 23 manifest-path rules from `config/waf-rules.json` without re-collection. WAF Scorecard and Findings tables added to management and technical tiers. |

## Previous Release — v1.3.0

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

## Unscheduled Backlog

Open features without a milestone assignment. All are implementation targets — no item is permanently deferred.

| Item | Detail | Issue |
| --- | --- | --- |
| Azure-hosted automation worker (#25) | Run Ranger from an Azure Automation account or hosted runner without a local PowerShell session | [#25](https://github.com/AzureLocal/azurelocal-ranger/issues/25) |
| Windows PowerShell 5.1 compatibility (#33) | Assess and implement compatibility without distorting the PowerShell 7 architecture | [#33](https://github.com/AzureLocal/azurelocal-ranger/issues/33) |
| Baseline comparison and drift detection (#123) | Compare a new discovery run against a previous manifest; surface added, removed, and changed findings | [#123](https://github.com/AzureLocal/azurelocal-ranger/issues/123) |
| Scheduled and automated recurring discovery (#124) | Task Scheduler XML template, GitHub Actions sample, and unattended invocation mode for recurring runs | [#124](https://github.com/AzureLocal/azurelocal-ranger/issues/124) |
| Incremental document update mode (#131) | Design a supported update mode so teams can refresh an existing as-built package rather than regenerating from scratch | [#131](https://github.com/AzureLocal/azurelocal-ranger/issues/131) |
| ESU eligibility and enrollment detection (#132) | Flag VMs running WS2012/2016/2019 on Azure Local that qualify for free Arc Extended Security Updates but are not yet enrolled | [#132](https://github.com/AzureLocal/azurelocal-ranger/issues/132) |

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
