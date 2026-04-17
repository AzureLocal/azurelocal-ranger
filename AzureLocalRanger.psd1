@{
    RootModule        = 'AzureLocalRanger.psm1'
    ModuleVersion     = '1.6.0'
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
        'Test-RangerPermissions',
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
## v1.6.0 — Platform Intelligence

### Added — Auth & Discovery
- **Auto-discover resource group (#196)** — subscription-wide ARM search by cluster name when resourceGroup is absent.
- **Auto-discover cluster FQDN (#197)** — pulled from Azure Arc; fallback to TrustedHosts + DNS on-prem chain.
- **Multi-method Azure auth (#200)** — service-principal-cert (thumbprint / PFX), tenant-matching context reuse, sovereign-cloud environment.
- **Save-AzContext handoff (#201)** — Export/Import-RangerAzureContext helpers for background runspaces.
- **Resource Graph single-query (#205)** — Search-AzGraph fast path for Arc machine discovery; Get-AzResource fallback.

### Added — Connectivity
- **WinRM TrustedHosts + DNS fallback (#203)** — on-prem FQDN resolution when Arc is unavailable.
- **Cross-RG node fallback (#204)** — Arc machines query with subscription-wide fallback; warning per cross-RG node.

### Added — Commands & UX
- **Invoke-AzureLocalRanger -Wizard (#211)** — inline wizard parameter; prompt text surfaces wizard as recommended alternative.
- **Test-RangerPermissions (#202)** — dedicated RBAC + provider registration audit; console/JSON/Markdown output.
- **-SkipPreCheck (#212)** — pre-run permission audit runs by default; opt-out flag and behavior.skipPreCheck config.
- **File-based progress IPC (#213)** — Write/Read/Remove-RangerProgressState for background runspace progress.

### Added — Resilience
- **Graceful degradation (#206)** — ARM error classifier + skipped-resources tracker; manifest.run.skippedResources; behavior.failOnPartialDiscovery gate.

### Added — Output
- **Headless-browser PDF (#207)** — msedge --headless=new --print-to-pdf renders the HTML report; plain-text fallback when no browser.
- **DOCX OOXML tables (#208)** — section.type='table'/'kv'/'sign-off' render as real Word tables.
- **XLSX formula-injection safety (#209)** — cells beginning with =, +, -, @ are apostrophe-prefixed.
- **Power BI export (#210)** — new `powerbi` format; nodes/volumes/storage-pools/health-checks/network-adapters CSVs + _relationships.json star-schema + _metadata.json.
- **Graduated WAF scoring (#214)** — threshold bands with partial point awards; named aggregate calculations; {value} message substitution.

## v1.5.0 — Document Quality

### Added
- **As-built document redesign (#193)** — Formal Installation and Configuration Record with
  per-node configuration, network address allocation, storage configuration, Azure integration,
  identity and security records, validation record, and known-issues/deviations register.
  Deployment past-tense framing; minimal-color formal styling.
- **Mode differentiation (#194)** — as-built uses distinct tier names (Installation and
  Configuration Record, Technical As-Built), CONFIDENTIAL classification banner, and
  Post-Deployment subtitle. current-state retains Management Summary, Technical Deep-Dive,
  Health Status traffic lights, and INTERNAL banner.
- **HTML report quality (#192)** — Inline architecture diagrams embedded under Architecture
  Diagrams section. Fixed-layout data tables with constrained column widths. Findings rendered
  as severity-colored callout boxes. Print CSS for clean browser-to-PDF output. Sign-off table
  with visible signature lines.

### Fixed
- **Wizard default formats (#195)** — Default report formats changed from
  `html,markdown,json,svg` (where `json` was invalid) to `html,markdown,docx,xlsx,pdf,svg`.
  Label now hints the valid format set.
- **Key Vault DNS error handling (#198)** — DNS resolution failures against Key Vault emit an
  actionable error naming likely causes (VPN not connected, wrong KV name, private endpoint
  unreachable). When `behavior.promptForMissingCredentials: true`, Ranger now falls back to
  `Get-Credential` rather than aborting the run.

Full history: https://github.com/AzureLocal/azurelocal-ranger/blob/main/CHANGELOG.md
'@
        }
    }
}
