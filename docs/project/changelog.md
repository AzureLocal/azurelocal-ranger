# Changelog

The primary changelog for the repository lives at the root in `CHANGELOG.md`, but the main milestones are summarised here for docs readers.

## v2.6.5 — Credential UX & Discovery Hardening

15 first-run friction issues closed after live tplabs validation. Milestone: [#32](https://github.com/AzureLocal/azurelocal-ranger/milestone/32).

- **Credential prompt clarity (#302)** — `Get-Credential` title and message now name the target system (`tplabs-clus01 cluster WinRM`) and the expected account format (`DOMAIN\user` or `user@domain.com`). Same treatment for BMC, switch, and firewall paths.
- **WinRM silent-start preflight (#303)** — `Invoke-RangerEnsureWinRmRunning` starts the WinRM service silently at the start of every run, preventing Windows from throwing an interactive service-start consent dialog mid-collection.
- **Cluster / domain credential reuse (#304)** — when `credentials.domain` is unconfigured, Ranger reuses the cluster credential automatically. No second prompt for the same account.
- **Node FQDN resolver (#306)** — `Resolve-RangerNodeFqdn` implements a 4-step chain (pass-through → cluster-suffix → DNS → short-name fallback) for nodes whose FQDN is not provided by Arc.
- **Arc node FQDN extraction (#308)** — `Invoke-RangerAzureAutoDiscovery` pulls `properties.dnsFqdn` from each Arc machine resource into a `nodeFqdns` map; all per-node WinRM/CIM fan-out uses FQDNs, eliminating `0x8009030e` failures on non-domain-joined management machines.
- **Cluster selection UX (#309)** — auto-selection now prints the chosen cluster name and resource group. When multiple HCI clusters exist in the subscription, a numbered menu is shown. `-Unattended` still throws `RANGER-DISC-002` on multiples.
- **Azure-first discovery phase (#310)** — Azure discovery (cluster, node FQDNs, resource group, domain, Arc extensions, policy, Advisor) completes before any on-prem WinRM session opens, so collectors start with full context.
- **Node inventory FQDN overwrite fix (#311)** — `Resolve-RangerNodeInventory` resolves all Arc short names through `Resolve-RangerNodeFqdn` before returning, preventing the topology collector from overwriting FQDNs that auto-discovery already set.
- **BMC interactive prompt (#312)** — when no BMC endpoints are configured and the session is interactive, Ranger asks whether to include iDRAC/BMC collection. Answering yes collects endpoint IPs before the collector map is built, so the hardware collector enters scope before credential prompting fires.
- **LLDP passive reporting (#313)** — replaced the broken `MSNdis_NetworkLinkDescription` WMI class with `Get-NetLldpNeighbor` (Windows Server 2019+ / Azure Local). WMI retained as a fallback for older hosts.
- **`-NetworkDeviceConfigs` parameter (#314)** — exposes the `domains.hints.networkDeviceConfigs` Cisco NX-OS/IOS running-config import feature as a direct `-NetworkDeviceConfigs [string[]]` CLI parameter on `Invoke-AzureLocalRanger`.
- **`-NetworkDeviceConfigs` directory expansion (#315)** — when a directory path is supplied, `Set-RangerStructuralOverrides` recursively expands it to all `.txt`, `.cfg`, `.conf`, `.log` files inside. A warning fires if the directory contains no matching files.
- **Hardware collector auto-deselect (#316)** — `Resolve-RangerSelectedCollectors` no longer selects the hardware collector when `targets.bmc.endpoints` is empty. The misleading `skipped` log entry no longer appears on runs that simply have no BMC configured.
- **`tenantId` auto-filled from Az session (#317)** — `Invoke-RangerAzureAutoDiscovery` fills `targets.azure.tenantId` from `(Get-AzContext).Tenant.Id` after cluster auto-discovery succeeds. The tenantId prompt no longer fires when the Az session is already authenticated.
- **Log bootstrapping gap fixed (#318)** — `Write-RangerLog` now buffers entries to `$script:RangerPreLogBuffer` during the bootstrap phase (config load → structural overrides → auto-discovery → validation) before the output path is known. `Initialize-RangerFileLog` flushes the buffer filtered to the configured log level under a `# bootstrap phase` section header. Invocation parameters are logged as the first line of every run log.
- **Interactive run-mode prompt (#319)** — `Invoke-RangerDiscoveryRuntime` prompts for run mode (`current-state` / `as-built`) in interactive sessions when `-OutputMode` was not passed on the CLI. Defaults to the current config value; CI and `-Unattended` runs are unaffected.
- **`-Debug`/`-Verbose` elevate log file verbosity (#320)** — passing `-Debug` or `-Verbose` to `Invoke-AzureLocalRanger` now elevates `$script:RangerLogLevel` to `debug` before the Az SDK noise guard fires, so debug-level entries appear in `ranger.log` as any operator would expect. The bootstrap buffer (issue #318) now captures all entries without early level filtering, so bootstrap debug output is also preserved when these flags are set. Precedence: `-Debug`/`-Verbose` > `behavior.logLevel` in config > `info` default.
- **`-Debug`/`-Verbose` entries missing from terminal (#328)** — `Write-RangerLog` calls `Write-Verbose` for every entry, but PowerShell common-parameter preference variables only apply to the declaring function's scope and do not propagate into nested module functions. Even with the log file fix (#322), the running terminal showed only INFO entries. Fixed: `Invoke-AzureLocalRanger` sets `$script:RangerVerboseToConsole = $true` when `-Debug`/`-Verbose` is detected; `Write-RangerLog` forces `$VerbosePreference = 'Continue'` locally before each `Write-Verbose` call when the flag is active. Both log file and terminal now receive all entries at debug level.
- **BMC credential prompt ordering (#326)** — after entering BMC/iDRAC IPs at the interactive prompt, the operator was asked for the WinRM cluster credential before the BMC credential, breaking the natural context flow. The BMC credential is now prompted immediately after the IP entry and stored as a credential override; cluster and domain credentials follow after.
- **Interactive BMC prompt stores plain IP strings (#324)** — the `#312` prompt split comma-separated IPs into a plain string array and wrote them directly to `config.targets.bmc.endpoints` after normalization had already run. The hardware collector reads `$endpoint.host`, gets `$null` on a plain string, and skips every endpoint → "No usable BMC endpoints" thrown even when valid IPs were provided. Fixed: each IP is now wrapped as `[ordered]@{ host = ip; node = null }` at prompt time.
- **`-NetworkDeviceConfigs` paths stored as plain strings (#325)** — `Set-RangerStructuralOverrides` added resolved paths as plain strings after normalization, so the networking parser read `$hint.path` → `$null` on every entry and warned "missing path field" for all files. Fixed: each resolved path is now stored as `[ordered]@{ path = resolved }` matching the normalized shape.
- **`-Debug`/`-Verbose` log elevation — definitive fix (#322)** — the #320 approach read `$DebugPreference`/`$VerbosePreference` inside `Invoke-RangerDiscoveryRuntime`, which is unreliable because PowerShell common parameters set preference variables only in the declaring function's scope — they do not propagate into child modules. Detection moved to `$PSBoundParameters.ContainsKey('Debug')` / `.ContainsKey('Verbose')` in `Invoke-AzureLocalRanger` and injected as `LogLevel = 'debug'` through `Set-RangerStructuralOverrides` into `config.behavior.logLevel`. The runtime now reads that field directly with no preference-variable check.
- **Arc node discovery 'Argument types do not match' (#327)** — `Resolve-RangerArcMachinesForCluster` assigned `$subscriptionId` and `$clusterRg` from the config dict without explicit `[string]` casts. Values from YAML parsing arrived as PSCustomObject wrappers, causing `Get-AzResource -ResourceGroupName $clusterRg` to throw "Argument types do not match". Both variables now receive `[string]` casts at assignment — same fix pattern as #261.
- **BMC Redfish 401 Unauthorized on all nodes (#329)** — `Invoke-RangerRedfishRequest` called `Invoke-RestMethod` with `-Credential` but without `-Authentication Basic`. PowerShell 7 defaults to Negotiate (Kerberos/NTLM); iDRAC Redfish requires Basic auth and returns 401 without it. Added `-Authentication Basic` to the `Invoke-RestMethod` call.
- **Raw ordered hashtable printed to console after run (#330)** — `Invoke-AzureLocalRanger` called `Invoke-RangerDiscoveryRuntime` without capturing the return value, causing the full `Config`/`Manifest`/`ManifestPath`/`PackageRoot`/`LogPath` hashtable to auto-print to the terminal on every unassigned call. Return value is now captured; a clean `Write-Host` summary (collector outcome counts + output path + log path) is emitted instead.
- **WAF rule SEC-007 spurious terminal warning (#331)** — `Invoke-RangerWafAssessment` used `Write-Warning` for both (a) calculation key missing from the definitions dict (rule authoring error) and (b) calculation key defined but resolved to null because the manifest field is absent (normal — e.g. AMA not deployed). Case (b) now logs at debug level via `Write-RangerLog`; case (a) keeps the `Write-Warning` so genuine rule authoring errors remain visible.
- **External verbose output missing from ranger.log (#332)** — `Invoke-RangerDiscoveryRuntime` installed a `global:Write-Warning` proxy but no `global:Write-Verbose` proxy.
- **Hardware collector probes iDRAC IPs with WinRM (#333)** — when BMC endpoints are added via the interactive prompt with `node = null`, `$remoteNodeTarget` fell back to the BMC IP itself; `Invoke-RangerClusterCommand` then probed that IP with WinRM, producing 45-second TCP timeouts and warnings on every endpoint. `$hasWinRmTarget = $remoteNodeTarget -ne $bmcHost` is now evaluated after node resolution; the VBS / DeviceGuard / OMI sub-collection is skipped with a debug log entry when no real cluster node FQDN was matched. When running with `-Debug`/`-Verbose`, all `Write-Verbose` output from external modules (Invoke-RestMethod HTTP request/response tracing, PackageManagement, CIM operations, Az SDK) appeared in the terminal but never reached `ranger.log`. A `global:Write-Verbose` proxy is now installed alongside the warning proxy; it writes external verbose output to the log when `$script:RangerLogLevel -eq 'debug'`, skipping entries that already carry a Ranger timestamp to avoid duplicates. Restored in the `finally` block.
- **Imported switch/firewall config report sections missing (#334)** — `Invoke-AzureLocalRanger -NetworkDeviceConfigs` parsed switch and firewall configs into `manifest.domains.networking.switchConfig` and `manifest.domains.networking.firewallConfig` but no report section rendered the data. Added **Imported Switch Configurations** and **Imported Firewall Configurations** table sections to the technical report tier (HTML/DOCX/PDF), each showing filename, vendor, parse status, VLAN count, port-channel count, interface count, and ACL count. Sections are omitted when the respective arrays are empty.

## v2.6.4 — First-Run UX Patch

Patch release that completes v2.6.3's First-Run UX work. The v2.6.3 drop shipped with a structural-placeholder leak in the default config that blocked the advertised 2-field / zero-config invocation path — bare `Invoke-AzureLocalRanger` still threw on `environment.name`, `cluster.fqdn`, and `resourceGroup` even after the operator supplied subscription + tenant. Same bug class as v2.6.3 #292 (kv-ranger leak) but for structural fields.

- **Default config scaffold placeholders removed (#300)** — `Get-RangerDefaultConfig` no longer ships `'azlocal-prod-01'`, `'00000000-...'`, etc. for `environment.*`, `targets.cluster.*`, `targets.azure.*`, or `targets.bmc.endpoints`. The v2.6.3 cluster auto-select gate now fires correctly.
- **Interactive prompt re-runs auto-discovery between answers (#300)** — answering subscription + tenant at the first two prompts fires `Select-RangerCluster` on the next pass and auto-fills everything else from Arc.
- **Prompt order leads with Azure identifiers (#300)** — `Get-RangerMissingRequiredInputs` lists `subscriptionId` and `tenantId` first, so auto-discovery has a chance to fire before operators are asked to hand-type fields Ranger could have filled.
- **Fixture-mode bypass in `Test-RangerConfiguration` (#300)** — fixture-backed test runs no longer fail the required-target check.

## v2.6.3 — First-Run UX

- **Cluster node auto-discovery (#294)** — `Invoke-RangerAzureAutoDiscovery` populates `targets.cluster.nodes` from Arc cluster `properties.nodes` or a subscription Arc machines query; short names are promoted to FQDNs via the discovered domain suffix.
- **Three-field minimum invocation (#296)** — `Invoke-AzureLocalRanger -SubscriptionId x -TenantId y -ClusterName z` now runs with zero config file; `Import-RangerConfiguration` returns defaults when neither `-ConfigPath` nor `-ConfigObject` is supplied, and `environment.name` derives from `clusterName`.
- **Two-field cluster auto-select (#297)** — new `Select-RangerCluster` enumerates HCI clusters in the subscription. Single clusters auto-select; multiples prompt an interactive menu; `-Unattended` and non-interactive hosts fail fast with `RANGER-DISC-002`; zero clusters throws `RANGER-DISC-001`; permission failures throw `RANGER-AUTH-001`.
- **Scope-gated device credential prompting (#295)** — `Resolve-RangerCredentialMap` only prompts for BMC / switch / firewall credentials when the relevant collector is in scope AND a target list is populated. Explicit overrides still honored when the target list is empty.
- **Wizard overhaul (#291)** — `Invoke-RangerWizard` now covers all six Azure auth methods (existing-context, run-time prompt, service-principal, managed-identity, device-code, azure-cli), validates GUID fields inline, adds an optional BMC section and run-mode toggle, prints a review screen before save/run, prompts for overwrite on existing files, and writes YAML via `ConvertTo-RangerYaml` by default (fixing the prior JSON-in-.yml bug).
- **kv-ranger credential leak fix (#292)** — `Get-RangerDefaultConfig` no longer ships placeholder `keyvault://kv-ranger/*` password references. Missing credentials fall through to the interactive prompt instead of failing the pre-check against a vault the operator never configured.

## v2.6.2 — TRAILHEAD Bug Fixes (P7 Regression)

- **Config validator accepts pptx and json-evidence (#262)** — `Test-RangerConfiguration` now includes `pptx` and `json-evidence` in the supported output format list. Both formats were added in v2.5.0 but were missing from the whitelist, causing config validation to reject any config that referenced them.
- **New-AzureLocalRangerConfig YAML indentation fix (#263)** — `credentials.azure.method` and `behavior.promptForMissingRequired` in the generated YAML template now have correct indentation, preventing parse errors when the template is used as-is.

## v2.6.1 — TRAILHEAD Bug Fixes (P3 Live Validation)

- **Topology collector returns 0 nodes on partial WinRM failure (#259)** — `Invoke-RangerRemoteCommand` now executes each cluster node individually rather than batching all targets in one `Invoke-Command` call. A single-node Kerberos/Negotiate error (0x80090304) no longer aborts collection from healthy nodes.
- **licenseProfiles/default 404 causes transcript noise (#260)** — `Get-AzResource` for optional Arc license profiles now uses `-ErrorAction SilentlyContinue` so missing profiles are returned as `not-found` without being promoted to terminating errors.
- **Search-AzGraph 'Argument types do not match' (#261)** — `Get-RangerArmResourcesByGraph` now explicitly casts subscription and management-group arrays to `[string[]]`, fixing a type mismatch when subscription IDs originate from YAML parsing.

## v2.5.0 Highlights — Extended Platform Coverage

- **Capacity headroom (#128)** — `manifest.domains.capacityAnalysis` with per-node + cluster totals (vCPU/memory/storage/pool) and Healthy/Warning/Critical status per dimension.
- **Idle / underutilized VM detection (#125)** — `vmUtilization` domain classifies VMs from `vm.utilization` sidecar data (avg/peak CPU, avg memory) and emits rightsizing proposals (proposed vCPU, proposed memory) with aggregated potential freed-resource savings.
- **Storage efficiency (#126)** — `storageEfficiency` domain exposes dedup state, dedup ratio, saved GiB, thin-provisioning coverage, and a `wasteClass` tag (`over-provisioned`, `dedup-candidate`, `none`).
- **SQL / Windows Server license inventory (#127)** — `licenseInventory` domain lists guest-detected SQL instances (edition, version, core count, license model, AHB eligibility) and Windows Server instances with aggregated core totals.
- **Multi-cluster estate rollup (#129)** — `Invoke-AzureLocalRangerEstate` runs Ranger against every target in an estate config and emits `estate-rollup.json`, `estate-summary.html`, and `powerbi/estate-clusters.csv`.
- **PowerPoint output (#80)** — new `pptx` output format builds a 7-slide executive overview OOXML .pptx via `System.IO.Packaging`. No Office dependency.
- **Import-RangerManualEvidence (#32)** — merge hand-collected evidence (network inventory, firewall exports) into an existing manifest with provenance. `manifest.run.manualImports` tracks source, domain, and evidence file path.

## v2.3.0 Highlights — Cloud Publishing

- **Azure Blob publisher (#244)** — `Publish-RangerRun` uploads the run package (manifest, evidence, package-index, log, reports, powerbi) to a named storage account. Auth chain: Managed Identity → Entra RBAC → SAS from Key Vault. SHA-256 idempotency skips unchanged blobs. `Invoke-AzureLocalRanger -PublishToStorage` triggers automatically post-run.
- **Catalog + latest-pointer blobs (#245)** — writes `_catalog/{cluster}/latest.json` (overwritten per run) and merges `_catalog/_index.json` with ETag concurrency. Downstream consumers find the latest run without listing.
- **Cloud Publishing guide + samples (#246)** — `docs/operator/cloud-publishing.md` with RBAC setup, config examples, and troubleshooting. `samples/cloud-publishing/` with Bicep, KQL workbook, and Teams webhook starter files.
- **Log Analytics Workspace sink (#247)** — `Invoke-AzureLocalRanger -PublishToLogAnalytics` posts one `RangerRun_CL` record (scores, AHB, counts, cloud-publish status) and one `RangerFinding_CL` row per failing WAF rule to a DCE/DCR pair via the Logs Ingestion API.

## v2.2.0 Highlights — WAF Compliance Guidance

- **Structured remediation block per WAF rule (#236)** — every rule in `config/waf-rules.json` now carries a `remediation` block with `rationale`, `steps`, `samplePowerShell`, `estimatedEffort` (S/M/L), `estimatedImpact` (low/medium/high), `dependencies`, and `docsUrl`. Reports surface a new Next Step column in the Findings table and a full Remediation Detail section.
- **Prioritized WAF Compliance Roadmap (#241)** — `Invoke-RangerWafRuleEvaluation` now returns a `roadmap` array bucketing failing rules into Now / Next / Later tiers by `priorityScore = (weight × severity × impact) / effort`. Power BI export: `powerbi/waf-roadmap.csv`.
- **Gap-to-Goal projection (#242)** — greedy fix plan showing "current 67% → projected 82% by closing 3 findings". Honours rule dependencies so prerequisites fix first. Power BI export: `powerbi/waf-gap-to-goal.csv`.
- **Per-pillar compliance checklist section (#238)** — one subsection per WAF pillar with every rule, status, weight, effort, next step, and a signed-off column for handoff / sprint use. Power BI export: `powerbi/waf-checklist.csv`.
- **`Get-RangerRemediation` command (#243)** — new public command emits a copy-pasteable remediation script from an existing manifest. `-Format ps1|md|checklist`, `-Commit` for live cmdlets (dry-run by default), `-IncludeDependencies` to expand prerequisites. Substitutes `$ClusterName` / `$ResourceGroup` / `$SubscriptionId` / `$Region` / `$NodeName` from the manifest.

## v2.1.0 Highlights — Preflight Hardening

- **Per-resource-type ARM probe (#235)** — pre-run audit now probes each v2.0.0 collector surface (logicalNetworks, storageContainers, customLocations, appliances, gateways, marketplace + gallery images). Scoped Reader roles that would have 403'd mid-run now Fail in the pre-check with named surfaces.
- **Deep WinRM CIM probe (#234)** — `Invoke-RangerCimDepthProbe` issues a representative `Get-CimInstance` against `root/MSCluster`, `root/virtualization/v2`, and `root/Microsoft/Windows/Storage` so WMI / DCOM rights problems surface before collectors run. Result recorded in `manifest.run.remoteExecution.cimDepth`.
- **Azure Advisor read probe (#233)** — `Get-AzAdvisorRecommendation` is exercised during the pre-check; 403 downgrades readiness to `Partial` with an actionable finding naming the missing `Microsoft.Advisor/recommendations/read` permission.

## v2.0.0 Highlights — Extended Collectors & WAF Intelligence

- **Seven new Arc-surface collectors (#215-#221)** — per-node Arc extensions, logical networks + subnets, storage paths, custom locations, Arc Resource Bridge, Arc Gateway, marketplace + custom images. Each surfaces a new HTML/Markdown/DOCX section and XLSX tab, plus a Power BI CSV.
- **AHB cost + savings analysis (#222, #228)** — cluster-level `softwareAssuranceStatus` drives a per-core $10/month calculation, AHB adoption %, potential monthly savings, and a dated pricing footer referencing the official Azure Local pricing page.
- **VM distribution balance (#223)** — coefficient-of-variation analysis across nodes with warning/fail thresholds.
- **Agent + OS version grouping (#224)** — nodes grouped by Arc agent and OS version with drift status (latest, maxBehind).
- **Weighted WAF scoring (#225)** — rule `weight` field 1-3, warning severity counts as 0.5x weight, graduated threshold bands, Excellent/Good/Fair/Needs Improvement thresholds.
- **`Export-RangerWafConfig` / `Import-RangerWafConfig` (#226)** — download the active WAF config, edit it locally, and re-import with `-Validate` dry-run or `-Default` restore.
- **`json-evidence` output format (#229)** — raw resource-only JSON payload with `_metadata` envelope; excludes scoring and run metadata.
- **Concurrent + empty-data guards (#230)** — second invocation in the same session warns and returns; zero-node manifest throws an actionable error instead of empty reports.
- **Module auto-install on startup (#231)** — required Az.* modules installed or updated via `Install-Module` / `Update-Module`; `-SkipModuleUpdate` opt-out.
- **Portrait/landscape PDF + status coloring (#227)** — `@page landscape-pg` for wide tables (Arc extensions, subnets); HTML status cells auto-colored.

## v1.6.0 Highlights — Platform Intelligence

- **Auto-discovery (#196, #197, #203)** — resource group and cluster FQDN resolved from Azure Arc, then from on-prem TrustedHosts / DNS. Removes required prompts when credentials are present.
- **Multi-method Azure auth (#200, #201)** — service-principal certificate support, tenant-matching context reuse (no MFA re-prompt), sovereign-cloud environment forwarding, and `Save-AzContext` handoff helpers for background runspaces.
- **`Test-RangerPermissions` + `-SkipPreCheck` (#202, #212)** — dedicated pre-run RBAC and resource-provider audit runs by default; aborts on `Insufficient`, warns on `Partial`, skipped automatically in fixture mode.
- **Cross-RG node fallback (#204)** — Arc machines query with subscription-wide fallback and per-cross-RG warnings.
- **Azure Resource Graph fast path (#205)** — `Search-AzGraph` single-query discovery replaces per-type `Get-AzResource` loops; graceful fallback when `Az.ResourceGraph` is absent.
- **Graceful degradation (#206)** — ARM error classifier, `manifest.run.skippedResources` tracker, `behavior.failOnPartialDiscovery` config gate.
- **`-Wizard` inline (#211)** — `Invoke-AzureLocalRanger -Wizard` routes to the interactive wizard; prompt text surfaces it as the recommended alternative.
- **Progress IPC (#213)** — file-based `Write`/`Read`/`Remove-RangerProgressState` for background-runspace progress.
- **High-fidelity PDF (#207)** — headless Edge / Chrome renders the HTML report to PDF; plain-text fallback when no browser is available. Sample PDFs are now 10-20× larger and include full HTML formatting.
- **DOCX OOXML tables (#208)** — `section.type='table'`, `'kv'`, `'sign-off'` now render as real Word tables with header styling and borders.
- **XLSX formula-injection safety (#209)** — values starting with `=`, `+`, `-`, `@` are apostrophe-prefixed.
- **Power BI CSV + star-schema (#210)** — `powerbi` output format produces 5 flat CSVs plus `_relationships.json` and `_metadata.json` ready for Power BI Desktop / Fabric import.
- **Graduated WAF scoring (#214)** — threshold-banded point awards and named aggregate calculations.

## v1.5.0 Highlights — Document Quality

- **As-built document redesign (#193)** — new Installation and Configuration Record tier with per-node configuration, network address allocation, storage configuration, Azure integration, identity/security records, a validation record, and a known-issues/deviations register; deployment past-tense framing
- **Mode differentiation (#194)** — distinct tier titles per mode, CONFIDENTIAL vs INTERNAL classification banner, Post-Deployment As-Built Package vs Live Discovery Report subtitle, Health Status traffic lights and WAF scorecard suppressed in as-built
- **HTML report quality (#192)** — inline architecture diagrams, fixed-layout data tables with constrained column widths, severity-coloured finding callout boxes, print stylesheet, visible sign-off signature lines
- **Wizard default formats (#195)** — default changed from `html,markdown,json,svg` (invalid `json`) to `html,markdown,docx,xlsx,pdf,svg`; prompt label now lists the valid set
- **Key Vault DNS error handling (#198)** — actionable error on DNS failure naming likely causes; graceful fallback to `Get-Credential` when `behavior.promptForMissingCredentials: true`

## v1.4.2 Highlights

- **TRAILHEAD test configs** — added `credentials.domain` section and `svg`/`drawio` output formats to tplabs config files so the field test cycle produces diagram output
- **Field test cycle script** — removed `SupportsShouldProcess` from `New-RangerFieldTestCycle.ps1` to eliminate `-WhatIf` parameter conflict
- **Docs deploy workflow** — removed `release: [published]` trigger; GitHub Pages environment protection only permits deployments from `main`
- **Operation TRAILHEAD v1.4.2** — full 8-phase field validation against live tplabs-clus01 (4-node Dell AX-760) closed successfully; 76/76 Pester tests passing

## v1.4.1 Highlights

- **Wizard interactive gate (#180)** — `Test-RangerInteractivePromptAvailable` now gates on `[Environment]::UserInteractive` only; no longer falsely fails in VS Code terminal or Windows Terminal when a real user is present

## v1.4.0 Highlights

- **HTML report rebuild** — type-aware section rendering (table, kv-grid, sign-off) across all tiers; Node, VM, Storage Pool, Physical Disk, Network Adapter, Event Log, and Security Audit inventory tables
- **Diagram engine quality** — SVG and draw.io XML rebuilt with group containers, color-coded node fills, cubic bezier edges, and swim-lane containers; near-empty diagrams skip gracefully
- **PDF cover page** — title, cluster, mode, version, date, and confidentiality notice prepended to all PDF reports
- **WAF Assessment integration** — `Invoke-RangerWafRuleEvaluation` evaluates 23 manifest-path rules from `config/waf-rules.json`; WAF Scorecard and Findings tables added to management and technical report tiers

## v1.3.0 Highlights

- **Full config parameter coverage** — every config key is now a runtime parameter on `Invoke-AzureLocalRanger`; no config file needed for any run
- **First Run guide** — linear six-step beginner guide from install to output with no decisions
- **Wizard guide** — complete `Invoke-RangerWizard` walkthrough with example inputs and generated YAML
- **Configuration reference** — full table of every config key with type, default, and Key Vault syntax
- **Understanding output** — directory tree, role-based reading path, collector status interpretation
- **Command reference scenarios** — nine copy-paste examples covering every common use case
- **Discovery domain enhancements** — all 10 domain pages now include example manifest data, common findings, and partial status guidance

## v1.2.1 Highlights

- **Redfish 404 retry** — 4xx responses no longer trigger retries; `Invoke-RangerRetry` extended with `-ShouldRetry` scriptblock
- **Hardware partial status** — collector reports `partial` instead of `success` when Redfish endpoints return 404; warning finding added
- **ShowProgress default-on** — progress display enabled without any config key or switch; opt out with `output.showProgress: false`
- **Prerequisite output** — `Test-AzureLocalRangerPrerequisites` renders a colour-coded Pass/Warn/FAIL table; optional checks for `Az.ConnectedMachine` and `PwshSpectreConsole` added

## v1.2.0 Highlights

- **Arc Run Command transport** — WinRM workloads fall back to `Invoke-AzConnectedMachineRunCommand` when nodes are unreachable; `behavior.transport: auto/winrm/arc` controls the strategy
- **Disconnected / semi-connected discovery** — pre-run connectivity matrix classifies posture; unreachable collectors skip with `status: skipped` instead of failing; matrix stored in `manifest.run.connectivity`
- **Spectre.Console TUI progress** — live per-collector bars via `PwshSpectreConsole`; falls back to `Write-Progress`; `-ShowProgress` parameter and `output.showProgress` config key
- **Interactive wizard** — `Invoke-RangerWizard` guided setup: cluster, nodes, Azure IDs, credentials, output, scope; save to YAML, run immediately, or both

## v1.1.2 Highlights

- schema contract rewritten as inline data — no file-path dependency, PSGallery installs work correctly
- `toolVersion` in manifests now reflects the actually installed module version dynamically
- Redfish/BMC retry entries now carry label and target URI for actionable log output
- `DebugPreference` no longer set to `Continue` at debug log level — eliminates MSAL/Az SDK debug flood
- null entries filtered from collector message arrays — no more `null` in manifest or report output
- domain credential tried before cluster credential — eliminates redundant WinRM auth retries
- 20 Pester unit tests added covering all 9 regression bugs; Trailhead field validation closed on live tplabs

## v1.1.1 Highlights

- fixed the installed-module regression where `Test-AzureLocalRangerPrerequisites` threw when run with no config arguments
- restored the documented first-run flow for PSGallery users validating a runner before generating a config file

## v1.1.0 Highlights

- intelligent remoting credential selection and authorization preflight for non-domain-joined runners
- Key Vault credential fallback via Azure CLI when Az PowerShell secret resolution is unavailable
- automatic BMC endpoint hydration from sibling `variables.yml`
- collector status semantics aligned so advisory findings do not downgrade successful collection to `partial`
- live v1.1.0 milestone validation closed on `tplabs` with all 6 collectors successful

## Root Changelog

This documentation page exists so the public documentation site can link readers to the project history without duplicating version notes across two places.
