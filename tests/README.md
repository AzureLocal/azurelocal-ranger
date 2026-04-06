# Tests

This directory contains all testing assets for Azure Local Ranger: unit tests, integration tests, fixture data, a simulation framework, and helper scripts.

All tests run with Pester 5. No live Azure or WinRM connections are required.

## Directory Layout

```
tests/
  Fixtures/                         pre-built JSON fixtures for unit and simulation tests
  unit/                             Pester unit tests
  integration/                      Pester integration tests (fixture-backed, no live connections)
  New-RangerSyntheticManifest.ps1   generator that builds the IIC synthetic manifest from scratch
  Test-RangerFromSyntheticManifest.ps1  standalone manual runner for visual inspection
```

## Running Tests

Run all tests from the repo root:

```powershell
Invoke-Pester -Path .\tests -Output Detailed
```

Run only unit tests:

```powershell
Invoke-Pester -Path .\tests\unit -Output Detailed
```

Run a specific test file:

```powershell
Invoke-Pester -Path .\tests\unit\Simulation.Tests.ps1 -Output Detailed
```

Current passing count: **18/18**.

## Test Files

| File | Purpose |
|---|---|
| `unit/Config.Tests.ps1` | Module config, schema defaults, and reserved template structure |
| `unit/Runtime.Tests.ps1` | Runtime pipeline, manifest load, schema validation, and collector invocation |
| `unit/Outputs.Tests.ps1` | Report and diagram generation from pre-built domain fixtures |
| `unit/Simulation.Tests.ps1` | Full render pipeline driven from the IIC synthetic manifest |
| `integration/` | End-to-end package generation and degraded-scenario tests |

## Fixtures

Fixtures are pre-built JSON files that stand in for live discovery output. Tests load fixtures instead of connecting to real clusters or Azure.

| Fixture | Covers |
|---|---|
| `hardware.json` | Hardware collector payload — Dell PowerEdge nodes with NVMe disks |
| `topology-cluster.json` | Cluster and node topology payload |
| `storage-networking.json` | Storage and networking collector payload |
| `storage-networking-degraded.json` | Same domain with degraded posture signals for finding tests |
| `monitoring-observability.json` | Monitoring and observability collector payload |
| `management-performance.json` | Management tools and performance baseline payload |
| `management-performance-degraded.json` | Same domain with degraded posture signals |
| `workload-identity-azure.json` | Workload, identity, and Azure integration payload |
| `manifest-sample.json` | Minimal complete manifest used in schema validation tests |
| `synthetic-manifest.json` | Full 3-node IIC as-built manifest — see Simulation Framework below |

## Simulation Framework

The simulation framework validates the full Ranger render pipeline without any live connections. It is modeled on the Azure Scout testing pattern.

### Philosophy

Rather than mocking individual collector functions, the simulation framework builds a complete, semantically valid manifest from a pool of known fictional data, then runs the full `Export-AzureLocalRangerReport` pipeline against it. This catches rendering bugs, schema mismatches, and findings logic that unit mocks cannot.

### IIC Canonical Data Standard

All synthetic data follows the mandatory IIC (Infinite Improbability Corp) canonical standard. The IIC standard is the defined fictional company for all AzureLocal project test data.

| Attribute | Value |
|---|---|
| Company name | Infinite Improbability Corp |
| Abbreviation | IIC |
| Internal domain | `iic.local` |
| NetBIOS name | `IMPROBABLE` |
| Public domain | `improbability.cloud` |
| Entra tenant | `improbability.onmicrosoft.com` |
| Cluster name | `azlocal-iic-01` |
| Nodes | `azl-iic-n01`, `azl-iic-n02`, `azl-iic-n03` |
| Node IPs | `10.0.0.11–10.0.0.13` |
| iDRAC IPs | `10.245.64.11–10.245.64.13` |
| Hardware | Dell PowerEdge R760 |
| Tenant ID | `00000000-0000-0000-0000-000000000000` |
| Subscription ID | `33333333-3333-3333-3333-333333333333` |
| Resource group (compute) | `rg-iic-compute-01` |

Do not substitute tplabs, Contoso, or any other fictional company name for test data in this project. All test data must use IIC values.

### Synthetic Manifest

`tests/Fixtures/synthetic-manifest.json` is the pre-generated IIC manifest that the simulation tests load. It represents a healthy 3-node as-built deployment with:

- 3 nodes all in `Up` state
- 5 VMs (3 AVD pool members + 2 Arc VMs)
- 24 NVMe disks across 3 nodes
- Azure Monitor Agent on all 3 nodes
- DCR, DCE, and Log Analytics Workspace configured
- 1 certificate expiring within 60 days (triggers a Warning finding)
- 2 warning findings and 2 informational findings
- mode set to `as-built`

The fixture is committed to the repository so that simulation tests run without executing the generator.

### Regenerating the Fixture

If the manifest schema changes, regenerate the fixture by running:

```powershell
.\tests\New-RangerSyntheticManifest.ps1
```

Then commit `tests/Fixtures/synthetic-manifest.json`. The generator script documents its own data pools at the top of the file.

### Simulation Tests

`tests/unit/Simulation.Tests.ps1` contains 7 tests that run the full pipeline against the synthetic manifest:

| Test | What It Validates |
|---|---|
| Renders all 3 report tiers | Executive, Management, and Technical markdown files are produced |
| IIC cluster name in reports | `azlocal-iic-01` appears in the rendered output |
| Warning findings surfaced | Warning-level findings appear in executive and management reports |
| At least 5 diagrams in as-built mode | As-built renders a meaningful diagram set |
| `monitoring-telemetry-flow` diagram generated | Monitoring diagram artifact is present and status is `generated` |
| `workload-family-placement` diagram generated | Workload placement diagram artifact is present and status is `generated` |
| No error-state artifacts | No artifact in the result set carries `status = error` |

### Manual Visual Runner

`tests/Test-RangerFromSyntheticManifest.ps1` is a standalone script for manual inspection. It runs the full pipeline and optionally opens the output folder.

```powershell
# Run and print artifact summary
.\tests\Test-RangerFromSyntheticManifest.ps1

# Run and open output folder
.\tests\Test-RangerFromSyntheticManifest.ps1 -Open
```

Use this when you want to visually review a rendered report or diagram before committing a change to the render engine.

## Adding New Tests

- Place unit tests in `tests/unit/` using the `*.Tests.ps1` naming convention.
- Place integration tests in `tests/integration/`.
- Use `$TestDrive` (Pester's per-test temp path) for all output paths so tests remain isolated and clean.
- Use `-BeGreaterOrEqual` for numeric lower-bound assertions in Pester 5. The alias `-BeGreaterThanOrEqualTo` does not exist.
- Filter artifact records by `$_.relativePath` not `$_.name`. The artifact record object does not have a `name` property.
- All test data must use IIC canonical values. Do not introduce new fictional company names.

## Pester Version

Tests require Pester 5. Install or update with:

```powershell
Install-Module Pester -Force -SkipPublisherCheck
```

The minimum verified version is 5.7.1.
