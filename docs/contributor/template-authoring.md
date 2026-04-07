# Template Authoring Guide

This page explains how Ranger's output template system works and how to extend it.

## What Templates Are

In Ranger, "templates" are PowerShell functions in `Modules/Outputs/Templates/` that construct report sections as structured data.

Ranger does not use a text-based template engine. Instead, templates are PowerShell functions that return structured section payloads (an ordered hashtable with a `heading` and a `body` array). The report renderer (`ConvertTo-RangerMarkdownReport`, `ConvertTo-RangerHtmlReport`) turns those into formatted output.

This keeps all section logic in typed, testable PowerShell rather than in embedded string templates.

## Directory Layout

```
Modules/
  Outputs/
    Templates/
      10-AsBuilt.ps1    as-built mode section templates
    Reports/
      10-Reports.ps1    core report payload builder and renderers
    Diagrams/
      10-Diagrams.ps1   diagram generation
```

## Section Payload Structure

Every section returned by a template function must follow this structure:

```powershell
[ordered]@{
    heading = 'Section Title'
    body    = @(
        'Line one',
        'Line two',
        'Line three'
    )
}
```

The `body` array holds plain strings. The renderer decides how to present them (as a bullet list, prose paragraph, or table rows depending on the format).

## Current Templates

### `10-AsBuilt.ps1`

| Function | Description |
|---|---|
| `New-RangerAsBuiltDocumentControlSection` | Document control block — environment name, package ID, tool version, and handoff status |
| `New-RangerAsBuiltInstallationRegisterSection` | Installation register — key platform parameters, node list, topology and Azure summary |
| `New-RangerAsBuiltSignOffSection` | Sign-off block — handoff acknowledgment table for human completion |

These sections are injected into each report tier when `$Mode -eq 'as-built'` in `New-RangerReportPayload`.

## How As-Built Mode Injects Sections

In `Modules/Outputs/Reports/10-Reports.ps1`, `New-RangerReportPayload` checks `$Mode` after building the standard sections:

```powershell
if ($Mode -eq 'as-built') {
    $sections.Insert(0, (New-RangerAsBuiltDocumentControlSection -Manifest $Manifest -Tier $Tier))
    if ($Tier -ne 'executive') {
        [void]$sections.Add((New-RangerAsBuiltInstallationRegisterSection -Manifest $Manifest))
    }
    [void]$sections.Add((New-RangerAsBuiltSignOffSection))
}
```

Document Control is prepended (position 0) so it always appears before the operational body of the report.
Installation Register and Sign-Off are appended at the end.

## Adding a New Template Section

1. Add a function to an appropriate file in `Modules/Outputs/Templates/`. Use the `New-RangerAsBuilt*Section` naming pattern: `New-Ranger<Mode><Purpose>Section`.

2. The function should accept `$Manifest` and optionally `$Tier` as parameters. Keep it focused — one section per function.

3. Call the function from `New-RangerReportPayload` at the appropriate injection point.

4. Add a simulation test in `tests/unit/Simulation.Tests.ps1` that verifies the section content appears in rendered output.

## Naming Conventions

| Convention | Example |
|---|---|
| Template file names are numbered | `10-AsBuilt.ps1`, `20-CurrentState.ps1` |
| Function names use the `New-Ranger*Section` pattern | `New-RangerAsBuiltDocumentControlSection` |
| Section headings are title-cased | `'Document Control'`, `'Sign-Off'` |

## Testing Templates

Templates are tested through the simulation framework. See [Simulation Testing](simulation-testing.md) for details.

At minimum, each new template section should have a simulation test that:

- renders the affected tier using the IIC synthetic manifest
- asserts the section heading appears in the rendered markdown output
- asserts that at least one meaningful line of content is present
