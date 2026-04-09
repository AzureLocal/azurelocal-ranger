# Repository Structure

Azure Local Ranger is intentionally both a public documentation site and a PowerShell module repository.

That means the repo structure has to support the current documentation-first phase without confusing that with the long-term module layout.

## Current Top-Level Structure

| Path | Purpose | Current posture |
| --- | --- | --- |
| `docs/` | Public documentation site content | Active now |
| `mkdocs.yml` | Site navigation and publication structure | Active now |
| `.github/workflows/` | Validation and GitHub Pages publication workflows | Active now |
| `repo-management/` | Internal plans, checklists, and working design material | Active now |
| `repo-management/reports/` | Canonical internal audit and implementation trackers | Active now |
| `Modules/` | PowerShell implementation tree | Active now |
| `tests/` | Automated validation and fixture-backed tests | Active now |
| `samples/` | Future sample configs, manifests, and output examples | Reserved |
| `branding/` | Shared visual assets and brand material | Reserved |

## PowerShell Module Surface

The repository includes a real root module plus the module-oriented implementation tree:

- `AzureLocalRanger.psd1`
- `AzureLocalRanger.psm1`

The main implementation surface now lives under `Modules/` and follows the layered architecture defined in the product plan.

## What Contributors Should Edit Now

Most contributors will now be touching one or more of these areas:

- `docs/`
- `mkdocs.yml`
- `repo-management/`
- `Modules/`
- `tests/`

The split still matters:

- `docs/` carries the public story
- `repo-management/` carries internal planning and audit detail
- `Modules/` and `tests/` carry the implementation itself

## Module Structure

The implementation layout is module-oriented rather than a generic `src/` tree.

| Planned path | Purpose |
| --- | --- |
| `Modules/Public` | Exported commands and public entry points |
| `Modules/Private` | Internal helper functions |
| `Modules/Core` | Orchestration, manifest assembly, and shared services |
| `Modules/Collectors` | Discovery-domain collectors |
| `Modules/Outputs/Reports` | Report renderers |
| `Modules/Outputs/Diagrams` | Diagram renderers and helpers |
| `Modules/Internal` | Shared models and non-exported utilities |

That structure reflects the architecture decisions already locked in the docs and now implemented in the repository.

## Public Docs vs Internal Planning

The split between `docs/` and `repo-management/` is intentional.

- `docs/` should tell the stable public story
- `repo-management/` can hold iterative internal planning detail

Public readers should not have to read internal planning files just to understand the product.

The new canonical implementation audit lives under `repo-management/reports/`, while public-facing delivery summaries live under `docs/project/`.

## Publication Model

The documentation side of the repo should stay GitHub Pages and MkDocs friendly.

The implementation side of the repo stays publishable as a PowerShell module as collectors and renderers evolve.

## Read Next

- [Status](status.md)
- [Roadmap](roadmap.md)
- [Documentation Roadmap](documentation-roadmap.md)
- [Getting Started](../contributor/getting-started.md)
