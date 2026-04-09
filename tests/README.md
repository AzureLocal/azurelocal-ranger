# Tests

AzureLocalRanger testing is split into two named solutions:

- `tests/trailhead/` for live field validation
- `tests/maproom/` for offline synthetic and post-discovery testing

## Purpose

The test layout is intentionally split into one container and one real home:

- `tests/` is the repo-root entry point
- `tests/trailhead/` is the testing solution

That means testing assets should not be spread across unrelated repo areas, and they should not live in `repo-management/`.

## Named Solutions

### `TRAILHEAD`

`TRAILHEAD` is the live field-validation solution.

It holds:

- live test-cycle documentation
- run scripts
- committed run logs
- milestone-close execution evidence

### `MAPROOM`

`MAPROOM` is the offline synthetic and cached-discovery testing solution.

It holds:

- fixtures
- unit tests
- integration tests
- synthetic manifest tooling
- report and output validation workflows that do not require live discovery

## Layout

```text
tests/
  trailhead/
    scripts/
    logs/
    docs/
    field-testing.md
    README.md
  maproom/
    Fixtures/
    unit/
    integration/
    scripts/
    docs/
    README.md
```

## Folder Summary

- `tests/trailhead/scripts/` holds live TRAILHEAD workflow helpers.
- `tests/trailhead/logs/` holds committed TRAILHEAD run logs.
- `tests/trailhead/docs/` holds detailed TRAILHEAD documentation.
- `tests/trailhead/field-testing.md` defines the live field-testing methodology.
- `tests/maproom/Fixtures/` holds committed fixture data used by offline tests.
- `tests/maproom/unit/` holds Pester unit tests.
- `tests/maproom/integration/` holds fixture-backed integration tests.
- `tests/maproom/scripts/` holds synthetic manifest and offline render-validation scripts.
- `tests/maproom/docs/` holds detailed MAPROOM documentation.

## Running Tests

Run the full suite from the repo root:

```powershell
Invoke-Pester -Path .\tests -Output Detailed
```

Run unit tests only:

```powershell
Invoke-Pester -Path .\tests\maproom\unit -Output Detailed
```

Run integration tests only:

```powershell
Invoke-Pester -Path .\tests\maproom\integration -Output Detailed
```

Run the synthetic-manifest simulation test only:

```powershell
Invoke-Pester -Path .\tests\maproom\unit\Simulation.Tests.ps1 -Output Detailed
```

Run the synthetic visual inspection script:

```powershell
.\tests\maproom\scripts\Test-RangerFromSyntheticManifest.ps1
```

Generate or refresh the synthetic manifest fixture:

```powershell
.\tests\maproom\scripts\New-RangerSyntheticManifest.ps1
```

Start a live TRAILHEAD run:

```powershell
.\tests\trailhead\scripts\Start-TrailheadRun.ps1
```

## References

- `tests/trailhead/README.md`
- `tests/trailhead/field-testing.md`
- `tests/trailhead/docs/trailhead-guide.md`
- `tests/maproom/README.md`
- `tests/maproom/docs/maproom-guide.md`
- `tests/maproom/scripts/New-RangerSyntheticManifest.ps1`
- `tests/maproom/scripts/Test-RangerFromSyntheticManifest.ps1`
- `tests/trailhead/scripts/New-RangerFieldTestCycle.ps1`
- `tests/trailhead/scripts/Start-TrailheadRun.ps1`
