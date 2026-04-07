# Simulation Testing

The simulation framework validates the full Ranger render pipeline without any live cluster or Azure connections.

It is the primary regression gate for output generation, report rendering, and diagram logic.

## Philosophy

Rather than mocking individual collector functions, the simulation framework builds a complete, semantically valid manifest from a pool of known fictional data and then runs the full `Export-AzureLocalRangerReport` pipeline against it.

This catches rendering bugs, schema mismatches, and findings logic that unit mocks cannot.

## IIC Canonical Data Standard

All synthetic test data follows the mandatory IIC (Infinite Improbability Corp) canonical standard. The IIC standard is the defined fictional company for all AzureLocal project test data.

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

Do not use tplabs, Contoso, or any other fictional company name in test data. All test data must use IIC values.

## Synthetic Manifest

`tests/Fixtures/synthetic-manifest.json` is the pre-generated IIC manifest the simulation tests load. It represents a healthy 3-node as-built deployment with:

- 3 nodes all in `Up` state
- 5 VMs (3 AVD pool members + 2 Arc VMs)
- 24 NVMe disks across 3 nodes
- Azure Monitor Agent on all 3 nodes
- DCR, DCE, and Log Analytics Workspace configured
- 1 certificate expiring within 60 days (triggers a Warning finding)
- 2 warning findings and 2 informational findings
- mode set to `as-built`

The fixture is committed to the repository so simulation tests run without executing the generator.

## Running Simulation Tests

```powershell
# Run simulation tests only
Invoke-Pester -Path .\tests\unit\Simulation.Tests.ps1 -Output Detailed

# Run all unit tests
Invoke-Pester -Path .\tests\unit -Output Detailed

# Run the full test suite
Invoke-Pester -Path .\tests -Output Detailed
```

## Manual Visual Runner

`tests/Test-RangerFromSyntheticManifest.ps1` runs the full pipeline and optionally opens the output folder for manual inspection.

```powershell
# Run and print artifact summary
.\tests\Test-RangerFromSyntheticManifest.ps1

# Run and open output folder in Explorer
.\tests\Test-RangerFromSyntheticManifest.ps1 -Open
```

Use this when you want to visually review a rendered report or diagram before committing changes to the render engine.

## Regenerating the Fixture

If the manifest schema changes (new domain keys, new required fields, schema version bump), regenerate the fixture:

```powershell
.\tests\New-RangerSyntheticManifest.ps1
```

Then commit `tests/Fixtures/synthetic-manifest.json`. The generator script documents its own data pools at the top of the file.

Regenerate the fixture when:

- you add new keys to `Get-RangerReservedDomainPayloads` in `01-Definitions.ps1`
- you bump the schema version in `Get-RangerManifestSchemaVersion`
- simulation tests fail with schema validation errors after a manifest model change
- you add a new collector domain that the existing fixture does not cover

## What Gets Tested

`tests/unit/Simulation.Tests.ps1` contains tests that validate the full pipeline:

| Test | What It Validates |
|---|---|
| Renders all 3 report tiers | Executive, Management, and Technical markdown files are produced |
| IIC cluster name in reports | `azlocal-iic-01` appears in the rendered output |
| Warning findings surfaced | Warning-level findings appear in executive and management reports |
| At least 5 diagrams in as-built mode | As-built renders a meaningful diagram set |
| `monitoring-telemetry-flow` diagram generated | Monitoring diagram artifact is present |
| `workload-family-placement` diagram generated | Workload placement diagram artifact is present |
| No error-state artifacts | No artifact in the result set carries `status = error` |
| As-built report includes document control block | Document control header is present in as-built markdown output |
| As-built report includes sign-off section | Sign-off block is present in as-built technical report |

## Writing New Simulation Tests

When adding a new render feature, add at least one simulation test that:

1. calls `Export-AzureLocalRangerReport` against `$manifestPath` (the IIC synthetic manifest)
2. asserts the specific artifact or content change your feature introduced
3. uses `$TestDrive` as the output root so it is cleaned up automatically by Pester

Example structure:

```powershell
It 'generates the new-feature artifact' {
    $outputRoot = Join-Path $TestDrive 'sim-new-feature'
    $result = Export-AzureLocalRangerReport -ManifestPath $manifestPath -OutputPath $outputRoot -Formats @('markdown')

    $generated = @($result.Artifacts | Where-Object { $_.relativePath -match 'new-feature' })
    $generated.Count | Should -BeGreaterThan 0
}
```

## Fixture Data Schema

The synthetic manifest must pass `Test-RangerManifestSchema` without errors. If you add new required fields, update both:

1. `Get-RangerReservedDomainPayloads` in `Modules/Internal/01-Definitions.ps1`
2. The corresponding data section in `tests/New-RangerSyntheticManifest.ps1`

Then regenerate and commit the fixture.
