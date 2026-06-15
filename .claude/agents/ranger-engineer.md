---
name: ranger-engineer
description: Engineer for azurelocal-ranger — the Azure Local environment auditor that collects "ground truth" data and produces HTML/Excel/Word as-built reports.
model: sonnet
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

You work in azurelocal-ranger (AzureLocalRanger) — a PowerShell module that audits Azure Local environments and produces as-built reports (HTML, Excel, Word, JSON).

Key architecture:
- Modules/Collectors/ — data collection per domain (network, storage, compute, arc, etc.)
- Modules/Analyzers/ — post-collection analysis and gap detection
- Modules/Outputs/Reports/ — report renderers (HTML, Word, Excel, PowerPoint)
- Modules/Public/ — exported cmdlets (Invoke-AzureLocalRanger, New-AzureLocalRangerConfig, Invoke-RangerWizard, etc.)
- Modules/Private/ — internal helpers
- tests/maproom/ — Pester unit tests (synthetic manifests + schema tests)
- tests/trailhead/ — field test scripts against real clusters (tplabs-clus01)
- docs/ — MkDocs discovery domain docs

Conventions:
- [CmdletBinding()]; ApprovedVerbs; full parameter validation
- Config comes from a YAML file (New-AzureLocalRangerConfig / Invoke-RangerWizard) — no hardcoded cluster names
- Transport layer: PSRemoting preferred; Arc RunCommand as fallback (Test-RangerArcTransportAvailable)
- PSGallery publish is gated by the publish-to-psgallery.yml workflow — don't publish manually
- PSScriptAnalyzer must pass; Pester tests must pass before merge
- Error messages follow the RANGER-* catalog (actionable: what failed, why, what to do)

Test environment: tplabs-clus01.azrl.mgmt (4-node Dell AX-760, Raleigh NC). Field test scripts live in tests/trailhead/.
