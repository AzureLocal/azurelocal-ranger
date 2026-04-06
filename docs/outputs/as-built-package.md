# As-Built Package

The as-built package is one of Ranger’s defining outputs.

It is not a thin export. It is a structured handoff artifact for another team, customer, or support function.

## Purpose

The as-built package should let a receiving team understand what was delivered without rediscovering the environment from scratch.

Typical uses include:

- customer handoff
- project closure
- transfer from implementation to operations
- managed-service onboarding
- support and governance readiness

## Package Structure

The exact file names can evolve, but the logical package should include:

```text
<cluster>-as-built-<timestamp>/
	manifest/
		audit-manifest.json
	reports/
		executive-summary.html
		management-summary.html
		technical-deep-dive.html
	diagrams/
		physical-architecture.svg
		logical-network-topology.svg
		azure-arc-integration.svg
		...
	evidence/
		optional raw evidence exports or references
	index.html or README.md
```

## Required Content

At a minimum, the package should include:

- environment identity and deployment summary
- cluster and node overview
- hardware summary
- storage and networking architecture summaries
- workload and service inventory
- Azure integration summary
- management and security posture summary
- selected diagrams appropriate for the environment
- technical deep-dive detail or appendix

## Conditional Content

Some content should appear only when the environment justifies it.

Examples:

- disconnected-operations control-plane sections
- local identity with Key Vault secret-flow sections
- multi-rack preview topology diagrams
- OEM-specific lifecycle sections when OEM tooling is detected

## What Makes It Different From a Raw Report

An as-built package should be:

- accurate
- organized
- narrative enough to be read by a receiving team
- diagram-supported
- explicit about what was discovered directly versus what was imported or inferred

## Naming and Artifact Expectations

Artifact naming should include:

- cluster or environment identifier
- mode (`as-built`)
- generation timestamp
- artifact type

Examples:

- `azlocal-prod-01-as-built-20260406-technical-deep-dive.html`
- `azlocal-prod-01-as-built-20260406-physical-architecture.svg`

## Relationship to Current-State Outputs

Current-state outputs are shorter-lived operational artifacts.

The as-built package is a formal delivery artifact. It should feel more curated, better structured, and more complete, even though it still depends on the same manifest contract.