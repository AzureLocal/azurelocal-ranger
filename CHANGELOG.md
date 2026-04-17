# Changelog

All notable changes to Azure Local Ranger will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Pre-release versions start at `0.5.0`. The first stable PSGallery release will be `1.0.0` once live-estate validation is complete.

## [Unreleased]

## [2.5.0] — 2026-04-17

Extended Platform Coverage — workload/cost intelligence, multi-cluster
orchestration, and presentation-ready output.

### Added

- **Capacity headroom analysis (#128)** — `manifest.domains.capacityAnalysis` domain. Per-node + cluster totals for vCPU allocation, memory allocation, storage used, and pool allocated. Healthy / Warning / Critical status per dimension from configurable thresholds (default warn 80%, fail 90%).
- **Idle / underutilized VM detection (#125)** — `manifest.domains.vmUtilization` domain. Classifies each VM as idle / underutilized / healthy / stopped / no-counters from `vm.utilization` sidecar data (avg/peak CPU %, avg memory %). Emits rightsizing proposals (`proposedVcpu`, `proposedMemoryMb`) and aggregated potential-freed-resource savings.
- **Storage efficiency analysis (#126)** — `manifest.domains.storageEfficiency` domain. Per-volume dedup state, dedup mode, dedup ratio, saved GiB, thin-provisioning coverage. Emits a `wasteClass` tag (`over-provisioned`, `dedup-candidate`, `none`) and aggregate logical-vs-physical GiB.
- **SQL / Windows Server license inventory (#127)** — `manifest.domains.licenseInventory` domain. Enumerates guest-detected SQL instances (edition, version, core count, license model, AHB eligibility) and Windows Server instances with core totals, ready for compliance reporting.
- **Multi-cluster estate rollup (#129)** — `Invoke-AzureLocalRangerEstate` runs Ranger against every target in an estate config. Emits per-cluster packages plus `estate-rollup.json`, `estate-summary.html`, and `powerbi/estate-clusters.csv` with WAF score / AHB / capacity posture per cluster.
- **PowerPoint output (#80)** — new `pptx` output format. Builds a 7-slide executive overview OOXML `.pptx` via `System.IO.Packaging`. No Office or third-party-module dependency.
- **Import-RangerManualEvidence (#32)** — merges hand-collected evidence (network inventory, firewall exports, externally governed data) into an existing audit-manifest.json with provenance labels. `manifest.run.manualImports` records source, domain, and evidence file path.

### Changed

- Runtime pipeline runs v2.5.0 analyzers after all collectors complete and before schema validation so the new domains are subject to the same verification as collected data.

## [2.3.0] — 2026-04-17

Cloud Publishing — push Ranger run packages to Azure Blob Storage and stream
WAF telemetry to Log Analytics Workspace after every run.

### Added

- **Azure Blob publisher (#244)** — `Publish-RangerRun` uploads the run package (manifest, evidence, package-index, log, optionally reports + powerbi) to a named storage account. Auth chain: Managed Identity → Entra RBAC → SAS from Key Vault. SHA-256 idempotency skips unchanged blobs. Blob tags: `cluster`, `mode`, `toolVersion`, `runId`. `Invoke-AzureLocalRanger -PublishToStorage` triggers automatically post-run.
- **Catalog + latest-pointer blobs (#245)** — after each publish, writes `_catalog/{cluster}/latest.json` (run summary + artifact paths + WAF score snapshot) and merges `_catalog/_index.json` so downstream consumers resolve the latest run per cluster without listing.
- **Cloud Publishing guide + samples (#246)** — `docs/operator/cloud-publishing.md` with RBAC setup (Storage Blob Data Contributor), config schema, auth chain explanation, and troubleshooting. `samples/cloud-publishing/` with Bicep storage Bicep, KQL workbook, and Teams webhook starter.
- **Log Analytics Workspace sink (#247)** — `Invoke-AzureLocalRanger -PublishToLogAnalytics` posts one `RangerRun_CL` row (scores, AHB adoption, node/VM counts, cloud-publish status) and one `RangerFinding_CL` row per failing WAF rule to a DCE/DCR pair via the Logs Ingestion API. Offline mode available for tests.

## [2.2.0] — 2026-04-17

WAF Compliance Guidance — turn the WAF score into an actionable roadmap with
priority-ranked fix order, projected post-fix score, and a copy-pasteable
remediation script.

### Added

- **Structured remediation block per WAF rule (#236)** — every rule in `config/waf-rules.json` now carries `remediation.{rationale, steps, samplePowerShell, estimatedEffort, estimatedImpact, dependencies, docsUrl}`. Reports surface a new "Next Step" column in the Findings table and a full Remediation Detail section per failing rule. Schema version bumped to `2.2.0` with a new `prioritization` block defining severity, impact, and effort factors.
- **WAF Compliance Roadmap (#241)** — `Invoke-RangerWafRuleEvaluation` now returns a `roadmap` array bucketing failing rules into Now/Next/Later tiers by `priorityScore = (weight * severityMultiplier * impactFactor) / effortFactor`. Rendered as a ranked table in the technical tier; exported as `powerbi/waf-roadmap.csv`.
- **Gap-to-Goal projection (#242)** — `gapToGoal` result block with a greedy fix plan: *"Current 67%. Closing these 3 findings raises you to 82% (Excellent)."* Honours rule dependencies so prerequisites fix first. Exported as `powerbi/waf-gap-to-goal.csv`. Truncated at 5 entries or when the projected score crosses the next threshold.
- **Per-pillar WAF Compliance Checklist (#238)** — one subsection per pillar with every rule, status, weight, effort, next step, and a Signed Off column for handoff / sprint artefact use. Exported as `powerbi/waf-checklist.csv`.
- **`Get-RangerRemediation` (#243)** — new public command emits a copy-pasteable remediation script from an existing manifest. `-Format ps1|md|checklist`, `-Commit` for live cmdlets (dry-run by default), `-IncludeDependencies` to expand prerequisites, `-FindingId` to target specific rules. Substitutes `$ClusterName`, `$ResourceGroup`, `$SubscriptionId`, `$Region`, `$NodeName` from the manifest.

### Changed

- `Invoke-RangerWafRuleEvaluation` now returns `roadmap` and `gapToGoal` alongside the existing `pillarScores` and `ruleResults`.
- Every rule result carries `estimatedEffort`, `estimatedImpact`, and `priorityScore` for downstream consumers.

## [2.1.0] — 2026-04-16

Preflight Hardening — closes three auth gaps identified during the v2.0.0
post-release review. Every failure that would have surfaced mid-run now
surfaces in the pre-run audit.

### Added

- **Per-resource-type ARM probe (#235)** — `Invoke-RangerPermissionAudit` now issues a `Get-AzResource` against each v2.0.0 collector surface (`Microsoft.AzureStackHCI/logicalNetworks`, `Microsoft.AzureStackHCI/storageContainers`, `Microsoft.ExtendedLocation/customLocations`, `Microsoft.ResourceConnector/appliances`, `Microsoft.HybridCompute/gateways`, `Microsoft.AzureStackHCI/marketplaceGalleryImages`, `Microsoft.AzureStackHCI/galleryImages`). Per-surface result is recorded on `$script:RangerLastArmSurfaceChecks`. All surfaces Pass → audit `v2.0.0 ARM surfaces` check is Pass. Some Deny → Warn with the denied surface names. All Deny → Fail with actionable remediation.
- **Deep WinRM CIM probe (#234)** — new `Invoke-RangerCimDepthProbe` in `Modules/Private/72-CimDepthProbe.ps1`. Runs after the shallow WinRM preflight and issues a representative `Get-CimInstance` against `root/MSCluster` (`MSCluster_Cluster`), `root/virtualization/v2` (`Msvm_VirtualSystemManagementService`), and `root/Microsoft/Windows/Storage` (`MSFT_StoragePool`). Result captured in `manifest.run.remoteExecution.cimDepth` with per-namespace status (`ok`, `denied`, `missing-namespace`, `error`). `denied` overall raises a warning finding; `partial` logs the denied namespace list; `sufficient` is quiet. Non-blocking — warns rather than throws so operators with arc-only transport can still run.
- **Azure Advisor read probe (#233)** — `Invoke-RangerPermissionAudit` calls `Get-AzAdvisorRecommendation`. Success → Pass. 403 → Warn with "WAF Assessment Advisor section will be empty" messaging and explicit `Microsoft.Advisor/recommendations/read` permission naming. Provider not registered → Warn with `Register-AzResourceProvider -ProviderNamespace Microsoft.Advisor` remediation. `Az.Advisor` module missing → Skip with an optional-install hint. Never blocks the run because Advisor is advisory.

### Changed

- Overall readiness semantics unchanged from v1.6.0 — `Insufficient` throws, `Partial` warns and continues, `Full` is quiet.
- New checks are all skipped in fixture mode (same `isFixtureMode` gate that already guards the v1.6.0 pre-check).

## [2.0.0] — 2026-04-16

### Added — Collectors

- **Arc machine extensions per node (#215)** — per-node inventory of Arc extensions (AMA, Defender for Servers, Guest Configuration) with `typeHandlerVersion`, `provisioningState`, `autoUpgradeMinorVersion`, `enableAutomaticUpgrade`. Surfaced as a dedicated `Arc Extensions by Node` HTML/Markdown/DOCX table (landscape-oriented in PDF), an `Extensions` XLSX tab, and an `arc-extensions.csv` Power BI table. `domains.azureIntegration.arcExtensionsDetail` is a hashtable with `byNode` + `summary.amaCoveragePct`.
- **Logical networks + subnet detail collector (#216)** — `Microsoft.AzureStackHCI/logicalNetworks` with per-subnet `addressPrefix`, `vlan`, `ipPools`, `dhcpOptions`, `vmSwitchName` cross-reference, and `dnsServers`. New `Logical Networks` + `Logical Network Subnets` sections; `LogicalNetworks` + `Subnets` XLSX tabs; `logical-networks.csv` Power BI CSV.
- **Storage paths collector (#217)** — `Microsoft.AzureStackHCI/storageContainers` inventory with CSV cross-reference. New `Storage Paths` section; `StoragePaths` XLSX tab; `storage-paths.csv` Power BI CSV.
- **Custom locations collector (#218)** — `Microsoft.ExtendedLocation/customLocations` linked to Resource Bridge `hostResourceId`.
- **Arc Resource Bridge collector (#219)** — `Microsoft.ResourceConnector/appliances` with version, distro, infrastructure provider, status. Arc VMs now carry a `vmProvisioningModel` field (`hyper-v-native` | `arc-vm-resource-bridge`).
- **Arc Gateway collector (#220)** — `Microsoft.HybridCompute/gateways` with per-node routing detection (`arcGatewayNodeRouting`).
- **Marketplace + custom image collector (#221)** — `Microsoft.AzureStackHCI/marketplaceGalleryImages` and `galleryImages` with storage-path cross-reference and publisher / offer / SKU metadata.

### Added — Intelligence

- **AHB cost/licensing analysis (#222)** — `Invoke-RangerCostLicensingAnalysis` reads `softwareAssuranceProperties.softwareAssuranceStatus` as the cluster-level AHB signal, multiplies physical cores against the public $10/core/month rate, and emits current monthly cost, potential savings, and `ahbAdoptionPct` under `domains.azureIntegration.costLicensing`. New `Cost & Licensing` + `Cost & Licensing — Per Node` HTML/Markdown/DOCX/PDF sections with pricing footer. `CostLicensing` XLSX tab + `cost-licensing.csv` Power BI CSV.
- **VM distribution balance analysis (#223)** — `Invoke-RangerVmDistributionAnalysis` computes coefficient of variation across nodes. Balanced/warning/fail thresholds at CV < 0.2 / 0.2–0.3 / > 0.3 or any node > 2× mean. Surfaces as per-node table with CV-in-caption status.
- **Agent version grouping (#224)** — `Invoke-RangerAgentVersionAnalysis` groups nodes by Arc agent + OS version with drift summary (`uniqueVersions`, `latestVersion`, `maxBehind`, `status`). New `Arc Agent Versions` section.
- **Weighted WAF scoring (#225)** — per-rule `weight` field (1–3); warning severity awards 0.5× weight; graduated threshold bands still work; pillar and overall scores aggregate weighted awarded over weighted max. `scoreThresholds` (Excellent/Good/Fair/Needs Improvement) exposed on the evaluator result. New rules: SEC-007 (AMA coverage graduated), SEC-008 (agent version drift), COST-003 (AHB adoption graduated), REL-007–009 (logical networks, resource bridge, VM distribution), OE-007–009 (storage paths, custom locations, image provenance).

### Added — Commands and UX

- **`Export-RangerWafConfig` / `Import-RangerWafConfig` (#226)** — hot-swap WAF rule config. `-Validate` schema-checks without writing. `-Default` restores the shipped `waf-rules.default.json` backup. `-ReRun -ManifestPath` re-evaluates against an existing manifest.
- **`json-evidence` output format (#229)** — raw resource-only JSON payload with a minimal `_metadata` envelope; excludes `healthChecks`, `wafResults`, `summary`, `run`. Accepted by `Invoke-AzureLocalRanger -OutputFormats json-evidence` and `Export-AzureLocalRangerReport -Formats json-evidence`. Filename: `<runId>-evidence.json` under `reports/`.
- **`-SkipModuleUpdate` (#231)** — opt-out of automatic Az.* module install/update on startup for air-gapped environments. Install/update validation is invoked before pre-check.

### Added — Reliability

- **Concurrent collection guard (#230)** — second `Invoke-AzureLocalRanger` call in the same session emits a warning and returns without racing shared `script:` state; flag is released in a `finally` block.
- **Empty-data safeguard (#230)** — when collection completes with zero nodes, Ranger throws an actionable error naming the cluster target and WinRM / RBAC remediation paths instead of producing empty reports.
- **Module auto-install/update on startup (#231)** — required modules (`Az.Accounts`, `Az.Resources`, `Az.ConnectedMachine`, `Az.KeyVault`) are installed or updated via `Install-Module`/`Update-Module -Force -Scope CurrentUser` when below minimum version. Optional modules (`Az.StackHCI`, `Az.ResourceGraph`, `ImportExcel`) emit an info hint when missing. Install/update failures log a warning but do not abort the run.

### Added — Output

- **Portrait/landscape page switching (#227)** — `@page landscape-pg` CSS rule applied to sections flagged `_layout='landscape'` (Arc extensions, logical network subnets). Headless Edge/Chrome `--print-to-pdf` honours the rule.
- **Conditional status-cell coloring (#227)** — HTML data tables apply `status-Healthy` / `status-Warning` / `status-Failed` CSS classes per recognized status token (Healthy/Succeeded/Connected/Running/Up/Enabled/Yes vs Warning/Updating/Degraded vs Failed/Critical/Disconnected).
- **Pricing footer with dated reference (#228)** — every Cost & Licensing section includes `pricingReference.asOfDate` and the official Azure Local pricing URL.

### Changed

- **Manifest schema bump to `1.2.0-draft`** to reflect the new domain shapes under `azureIntegration.arcExtensionsDetail`, `networking.logicalNetworks`, `storage.storagePaths`, `azureIntegration.costLicensing`, and `virtualMachines.summary.vmDistribution*`.

## [1.6.0] — 2026-04-16

### Added — Auth and Discovery

- **Auto-discover resource group (#196)** — `Resolve-RangerClusterArcResource` falls back to a subscription-wide ARM search by cluster name when `targets.azure.resourceGroup` is absent; the discovered RG is written back into the resolved config for downstream callers.
- **Auto-discover cluster FQDN (#197)** — new `Invoke-RangerAzureAutoDiscovery` runs before prompts and validation. Pulls the FQDN from Arc properties (`dnsName`, `reportedProperties.clusterId`, or `name + domainName`), or composes it from a resolved Arc domain. Eliminates the field-by-field prompt when Azure credentials are present.
- **Multi-method Azure auth chain (#200)** — `Connect-RangerAzureContext` now supports `service-principal-cert` (certificate thumbprint or PFX path with optional password), tenant-matching existing-context reuse (no re-auth when the loaded context already matches the requested tenant), and sovereign-cloud environment forwarding.
- **Save-AzContext handoff (#201)** — new `Export-RangerAzureContext` and `Import-RangerAzureContext` helpers. Runs save the Az session to a temp file for handoff into a background runspace that imports it as its first action; temp file is deleted by default after import.
- **Azure Resource Graph single-query (#205)** — new `Get-RangerArmResourcesByGraph` runs a single `Search-AzGraph` KQL query for a configurable list of resource types, scoped optionally to subscription / RG / management group. `Resolve-RangerArcMachinesForCluster` now uses Resource Graph as the fast path with `Get-AzResource` fallback when `Az.ResourceGraph` is absent.

### Added — Connectivity

- **WinRM TrustedHosts + DNS fallback (#203)** — new `Resolve-RangerClusterFqdn` and `Resolve-RangerNodeFqdn` implement a passthrough → TrustedHosts scan → DNS `GetHostEntry` chain. Wired into `Invoke-RangerAzureAutoDiscovery` so on-prem environments resolve FQDNs without Azure.
- **Node / VM cross-RG fallback (#204)** — new `Resolve-RangerArcMachinesForCluster` runs an RG-scoped Arc machines query first, then a subscription-wide fallback when nodes live outside the cluster RG. Emits a `warning` per cross-RG node and reports them via `CrossRg`.

### Added — Commands and UX

- **`Invoke-AzureLocalRanger -Wizard` (#211)** — inline `-Wizard` / `-OutputConfigPath` / `-SkipRun` parameters on the main command dispatch to `Invoke-RangerWizard`. Missing-input prompts now surface `Invoke-AzureLocalRanger -Wizard` as the recommended alternative to field-by-field prompting.
- **`Test-RangerPermissions` (#202)** — new public command. Checks Azure context, Subscription Reader, HCI cluster read, Arc machine read, Key Vault secret access (when `keyvault://` refs exist), and `Microsoft.AzureStackHCI` / `Microsoft.HybridCompute` provider registration. `-OutputFormat console|json|markdown`.
- **`-SkipPreCheck` (#212)** — the pre-run permission audit runs by default. Failed audit aborts with actionable remediation; partial emits a warning and continues. Skipped automatically in fixture mode. Opt out via `-SkipPreCheck` or `behavior.skipPreCheck: true`.
- **File-based progress IPC (#213)** — new `Write-RangerProgressState`, `Read-RangerProgressState`, and `Remove-RangerProgressState` write atomic JSON snapshots to `$env:TEMP\ranger-progress-<RunId>.json`. Path-traversal-safe `RunId` sanitisation. Foundation for background-runspace progress reporting.

### Added — Resilience

- **Graceful degradation on partial Azure permissions (#206)** — new `Get-RangerArmErrorCategory` classifier (Authorization / NetworkUnreachable / NotFound / Throttled / Other) plus a skipped-resources tracker. `Resolve-RangerClusterArcResource` and Resource Graph queries record skips with category + reason; `manifest.run.skippedResources` surfaces partial runs. A warning finding is added when any skip occurred. New `behavior.failOnPartialDiscovery` (default `false`) aborts the run at end-of-collection when set.

### Added — Output formats

- **Headless-browser PDF (#207)** — new `Resolve-RangerHeadlessBrowser` and `Invoke-RangerHeadlessPdf`; the `pdf` format renders the HTML report through `msedge --headless=new --print-to-pdf` for high-fidelity output. The existing plain-text PDF writer remains the fallback when no browser is found. Sample output sizes jumped from ~40 KB plain-text to 440–812 KB rendered HTML.
- **DOCX OOXML tables (#208)** — `section.type='table'`, `'kv'`, and `'sign-off'` now render as real Word tables with header styling, borders, and caption rows. Previously these section types rendered as empty paragraphs.
- **XLSX formula-injection safety (#209)** — cell values that begin with `=`, `+`, `-`, or `@` are apostrophe-prefixed so Excel treats them as literal text. Existing multi-tab workbook, frozen header, and auto-filter behaviour retained.
- **Power BI CSV + star-schema export (#210)** — new `Invoke-RangerPowerBiExport` produces `nodes.csv`, `volumes.csv`, `storage-pools.csv`, `health-checks.csv`, `network-adapters.csv`, `_relationships.json` (star-schema manifest), and `_metadata.json`. Added `powerbi` to supported `OutputFormats`. All CSV values sanitised against formula injection and embedded newlines.
- **Graduated WAF scoring (#214)** — `Invoke-RangerWafRuleEvaluation` now supports a `thresholds` array with graduated point awards, named `calculation` references (`min` / `max` / `avg` / `sum` / `count` / `pct` aggregates pre-computed from the manifest), and `{value}` message substitution. Existing `check`-style pass/fail rules remain unchanged. Pillar and overall scores now weight by `awardedPoints` / `maxPoints`.

## [1.5.0] — 2026-04-16

### Added

- **As-built document redesign (#193)** — The as-built mid-tier is now an Installation and Configuration Record with per-node configuration, network address allocation, storage configuration, Azure integration, identity and security records, a validation record, and a known-issues/deviations register. Deployment past-tense framing throughout; minimal-color formal styling. `samples/output/iic-as-built/` regenerated.
- **Mode differentiation (#194)** — as-built now uses distinct tier names ("Installation and Configuration Record", "Technical As-Built"), a CONFIDENTIAL classification banner, and a "Post-Deployment As-Built Package" subtitle. current-state retains "Management Summary", "Technical Deep-Dive", Health Status traffic lights, and an INTERNAL banner. Field engineers can tell the two deliverables apart at a glance.
- **HTML report quality (#192)** — Inline architecture diagrams embedded under a new Architecture Diagrams section. Data tables use fixed layout with constrained column widths. Findings render as severity-colored callout boxes. A print stylesheet ensures clean browser-to-PDF output. Sign-off tables have visible signature lines.

### Fixed

- **Wizard default formats (#195)** — Default report formats changed from `html,markdown,json,svg` (where `json` was invalid) to `html,markdown,docx,xlsx,pdf,svg`. The prompt label now lists the valid set so operators can reference it inline.
- **Key Vault DNS error handling (#198)** — DNS resolution failures against Key Vault now emit an actionable error naming the likely causes (VPN not connected, wrong KV name, private endpoint unreachable). When `behavior.promptForMissingCredentials: true`, Ranger falls back to `Get-Credential` rather than aborting the run.

## [1.4.2] — 2026-04-16

### Fixed

- **TRAILHEAD test configs** — Added `credentials.domain` section to both `tests/trailhead/configs/tplabs-current-state.yml` and `tplabs-as-built.yml`. Without this section the module fell back to `keyvault://kv-ranger/domain-read`, which does not exist in the tplabs environment.
- **TRAILHEAD test configs** — Added `svg` and `drawio` to `output.formats` in both tplabs configs. `Invoke-RangerOutputGeneration` only calls `Invoke-RangerDiagramGeneration` when `svg` or `drawio` appears in the normalised formats list; omitting them silently skipped all diagram output.
- **New-RangerFieldTestCycle.ps1** — Removed `SupportsShouldProcess` from `[CmdletBinding()]` to eliminate parameter conflict with previously explicit `[switch]$WhatIf`.
- **deploy-docs.yml** — Removed `release: [published]` trigger. GitHub Pages environment protection allows deployments only from `main`; release-tag triggers always failed the environment protection check.

### Validated

- **Operation TRAILHEAD v1.4.2** — Full 8-phase (P0-P7) field validation cycle completed against live tplabs-clus01 (4-node Dell AX-760, TierPoint Labs, Raleigh NC). All 7 collectors succeeded (hardware partial due to firmware Redfish limitation, gracefully handled). All output formats generated: HTML, Markdown, JSON, XLSX, PDF, 13×SVG, 13×draw.io (33 files total). as-built vs current-state differentiation confirmed. Wizard (`Invoke-RangerWizard`) guided config + run confirmed. Pester 76/76 passing. WAF Assessment rule engine scored 48% overall ("At Risk"), 11/23 rules passing.

## [1.4.1] — 2026-04-16

### Fixed

- **Invoke-RangerWizard interactive gate (#180)** — `Test-RangerInteractivePromptAvailable` previously checked `[Console]::IsInputRedirected`, which returns `true` in VS Code terminal and Windows Terminal even when a real user is present. Now gates on `[Environment]::UserInteractive` only. Two regression tests added to `Config.Tests.ps1`.

## [1.4.0] — 2026-04-16

### Added

- **Issue #168** — HTML report rebuild. `ConvertTo-RangerHtmlReport` now renders type-aware section content: `type='table'` sections use styled `<table>` elements, `type='kv'` uses a two-column key-value grid, `type='sign-off'` renders a formal handoff table with Implementation Engineer / Technical Reviewer / Customer Representative rows. New section data shapes added for Node Inventory, VM Inventory, Storage Pool Capacity, Physical Disk Inventory, Network Adapter Inventory, Event Log Summary, and Security Audit. `ConvertTo-RangerMarkdownReport` updated with equivalent type-aware rendering for table, kv, and sign-off sections.
- **Issue #140** — Diagram engine quality. `ConvertTo-RangerSvgDiagram` rebuilt with two-pass layout: first pass assigns positions, second renders group containers (color-coded background rects with labels) then nodes and cubic bezier edges. `ConvertTo-RangerDrawIoXml` rebuilt with swim-lane group containers, per-kind node styles (volume, disk, adapter, workload, policy, bmc, hardware, monitor, heat), and orthogonal edge style. Near-empty diagrams (< 1 non-root node) return `$null` and record a skipped artifact instead of writing an unusable file.
- **Issue #96** — PDF output. `Write-RangerPdfReport` now prepends a cover page with title, cluster name, mode, version, generated date, and confidentiality notice. `Get-RangerReportPlainTextLines` renders type-aware plain text for PDF: pipe-delimited tables, aligned key: value pairs, and sign-off placeholders.
- **Issue #94** — WAF Assessment integration. New optional collector `Invoke-RangerWafAssessmentCollector` queries Azure Advisor recommendations and maps them to WAF pillars (Reliability, Security, Cost Optimization, Operational Excellence, Performance Efficiency). New rule engine (`Invoke-RangerWafRuleEvaluation`) evaluates 23 manifest-path rules from `config/waf-rules.json` — rules do not require re-collection and can be re-evaluated from any saved manifest. WAF Scorecard table (management + technical tiers) and WAF Findings detail table (technical tier) added to report payload. New `wafAssessment` manifest domain and fixture file.

### Fixed

- **Invoke-RangerWizard interactive gate** — `Test-RangerInteractivePromptAvailable` previously checked `[Console]::IsInputRedirected`, which returns `true` in VS Code terminal, Windows Terminal, and similar hosts even when a real user is present. The check now uses only `[Environment]::UserInteractive`, which correctly distinguishes interactive users from CI runners, service accounts, and scheduled tasks. Two unit tests added to `Config.Tests.ps1` to prevent regression.

## [1.3.0] — 2026-04-16

### Added

- **Issue #171** — Full config parameter coverage. Every `behavior.*`, `output.*`, and `credentials.azure.*` config key is now a direct runtime parameter on `Invoke-AzureLocalRanger`; parameters take precedence over config file values via `Set-RangerStructuralOverrides`.
- **Issue #174** — First Run guide (`docs/operator/first-run.md`): six-step linear guide from install to output with no decisions.
- **Issue #175** — Wizard guide (`docs/operator/wizard-guide.md`): full `Invoke-RangerWizard` walkthrough with example inputs and generated YAML.
- **Issue #176** — Command reference scenarios: nine copy-paste examples and parameter precedence documentation added to `docs/operator/command-reference.md`.
- **Issue #177** — Configuration reference (`docs/operator/configuration-reference.md`): every config key with type, default, required/optional, and Key Vault syntax.
- **Issue #178** — Understanding output guide (`docs/operator/understanding-output.md`): output directory tree, role-based reading path, collector status interpretation.
- **Issue #179** — Discovery domain enhancements: all 10 domain pages now include example manifest data, common findings, partial status guidance, and domain dependencies.

## [1.2.0] — 2026-04-16

### Added

- **Issue #26** — Arc Run Command transport. `Invoke-AzureLocalRanger` now routes WinRM workloads through Azure Arc Run Command (`Invoke-AzConnectedMachineRunCommand`) when cluster nodes are unreachable on ports 5985/5986. New functions: `Invoke-RangerArcRunCommand`, `Test-RangerArcTransportAvailable`. Transport mode configured via `behavior.transport` (auto / winrm / arc). Falls back gracefully when `Az.ConnectedMachine` is absent. `Az.ConnectedMachine` added to `ExternalModuleDependencies`.
- **Issue #30** — Disconnected / semi-connected discovery. A pre-run connectivity matrix (`Get-RangerConnectivityMatrix`) probes all transport surfaces (cluster WinRM, Azure management plane, BMC HTTPS) and classifies posture as `connected`, `semi-connected`, or `disconnected`. Collectors whose transport is unreachable receive `status: skipped` instead of failing mid-run. Full matrix stored at `manifest.run.connectivity`. New `behavior.degradationMode` config key (graceful / strict). New file: `Modules/Private/70-Connectivity.ps1`.
- **Issue #76** — Spectre.Console TUI progress display. A live per-collector progress bar using `PwshSpectreConsole` renders during collection when the module is installed and the session is interactive. Falls back to `Write-Progress` automatically. Suppressed in CI and `Unattended` mode. New file: `Modules/Private/80-ProgressDisplay.ps1`. New `-ShowProgress` parameter on `Invoke-AzureLocalRanger`. New `output.showProgress` config key.
- **Issue #75** — Interactive configuration wizard. `Invoke-RangerWizard` walks through a guided question sequence (cluster, nodes, Azure IDs, credentials, output, scope), then offers to save the config as YAML, launch a run, or both. Available as a public exported command.

## [1.1.2] — 2026-04-15

### Fixed

- **Issue #160** — `Get-RangerManifestSchemaContract` rewritten to return an inline hashtable instead of reading a file path. Eliminates `FileNotFoundException` for PSGallery installs where `repo-management/` is not present.
- **Issue #161** — `Get-RangerToolVersion` helper added to `Modules/Core/10-Manifest.ps1`. `New-RangerManifest` now reads `toolVersion` dynamically from the loaded module version instead of the previously hardcoded `'1.1.0'` default parameter value.
- **Issue #162** — `Invoke-RangerRedfishRequest` now passes `-Label 'Invoke-RangerRedfishRequest' -Target $Uri` to `Invoke-RangerRetry`. Retry log entries for BMC/Redfish calls now carry actionable label and target URI instead of empty strings.
- **Issue #163** — `$DebugPreference = 'Continue'` removed from the `debug` log-level branch of `Initialize-RangerRuntime`. `$DebugPreference` is unconditionally set to `'SilentlyContinue'`, preventing thousands of MSAL and Az SDK internal debug lines from flooding output.
- **Issue #164** — Null entries filtered from the collector messages array via `Where-Object { $null -ne $_ }` in `Invoke-RangerCollector`. Prevents `null` entries from propagating into manifest `messages` arrays and HTML/Markdown report output.
- **Issue #165** — `Get-RangerRemoteCredentialCandidates` now appends domain credential before cluster credential. Domain admin has WinRM PSRemoting rights by default; the LCM cluster account typically does not, so domain-first ordering eliminates redundant auth retries.

### Added

- **Issues #166 and #167** — 20 Pester unit tests added at `tests/maproom/unit/Execution.Tests.ps1` covering all 9 v1.1.2 regression bugs (#157–#165). Trailhead field validation run against live tplabs cluster (4-node Dell AX-760, Raleigh NC) confirmed all 6 collectors succeeded with zero auth retries, schema valid, `toolVersion=1.1.2`.

## [1.1.1] — 2026-04-16

### Fixed

- `Test-AzureLocalRangerPrerequisites` now supports the documented no-config invocation path again. Running it with no arguments returns a structured prerequisite result and skips config-specific validation cleanly instead of throwing `Either ConfigPath or ConfigObject must be supplied.`

## [1.1.0] — 2026-04-15

### Added

- **Issue #36** — Offline network device config import via `domains.hints.networkDeviceConfigs` hints: Cisco NX-OS and IOS parser extracting VLANs, port-channels/LAGs, interfaces, and ACLs. New `switchConfig` and `firewallConfig` keys added to the `networking` manifest domain. New private module `Modules/Private/60-NetworkDeviceParser.ps1`. 7 new Pester tests in `tests/maproom/unit/NetworkDevice.Tests.ps1` including IIC NX-OS fixture at `tests/maproom/Fixtures/network-configs/switch-nxos-sample.txt`.
- **Issue #38** — As-built mode now produces differentiated report content: Document Control block, Installation Register, and Sign-Off table injected into each tier report when `mode = as-built`. New `Modules/Outputs/Templates/10-AsBuilt.ps1` with three template section functions. `Modules/Outputs/Templates/` added to module load path in `AzureLocalRanger.psm1`. 2 new simulation tests covering as-built document control and sign-off content.
- **Issue #37** — Full documentation audit: Manifest Sub-Domains tables added to all 8 domain pages that were missing them (`networking`, `cluster-and-node`, `storage`, `hardware`, `virtual-machines`, `management-tools`, `performance-baseline`, `oem-integration`). New contributor docs: `simulation-testing.md` (complete simulation framework guide, IIC canonical data standard, fixture regeneration), `template-authoring.md` (template system design, how to add new report sections). `contributor/getting-started.md` updated to remove deleted page references and reflect current implementation focus. MkDocs nav updated for new contributor pages.
- **Issues #123 and #124** — Unattended and repeatable discovery runs: `Invoke-AzureLocalRanger` now supports `-Unattended` and `-BaselineManifestPath`, writes `run-status.json`, emits `manifest/drift-report.json`, and includes scheduler-ready samples for Task Scheduler and GitHub Actions.
- **Issue #153** — Storage reserve and provisioning analysis: the storage collector now models raw, usable, used, free, reserve-target, and safe-allocatable capacity per pool, surfaces thin-provisioning exposure, and adds storage posture findings to the manifest and reports.
- **Issues #132 and #134** — Arc-backed guest intelligence: VM inventory now falls back to Arc network-profile IP data when Hyper-V guest IPs are unavailable, and Azure integration inventory now tracks Arc ESU eligibility and enrollment state for supported Windows Server guests.
- **Issues #118, #131, and #77** — Delivery guidance for the next phase: added the detailed technical runtime flow diagram, recorded the update-mode design, and completed the terminal TUI alternatives survey with `PwshSpectreConsole` selected as the preferred rich-terminal path.
- **Issue #139** — WinRM preflight validation: `Invoke-AzureLocalRanger` now probes all configured cluster targets (VIP + nodes) via TCP 5985/5986 and `Test-WSMan` before any collector runs, and throws immediately with a human-readable per-target error summary if any target is unreachable. `Test-AzureLocalRangerPrerequisites` includes the same per-target probe in its "Cluster WinRM connectivity" check. Probe results are cached per `(ComputerName, credential)` for the duration of the run so subsequent `Invoke-Command` calls do not re-probe. 2 new unit tests: successful probe cached on second call, WSMan authentication failure.
- **Issue #156** — Intelligent remoting credential selection for non-domain-joined runners: Ranger now probes authorization with current context, cluster credentials, and domain credentials in priority order, records the selected remote execution identity in `manifest.run.remoteExecution`, and falls back from `Get-AzKeyVaultSecret` to `az keyvault secret show` when Az PowerShell secret resolution is unavailable on the runner.

### Fixed

- **Issue #103** — `Export-AzureLocalRangerReport`: Added `-AsHashtable` to `ConvertFrom-Json` to correctly handle mixed-case JSON keys in live manifests; changed `$manifest.run.mode` to bracket access `$manifest['run']['mode']` for consistent hashtable compatibility.
- **Issue #105** — Workload/identity/Azure collector: Changed `Select-Object -ExpandProperty hostNode` to `ForEach-Object { $_['hostNode'] }` and `Group-Object -Property hostNode` to `Group-Object -Property { $_['hostNode'] }` to fix hashtable VM inventory property access producing incorrect `avgVmsPerNode` and always-empty `highestDensityNode`.
- **Issue #107** — Diagram generation: `Get-RangerSafeName` now accepts null/empty input (returns `'unnamed'`), SVG layout loop skips nodes with null/empty id, SVG edge loop skips edges with null/empty source or target. Prevents storage-architecture diagram crash when storage pool/CSV has no friendly name.
- **Issue #108** — `Test-RangerTargetConfigured`: Fixed `@($null).Count -gt 0` returning true when `targets.cluster` is absent; added explicit null check before testing for fqdn/nodes; node and endpoint lists filtered for null/empty entries before count check.
- **Issue #121** — v1.1.0 milestone-close validation: live `tplabs` validation now succeeds from the standard config path, including automatic BMC endpoint hydration from sibling `variables.yml` when `targets.bmc.endpoints` is omitted, and collectors now preserve actionable findings without downgrading an otherwise complete collection to `partial`.

### Changed

- `domains.hints.networkDeviceConfigs` added to `Get-RangerDefaultConfig` default hints structure
- `networking` domain reserved template now includes `switchConfig` and `firewallConfig` keys
- `networking` domain summary now includes `importedSwitchConfigCount` and `importedFirewallConfigCount` counts
- Report payloads now expose drift state, storage reserve headroom, safe allocatable capacity, Arc IP fallback usage, and Arc ESU enrollment summaries across HTML, Markdown, and Office exports.
- Fixture-backed storage snapshots are normalized through the same storage analysis pipeline as live data so reserve and posture math stay consistent across real and simulated runs.
- Tests: 18 → 27 → 28 → 41 → 42 total, including new runtime, drift detection, storage analysis, and workload/Azure collector coverage.
- CI (`validate.yml` and new `ci.yml`) now runs all 41 unit tests via `run-pester: true` and PSScriptAnalyzer via `run-psscriptanalyzer: true` on every PR and push to main. Previously tests were disabled in CI. `tests/maproom/integration/` (requires live cluster) is excluded from automated runs.

### Known Issues

- **Issue #106** — Unreachable cluster nodes are silently excluded from collection without emitting a manifest finding. Retry attempt count is not tracked in `manifest.run` metadata.
- **Issue #93** — Storage domain collection fails silently on some node configurations due to script block parsing errors for the `sofs` helper.

## [0.5.0] — 2026-04-07

### Added

- Full collector suite: topology/cluster, hardware (Dell/Redfish), storage/networking, workload/identity/Azure, monitoring, management/performance
- Manifest-first design with `audit-manifest.json`, schema contract (`manifest-schema.json` v1.1.0-draft), and runtime schema validation
- Three-tier report generation (executive, management, technical) in HTML and Markdown from cached manifest only
- 18-diagram catalog (6 baseline + 12 extended) with variant-aware selection rules and draw.io XML + SVG output
- Simulation testing framework: synthetic IIC 3-node fixture, `New-RangerSyntheticManifest.ps1`, `Test-RangerFromSyntheticManifest.ps1`
- 18 Pester tests passing: schema, degraded scenarios, cached outputs, end-to-end fixture, 7 simulation tests
- Azure authentication: existing-context, managed identity, device-code, service principal, Azure CLI fallback
- Key Vault credential resolution via `keyvault://` URI references in config
- `-OutputPath` parameter on `Invoke-AzureLocalRanger` for user-controlled export destination
- Public docs foundation under `docs/` with architecture, operator, contributor, outputs, and domain pages
- `New-AzureLocalRangerConfig`, `Export-AzureLocalRangerReport`, `Test-AzureLocalRangerPrerequisites` public commands

### Changed

- Version bumped from `0.2.0` to `0.5.0` to reflect substantial implementation completeness ahead of PSGallery `1.0.0` release
- Roadmap rewritten in versioned-milestone format (Current Release, Next Release, Post-v1 Backlog, Long-term Vision) aligned with Azure Scout pattern
- `docs/project/status.md` removed — current delivery state folded into roadmap Current Release section
- `docs/project/documentation-roadmap.md` removed — internal planning artifact no longer relevant for public docs
- `mkdocs.yml` nav updated to remove deleted pages

## [0.2.0]

### Added

- initial repository skeleton
- documentation structure for project vision, architecture, collectors, diagrams, reports, and contribution guidance
- MkDocs Material configuration and navigation tree
- placeholder implementation directories with `.gitkeep` files

### Changed

- aligned GitHub Actions workflows with repo-management standards and sibling Azure Local MkDocs repositories
- added standard GitHub support files for code ownership, pull request review, and release automation
- removed standalone MkDocs dependency file in favor of inline workflow dependency installation
- removed the completed repo restructure plan after its decisions were reflected in the live repository structure and docs
