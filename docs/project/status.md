# Project Status

## Current Release Track — v1.1.0

AzureLocalRanger v1.1.0 is complete in this repository. Milestone-close validation succeeded, the v1.1.0 milestone is closed, and the next release track now moves to post-v1.1 feature delivery.

```powershell
Import-Module .\AzureLocalRanger.psd1 -Force
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
| Pester test suite | ✅ 31 focused milestone-close tests passing |
| Field validation (TRAILHEAD) | ✅ v1.1.0 gate closed on live tplabs validation |
| Report output (HTML/Markdown/JSON/DOCX/XLSX/PDF) | ✅ Complete |
| Diagram output (SVG/draw.io) | ✅ Complete |
| PSGallery release | 🔄 Publication workflow remains separate from milestone-close validation |
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
