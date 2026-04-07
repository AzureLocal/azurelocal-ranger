# Changelog

All notable changes to Azure Local Ranger will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Pre-release versions start at `0.5.0`. The first stable PSGallery release will be `1.0.0` once live-estate validation is complete.

## [Unreleased]

## [0.5.0] — 2026-04-07

### Added

- Full collector suite: topology/cluster, hardware (Dell/Redfish), storage/networking, workload/identity/Azure, monitoring, management/performance
- Manifest-first design with `audit-manifest.json`, schema contract (`manifest-schema.json` v1.1.0-draft), and runtime schema validation
- Three-tier report generation (executive, management, technical) in HTML and Markdown from cached manifest only
- 18-diagram catalog (6 baseline + 12 extended) with variant-aware selection rules and draw.io XML + SVG output
- Simulation testing framework: synthetic IIC 3-node fixture, `New-RangerSyntheticManifest.ps1`, `Test-RangerFromSyntheticManifest.ps1`
- 18 Pester tests passing: schema, degraded scenarios, cached outputs, end-to-end fixture, 7 simulation tests
- Azure authentication: existing-context, managed identity, device-code, service principal, Azure CLI fallback
- Key Vault credential resolution via `keyvault://` URI references in config
- `-OutputPath` parameter on `Invoke-AzureLocalRanger` for user-controlled export destination
- Public docs foundation under `docs/` with architecture, operator, contributor, outputs, and domain pages
- `New-AzureLocalRangerConfig`, `Export-AzureLocalRangerReport`, `Test-AzureLocalRangerPrerequisites` public commands

### Changed

- Version bumped from `0.2.0` to `0.5.0` to reflect substantial implementation completeness ahead of PSGallery `1.0.0` release

## [0.2.0]

### Added

- initial repository skeleton
- documentation structure for project vision, architecture, collectors, diagrams, reports, and contribution guidance
- MkDocs Material configuration and navigation tree
- placeholder implementation directories with `.gitkeep` files

### Changed

- aligned GitHub Actions workflows with repo-management standards and sibling Azure Local MkDocs repositories
- added standard GitHub support files for code ownership, pull request review, and release automation
- removed standalone MkDocs dependency file in favor of inline workflow dependency installation
- removed the completed repo restructure plan after its decisions were reflected in the live repository structure and docs