# Roadmap

This page outlines what has shipped, what is next, and where Ranger is heading.
Community contributions are welcome — see [Contributing](../contributor/contributing.md) to get involved.

Ranger supports two outcomes through one discovery engine:

- **Current-state** — recurring operational snapshot of a live Azure Local deployment
- **As-built** — formal documentation package for customer or operational handoff

---

**Upcoming** — what's next, in ship order. Each milestone link has the full issue backlog; tables below surface the highlights.

## v2.6.5 — Credential UX & Discovery Hardening

First-run friction fixes uncovered during live validation: credential prompts that don't explain themselves, WinRM dialogs that fire mid-flow, duplicate cluster/domain prompts, node connections that use short names instead of FQDNs, and silent cluster auto-selection. Milestone: [#32](https://github.com/AzureLocal/azurelocal-ranger/milestone/32).

| Item | Detail | Issue |
| --- | --- | --- |
| Credential prompt clarity | `Get-Credential` title and message must name the target system and expected account format (`DOMAIN\user` or `user@domain.com`); same treatment for BMC / switch / firewall paths | [#302](https://github.com/AzureLocal/azurelocal-ranger/issues/302) |
| WinRM silent-start preflight | Ranger starts WinRM service silently during preflight instead of letting Windows throw an interactive service-start dialog mid-run | [#303](https://github.com/AzureLocal/azurelocal-ranger/issues/303) |
| Cluster / domain credential reuse | When `credentials.domain` is unconfigured, reuse the cluster credential automatically — no second prompt for the same account | [#304](https://github.com/AzureLocal/azurelocal-ranger/issues/304) |
| Arc node FQDN extraction | `Invoke-RangerAzureAutoDiscovery` pulls `properties.dnsFqdn` from Arc machines into a `nodeFqdns` map; all per-node WinRM/CIM fan-out uses FQDNs, eliminating `0x8009030e` failures on non-domain-joined management machines | [#308](https://github.com/AzureLocal/azurelocal-ranger/issues/308) |
| Node FQDN resolver (s2d pattern) | Port `Resolve-S2DNodeFqdn`'s 4-step chain (pass-through / cluster-suffix / DNS / short-name) as `Resolve-RangerNodeFqdn` for cases where Arc does not supply a FQDN | [#306](https://github.com/AzureLocal/azurelocal-ranger/issues/306) |
| Cluster selection UX | Auto-selection prints the chosen cluster and RG; multiple clusters show a numbered menu; `-Unattended` still throws `RANGER-DISC-002` on multiples | [#309](https://github.com/AzureLocal/azurelocal-ranger/issues/309) |
| Azure-first discovery phase | Azure discovery (cluster, node FQDNs, RG, domain, Arc overlay) runs to completion before any on-prem WinRM session opens, so collectors start with full context | [#310](https://github.com/AzureLocal/azurelocal-ranger/issues/310) |

## v2.7.0 — Documentation and Reporting Overhaul

Two parallel tracks: deep, comprehensive public-facing documentation with production-quality draw.io diagrams, and a full revisit of every output format for executive-grade quality. Milestone: [#25](https://github.com/AzureLocal/azurelocal-ranger/milestone/25).

### Documentation

| Item | Detail | Issue |
| --- | --- | --- |
| End-to-end operator workflow guides | Network-gear import, drift, cloud publishing, estate, WAF remediation — raw input to verified outcome | [#267](https://github.com/AzureLocal/azurelocal-ranger/issues/267) |
| Manifest schema reference | Every field in `audit-manifest.json` documented with a machine-readable JSON Schema | [#266](https://github.com/AzureLocal/azurelocal-ranger/issues/266) |
| Configuration reference deep-dive | Every `ranger.yml` key, decision trees, 5 annotated sample configs | [#265](https://github.com/AzureLocal/azurelocal-ranger/issues/265) |
| Production-quality draw.io diagrams | 9 architecture/data-flow/auth/output-pipeline diagrams with consistent shape library, layers, legends | [#270](https://github.com/AzureLocal/azurelocal-ranger/issues/270) |
| Per-collector operator reference | One page per collector + analyzer — permissions, output, failure modes | [#269](https://github.com/AzureLocal/azurelocal-ranger/issues/269) |
| WAF rule engine reference | Calculations, thresholds, priority scoring, authoring custom rules, full rule catalog | [#268](https://github.com/AzureLocal/azurelocal-ranger/issues/268) |
| Troubleshooting playbook | Symptom → diagnosis → fix for 40+ common failure modes, keyed by error text | [#272](https://github.com/AzureLocal/azurelocal-ranger/issues/272) |
| Public-facing getting-started funnel | Landing, 5-minute quickstart, first 30 minutes, next steps with branching paths | [#271](https://github.com/AzureLocal/azurelocal-ranger/issues/271) |

### Output overhaul

| Item | Detail | Issue |
| --- | --- | --- |
| S2D-style storage analysis | 7-stage capacity waterfall, per-disk wear / firmware / reliability telemetry, thin-provisioning risk checks, cache tier analysis, TiB/TB dual-unit display, and four new SVG diagrams (Disk-to-Node Map, Pool Layout, Volume Resiliency, Health Scorecard) ported from `azurelocal-s2d-cartographer` | [#307](https://github.com/AzureLocal/azurelocal-ranger/issues/307) |
| HTML reports | Executive-grade visual design, interactive navigation, theming, accessibility | [#281](https://github.com/AzureLocal/azurelocal-ranger/issues/281) |
| Markdown reports | GitHub-flavored fidelity, Mermaid diagrams, MkDocs integration, cross-links | [#274](https://github.com/AzureLocal/azurelocal-ranger/issues/274) |
| DOCX | Professional Word deliverable — cover page, TOC, styles, embedded diagrams | [#273](https://github.com/AzureLocal/azurelocal-ranger/issues/273) |
| PDF | Print-ready with paginated headers, tagged accessibility, consistent rendering | [#277](https://github.com/AzureLocal/azurelocal-ranger/issues/277) |
| XLSX workbook | Analyst-grade with cover sheet, pivot-ready named tables, conditional formatting, dashboard tab | [#278](https://github.com/AzureLocal/azurelocal-ranger/issues/278) |
| SVG diagrams | Proper layout algorithms, consistent styling, legends, light/dark theming | [#280](https://github.com/AzureLocal/azurelocal-ranger/issues/280) |
| drawio XML | Production-quality source files, named shape library, layers, grid-aligned | [#284](https://github.com/AzureLocal/azurelocal-ranger/issues/284) |
| PPTX deck | Boardroom-ready slide master, consistent charts, speaker notes, theme variants | [#282](https://github.com/AzureLocal/azurelocal-ranger/issues/282) |
| Power BI star schema | Published `.pbit` template, documented DAX measures, sample dashboards, estate variant | [#283](https://github.com/AzureLocal/azurelocal-ranger/issues/283) |
| json-evidence + raw manifest JSON | Published JSON Schema, versioning, consumer examples (jq / PowerShell / Python / C#) | [#285](https://github.com/AzureLocal/azurelocal-ranger/issues/285) |
| Estate rollup outputs | Cross-cluster heatmaps, drill-down, trend tracking, estate PPTX + SVG | [#286](https://github.com/AzureLocal/azurelocal-ranger/issues/286) |
| Remediation runbooks | Change-management-ready, rollback guidance, dependency graph, ServiceNow/Jira formats | [#288](https://github.com/AzureLocal/azurelocal-ranger/issues/288) |

## v2.8.0 — Cloud Publishing UX

Cloud publishing ergonomics plus the Spectre.Console TUI rewrite. Milestone: [#29](https://github.com/AzureLocal/azurelocal-ranger/milestone/29).

| Item | Detail | Issue |
| --- | --- | --- |
| Auto-provision storage account + container + RBAC | `output.remoteStorage.ensureExists` block and `-EnsureExists` parameter so first-time publishers don't have to pre-create SA, container, and role assignment manually | [#289](https://github.com/AzureLocal/azurelocal-ranger/issues/289) |
| Spectre.Console TUI — real implementation | Current `80-ProgressDisplay.ps1` is a non-functional stub (no live bars, module not in manifest, syntax error on line 175, zero tests). Rewrite using `Invoke-SpectreCommandWithProgress` + `Add-SpectreJob` for genuine live-updating per-collector bars; add `PwshSpectreConsole` as an optional manifest dependency; add Pester coverage; run PSScriptAnalyzer in CI | [#305](https://github.com/AzureLocal/azurelocal-ranger/issues/305) |

## v3.0.0 — Enterprise & OEM Integration

Enterprise integrations, specialized hardware protocols, advanced topology coverage, and interactive self-contained output tools. Milestone: [#9](https://github.com/AzureLocal/azurelocal-ranger/milestone/9).

| Item | Detail | Issue |
| --- | --- | --- |
| Direct switch interrogation (#27) | SSH/RESTCONF/NETCONF collection from Dell OS10, Arista EOS, Cisco Nexus, and other ToR switches | [#27](https://github.com/AzureLocal/azurelocal-ranger/issues/27) |
| Direct firewall interrogation (#28) | Collect firewall policy from Palo Alto, FortiGate, Cisco ASA, pfSense, and other appliances | [#28](https://github.com/AzureLocal/azurelocal-ranger/issues/28) |
| Non-Dell OEM hardware support (#29) | Hardware inventory collectors for HPE iLO, Lenovo XClarity, and DataON via Redfish | [#29](https://github.com/AzureLocal/azurelocal-ranger/issues/29) |
| Multi-rack Azure Local discovery (#31) | Rack topology, SAN storage, compute rack correlation, northbound connectivity for rack-scale deployments | [#31](https://github.com/AzureLocal/azurelocal-ranger/issues/31) |
| CMDB and ITSM structured export (#130) | `Export-AzureLocalRangerCmdb` producing ServiceNow, CSV, and JSON CI records from the audit manifest | [#130](https://github.com/AzureLocal/azurelocal-ranger/issues/130) |
| Interactive self-contained HTML tools | Capacity what-if, VM rightsizing, AHB/license break-even, storage efficiency explorer — JS-driven, offline, no web server | [#264](https://github.com/AzureLocal/azurelocal-ranger/issues/264) |

---

**Shipped** — most recent first.

## Shipped — v2.6.4 — First-Run UX Patch (2026-04-17)

Fixes a structural-placeholder leak that blocked the 2-field / zero-config invocation path advertised in v2.6.3. Same bug class as v2.6.3 #292 but for structural fields.

| Item | Detail | Issue |
| --- | --- | --- |
| Default config scaffold placeholders removed | `Get-RangerDefaultConfig` no longer ships `'azlocal-prod-01'`, `'00000000-...'`, etc. for `environment.*`, `targets.cluster.*`, `targets.azure.*`, or `targets.bmc.endpoints`. The v2.6.3 cluster auto-select gate now fires correctly; bare `Invoke-AzureLocalRanger` completes after supplying only subscription + tenant | [#300](https://github.com/AzureLocal/azurelocal-ranger/issues/300) |
| Interactive prompt re-runs auto-discovery between answers | `Invoke-RangerInteractiveInput` now prompts one field at a time and re-runs `Invoke-RangerAzureAutoDiscovery` after each answer; subscription + tenant unlock `Select-RangerCluster` on the next pass, collapsing remaining prompts to zero or one | [#300](https://github.com/AzureLocal/azurelocal-ranger/issues/300) |
| Prompt order leads with Azure identifiers | `Get-RangerMissingRequiredInputs` lists `subscriptionId` and `tenantId` before fields that auto-discovery would fill | [#300](https://github.com/AzureLocal/azurelocal-ranger/issues/300) |
| Fixture-mode bypass in `Test-RangerConfiguration` | Required-target check now respects fixture mode the same way the missing-required check does; fixture-backed runs no longer fail validation just because the default cluster target is now legitimately empty | [#300](https://github.com/AzureLocal/azurelocal-ranger/issues/300) |

## Shipped — v2.6.3 — First-Run UX (2026-04-17)

Drops the required-input floor to tenantId + subscriptionId, fills in the rest via Azure Arc auto-discovery, and rebuilds the setup wizard.

| Item | Detail | Issue |
| --- | --- | --- |
| Cluster node auto-discovery | `Invoke-RangerAzureAutoDiscovery` populates `targets.cluster.nodes` from Arc cluster `properties.nodes` or a subscription Arc machines query; short names are promoted to FQDNs via the discovered domain suffix | [#294](https://github.com/AzureLocal/azurelocal-ranger/issues/294) |
| Three-field minimum invocation | `Invoke-AzureLocalRanger -SubscriptionId x -TenantId y -ClusterName z` now runs with zero config file; defaults + overrides + Arc auto-discovery fill the rest; `environment.name` derives from `clusterName` | [#296](https://github.com/AzureLocal/azurelocal-ranger/issues/296) |
| Two-field cluster auto-select | New `Select-RangerCluster` enumerates HCI clusters in the subscription; auto-selects singletons, prompts menu on multiples, throws `RANGER-DISC-002` under `-Unattended`, `RANGER-DISC-001` when none, `RANGER-AUTH-001` on permission failure | [#297](https://github.com/AzureLocal/azurelocal-ranger/issues/297) |
| Scope-gated device credential prompting | `Resolve-RangerCredentialMap` only prompts for BMC / switch / firewall credentials when the relevant collector is in scope AND a target list is populated; explicit overrides still honored | [#295](https://github.com/AzureLocal/azurelocal-ranger/issues/295) |
| Wizard overhaul | `Invoke-RangerWizard` covers all six Azure auth methods, inline GUID validation, optional BMC section, run-mode toggle, review screen, overwrite guard, and a proper YAML serializer (fixes prior JSON-in-.yml bug) | [#291](https://github.com/AzureLocal/azurelocal-ranger/issues/291) |
| kv-ranger credential leak fix | `Get-RangerDefaultConfig` no longer ships placeholder `keyvault://kv-ranger/*` password references; missing creds fall through to the prompt instead of failing the pre-check against a vault the operator never configured | [#292](https://github.com/AzureLocal/azurelocal-ranger/issues/292) |
| tplabs test config matrix | 13 scenario configs + parameter runbook at `demo-repository/config/env/tplabs/ranger/` covering every auth method, transport, mode, scope, and behavior combination | [#293](https://github.com/AzureLocal/azurelocal-ranger/issues/293) |

## Shipped — v2.6.2 — TRAILHEAD Bug Fixes P7 (2026-04-17)

| Item | Detail | Issue |
| --- | --- | --- |
| Config validator accepts pptx and json-evidence | `Test-RangerConfiguration` now includes `pptx` and `json-evidence` in the supported format whitelist | [#262](https://github.com/AzureLocal/azurelocal-ranger/issues/262) |
| YAML config template indentation fix | `New-AzureLocalRangerConfig` YAML template now has correct indentation for `credentials.azure.method` and `behavior.promptForMissingRequired` | [#263](https://github.com/AzureLocal/azurelocal-ranger/issues/263) |

## Shipped — v2.6.1 — TRAILHEAD Bug Fixes P3 (2026-04-17)

| Item | Detail | Issue |
| --- | --- | --- |
| Topology collector 0-node fix | `Invoke-RangerRemoteCommand` now executes per-node; a single WinRM failure (0x80090304) no longer aborts collection from healthy nodes | [#259](https://github.com/AzureLocal/azurelocal-ranger/issues/259) |
| licenseProfiles/default 404 silenced | `Get-AzResource` for optional Arc license profiles uses `-ErrorAction SilentlyContinue`; missing profiles return `not-found` without transcript noise | [#260](https://github.com/AzureLocal/azurelocal-ranger/issues/260) |
| Search-AzGraph type mismatch fix | `Get-RangerArmResourcesByGraph` casts subscription and management-group arrays to `[string[]]` to fix YAML-parsed subscription ID type errors | [#261](https://github.com/AzureLocal/azurelocal-ranger/issues/261) |

## Shipped — v2.5.0 — Extended Platform Coverage (2026-04-17)

Workload/cost intelligence, multi-cluster orchestration, and presentation-ready output.

| Item | Detail | Issue |
| --- | --- | --- |
| Capacity headroom analysis | `capacityAnalysis` domain with Healthy / Warning / Critical status per dimension | [#128](https://github.com/AzureLocal/azurelocal-ranger/issues/128) |
| Idle / underutilized VM detection | `vmUtilization` domain with rightsizing proposals and freed-resource savings | [#125](https://github.com/AzureLocal/azurelocal-ranger/issues/125) |
| Storage efficiency analysis | `storageEfficiency` domain: dedup, thin-provisioning, waste class tagging | [#126](https://github.com/AzureLocal/azurelocal-ranger/issues/126) |
| SQL / Windows Server license inventory | `licenseInventory` domain for compliance reporting | [#127](https://github.com/AzureLocal/azurelocal-ranger/issues/127) |
| Multi-cluster estate rollup | `Invoke-AzureLocalRangerEstate` + estate-rollup.json + estate-summary.html | [#129](https://github.com/AzureLocal/azurelocal-ranger/issues/129) |
| PowerPoint deck output | `pptx` output format built via `System.IO.Packaging` — no Office dependency | [#80](https://github.com/AzureLocal/azurelocal-ranger/issues/80) |
| Manual evidence import | `Import-RangerManualEvidence` merges hand-collected data with provenance | [#32](https://github.com/AzureLocal/azurelocal-ranger/issues/32) |

## Shipped — v2.3.0 — Cloud Publishing (2026-04-17)

Push Ranger run packages to Azure and stream WAF telemetry to Log Analytics after every run.

| Item | Detail | Issue |
| --- | --- | --- |
| Azure Blob publisher | `Publish-RangerRun` + `-PublishToStorage`. MI / Entra RBAC / Key-Vault SAS auth; SHA-256 idempotency; blob tags | [#244](https://github.com/AzureLocal/azurelocal-ranger/issues/244) |
| Catalog blobs | `_catalog/{cluster}/latest.json` + `_catalog/_index.json` per run | [#245](https://github.com/AzureLocal/azurelocal-ranger/issues/245) |
| Cloud Publishing guide | `docs/operator/cloud-publishing.md` + `samples/cloud-publishing/` | [#246](https://github.com/AzureLocal/azurelocal-ranger/issues/246) |
| Log Analytics sink | `RangerRun_CL` + `RangerFinding_CL` via DCE/DCR Logs Ingestion API | [#247](https://github.com/AzureLocal/azurelocal-ranger/issues/247) |

## Shipped — v2.2.0 — WAF Compliance Guidance (2026-04-17)

Turn the WAF score from a snapshot of what's broken into an actionable roadmap. Every failing rule now carries a structured remediation block, and the report ranks fixes by priority, projects the post-fix score, and can emit a copy-pasteable runbook.

| Item | Detail | Issue |
| --- | --- | --- |
| Structured remediation per rule | `remediation` block with rationale, steps, sample PowerShell, effort, impact, dependencies, docsUrl on every rule. Reports surface a Next Step column and a full Remediation Detail section. | [#236](https://github.com/AzureLocal/azurelocal-ranger/issues/236) |
| Prioritized WAF Compliance Roadmap | `priorityScore = (weight × severity × impact) / effort` buckets failing rules into Now / Next / Later tiers. Exported as `powerbi/waf-roadmap.csv`. | [#241](https://github.com/AzureLocal/azurelocal-ranger/issues/241) |
| Gap-to-Goal projection | Greedy fix plan: "current 67% → projected 82% by closing 3 findings". Honours rule dependencies. Exported as `powerbi/waf-gap-to-goal.csv`. | [#242](https://github.com/AzureLocal/azurelocal-ranger/issues/242) |
| Per-pillar compliance checklist | One subsection per WAF pillar with status / weight / effort / next step / signed-off column. Exported as `powerbi/waf-checklist.csv`. | [#238](https://github.com/AzureLocal/azurelocal-ranger/issues/238) |
| `Get-RangerRemediation` command | Emits copy-pasteable `.ps1` (dry-run by default, `-Commit` for live), markdown runbook, or checklist for one or more findings. Substitutes `$ClusterName`/`$ResourceGroup`/`$SubscriptionId`/`$Region`/`$NodeName` from the manifest. | [#243](https://github.com/AzureLocal/azurelocal-ranger/issues/243) |

## Shipped — v2.1.0 — Preflight Hardening (2026-04-16)

Close the three auth / preflight gaps identified during the v2.0.0 post-release review. Every failure that would have surfaced mid-run now surfaces in the pre-run audit.

| Item | Detail | Issue |
| --- | --- | --- |
| Per-resource-type ARM probe | `Invoke-RangerPermissionAudit` now probes the seven v2.0.0 collector surfaces (logicalNetworks, storageContainers, customLocations, appliances, gateways, marketplace + gallery images). All pass → Pass; some 403 → Warn; all 403 → Fail | [#235](https://github.com/AzureLocal/azurelocal-ranger/issues/235) |
| Deep WinRM CIM probe | New `Invoke-RangerCimDepthProbe` issues a representative `Get-CimInstance` against `root/MSCluster`, `root/virtualization/v2`, and `root/Microsoft/Windows/Storage`. Recorded in `manifest.run.remoteExecution.cimDepth`. Non-blocking warning on deny | [#234](https://github.com/AzureLocal/azurelocal-ranger/issues/234) |
| Azure Advisor read probe | Pre-check calls `Get-AzAdvisorRecommendation`; 403 downgrades to `Partial` with actionable remediation. Missing `Az.Advisor` is a Skip with an install hint | [#233](https://github.com/AzureLocal/azurelocal-ranger/issues/233) |

## Shipped — v2.0.0 — Extended Collectors & WAF Intelligence (2026-04-16)

Collector breadth, cost intelligence, and scoring rigour. Adds seven Arc-surface collectors, Azure Hybrid Benefit cost analysis, weighted WAF scoring, and a hot-swap WAF config pipeline.

### Collectors

| Item | Detail | Issue |
| --- | --- | --- |
| Arc machine extensions per node | AMA / Defender / Guest Configuration inventory with provisioning state and auto-upgrade flags | [#215](https://github.com/AzureLocal/azurelocal-ranger/issues/215) |
| Logical networks + subnet detail | `Microsoft.AzureStackHCI/logicalNetworks` with VLAN, IP pools, DHCP, vSwitch cross-reference | [#216](https://github.com/AzureLocal/azurelocal-ranger/issues/216) |
| Storage paths (CSV/SMB) | `Microsoft.AzureStackHCI/storageContainers` with CSV mount-point cross-reference | [#217](https://github.com/AzureLocal/azurelocal-ranger/issues/217) |
| Custom locations | `Microsoft.ExtendedLocation/customLocations` linked to Resource Bridge host | [#218](https://github.com/AzureLocal/azurelocal-ranger/issues/218) |
| Arc Resource Bridge | `Microsoft.ResourceConnector/appliances` + `vmProvisioningModel` classification for VMs | [#219](https://github.com/AzureLocal/azurelocal-ranger/issues/219) |
| Arc Gateway | `Microsoft.HybridCompute/gateways` + per-node routing detection | [#220](https://github.com/AzureLocal/azurelocal-ranger/issues/220) |
| Marketplace + custom images | `marketplaceGalleryImages` + `galleryImages` with storage-path cross-reference | [#221](https://github.com/AzureLocal/azurelocal-ranger/issues/221) |

### Intelligence

| Item | Detail | Issue |
| --- | --- | --- |
| Azure Hybrid Benefit + cost analysis | Cluster-level AHB detection, $10/core/month calculation, per-node breakdown, potential savings, pricing footer | [#222](https://github.com/AzureLocal/azurelocal-ranger/issues/222), [#228](https://github.com/AzureLocal/azurelocal-ranger/issues/228) |
| VM distribution balance analysis | Coefficient of variation across nodes with warning/fail thresholds | [#223](https://github.com/AzureLocal/azurelocal-ranger/issues/223) |
| Agent + OS version grouping | Per-version group with drift status (latest / maxBehind) | [#224](https://github.com/AzureLocal/azurelocal-ranger/issues/224) |
| Weighted WAF scoring | Rule weight 1-3, warning awards 0.5x weight, Excellent/Good/Fair/Needs Improvement thresholds | [#225](https://github.com/AzureLocal/azurelocal-ranger/issues/225) |

### Commands & UX

| Item | Detail | Issue |
| --- | --- | --- |
| `Export-RangerWafConfig` / `Import-RangerWafConfig` | Hot-swap WAF config with `-Validate` dry-run and `-Default` restore | [#226](https://github.com/AzureLocal/azurelocal-ranger/issues/226) |
| `json-evidence` output format | Raw inventory export, no scoring / run metadata, `_metadata` envelope | [#229](https://github.com/AzureLocal/azurelocal-ranger/issues/229) |
| Module auto-install on startup | Az.* required modules installed/updated if below minimum; `-SkipModuleUpdate` opt-out | [#231](https://github.com/AzureLocal/azurelocal-ranger/issues/231) |

### Reliability

| Item | Detail | Issue |
| --- | --- | --- |
| Concurrent collection guard | Second invocation warns and returns instead of racing script: state | [#230](https://github.com/AzureLocal/azurelocal-ranger/issues/230) |
| Empty-data safeguard | Zero-node manifest throws an actionable error instead of empty reports | [#230](https://github.com/AzureLocal/azurelocal-ranger/issues/230) |

### Output

| Item | Detail | Issue |
| --- | --- | --- |
| Portrait/landscape page switching | `@page landscape-pg` CSS for Arc extensions + subnet detail sections | [#227](https://github.com/AzureLocal/azurelocal-ranger/issues/227) |
| Conditional status-cell coloring | HTML tables auto-color Healthy / Warning / Failed tokens | [#227](https://github.com/AzureLocal/azurelocal-ranger/issues/227) |

## Shipped — v1.6.0 — Platform Intelligence (2026-04-16)

Auth, connectivity, discovery, and output-format uplift. Establishes the engine foundations that all subsequent collector and WAF work depends on.

### Auth & Connectivity

| Item | Detail | Issue |
| --- | --- | --- |
| Multi-method Azure auth chain | SPN cert (thumbprint / PFX), tenant-matching context reuse, sovereign-cloud environment, existing / device-code / MI / SPN-secret | [#200](https://github.com/AzureLocal/azurelocal-ranger/issues/200) |
| Save-AzContext for background runspaces | `Export-RangerAzureContext` / `Import-RangerAzureContext` helpers for runspace handoff | [#201](https://github.com/AzureLocal/azurelocal-ranger/issues/201) |
| Pre-run RBAC and resource-provider audit | `Test-RangerPermissions`; default-on at start of `Invoke-AzureLocalRanger` | [#202](https://github.com/AzureLocal/azurelocal-ranger/issues/202) |
| WinRM TrustedHosts + DNS fallback chain | Passthrough → TrustedHosts scan → DNS `GetHostEntry` for cluster / node FQDN resolution | [#203](https://github.com/AzureLocal/azurelocal-ranger/issues/203) |
| Node / VM cross-resource-group fallback | Arc machines query with subscription-wide fallback and per-cross-RG warnings | [#204](https://github.com/AzureLocal/azurelocal-ranger/issues/204) |
| Azure Resource Graph single-query discovery | `Search-AzGraph` KQL fast path with `Get-AzResource` fallback | [#205](https://github.com/AzureLocal/azurelocal-ranger/issues/205) |
| Graceful degradation on partial Azure permissions | Error classifier + `manifest.run.skippedResources` + `behavior.failOnPartialDiscovery` | [#206](https://github.com/AzureLocal/azurelocal-ranger/issues/206) |

### Discovery

| Item | Detail | Issue |
| --- | --- | --- |
| Auto-discover resource group | Subscription-wide ARM search when `targets.azure.resourceGroup` is absent | [#196](https://github.com/AzureLocal/azurelocal-ranger/issues/196) |
| Auto-discover cluster FQDN | Arc properties first, TrustedHosts / DNS on-prem fallback | [#197](https://github.com/AzureLocal/azurelocal-ranger/issues/197) |

### Output Formats

| Item | Detail | Issue |
| --- | --- | --- |
| PDF via headless Edge / Chrome | `--headless=new --print-to-pdf` renders HTML; plain-text fallback when no browser | [#207](https://github.com/AzureLocal/azurelocal-ranger/issues/207) |
| DOCX OOXML tables | `section.type='table'` / `'kv'` / `'sign-off'` render as real Word tables | [#208](https://github.com/AzureLocal/azurelocal-ranger/issues/208) |
| XLSX formula-injection safety | Cells starting with `=`, `+`, `-`, `@` are apostrophe-prefixed | [#209](https://github.com/AzureLocal/azurelocal-ranger/issues/209) |
| Power BI CSV + star-schema export | Five CSVs + `_relationships.json` + `_metadata.json` bundle ready for Power BI Desktop / Fabric | [#210](https://github.com/AzureLocal/azurelocal-ranger/issues/210) |

### Engine

| Item | Detail | Issue |
| --- | --- | --- |
| `-Wizard` as inline parameter | `Invoke-AzureLocalRanger -Wizard` dispatches to the interactive wizard | [#211](https://github.com/AzureLocal/azurelocal-ranger/issues/211) |
| `-SkipPreCheck` flag | Pre-run audit default-on; opt-out via flag or `behavior.skipPreCheck` | [#212](https://github.com/AzureLocal/azurelocal-ranger/issues/212) |
| File-based progress IPC | `Write`/`Read`/`Remove-RangerProgressState` for background runspace progress | [#213](https://github.com/AzureLocal/azurelocal-ranger/issues/213) |
| Graduated threshold WAF scoring | Threshold bands with named aggregate calculations in `waf-rules.json` | [#214](https://github.com/AzureLocal/azurelocal-ranger/issues/214) |

## Shipped — v1.5.0 — Document Quality (2026-04-16)

Stabilisation milestone. Fixed broken report output, crashes, and incorrect defaults before new capability work begins.

| Item | Detail | Issue |
| --- | --- | --- |
| HTML reports — quality overhaul | Fixed-layout tables with constrained column widths, inline architecture diagrams, severity-coloured finding callouts, print stylesheet, visible sign-off signature lines | [#192](https://github.com/AzureLocal/azurelocal-ranger/issues/192) |
| as-built report redesign | New Installation and Configuration Record with per-node configuration, network address allocation, storage configuration, Azure integration, identity/security, validation record, and known-issues/deviations register | [#193](https://github.com/AzureLocal/azurelocal-ranger/issues/193) |
| as-built vs current-state differentiation | Distinct tier names, classification banner (CONFIDENTIAL vs INTERNAL), subtitle (Post-Deployment As-Built Package vs Live Discovery Report); Health Status traffic lights and WAF scorecard suppressed in as-built | [#194](https://github.com/AzureLocal/azurelocal-ranger/issues/194) |
| Wizard format list bug | Default changed from `html,markdown,json,svg` (invalid `json`) to `html,markdown,docx,xlsx,pdf,svg` with prompt label listing valid set | [#195](https://github.com/AzureLocal/azurelocal-ranger/issues/195) |
| Key Vault DNS crash | Actionable error message on DNS failure naming likely causes; graceful fallback to `Get-Credential` when `behavior.promptForMissingCredentials: true` | [#198](https://github.com/AzureLocal/azurelocal-ranger/issues/198) |

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
