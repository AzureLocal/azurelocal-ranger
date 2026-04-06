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

## Current-State vs As-Built

Current-state reports emphasize present posture, findings, and current operating risk.

As-built reports emphasize transfer-of-ownership clarity, structure, diagrams, and narrative completeness. The as-built package can include one or more of the report tiers as part of a larger delivery artifact.

## Relationship to Raw Evidence

Reports should make the distinction between these layers clear:

- raw evidence
- normalized manifest data
- rendered narrative output

Operators should not have to guess whether a sentence came from direct evidence, inferred logic, or manual/imported context.
