# Repository Structure

Azure Local Ranger is intentionally both a public documentation site and a future PowerShell module repository.

That means the repo structure has to support the current documentation-first phase without confusing that with the long-term module layout.

## Current Top-Level Structure

| Path | Purpose | Current posture |
|---|---|---|
| `docs/` | Public documentation site content | Active now |
| `mkdocs.yml` | Site navigation and publication structure | Active now |
| `.github/workflows/` | Validation and GitHub Pages publication workflows | Active now |
| `repo-management/` | Internal plans, checklists, and working design material | Active now |
| `tests/` | Future automated validation and fixture tests | Reserved |
| `samples/` | Future sample configs, manifests, and output examples | Reserved |
| `branding/` | Shared visual assets and brand material | Reserved |

## Root Module Shell

The repository includes a root module shell:

- `AzureLocalRanger.psd1`
- `AzureLocalRanger.psm1`

These files exist so the repo can evolve into a real PowerShell module without forcing premature collector implementation into the public documentation phase.

## What Contributors Should Edit Now

At the current maturity stage, most contributors should be touching:

- `docs/`
- `mkdocs.yml`
- `repo-management/`

They should not create large implementation trees just to make the repo look busy.

## Planned Module Structure

The intended long-term implementation layout is module-oriented rather than a generic `src/` tree.

| Planned path | Purpose |
|---|---|
| `Modules/Public` | Exported commands and public entry points |
| `Modules/Private` | Internal helper functions |
| `Modules/Core` | Orchestration, manifest assembly, and shared services |
| `Modules/Collectors` | Discovery-domain collectors |
| `Modules/Outputs/Reports` | Report renderers |
| `Modules/Outputs/Diagrams` | Diagram renderers and helpers |
| `Modules/Internal` | Shared models and non-exported utilities |

That structure reflects the architecture decisions already locked in the docs.

## Public Docs vs Internal Planning

The split between `docs/` and `repo-management/` is intentional.

- `docs/` should tell the stable public story
- `repo-management/` can hold iterative internal planning detail

Public readers should not have to read internal planning files just to understand the product.

## Publication Model

The documentation side of the repo should stay GitHub Pages and MkDocs friendly.

The implementation side of the repo should stay publishable as a PowerShell module when collector work begins.

## Read Next

- [Roadmap](roadmap.md)
- [Documentation Roadmap](documentation-roadmap.md)
- [Getting Started](../contributor/getting-started.md)
