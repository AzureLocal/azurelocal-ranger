@{
    RootModule        = 'AzureLocalRanger.psm1'
    ModuleVersion     = '2.6.5'
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
## v2.6.5 — Credential UX & Discovery Hardening

24 first-run friction and reliability issues found during live tplabs validation.

### Fixed
- **Credential prompt clarity (#302)** — prompts name the target system and expected account format.
- **WinRM silent-start (#303)** — WinRM service started automatically at run start.
- **Credential reuse (#304)** — domain credential reuses cluster credential when unconfigured.
- **Node FQDN resolver (#306)** — 4-step chain: pass-through → Arc map → cluster suffix → DNS.
- **Arc FQDN extraction (#308)** — `properties.dnsFqdn` fed into nodeFqdns map.
- **Cluster selection UX (#309)** — auto-selects and prints chosen cluster; numbered menu for multi-cluster.
- **Azure-first phase (#310)** — Azure discovery completes before any on-prem WinRM session opens.
- **FQDN overwrite fix (#311)** — `Resolve-RangerNodeInventory` no longer overwrites Arc-discovered FQDNs.
- **BMC interactive prompt (#312)** — iDRAC prompts before credentials when no endpoints configured.
- **LLDP passive reporting (#313)** — `Get-NetLldpNeighbor` replaces broken MSNdis WMI class.
- **`-NetworkDeviceConfigs` parameter (#314)** — exposed as direct CLI parameter on `Invoke-AzureLocalRanger`.
- **`-NetworkDeviceConfigs` directory expansion (#315)** — directory paths recursively expanded to config files.
- **Hardware collector auto-deselect (#316)** — excluded from scope when no BMC endpoints configured.
- **`tenantId` auto-fill (#317)** — filled from `(Get-AzContext).Tenant.Id` after cluster auto-discovery.
- **Log bootstrapping gap (#318)** — bootstrap-phase entries buffered and flushed to `ranger.log` with level filtering.
- **Run-mode prompt (#319)** — prompts for `current-state`/`as-built` when `-OutputMode` is not set.
- **`-Debug`/`-Verbose` (#320, #322, #328)** — log level elevated via `$PSBoundParameters`; terminal and log both receive debug entries.
- **BMC credential ordering (#326)** — BMC credential prompted immediately after IP entry, before WinRM credentials.
- **BMC prompt stores objects (#324)** — IPs stored as `{ host, node }` objects; hardware collector reads `.host`.
- **`-NetworkDeviceConfigs` path objects (#325)** — paths stored as `{ path }` objects; parser no longer warns on missing field.
- **Arc type mismatch (#327)** — `$subscriptionId`/`$clusterRg` cast to `[string]` before `Get-AzResource`.
- **Redfish 401 Unauthorized (#329)** — `Invoke-RangerRedfishRequest` passes `-Authentication Basic` to `Invoke-RestMethod`.
- **Console hashtable (#330)** — `Invoke-AzureLocalRanger` emits clean `Write-Host` summary instead of raw ordered hashtable.
- **WAF SEC-007 null calc (#331)** — no warning when AMA absent; warning preserved for missing calculation keys.
- **Network device report sections (#332)** — switchConfig/firewallConfig now rendered in HTML report.

## v2.6.4 — First-Run UX Patch

Completes v2.6.3 First-Run UX: fixes structural-placeholder leak in default config
that blocked bare `Invoke-AzureLocalRanger` even after answering prompts. Interactive
prompt re-runs auto-discovery between answers; prompt order leads with Azure identifiers;
fixture-mode bypass in config validation (#300).

## v2.6.3 — First-Run UX

Lowers required-input floor to tenantId + subscriptionId; rest filled via Arc
auto-discovery. Added cluster node auto-discovery (#294), 3-field minimum invocation
(#296), 2-field cluster auto-select (#297), scope-gated credential prompting (#295),
wizard overhaul with all 6 Azure auth strategies (#291). Fixed kv-ranger credential
leak (#292).

## v2.6.2 — TRAILHEAD Bug Fixes (P7 Regression)

`pptx`/`json-evidence` format validation fix (#262); YAML template indentation fix (#263).

## v2.6.1 — TRAILHEAD Bug Fixes (P3 Live Validation)

Per-node WinRM execution prevents single-node failure aborting collection (#259);
Arc license profile 404 suppressed (#260); Search-AzGraph type cast fix (#261).

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
Structured remediation blocks per rule, WAF compliance roadmap (Now/Next/Later),
gap-to-goal projection, per-pillar checklist, Get-RangerRemediation command.

## v2.1.0 — Preflight Hardening
Per-resource-type ARM probe, deep WinRM CIM probe (root/MSCluster +
root/virtualization/v2 + root/Microsoft/Windows/Storage), Azure Advisor read probe.

## v2.0.0 — Extended Collectors & WAF Intelligence
Seven new Arc-surface collectors (per-node extensions, logical networks +
subnets, storage paths, custom locations, Arc Resource Bridge, Arc Gateway,
marketplace + custom images), Azure Hybrid Benefit cost analysis, VM
distribution balance, agent version grouping, weighted WAF scoring,
hot-swap WAF config, `json-evidence` output format, concurrent-collection
and empty-data guards, and automatic required-module install/update.

## v1.6.0 — Platform Intelligence

Auto-discovery of RG/FQDN, multi-method Azure auth, graceful degradation, PDF / DOCX tables / XLSX / Power BI exports, graduated WAF scoring. Full v1.6.0 and earlier release notes: https://github.com/AzureLocal/azurelocal-ranger/blob/main/CHANGELOG.md

Full history: https://github.com/AzureLocal/azurelocal-ranger/blob/main/CHANGELOG.md
'@
        }
    }
}
