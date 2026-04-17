# Project Status

## Current Release Track — v2.5.0

AzureLocalRanger v2.5.0 — Extended Platform Coverage — closes the long-standing operator backlog with workload/cost intelligence, multi-cluster orchestration, and presentation-ready output. Key additions: capacity headroom analyzer with per-node + cluster totals and Healthy/Warning/Critical status (#128); idle / underutilized VM detection with rightsizing proposals (#125); storage efficiency analysis surfacing dedup and thin-provisioning coverage (#126); SQL / Windows Server license inventory for compliance reporting (#127); `Invoke-AzureLocalRangerEstate` multi-cluster rollup with per-cluster + estate-level summary (#129); PowerPoint `.pptx` output format built directly via `System.IO.Packaging` with no Office dependency (#80); and `Import-RangerManualEvidence` for merging hand-collected evidence into the audit manifest with provenance labels (#32). v2.3.0 — Cloud Publishing — remains the previous release.

## Previous Release — v2.3.0 — Cloud Publishing

AzureLocalRanger v2.3.0 — Cloud Publishing — pushes Ranger run packages to Azure Blob Storage and streams distilled telemetry to Log Analytics Workspace after every run, with no code changes required if the runner has Storage Blob Data Contributor. Key additions: `Publish-RangerRun` command with Managed Identity / Entra RBAC / Key-Vault SAS auth chain and SHA-256 idempotency (#244); `_catalog/{cluster}/latest.json` + `_catalog/_index.json` catalog blobs updated per run (#245); cloud publishing guide + samples (#246); `RangerRun_CL` and `RangerFinding_CL` rows posted to a DCE/DCR pair via the Logs Ingestion API (#247). v2.2.0 — WAF Compliance Guidance — remains the previous release.

## Previous Release — v2.2.0 — WAF Compliance Guidance

AzureLocalRanger v2.2.0 — WAF Compliance Guidance — is the previous release. It turns the WAF score from a static grade into an actionable roadmap: every rule now carries a structured `remediation` block (rationale, steps, sample PowerShell, effort, impact, dependencies, docs URL — #236); a new Compliance Roadmap bucket ranks failing rules into Now / Next / Later tiers by `priorityScore = (weight × severity × impact) / effort` (#241); a Gap-to-Goal projection emits a greedy fix plan showing the projected score after closing the top N findings (#242); a per-pillar Compliance Checklist section ships a sign-able handoff artefact with one subsection per WAF pillar (#238); and a new public `Get-RangerRemediation` command emits copy-pasteable `.ps1` / markdown / checklist remediation scripts, substituting `$ClusterName` / `$ResourceGroup` / `$SubscriptionId` / `$Region` / `$NodeName` from the manifest with `-Commit` for live cmdlets (#243). v2.1.0 — Preflight Hardening — remains the previous release.

## Previous Release — v2.1.0 — Preflight Hardening

AzureLocalRanger v2.1.0 — Preflight Hardening — closes the three auth / preflight gaps identified against v2.0.0 so RBAC and credential problems surface up-front instead of mid-run: per-resource-type ARM probe (#235), deep WinRM CIM probe (#234), and an Azure Advisor read probe (#233). All three probes are skipped in fixture mode.

## Previous Release — v2.0.0 — Extended Collectors & WAF Intelligence

AzureLocalRanger v2.0.0 — Extended Collectors & WAF Intelligence — lands seven new Arc-surface collectors (per-node extensions, logical networks + subnets, storage paths, custom locations, Arc Resource Bridge, Arc Gateway, marketplace + custom images), Azure Hybrid Benefit cost and savings analysis with dated pricing footer, VM distribution balance via coefficient-of-variation, Arc agent + OS version grouping with drift detection, weighted WAF scoring (rule weight 1–3 + warning-as-half-weight + score thresholds), hot-swap WAF config via `Export-RangerWafConfig` / `Import-RangerWafConfig`, a `json-evidence` raw-inventory output format, concurrent-collection and empty-data reliability guards, automatic required-module install/update on startup, portrait/landscape PDF switching, and conditional status-cell coloring across all tables.

## Previous Release — v1.6.0 — Platform Intelligence

AzureLocalRanger v1.6.0 — Platform Intelligence — lands auto-discovery of resource group and cluster FQDN (from Azure Arc and from on-prem TrustedHosts / DNS fallbacks), a multi-method Azure auth chain (service-principal-cert, tenant-matching context reuse, sovereign-cloud), a dedicated pre-run permission audit (`Test-RangerPermissions` with `-SkipPreCheck` opt-out), cross-RG node fallback, Azure Resource Graph single-query discovery, graceful degradation on partial Azure permissions, file-based progress IPC for background runspaces, high-fidelity PDF rendering via headless Edge, DOCX OOXML tables, XLSX formula-injection safety, a Power BI CSV + star-schema export, and graduated WAF threshold scoring.

```powershell
Install-Module AzureLocalRanger -Force
Import-Module AzureLocalRanger
```

| Area | State |
| --- | --- |
| Module structure | ✅ Complete |
| Core orchestration | ✅ Complete |
| Identity collectors | ✅ Complete |
| Networking collectors | ✅ Complete |
| Storage collectors | ✅ Complete |
| Azure integration collectors | ✅ Complete |
| Hyper-V collectors | ✅ Complete |
| GPO collectors | ✅ Complete |
| Manifest assembly | ✅ Complete |
| Arc Run Command transport | ✅ Complete — auto/winrm/arc transport modes, Az.ConnectedMachine fallback |
| Disconnected discovery | ✅ Complete — pre-run connectivity matrix, graceful skip, posture classification |
| Spectre TUI progress | ✅ Complete — PwshSpectreConsole live bars, Write-Progress fallback, CI-safe |
| Interactive wizard | ✅ Complete — Invoke-RangerWizard guided config + run |
| Full config parameter coverage | ✅ Complete — every config key is a runtime parameter on Invoke-AzureLocalRanger |
| Operator guide docs | ✅ Complete — First Run, Wizard Guide, Configuration Reference, Understanding Output |
| HTML report rebuild | ✅ Complete — type-aware table/kv/sign-off rendering, inventory tables (#168) |
| Diagram engine quality | ✅ Complete — group containers, per-kind styles, SVG + draw.io (#140) |
| PDF output | ✅ Complete — cover page, type-aware plain-text sections (#96) |
| WAF Assessment integration | ✅ Complete — Azure Advisor + manifest rule engine, 23 built-in rules (#94) |
| Pester test suite | ✅ 129 tests passing (76 baseline + 28 v2.0.0 + 8 v2.1.0 + 17 v2.2.0) |
| Field validation (TRAILHEAD) | ✅ v1.4.2 gate closed — all 7 collectors, 76/76 Pester, 33-file output, WAF rule engine confirmed. v1.5.0 is a doc-quality stabilisation on the same engine |
| As-built document redesign | ✅ Complete — Installation and Configuration Record with per-node/network/storage/Azure/identity/validation/deviations records (#193) |
| Mode differentiation (as-built vs current-state) | ✅ Complete — distinct tier titles, classification banners, subtitles, mode-specific section suppression (#194) |
| HTML report visual quality | ✅ Complete — inline architecture diagrams, fixed-layout tables, severity callouts, print CSS, sign-off signature lines (#192) |
| Report output (HTML/Markdown/JSON/DOCX/XLSX/PDF) | ✅ Complete |
| Diagram output (SVG/draw.io) | ✅ Complete |
| PSGallery release | ✅ `2.1.0` on PSGallery; `2.2.0` ready for publish |
| Azure auto-discovery (RG + FQDN) | ✅ Complete — Arc-first with TrustedHosts / DNS on-prem fallback (#196, #197, #203) |
| Multi-method Azure auth chain | ✅ Complete — SPN cert, SPN secret, MI, device-code, existing-context with tenant-match reuse, sovereign-cloud env (#200) |
| Pre-run permission audit | ✅ Complete — `Test-RangerPermissions`, default-on with `-SkipPreCheck` opt-out (#202, #212) |
| Cross-RG node/VM fallback | ✅ Complete — Arc machines query with subscription-wide fallback (#204) |
| Azure Resource Graph fast path | ✅ Complete — `Search-AzGraph` single query with Get-AzResource fallback (#205) |
| Graceful ARM degradation | ✅ Complete — error classifier, skipped-resources tracker, `behavior.failOnPartialDiscovery` gate (#206) |
| Headless-browser PDF | ✅ Complete — Edge / Chrome `--print-to-pdf` with plain-text fallback (#207) |
| Word (DOCX) OOXML tables | ✅ Complete — `table` / `kv` / `sign-off` render as real Word tables (#208) |
| Power BI CSV + star-schema | ✅ Complete — nodes/volumes/pools/health-checks/adapters + `_relationships.json` (#210) |
| Graduated WAF scoring | ✅ Complete — threshold bands, named aggregate calculations (#214) |
| Arc-first node inventory | ✅ Complete |
| Domain auto-detection | ✅ Complete |
| Parameter-first input model | ✅ Complete |
| File-based logging | ✅ Complete |

## Operation TRAILHEAD

Field validation is structured as **Operation TRAILHEAD** — an eight-phase test cycle covering preflight, authentication, connectivity, individual collectors, data quality, reporting, and end-to-end scenarios. The gate issue remains the milestone-close checkpoint.

## Roadmap

See the [Roadmap](roadmap.md) for post-v1 work, including PowerPoint output, firewall collector expansion, and richer operator experiences.

## Changelog

See the [Changelog](changelog.md) for a full version history.
