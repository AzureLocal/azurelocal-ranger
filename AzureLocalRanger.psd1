@{
    RootModule        = 'AzureLocalRanger.psm1'
    ModuleVersion     = '2.5.0'
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
        'Import-RangerWafConfig',
        'Get-RangerRemediation',
        'Publish-RangerRun',
        'Invoke-AzureLocalRangerEstate',
        'Import-RangerManualEvidence'
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
## v2.5.0 — Extended Platform Coverage

Workload/cost intelligence, multi-cluster orchestration, and executive-ready
presentation output.

### Added
- **Capacity headroom (#128)** — `capacityAnalysis` domain: per-node + cluster
  vCPU/memory/storage/pool allocation with Healthy/Warning/Critical status.
- **Idle / underutilized VM detection (#125)** — `vmUtilization` domain.
  Classifies VMs from `vm.utilization` sidecar data and emits rightsizing
  proposals plus potential freed-resource savings.
- **Storage efficiency (#126)** — `storageEfficiency` domain: per-volume dedup
  state, dedup ratio, saved GiB, thin-provisioning coverage, and a `wasteClass`
  tag for dedup candidates and over-provisioned volumes.
- **SQL / Windows Server license inventory (#127)** — `licenseInventory` domain
  enumerates guest SQL instances (edition, version, core count, license model,
  AHB eligibility) and Windows Server instances with totals.
- **Multi-cluster estate rollup (#129)** — `Invoke-AzureLocalRangerEstate` runs
  Ranger across an estate config and emits `estate-rollup.json`,
  `estate-summary.html`, and `powerbi/estate-clusters.csv`.
- **PowerPoint output (#80)** — `pptx` output format builds an OOXML .pptx
  via `System.IO.Packaging`. No Office dependency.
- **Manual evidence import (#32)** — `Import-RangerManualEvidence` merges
  hand-collected evidence into an existing manifest with provenance labels.

### Changed
- Runtime pipeline runs v2.5.0 analyzers after collectors and before schema
  validation so new domains are subject to the same checks.

## v2.3.0 — Cloud Publishing

Push Ranger run packages to Azure Blob and stream telemetry to Log Analytics
Workspace after every run — with no code changes required if the cluster is
already Arc-enrolled and the runner has Storage Blob Data Contributor.

### Added
- **Azure Blob publisher (#244)** — `Publish-RangerRun` uploads the run package
  (manifest, evidence, package-index, log, reports, powerbi) to Azure Blob with
  SHA-256 idempotency. Auth chain: Managed Identity → Entra RBAC → SAS from Key Vault.
  `Invoke-AzureLocalRanger -PublishToStorage` triggers automatically post-run.
- **Catalog + latest-pointer blobs (#245)** — after each publish, writes
  `_catalog/{cluster}/latest.json` and merges `_catalog/_index.json` so
  downstream consumers find the latest run without listing.
- **Log Analytics Workspace sink (#247)** — `Invoke-AzureLocalRanger -PublishToLogAnalytics`
  posts `RangerRun_CL` (scores, counts, AHB, cloud-publish status) and
  `RangerFinding_CL` (one row per failing WAF rule) to a DCE/DCR pair via
  the Logs Ingestion API.
- **Cloud Publishing guide (#246)** — `docs/operator/cloud-publishing.md` with
  step-by-step RBAC setup, config examples, and troubleshooting.
## v2.2.0 — WAF Compliance Guidance

Turn the WAF score from a static grade into an actionable roadmap: every rule
now carries a structured remediation block, and the report ranks fixes by
priority, projects your post-fix score, and can emit a copy-pasteable script.

### Added
- **Structured remediation block per WAF rule (#236)** — every rule in
  `config/waf-rules.json` now carries `remediation.{rationale, steps,
  samplePowerShell, estimatedEffort, estimatedImpact, dependencies, docsUrl}`.
  Reports surface a new "Next Step" column in Findings and a full Remediation
  Detail section per failing rule.
- **WAF Compliance Roadmap (#241)** — failing rules are bucketed into
  Now/Next/Later tiers by `priorityScore = (weight * severity * impact) / effort`.
  Rendered as a ranked table in the technical tier; exported as
  `powerbi/waf-roadmap.csv`.
- **Gap-to-Goal projection (#242)** — greedy fix-plan: *"Current 67%. Closing
  these 3 findings raises you to 82% (Excellent)."* Honours rule dependencies
  so prerequisites fix first. Exported as `powerbi/waf-gap-to-goal.csv`.
- **Per-pillar WAF Compliance Checklist (#238)** — one subsection per pillar
  with every rule, status, weight, effort, next step, and a Signed Off column
  for handoff / sprint artefact use. Exported as `powerbi/waf-checklist.csv`.
- **Get-RangerRemediation (#243)** — new public command emits a copy-pasteable
  remediation script from an existing manifest. Supports `-Format ps1|md|checklist`,
  `-Commit` for live cmdlets (dry-run by default), `-IncludeDependencies` to
  expand prerequisites, `-FindingId` to target specific rules.

### Changed
- `config/waf-rules.json` schema version bumped to `2.2.0` with a new
  `prioritization` block defining severity / impact / effort factors.
- Invoke-RangerWafRuleEvaluation now returns `roadmap` and `gapToGoal`
  alongside the existing `pillarScores` / `ruleResults`.

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

Auto-discovery of RG/FQDN, multi-method Azure auth, graceful degradation, PDF / DOCX tables / XLSX / Power BI exports, graduated WAF scoring. Full v1.6.0 and earlier release notes: https://github.com/AzureLocal/azurelocal-ranger/blob/main/CHANGELOG.md

Full history: https://github.com/AzureLocal/azurelocal-ranger/blob/main/CHANGELOG.md
'@
        }
    }
}
