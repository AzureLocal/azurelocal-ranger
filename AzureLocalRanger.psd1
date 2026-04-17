@{
    RootModule        = 'AzureLocalRanger.psm1'
    ModuleVersion     = '2.1.0'
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
        'Invoke-RangerWizard',
        'Export-RangerWafConfig',
        'Import-RangerWafConfig'
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
## v2.1.0 — Preflight Hardening

Close the three auth/preflight gaps identified against v2.0.0 so RBAC and
credential problems surface up-front instead of mid-run.

### Added
- **Per-resource-type ARM probe (#235)** — pre-run permission audit now issues a
  `Get-AzResource` against each v2.0.0 collector surface
  (`logicalNetworks`, `storageContainers`, `customLocations`, `appliances`,
  `gateways`, `marketplaceGalleryImages`, `galleryImages`). `Partial` overall
  when some surfaces 403, `Fail` when all do. Skipped in fixture mode.
- **Deep WinRM CIM probe (#234)** — `Invoke-RangerCimDepthProbe` runs after the
  shallow WinRM preflight and issues a representative `Get-CimInstance`
  against `root/MSCluster`, `root/virtualization/v2`, and
  `root/Microsoft/Windows/Storage`. Non-blocking warning on `partial` /
  `denied`; result captured in `manifest.run.remoteExecution.cimDepth`.
- **Azure Advisor read probe (#233)** — pre-check calls
  `Get-AzAdvisorRecommendation`. Denied 403 downgrades overall readiness to
  `Partial` and emits an actionable finding. Absent `Az.Advisor` is a `Skip`
  with an install hint, not a failure.

### Changed
- Overall readiness thresholds unchanged: `Insufficient` throws,
  `Partial` warns and continues, `Full` proceeds silently.

## v2.0.0 — Extended Collectors & WAF Intelligence

### Added — Collectors
- **Arc machine extensions per node (#215)** — AMA / Defender for Servers / Guest Configuration inventory per Arc-enrolled node with provisioning state; XLSX Extensions tab; Power BI `arc-extensions.csv`.
- **Logical networks + subnets (#216)** — Microsoft.AzureStackHCI/logicalNetworks with subnet, VLAN, IP pool, DHCP detail; cross-reference against host vSwitch; new Logical Networks / Subnets XLSX tabs.
- **Storage paths (#217)** — Microsoft.AzureStackHCI/storageContainers with CSV cross-reference; StoragePaths XLSX tab + Power BI CSV.
- **Custom locations (#218)** — Microsoft.ExtendedLocation/customLocations inventory linked to Resource Bridge host resource IDs.
- **Arc Resource Bridge (#219)** — bridge version / distro / status collection + Arc VM `vmProvisioningModel` classification (hyper-v-native / arc-vm-resource-bridge).
- **Arc Gateway (#220)** — Microsoft.HybridCompute/gateways with per-node routing detection.
- **Marketplace + custom images (#221)** — Microsoft.AzureStackHCI/marketplaceGalleryImages + galleryImages with storage-path cross-reference.

### Added — Intelligence
- **Azure Hybrid Benefit + cost analysis (#222)** — softwareAssuranceProperties-based AHB detection, per-core $10/month cost calculation, potential monthly savings, pricing reference footer. New Cost & Licensing HTML/Markdown/DOCX/PDF section + CostLicensing XLSX tab + cost-licensing Power BI CSV.
- **VM distribution balance (#223)** — coefficient-of-variation analysis across nodes; warning/fail thresholds; per-node distribution table in management + technical tiers.
- **Agent version grouping (#224)** — Arc agent + OS version grouped by node with drift detection (latestVersion, maxBehind, status).
- **Weighted WAF scoring (#225)** — per-rule weight 1-3, warnings award 0.5x weight, graduated threshold bands, score thresholds (Excellent/Good/Fair/Needs Improvement) exposed on the result.

### Added — Commands & UX
- **Export-RangerWafConfig / Import-RangerWafConfig (#226)** — hot-swap WAF rule config with schema validation, -Validate dry-run, -Default restore.
- **json-evidence export format (#229)** — raw resource-only JSON payload with minimal `_metadata` envelope, no scoring/run metadata; accepted via `Invoke-AzureLocalRanger -OutputFormats json-evidence` and `Export-AzureLocalRangerReport -Formats json-evidence`.
- **-SkipModuleUpdate (#231)** — opt-out of automatic Az.* module install/update on startup for air-gapped environments.

### Added — Reliability
- **Concurrent collection guard (#230)** — second `Invoke-AzureLocalRanger` call in the same session warns and returns rather than racing shared state.
- **Empty-data safeguard (#230)** — collection with zero nodes throws an actionable error instead of rendering empty tables.
- **Module auto-install/update on startup (#231)** — required modules (Az.Accounts, Az.Resources, Az.ConnectedMachine, Az.KeyVault) are installed or updated if missing/below minimum version.

### Added — Output
- **Portrait/landscape page switching (#227)** — `@page landscape-pg` rule applied to wide tables (Arc extensions, logical network subnets).
- **Conditional status-cell coloring (#227)** — Healthy / Warning / Failed cells are auto-colored in HTML/PDF.
- **Pricing footer with dated reference (#228)** — every cost section lists the pricing as-of date and official pricing URL.

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

Full history: https://github.com/AzureLocal/azurelocal-ranger/blob/main/CHANGELOG.md
'@
        }
    }
}
