# Changelog

The primary changelog for the repository lives at the root in `CHANGELOG.md`, but the main milestones are summarised here for docs readers.

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
