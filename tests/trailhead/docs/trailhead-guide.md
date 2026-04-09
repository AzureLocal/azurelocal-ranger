# Operation TRAILHEAD Guide

## What TRAILHEAD Is

Operation TRAILHEAD is the live field-validation solution for AzureLocalRanger.

It exists to prove Ranger against a real Azure Local environment instead of only against fixtures or synthetic manifests.

TRAILHEAD provides one place for:

- live test-cycle methodology
- run scripts
- committed run logs
- milestone-close validation evidence

TRAILHEAD is intentionally separate from `MAPROOM`, which is the offline synthetic and post-discovery testing solution under `tests/maproom/`.

## Why It Exists

Ranger needs real-environment validation so remoting, credential resolution, output generation, packaging, and operator workflows are tested against actual Azure Local estates.

Without TRAILHEAD, the project ships false confidence because fixture-only tests do not catch environment-specific failures such as:

- WinRM behavior differences
- CIM and PowerShell remoting edge cases
- Azure auth and context issues
- runtime packaging defects
- log and artifact behavior under real execution

## Folder Layout

Current TRAILHEAD structure:

```text
tests/
  trailhead/
    scripts/
    logs/
    docs/
    field-testing.md
    README.md
```

### `scripts/`

Purpose: live TRAILHEAD execution helpers.

These scripts support the live testing workflow, including:

- creating GitHub milestone and phase issue cycles
- starting a TRAILHEAD run
- appending structured run-log entries
- closing out a run with a summary

### `logs/`

Purpose: committed run logs from live validation.

This folder should contain logs. Nothing more. No general docs, no helper notes, no planning content.

Each log is an auditable record of a TRAILHEAD execution session.

### `docs/`

Purpose: detailed documentation for the TRAILHEAD live-validation solution.

This folder is where longer-form explanatory documentation belongs when it is specifically about testing structure, testing workflow, and testing governance.

### `field-testing.md`

Purpose: the formal live field-validation methodology.

This is the operational definition of the live TRAILHEAD cycle and its pass criteria.

### `README.md`

Purpose: short index for the TRAILHEAD area.

This should stay concise and point readers to the detailed docs and workflow files.

## Baseline Before TRAILHEAD

TRAILHEAD is the live lane.

The offline lane is `MAPROOM` under `tests/maproom/`.

Typical baseline commands before a live run:

```powershell
Invoke-Pester -Path .\tests -Output Detailed
```

```powershell
Invoke-Pester -Path .\tests\maproom\unit -Output Detailed
```

```powershell
Invoke-Pester -Path .\tests\maproom\unit\Simulation.Tests.ps1 -Output Detailed
```

## Live Field Validation

This lane is used when the code must be proven against a real Azure Local environment.

Characteristics:

- uses actual environment access
- validates remoting and runtime behavior
- validates packaging and output generation under real conditions
- supports milestone and release exit decisions

This lane includes:

- `tests/trailhead/field-testing.md`
- `tests/trailhead/scripts/`
- `tests/trailhead/logs/`

## Phase Model

The live TRAILHEAD cycle is organized as phases `P0` through `P7`.

### `P0` Preflight

Validate that the execution machine, module, prerequisites, and baseline environment are ready.

Typical checks:

- PowerShell version
- module import
- Pester baseline
- required modules present
- Azure context present
- prerequisite validator success

### `P1` Authentication and Credentials

Validate secret resolution and credential behavior before live collector work begins.

Typical checks:

- Azure auth behavior
- Key Vault resolution
- cluster credential validity
- BMC credential validity where applicable

### `P2` Connectivity and Remote Execution

Validate the transports and remote execution paths Ranger relies on.

Typical checks:

- WinRM
- Redfish where relevant
- Azure query connectivity
- DNS correctness
- retry behavior

### `P3` Individual Collector Tests

Run collectors in isolation against the live environment and validate payload shape and basic completeness.

### `P4` Data Quality and Accuracy

Cross-check collected data against known values in the environment.

### `P5` Reporting and Diagrams

Validate that artifacts are rendered correctly and that expected outputs are present.

### `P6` End-to-End Scenarios

Run realistic end-to-end execution scenarios, including degraded or partial conditions where required.

### `P7` Regression and Sign-Off

Close the validation loop, record remaining risks, and support milestone sign-off.

## When To Use TRAILHEAD

Use TRAILHEAD:

- before minor and major releases
- after significant runtime, auth, remoting, manifest, or rendering changes
- when validating against a new environment type
- when milestone exit depends on real-environment confidence

