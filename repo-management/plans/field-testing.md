# Field Testing Methodology — Operation TRAILHEAD

This document describes the AzureLocalRanger field-testing methodology. A field-testing cycle is run
against a **real Azure Local environment** before any significant release to validate that live data
collection, credential resolution, connectivity, reporting, and edge-case handling all work against
actual infrastructure — not just fixture data.

## Codename

Each field-testing cycle uses the codename **Operation TRAILHEAD**.

> Rangers don't begin their work until they reach the trailhead — the point where real terrain starts.

## When to Run a Cycle

- Before every minor or major release (v0.x.0, v1.0.0, etc.)
- After significant changes to collectors, credential resolution, or output generation
- When validating Ranger against a new environment type for the first time

## Milestone Exit Policy

Every delivery milestone should have a corresponding **TRAILHEAD gate issue** before the milestone is closed.

- Create the issue from `.github/ISSUE_TEMPLATE/trailhead_milestone_gate.md`.
- Run `Invoke-Pester -Path .\tests` for the baseline regression check.
- Run a full P0-P7 cycle for milestones that affect live discovery, authentication, execution, rendering, packaging, or release automation.
- For narrower milestones, execute only the impacted TRAILHEAD phases and document any waived phases in the gate issue.
- Do not close the release milestone until the gate issue is closed or explicitly waived.

## What is NOT Tested

The following are **explicitly excluded** from all TRAILHEAD phases by default:

| Excluded | Reason |
|----------|--------|
| Firewalls | Opt-in only — requires `-IncludeNetworkDevices` (future feature) |
| Switches | Same |
| OpenGear / OOB console servers | Same |
| SOFS (Scale-Out File Server) | Only tested when the SOFS solution is actively deployed |
| Lighthouse | Not used in test environments |

## Starting a New Cycle

Use the `New-RangerFieldTestCycle.ps1` script to create a GitHub milestone and all 8 phase issues
in one command:

```powershell
cd E:\git\azurelocal-ranger
.\repo-management\scripts\New-RangerFieldTestCycle.ps1 `
    -Version "0.6.0" `
    -Environment "tplabs-clus01 (4-node Dell, TierPoint Labs)" `
    -DueDate "2026-06-30"
```

This creates:
- Milestone: `Operation TRAILHEAD — v0.6.0 Field Validation`
- Issues #P0–#P7, all labelled `type/infra`, `priority/high`, `solution/ranger`, assigned to the milestone

Use `-WhatIf` to preview without touching GitHub.

## Phase Summary

| Phase | Name | Gate |
|-------|------|------|
| P0 | Preflight | All environment checks pass |
| P1 | Authentication & Credentials | KV resolution + cluster/BMC auth |
| P2 | Connectivity & Remote Execution | WinRM, Redfish, Azure API |
| P3 | Individual Collector Live Tests | All 6 collectors run without terminating error |
| P4 | Data Quality & Accuracy | Collected data cross-validated against known values |
| P5 | Reporting & Diagrams | All output artifacts generated and valid |
| P6 | End-to-End Scenarios (7) | All scenarios reach a recorded outcome |
| P7 | Regression & Sign-off | Pester baseline holds; milestone closed |

## Test Environment Requirements

The execution host (machine running Ranger) must have:

- PowerShell 7.0+
- Az PowerShell module
- RSAT ActiveDirectory and GroupPolicy tools
- Network line-of-sight to cluster nodes (WinRM 5985), iDRACs (443), and Azure (443)
- Azure context authenticated to the correct subscription
- Key Vault access to resolve secrets

See `docs/prerequisites.md` (issue #79) when that document is complete.

## IIC Canonical Data Standard

All **Pester unit and integration tests** use the IIC (Infinite Improbability Corp) fictional company
as test data. Do not use tplabs, Contoso, or real environment data in Pester tests.

Field testing (TRAILHEAD) uses **real environment data** and is never committed to the repository.

## Recording Results

Each phase issue contains a markdown checklist. As tests are executed:

1. Check off passing items in the issue checklist
2. For any failure, open a new bug issue and link it to the phase issue with a comment
3. For any waived test, add a comment on the issue explaining the reason
4. Close the phase issue when all checkboxes are either checked, have a linked bug, or are documented as waived
5. Close the milestone when P7 is closed

## Repeating a Cycle

Run `New-RangerFieldTestCycle.ps1` again with the new version number. Previous cycle issues and
milestones are left closed for history — do not reuse them.

## Related

- Script: `repo-management/scripts/New-RangerFieldTestCycle.ps1`
- Prerequisites doc: `docs/prerequisites.md` (#79)
- Validate Ranger issue: #34
- PSGallery release issue: #81
