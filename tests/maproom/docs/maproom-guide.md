# Operation MAPROOM Guide

## What MAPROOM Is

Operation MAPROOM is the offline synthetic and post-discovery testing solution for AzureLocalRanger.

MAPROOM exists so the project can validate features that depend on discovered data without having to perform live discovery every time. It is the place for testing work that starts after discovery-shaped data already exists.

Typical MAPROOM use cases include:

- report generation
- output rendering
- diagram generation
- cached-manifest workflows
- findings and formatting behavior
- schema-aligned synthetic manifest validation

## Why MAPROOM Exists

Live discovery is expensive and slow.

If every reporting or output change required a full live run, the project would waste time and lose repeatability. MAPROOM solves that by letting developers and maintainers work from fixtures and synthetic manifests instead of real infrastructure.

That makes it possible to:

- iterate on output features quickly
- validate rendering deterministically
- reproduce edge cases reliably
- test without Azure or WinRM access

## Relationship To TRAILHEAD

`TRAILHEAD` and `MAPROOM` are complementary, but they are not the same thing.

- `TRAILHEAD` is live field validation.
- `MAPROOM` is offline testing against synthetic or cached discovery data.

If the question is “does Ranger work against a real environment,” that belongs to `TRAILHEAD`.

If the question is “does the reporting or post-discovery behavior work when fed valid discovery-shaped data,” that belongs to `MAPROOM`.

## Folder Layout

```text
tests/
  maproom/
    Fixtures/
    unit/
    integration/
    scripts/
    docs/
    README.md
```

### `Fixtures/`

This directory holds committed offline test data.

It includes:

- per-domain collector fixtures
- degraded-state fixtures
- synthetic manifests
- offline network-device sample configs

These fixtures are the raw material for MAPROOM testing.

### `unit/`

This directory holds focused Pester unit tests.

Examples of what belongs here:

- config behavior tests
- output-generation tests
- parser tests
- synthetic simulation tests

### `integration/`

This directory holds fixture-backed integration tests.

These tests validate larger end-to-end slices without requiring live infrastructure.

### `scripts/`

This directory holds the main MAPROOM helpers.

- `New-RangerSyntheticManifest.ps1`
- `Test-RangerFromSyntheticManifest.ps1`

### `docs/`

This directory holds detailed MAPROOM documentation such as this guide.

## Main Scripts

### `New-RangerSyntheticManifest.ps1`

Purpose:

- generate a full synthetic manifest
- keep the synthetic fixture aligned with schema changes
- support render and report testing without live discovery

Example:

```powershell
.\tests\maproom\scripts\New-RangerSyntheticManifest.ps1
```

### `Test-RangerFromSyntheticManifest.ps1`

Purpose:

- render reports and diagrams from the synthetic manifest
- validate output behavior from cached discovery-shaped data
- optionally open rendered output for manual review

Example:

```powershell
.\tests\maproom\scripts\Test-RangerFromSyntheticManifest.ps1
```

## Running MAPROOM Tests

Run all offline unit tests:

```powershell
Invoke-Pester -Path .\tests\maproom\unit -Output Detailed
```

Run fixture-backed integration tests:

```powershell
Invoke-Pester -Path .\tests\maproom\integration -Output Detailed
```

Run simulation tests only:

```powershell
Invoke-Pester -Path .\tests\maproom\unit\Simulation.Tests.ps1 -Output Detailed
```

Generate the synthetic manifest:

```powershell
.\tests\maproom\scripts\New-RangerSyntheticManifest.ps1
```

Run the synthetic visual validation flow:

```powershell
.\tests\maproom\scripts\Test-RangerFromSyntheticManifest.ps1 -Open
```

## How MAPROOM Works

The basic flow is:

1. use committed fixtures or generate a synthetic manifest
2. feed that data into Ranger’s cached-manifest and output paths
3. validate rendered output, artifact sets, and behavior
4. iterate without paying the cost of live discovery

That makes MAPROOM the correct place for testing features that depend on discovery results but do not require discovery itself to be executed live every time.

## Typical Scenarios

MAPROOM is the right tool when:

- changing report layouts
- changing output formats
- validating diagram generation
- testing cached manifest behavior
- reproducing a rendering regression
- testing a bug fix in formatting, reporting, or packaging

MAPROOM is not the right tool when:

- validating live remoting behavior
- validating Azure authentication against real endpoints
- validating cluster connectivity or runtime execution against live infrastructure

Those belong to `TRAILHEAD`.

## Fixture Discipline

Fixtures must stay:

- deterministic
- non-secret
- schema-valid
- reusable

Do not drop ad hoc scratch files or live-captured sensitive data into MAPROOM.

## Synthetic Data Standard

Synthetic data follows the IIC standard used by AzureLocal project testing.

That keeps fictional data consistent and prevents the repo from accumulating random fake-company naming conventions.

## Summary

`MAPROOM` is where AzureLocalRanger tests behavior that depends on already-discovered data.

It exists so the team can test reporting, rendering, packaging, and other post-discovery capabilities quickly, repeatedly, and without a live environment.
