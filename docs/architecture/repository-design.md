# Repository Design

This repository is a MkDocs-backed PowerShell module repository and should be structured accordingly.

## Documentation Site Model

The public documentation should be authored in `docs/` and published through MkDocs to GitHub Pages.

That means the repo should favor:

- clean Markdown source under `docs/`
- a clear `mkdocs.yml` navigation model
- a structure that reads well on a public documentation site
- public-facing pages focused on product clarity, not internal implementation clutter

## Future PowerShell Module Layout

Using Azure Scout as the reference point, Ranger should be shaped like a real PowerShell module repository, not a generic source tree.

For that reason, the repo now reserves a `Modules/` layout instead of leaning on the earlier `src/` placeholder structure.

## Planned Module Areas

- `Modules/Public` for exported entry points and public cmdlets
- `Modules/Private` for internal helpers
- `Modules/Collectors` for discovery-domain logic
- `Modules/Core` for manifest, orchestration, and shared execution flow
- `Modules/Outputs/Reports` for report-generation logic
- `Modules/Outputs/Diagrams` for diagram-generation logic
- `Modules/Internal` for shared non-exported internals

## Why This Is Better Than The Earlier Placeholder

The earlier flat `src/` placeholder came from generic scaffolding and did not reflect the fact that this repo is being built as a PowerShell module that should eventually feel publishable and professional.

A module-oriented layout is clearer for:

- future PSGallery packaging
- contributor expectations
- public repo readability
- alignment with Azure Scout as a sister project

## GitHub Pages Expectation

This repository should be treated as a GitHub Pages-backed docs repo.

The repo can be prepared for that now through:

- MkDocs navigation and site metadata
- public-facing docs grouped by concept
- disciplined separation between public docs and internal planning

Repository settings for Pages cannot be changed from documentation alone, but the repo structure should assume GitHub Pages publication as the intended outcome.
