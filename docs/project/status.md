# Project Status

## Current Release Track — v1.5.0

AzureLocalRanger v1.5.0 — Document Quality — is the current release. It lands the as-built document redesign (Installation and Configuration Record with per-node, network, storage, Azure, identity, validation, and deviations records), distinct mode differentiation (CONFIDENTIAL as-built vs INTERNAL current-state), inline architecture diagrams in HTML, fixed-layout tables, severity-coloured finding callouts, print CSS, and two priority bug fixes (wizard format defaults, Key Vault DNS graceful fallback). v1.4.2 was field-validated against a live tplabs-clus01 cluster via Operation TRAILHEAD; v1.5.0 is a stabilisation release on that foundation.

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
| Pester test suite | ✅ 76 tests passing |
| Field validation (TRAILHEAD) | ✅ v1.4.2 gate closed — all 7 collectors, 76/76 Pester, 33-file output, WAF rule engine confirmed. v1.5.0 is a doc-quality stabilisation on the same engine |
| As-built document redesign | ✅ Complete — Installation and Configuration Record with per-node/network/storage/Azure/identity/validation/deviations records (#193) |
| Mode differentiation (as-built vs current-state) | ✅ Complete — distinct tier titles, classification banners, subtitles, mode-specific section suppression (#194) |
| HTML report visual quality | ✅ Complete — inline architecture diagrams, fixed-layout tables, severity callouts, print CSS, sign-off signature lines (#192) |
| Report output (HTML/Markdown/JSON/DOCX/XLSX/PDF) | ✅ Complete |
| Diagram output (SVG/draw.io) | ✅ Complete |
| PSGallery release | 🟡 `1.4.2` current on PSGallery; `1.5.0` ready for publish |
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
