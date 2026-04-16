# Project Status

## Current Release Track — v1.4.1

AzureLocalRanger v1.4.1 is the current release — patch fixing `Invoke-RangerWizard` in VS Code and Windows Terminal. It delivers handoff-quality HTML reports with type-aware table rendering, improved SVG and draw.io diagram output, PDF cover pages, and WAF Assessment integration with an external rule engine.

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
| Pester test suite | ✅ 74 tests passing |
| Field validation (TRAILHEAD) | ✅ v1.1.2 gate closed — all 6 collectors succeeded, zero auth retries |
| Report output (HTML/Markdown/JSON/DOCX/XLSX/PDF) | ✅ Complete |
| Diagram output (SVG/draw.io) | ✅ Complete |
| PSGallery release | ✅ `1.4.0` current on PSGallery |
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
