# Project Status

## Current Release — v0.5.0

Azure Local Ranger is in active field validation. The core module structure, collector architecture, and documentation framework are all in place. Testing against a live Azure Local environment is in progress under **Operation TRAILHEAD**.

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
| Pester test suite | ✅ 29+ passing |
| Field validation (TRAILHEAD) | 🔄 In progress |
| Report output (HTML/CSV) | 🔄 In progress |
| Diagram output (SVG) | 🔄 In progress |
| PSGallery release | ⬜ Pending field sign-off |

## Operation TRAILHEAD

Field validation is structured as **Operation TRAILHEAD** — an eight-phase test cycle that covers preflight, authentication, connectivity, individual collectors, data quality, reporting, and end-to-end scenarios.

See the [testing methodology](https://github.com/AzureLocal/azurelocal-ranger/tree/main/repo-management/plans/field-testing.md) for the full plan.

## Roadmap

See the [Roadmap](roadmap.md) for what is planned after field validation completes, including PSGallery release, PowerPoint output, firewall collector, and Spectre.Console TUI enhancements.

## Changelog

See the [Changelog](changelog.md) for a full version history.
