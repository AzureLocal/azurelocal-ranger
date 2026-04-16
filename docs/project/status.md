# Project Status

## Current Release Track — v1.1.2

AzureLocalRanger v1.1.2 is the current shipped patch release. It fixes 6 runtime regressions from v1.1.0/v1.1.1, adds 20 Pester unit tests covering all regression bugs, and closes the Trailhead field validation gate on the live tplabs cluster.

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
| Pester test suite | ✅ 20 regression unit tests + 42 total tests passing |
| Field validation (TRAILHEAD) | ✅ v1.1.2 gate closed — all 6 collectors succeeded, zero auth retries |
| Report output (HTML/Markdown/JSON/DOCX/XLSX/PDF) | ✅ Complete |
| Diagram output (SVG/draw.io) | ✅ Complete |
| PSGallery release | ✅ `1.1.2` current on PSGallery |
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
