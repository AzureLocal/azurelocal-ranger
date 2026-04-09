# Getting Started

This repository contains the implemented v1 module, the public documentation site, and the supporting test suite.

## What Contributors Should Do First

- read `What Ranger Is`
- read `Ranger vs Scout`
- read `Scope Boundary`
- read `Deployment Variants`
- read the architecture pages in this order: `System Overview`, `How Ranger Works`, `Audit Manifest`, `Implementation Architecture`, `Configuration Model`
- read the operator pages if your change affects how Ranger will be run
- read the [Roadmap](../project/roadmap.md) before proposing structural or scope changes
- review the grouped discovery-domain and output docs only after the core architecture story is clear
- keep the [technical runtime flow diagram](../architecture/how-ranger-works.md) open while reading `Modules/Core/20-Runtime.ps1` and the collector files

## Contribution Focus Right Now

The highest-value contributions at this stage are:

- implementing and testing collectors and output generators
- refining discovery-domain definitions and evidence boundaries
- keeping docs aligned with current collector and manifest reality
- writing Pester tests — unit, fixture-based, and simulation
- keeping public docs aligned with current Microsoft Azure Local documentation where product facts are involved
- making future-scope items visible as roadmap entries or separate issues instead of leaving them buried in planning prose

## Testing Your Changes

Ranger uses Pester 5 for all tests. Run the full suite from the repo root:

```powershell
Invoke-Pester -Path .\tests -Output Detailed
```

For simulation testing in MAPROOM (full pipeline validation without live connections), use the IIC synthetic manifest:

```powershell
Invoke-Pester -Path .\tests\maproom\unit\Simulation.Tests.ps1 -Output Detailed
```

See [Simulation Testing](simulation-testing.md) for a detailed guide to the simulation framework, the IIC canonical data standard, and how to regenerate the synthetic manifest fixture.

## Read Next

- [Roadmap](../project/roadmap.md)
- [Simulation Testing](simulation-testing.md)
- [Contributing](contributing.md)
