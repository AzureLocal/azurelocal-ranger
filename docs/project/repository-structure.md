# Repository Structure

Azure Local Ranger is a PowerShell module repository with a MkDocs documentation site.

## Public Structure

- `docs/` holds the public documentation site content
- `mkdocs.yml` defines site structure and navigation
- `.github/workflows/` holds validation and GitHub Pages documentation workflows
- `repo-management/` holds internal planning artifacts
- `tests/` is reserved for future validation
- `branding/` is reserved for future visual assets
- `samples/` is reserved for future sample outputs

## Root Module Files

The repository now also includes a root PowerShell module shell:

- `AzureLocalRanger.psd1`
- `AzureLocalRanger.psm1`

These provide a real starting point for future module implementation and validation without forcing premature collector code into the repo.

## Future Module Structure

To align more closely with Azure Scout and with eventual PSGallery publication, Ranger reserves `Modules/` as the future PowerShell implementation root.

### Planned Areas

- `Modules/Public`
- `Modules/Private`
- `Modules/Collectors`
- `Modules/Core`
- `Modules/Outputs/Reports`
- `Modules/Outputs/Diagrams`
- `Modules/Internal`

## Site Publication Model

This repository is intended to be a GitHub Pages-backed MkDocs site. The documentation structure should therefore remain focused, public-facing, and easy to navigate.
