# Project Status

## Current Release Track — v1.2.0

AzureLocalRanger v1.2.0 is the current release — the v1.2.0 UX & Transport milestone. It delivers Arc Run Command transport, disconnected/semi-connected discovery, Spectre.Console TUI progress display, and the interactive configuration wizard.

```powershell
Install-Module AzureLocalRanger -Force
Import-Module AzureLocalRanger
```

| Area | State |
|---|---|
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
| Pester test suite | ✅ 20 regression unit tests + 42 total tests passing |
| Field validation (TRAILHEAD) | ✅ v1.1.2 gate closed — all 6 collectors succeeded, zero auth retries |
| Report output (HTML/Markdown/JSON/DOCX/XLSX/PDF) | ✅ Complete |
| Diagram output (SVG/draw.io) | ✅ Complete |
| PSGallery release | ✅ `1.2.0` current on PSGallery |
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