Use MAPROOM instead:

- for normal development
- when changing collectors or outputs against fixtures
- when validating regressions quickly
- when testing report and diagram behavior from cached or synthetic manifests

## Relationship To Milestone Gates

TRAILHEAD is part of release discipline.

For delivery milestones, the expected pattern is:

1. finish in-scope code work
2. run the offline Pester baseline
3. run the required TRAILHEAD live phases
4. record results in a gate issue
5. close the milestone only after validation is recorded or explicitly waived

The issue template at `.github/ISSUE_TEMPLATE/trailhead_milestone_gate.md` is the milestone-close control point.

## Main Scripts

### `tests/trailhead/scripts/New-RangerFieldTestCycle.ps1`

Purpose: create the GitHub milestone and phase issues for a new TRAILHEAD cycle.

Use it when starting a fresh versioned validation cycle.

Example:

```powershell
.\tests\trailhead\scripts\New-RangerFieldTestCycle.ps1 `
  -Version "1.0.0" `
  -Environment "tplabs-clus01 (4-node Dell, TierPoint Labs)"
```

### `tests/trailhead/scripts/Start-TrailheadRun.ps1`

Purpose: start a live run and create the markdown run log plus live GitHub issue feed.

Example:

```powershell
.\tests\trailhead\scripts\Start-TrailheadRun.ps1 -Version "1.0.0" -Environment "tplabs" -Phase 0
```

### `tests/trailhead/scripts/TrailheadLog-Helpers.ps1`

Purpose: append structured log records during a live run.

Example:

```powershell
. .\tests\trailhead\scripts\TrailheadLog-Helpers.ps1

Write-THPhase "P0 — Preflight"
Write-THPass  "P0.1" "PowerShell 7 present"
Write-THFail  "P2.1" "WinRM to node 01 failed"
Write-THFix   "P2.1" "Corrected TrustedHosts entry"
Write-THPass  "P2.1" "Retry succeeded"
Close-THRun -Passed 8 -Failed 0
```

## Relationship To MAPROOM

MAPROOM is where offline synthetic and post-discovery testing lives.

If the question is whether Ranger works from fixture-backed or synthetic discovery-shaped data, use MAPROOM.

If the question is whether Ranger works against a real environment, use TRAILHEAD.

## Fixture Standard

Synthetic and offline test data follows the IIC canonical standard in MAPROOM.

That means fictional test data should use:

- Infinite Improbability Corp
- `iic.local`
- `IMPROBABLE`
- `improbability.cloud`

The point is consistency. Test data should not drift between random fictional organizations.

## What Does Not Belong In TRAILHEAD

The testing solution should not become a dumping ground.

These do not belong here:

- repo-governance plans that are not about testing
- offline fixtures and synthetic manifests
- fixture-backed unit and integration tests
- unrelated design notes
- personal scratch files
- secrets
- real environment exports with sensitive material

Those belong elsewhere or not in the repo at all.

## What Does Not Belong In `repo-management/`

The converse is also important.

These testing assets should not live in `repo-management/`:

- test scripts
- run logs
- live validation workflow assets

If it is part of how Ranger is tested, it belongs under `tests/` in either `trailhead/` or `maproom/`.

## Recommended Contributor Workflow

### For normal development

1. make the code change
2. run relevant unit or integration tests
3. run the full Pester suite if the change is broad enough
4. update MAPROOM fixtures or synthetic tooling if schema or output expectations changed

### For output and report work

1. run Pester output tests
2. run the MAPROOM synthetic visual runner
3. inspect generated outputs manually if needed

### For release or milestone-close work

1. run the baseline Pester suite
2. create or update the TRAILHEAD gate issue
3. execute the required live phases
4. record results in `tests/trailhead/logs/`
5. close out the gate only when evidence is complete

## Expected Artifacts

TRAILHEAD produces live-validation artifacts such as:

- GitHub milestone and phase issues
- run log markdown files
- issue comments attached during execution
- produced Ranger packages and report paths recorded in the run evidence

## Naming and Discipline

Keep names explicit and boring.

Examples:

- `run-YYYYMMDD-HHMM.md`
- `Simulation.Tests.ps1`
- `EndToEnd.Tests.ps1`
- `New-RangerFieldTestCycle.ps1`

Avoid vague names, throwaway scratch files, or personal conventions.

## Summary

TRAILHEAD is the single home for Ranger live field validation.

Use it to keep live execution methodology, live scripts, logs, and milestone evidence out of `repo-management/` and separate from MAPROOM offline testing.

That is the point of the structure.
