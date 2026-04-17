# Project Status

## Current Release Track — v2.0.0

AzureLocalRanger v2.0.0 — Extended Collectors & WAF Intelligence — is the current release. It lands seven new Arc-surface collectors (per-node extensions, logical networks + subnets, storage paths, custom locations, Arc Resource Bridge, Arc Gateway, marketplace + custom images), Azure Hybrid Benefit cost and savings analysis with dated pricing footer, VM distribution balance via coefficient-of-variation, Arc agent + OS version grouping with drift detection, weighted WAF scoring (rule weight 1–3 + warning-as-half-weight + score thresholds), hot-swap WAF config via `Export-RangerWafConfig` / `Import-RangerWafConfig`, a `json-evidence` raw-inventory output format, concurrent-collection and empty-data reliability guards, automatic required-module install/update on startup, portrait/landscape PDF switching, and conditional status-cell coloring across all tables. v1.6.0 — Platform Intelligence — remains the previous release.

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
| Pester test suite | ✅ 104 tests passing (76 baseline + 28 v2.0.0) |
| Field validation (TRAILHEAD) | ✅ v1.4.2 gate closed — all 7 collectors, 76/76 Pester, 33-file output, WAF rule engine confirmed. v1.5.0 is a doc-quality stabilisation on the same engine |
| As-built document redesign | ✅ Complete — Installation and Configuration Record with per-node/network/storage/Azure/identity/validation/deviations records (#193) |
| Mode differentiation (as-built vs current-state) | ✅ Complete — distinct tier titles, classification banners, subtitles, mode-specific section suppression (#194) |
| HTML report visual quality | ✅ Complete — inline architecture diagrams, fixed-layout tables, severity callouts, print CSS, sign-off signature lines (#192) |
| Report output (HTML/Markdown/JSON/DOCX/XLSX/PDF) | ✅ Complete |
| Diagram output (SVG/draw.io) | ✅ Complete |
| PSGallery release | ✅ `1.6.0` on PSGallery; `2.0.0` ready for publish |
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
