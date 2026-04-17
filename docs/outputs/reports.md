# Reports

Reports turn Ranger’s manifest into documentation that people can actually use.

The reporting model should support both operational understanding and formal handoff without changing the discovery engine.

## Report Rendering Rule

Reports render from cached manifest data only. Report generation must not reconnect to the cluster or Azure.

## Report Standards

Every report tier should include:

- tool version watermark
- generation timestamp
- target cluster or environment identifier
- stable finding severity labels
- clear distinction between observed facts and derived recommendations

## Supported Formats

Ranger renders from the cached manifest in these formats. Pass the format names to `-OutputFormats` (Invoke-AzureLocalRanger) or `-Formats` (Export-AzureLocalRangerReport).

| Format | Output | Notes |
| --- | --- | --- |
| `html` | HTML narrative report (all tiers) | Default |
| `markdown` | Markdown narrative report | Default |
| `json` | Raw manifest export | Full manifest JSON |
| `json-evidence` | Raw resource-only inventory JSON | Minimal `_metadata` envelope; no scoring or run metadata (v2.0.0) |
| `svg` | SVG vector diagrams | Default |
| `drawio` | draw.io XML diagrams | |
| `docx` | Word document narrative report | |
| `xlsx` | Excel workbook (inventory + findings tabs) | |
| `pdf` | PDF rendered from HTML | Requires headless Edge or Chrome |
| `pptx` | PowerPoint executive presentation | 7-slide deck via `System.IO.Packaging`; no Office dependency (v2.5.0) |
| `powerbi` | Power BI CSV star-schema exports | Writes a `powerbi/` folder with per-domain CSVs and `_relationships.json` (v2.0.0) |

The report pipeline is render-only. It does not reconnect to WinRM, Azure, or Redfish when generating alternate formats.

## Findings Model

Findings should use these severities:

- `Critical` — immediate action required
- `Warning` — should be addressed soon
- `Informational` — useful context or non-blocking observation
- `Good` — healthy or compliant posture worth affirming

Each finding should include title, description, affected scope, current state, recommendation, and a supporting reference when available.

## Report Tiers

### Executive Summary

Audience: CIOs, directors, sponsors, or customers who need the state of the environment quickly.

Characteristics:

- short and visual
- minimal jargon
- top risks and recommended actions only

Typical content:

- environment identity
- node count and high-level capacity
- overall health summary
- Azure integration summary
- top critical and warning findings
- high-level recommendations

### Management Summary

Audience: IT managers, leads, service owners.

Characteristics:

- more operational detail than executive output
- still selective rather than exhaustive

Typical content:

- density and overcommit indicators
- storage utilization summary
- network and backup posture
- update compliance summary
- security posture summary
- monitoring coverage summary
- prioritized recommendations

### Technical Deep Dive

Audience: engineers, architects, and specialist operators.

Characteristics:

- dense, detailed, and highly structured
- aligned to the collector and manifest model

Typical content:

- full hardware inventory
- complete VM, storage, and network detail
- Azure integration and extension detail
- security and certificate detail
- event-pattern and performance-baseline detail
- complete findings set and supporting context

## Office-Format Deliverables

The v1 renderer also produces formal handoff formats without requiring a locally installed Office desktop application.

- `docx` outputs are generated for the executive, management, and technical tiers.
- `pdf` outputs are generated from the same saved report payloads used by the HTML and Word renderers.
- `xlsx` output is generated as a technical workbook of inventories, findings, and collector status registers.

The Excel workbook is domain-oriented and includes stable worksheet ordering with filterable header rows.

## Current-State vs As-Built

Current-state reports emphasize present posture, findings, and current operating risk.

As-built reports emphasize transfer-of-ownership clarity, structure, diagrams, and narrative completeness. The as-built package can include one or more of the report tiers as part of a larger delivery artifact.

## Relationship to Raw Evidence

Reports should make the distinction between these layers clear:

- raw evidence
- normalized manifest data
- rendered narrative output

Operators should not have to guess whether a sentence came from direct evidence, inferred logic, or manual/imported context.
