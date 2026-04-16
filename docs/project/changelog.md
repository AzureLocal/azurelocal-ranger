# Changelog

The primary changelog for the repository lives at the root in `CHANGELOG.md`, but the main milestones are summarised here for docs readers.

## v1.3.0 Highlights

- **Full config parameter coverage** — every config key is now a runtime parameter on `Invoke-AzureLocalRanger`; no config file needed for any run
- **First Run guide** — linear six-step beginner guide from install to output with no decisions
- **Wizard guide** — complete `Invoke-RangerWizard` walkthrough with example inputs and generated YAML
- **Configuration reference** — full table of every config key with type, default, and Key Vault syntax
- **Understanding output** — directory tree, role-based reading path, collector status interpretation
- **Command reference scenarios** — nine copy-paste examples covering every common use case
- **Discovery domain enhancements** — all 10 domain pages now include example manifest data, common findings, and partial status guidance

## v1.2.1 Highlights

- **Redfish 404 retry** — 4xx responses no longer trigger retries; `Invoke-RangerRetry` extended with `-ShouldRetry` scriptblock
- **Hardware partial status** — collector reports `partial` instead of `success` when Redfish endpoints return 404; warning finding added
- **ShowProgress default-on** — progress display enabled without any config key or switch; opt out with `output.showProgress: false`
- **Prerequisite output** — `Test-AzureLocalRangerPrerequisites` renders a colour-coded Pass/Warn/FAIL table; optional checks for `Az.ConnectedMachine` and `PwshSpectreConsole` added

## v1.2.0 Highlights

- **Arc Run Command transport** — WinRM workloads fall back to `Invoke-AzConnectedMachineRunCommand` when nodes are unreachable; `behavior.transport: auto/winrm/arc` controls the strategy
- **Disconnected / semi-connected discovery** — pre-run connectivity matrix classifies posture; unreachable collectors skip with `status: skipped` instead of failing; matrix stored in `manifest.run.connectivity`
- **Spectre.Console TUI progress** — live per-collector bars via `PwshSpectreConsole`; falls back to `Write-Progress`; `-ShowProgress` parameter and `output.showProgress` config key
- **Interactive wizard** — `Invoke-RangerWizard` guided setup: cluster, nodes, Azure IDs, credentials, output, scope; save to YAML, run immediately, or both

## v1.1.2 Highlights

- schema contract rewritten as inline data — no file-path dependency, PSGallery installs work correctly
- `toolVersion` in manifests now reflects the actually installed module version dynamically
- Redfish/BMC retry entries now carry label and target URI for actionable log output
- `DebugPreference` no longer set to `Continue` at debug log level — eliminates MSAL/Az SDK debug flood
- null entries filtered from collector message arrays — no more `null` in manifest or report output
- domain credential tried before cluster credential — eliminates redundant WinRM auth retries
- 20 Pester unit tests added covering all 9 regression bugs; Trailhead field validation closed on live tplabs

## v1.1.1 Highlights

- fixed the installed-module regression where `Test-AzureLocalRangerPrerequisites` threw when run with no config arguments
- restored the documented first-run flow for PSGallery users validating a runner before generating a config file

## v1.1.0 Highlights

- intelligent remoting credential selection and authorization preflight for non-domain-joined runners
- Key Vault credential fallback via Azure CLI when Az PowerShell secret resolution is unavailable
- automatic BMC endpoint hydration from sibling `variables.yml`
- collector status semantics aligned so advisory findings do not downgrade successful collection to `partial`
- live v1.1.0 milestone validation closed on `tplabs` with all 6 collectors successful

## Root Changelog

This documentation page exists so the public documentation site can link readers to the project history without duplicating version notes across two places.
