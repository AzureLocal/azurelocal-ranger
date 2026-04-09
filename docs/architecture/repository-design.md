# Repository Design

Azure Local Ranger is intentionally two things at once:

- a public MkDocs documentation site
- a PowerShell module repository

The repository structure needs to support both without mixing public explanation and internal implementation concerns together.

## Public Documentation Structure

The `docs/` tree should stay concept-driven and readable as a published site.

| Area | Purpose |
|---|---|
| `docs/` | Public documentation content |
| `docs/assets/images` | Static image assets |
| `docs/assets/diagrams` | Diagram source and exported SVG assets |
| `mkdocs.yml` | Site navigation and publication structure |

The public docs should explain what Ranger is, how it runs, what it discovers, and what it outputs without forcing readers into implementation details or internal planning notes.

## Internal Planning vs Public Docs

`repo-management/` is where planning artifacts belong.

That separation matters because:

- public docs should be stable and reader-focused
- planning files can remain detailed, iterative, and implementation-oriented
- contributors need one place for source planning and another for public-facing docs

The public site should absorb mature decisions from `repo-management/` rather than exposing the planning file as the only authoritative explanation.

## Diagram Asset Model

When diagrams materially improve clarity, Ranger docs should use draw.io source files exported to SVG.

The intended location is:

- `docs/assets/diagrams/*.drawio`
- `docs/assets/diagrams/*.svg`

That keeps the editable source and published asset side by side.

## Planned Module Layout

The implementation side should remain module-oriented.

| Path | Purpose |
|---|---|
| `Modules/Public` | Exported commands and public entry points |
| `Modules/Private` | Internal helper functions |
| `Modules/Core` | Orchestration, manifest assembly, and shared services |
| `Modules/Collectors` | Domain collectors |
| `Modules/Outputs/Reports` | Report renderers |
| `Modules/Outputs/Diagrams` | Diagram renderers |
| `Modules/Internal` | Shared internal models and helpers |

That layout is more honest than a generic `src/` tree because Ranger is a publishable PowerShell module.

## Supporting Repository Areas

Other top-level areas should stay intentional.

| Path | Role |
|---|---|
| `.github/workflows/` | Validation, automation, and publishing workflows |
| `tests/` | Future test coverage for schema, collectors, and outputs |
| `samples/` | Future sample manifests and output examples |
| `branding/` | Shared visual assets |

## Publication Model

The docs structure should assume GitHub Pages publication, and the module structure should assume eventual PSGallery publication.

That dual model is a feature of the repo, not an accidental compromise.
