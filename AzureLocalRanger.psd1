@{
    RootModule        = 'AzureLocalRanger.psm1'
    ModuleVersion     = '1.2.1'
    CompatiblePSEditions = @('Core')
    GUID              = '8bc325c2-9b7f-46f9-b102-ef29e92a15b8'
    Author            = 'Azure Local Cloud'
    CompanyName       = 'Azure Local Cloud'
    Copyright         = '(c) 2026 Hybrid Cloud Solutions. All rights reserved.'
    Description       = 'AzureLocalRanger performs automated, read-only discovery and reporting against Azure Local (formerly Azure Stack HCI) clusters. It collects cluster topology, storage and networking health, VM workload inventory, security posture, and Azure Arc registration state — then renders HTML, Markdown, JSON, and SVG as-built report packages. Run from any Windows machine with WinRM access to the cluster.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Invoke-AzureLocalRanger',
        'New-AzureLocalRangerConfig',
        'Export-AzureLocalRangerReport',
        'Test-AzureLocalRangerPrerequisites',
        'Invoke-RangerWizard'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags = @(
                'AzureLocal',
                'AzureStackHCI',
                'HCI',
                'Arc',
                'ArcEnabledInfrastructure',
                'PowerShell',
                'Documentation',
                'Inventory',
                'Audit',
                'AsBuilt',
                'Report',
                'Discovery',
                'HealthCheck',
                'Cluster',
                'FailoverClustering',
                'Windows',
                'WindowsServer',
                'Hyper-V',
                'StorageSpacesDirect',
                'S2D'
            )
            IconUri      = 'https://raw.githubusercontent.com/AzureLocal/azurelocal-ranger/main/docs/assets/images/azurelocalranger-icon.svg'
            LicenseUri   = 'https://github.com/AzureLocal/azurelocal-ranger/blob/main/LICENSE'
            ProjectUri   = 'https://azurelocal.cloud/azurelocal-ranger/'
            HelpInfoUri  = 'https://azurelocal.cloud/azurelocal-ranger/'
            ExternalModuleDependencies = @(
                'Az.Accounts',
                'Az.Resources',
                'Az.ConnectedMachine'
            )
            ReleaseNotes = @'
## v1.2.0 — UX & Transport

### Added
- **Arc Run Command transport (#26)** — `Invoke-AzureLocalRanger` now routes WinRM workloads
  through Azure Arc Run Command (`Invoke-AzConnectedMachineRunCommand`) when cluster nodes
  are unreachable on ports 5985/5986. Transport mode is controlled by `behavior.transport`
  (auto / winrm / arc) and falls back gracefully when `Az.ConnectedMachine` is absent.
- **Disconnected / semi-connected discovery (#30)** — A pre-run connectivity matrix probes
  all transport surfaces (cluster WinRM, Azure management plane, BMC HTTPS) and classifies
  the runner posture as `connected`, `semi-connected`, or `disconnected`. Collectors whose
  transport is unreachable are skipped with `status: skipped` rather than failing mid-run.
  The full matrix is stored in `manifest.run.connectivity` for observability.
- **Spectre.Console TUI progress display (#76)** — A live per-collector progress display
  using PwshSpectreConsole renders during collection when the module is installed and the
  host is interactive. Falls back to `Write-Progress` automatically. Suppressed in CI and
  Unattended mode. Enable with `-ShowProgress` or `output.showProgress: true` in config.
- **Interactive configuration wizard (#75)** — `Invoke-RangerWizard` walks through a
  prompted question sequence (cluster, nodes, Azure IDs, credentials, output, scope) and
  offers to save the config as YAML, launch a run immediately, or both.

## v1.1.2 — Regression Patch

### Fixed
- Schema contract (`Get-RangerManifestSchemaContract`) rewritten as inline hashtable — eliminates
  FileNotFoundException for PSGallery installs where repo-management/ is not present (#160).
- `toolVersion` in manifests now reflects the installed module version dynamically via
  `Get-RangerToolVersion` — no longer hardcoded to '1.1.0' (#161).
- `Invoke-RangerRedfishRequest` now passes `-Label` and `-Target` to `Invoke-RangerRetry` so
  BMC/Redfish retry log entries carry actionable label and URI (#162).
- `$DebugPreference` no longer set to `'Continue'` at debug log level — eliminates thousands of
  MSAL and Az SDK internal debug lines flooding output (#163).
- Null entries filtered from collector message arrays before manifest and report assembly (#164).
- Domain credential probed before cluster credential in `Get-RangerRemoteCredentialCandidates` —
  eliminates redundant WinRM auth retries on domain-joined clusters (#165).

### Added
- 20 Pester unit tests in `tests/maproom/unit/Execution.Tests.ps1` covering all 9 regression
  bugs (#157–#165). Trailhead field validation closed on live tplabs cluster.

## v1.0.0 — PSGallery Launch

### New Features
- **Parameter-first input model** — pass ClusterFqdn, ClusterNodes, SubscriptionId,
  TenantId, and ResourceGroup directly to Invoke-AzureLocalRanger without a config file.
- **Arc-first node inventory** — cluster nodes are auto-resolved from Azure Arc resource
  properties before falling back to direct WinRM scan or static config.
- **Domain auto-detection** — domain FQDN is resolved from Arc, CIM, or credential hints;
  workgroup clusters are handled gracefully with an informational finding.
- **File-based logging** — every run writes a plain-text ranger.log alongside reports.
- **Self-documenting config scaffold** — New-AzureLocalRangerConfig emits YAML with inline
  comments and [REQUIRED] markers on all mandatory fields.
- **Unreachable-node finding** — a warning finding is raised for any configured node that
  does not respond to WinRM during the topology collection pass.
- **Comment-based help** — Get-Help is now fully populated for all four public commands.

### Bug Fixes
- Fixed null-reference crashes in the storage collector when any sub-section
  (tiers, subsystems, resiliency, jobs, csvs, qos, sofs, replica, clusterNetworks)
  throws during a remote session.

### Improvements
- retryCount and timeoutSeconds from config are now applied to every WinRM operation.
- PSGallery manifest metadata, tags, and description updated for discoverability.
'@
        }
    }
}
