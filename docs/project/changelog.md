# Changelog

The primary changelog for the repository lives at the root in `CHANGELOG.md`, but the main milestones are summarised here for docs readers.

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
