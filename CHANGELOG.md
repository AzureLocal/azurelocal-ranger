# Changelog

All notable changes to Azure Local Ranger will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Pre-release versions start at `0.5.0`. The first stable PSGallery release will be `1.0.0` once live-estate validation is complete.

## [Unreleased]

### Added

- **Issue #36** — Offline network device config import via `domains.hints.networkDeviceConfigs` hints: Cisco NX-OS and IOS parser extracting VLANs, port-channels/LAGs, interfaces, and ACLs. New `switchConfig` and `firewallConfig` keys added to the `networking` manifest domain. New private module `Modules/Private/60-NetworkDeviceParser.ps1`. 7 new Pester tests in `tests/unit/NetworkDevice.Tests.ps1` including IIC NX-OS fixture at `tests/Fixtures/network-configs/switch-nxos-sample.txt`.
- **Issue #38** — As-built mode now produces differentiated report content: Document Control block, Installation Register, and Sign-Off table injected into each tier report when `mode = as-built`. New `Modules/Outputs/Templates/10-AsBuilt.ps1` with three template section functions. `Modules/Outputs/Templates/` added to module load path in `AzureLocalRanger.psm1`. 2 new simulation tests covering as-built document control and sign-off content.
- **Issue #37** — Full documentation audit: Manifest Sub-Domains tables added to all 8 domain pages that were missing them (`networking`, `cluster-and-node`, `storage`, `hardware`, `virtual-machines`, `management-tools`, `performance-baseline`, `oem-integration`). New contributor docs: `simulation-testing.md` (complete simulation framework guide, IIC canonical data standard, fixture regeneration), `template-authoring.md` (template system design, how to add new report sections). `contributor/getting-started.md` updated to remove deleted page references and reflect current implementation focus. MkDocs nav updated for new contributor pages.

### Changed

- `domains.hints.networkDeviceConfigs` added to `Get-RangerDefaultConfig` default hints structure
- `networking` domain reserved template now includes `switchConfig` and `firewallConfig` keys
- `networking` domain summary now includes `importedSwitchConfigCount` and `importedFirewallConfigCount` counts
- Tests: 18 → 27 total (7 new network device tests + 2 new simulation tests)

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
- Roadmap rewritten in versioned-milestone format (Current Release, Next Release, Post-v1 Backlog, Long-term Vision) aligned with Azure Scout pattern
- `docs/project/status.md` removed — current delivery state folded into roadmap Current Release section
- `docs/project/documentation-roadmap.md` removed — internal planning artifact no longer relevant for public docs
- `mkdocs.yml` nav updated to remove deleted pages

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