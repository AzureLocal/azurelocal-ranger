@{
    RootModule        = 'AzureLocalRanger.psm1'
    ModuleVersion     = '2.6.3'
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
## v2.6.3 — First-Run UX

Lowers the required-input floor to **tenantId + subscriptionId**, fills in the
rest via Azure Arc auto-discovery, and rebuilds the setup wizard with full
credential-method coverage and a proper YAML serializer.

### Added
- **Cluster node auto-discovery (#294)** — `Invoke-RangerAzureAutoDiscovery`
  now populates `targets.cluster.nodes` from Arc cluster `properties.nodes` or
  a subscription-wide Arc machines query. Short names are promoted to FQDNs
  using the discovered cluster domain suffix.
- **Three-field minimum invocation (#296)** — `Invoke-AzureLocalRanger` no
  longer requires `-ConfigPath` or `-ConfigObject`. Passing
  `-SubscriptionId -TenantId -ClusterName` on the command line (or any subset,
  with prompting for the rest in interactive mode) is enough to start a run.
- **Two-field cluster auto-select (#297)** — new `Select-RangerCluster`
  enumerates `microsoft.azurestackhci/clusters` in the subscription. Single
  clusters auto-select; multiples prompt an interactive menu; `-Unattended`
  and non-interactive hosts fail fast with `RANGER-DISC-002`. No HCI clusters
  throws `RANGER-DISC-001`; permission failures throw `RANGER-AUTH-001`.

### Changed
- **Scope-gated device credential prompting (#295)** —
  `Resolve-RangerCredentialMap` only prompts for BMC / switch / firewall
  credentials when the relevant collector is in scope AND a matching target
  list is populated. Explicit credential overrides are still honored even
  when the target list is empty.
- **Wizard overhaul (#291)** — `Invoke-RangerWizard` covers all six Azure
  auth strategies (existing-context, run-time prompt, service-principal with
  optional KV secret ref, managed-identity, device-code, azure-cli); GUID
  fields are validated inline and re-prompted; an optional BMC section adds
  iDRAC endpoints; a review screen prints the assembled YAML before save or
  run; existing files prompt for overwrite; and save now writes YAML via
  `ConvertTo-RangerYaml` by default — fixing the bug where `.yml` files
  contained JSON.

### Fixed
- **kv-ranger credential leak (#292)** — `Get-RangerDefaultConfig` no longer
  ships placeholder `keyvault://kv-ranger/*` password references for the
  `cluster`, `domain`, and `bmc` credential blocks. Missing credentials now
  fall through to the interactive prompt instead of producing a spurious KV
  DNS error from a vault the operator never configured.

## v2.6.2 — TRAILHEAD Bug Fixes (P7 Regression)

Bug-fix release addressing two issues found during TRAILHEAD P7 regression testing.

### Fixed
- **Config validator rejects pptx and json-evidence formats (#262)** —
  `Test-RangerConfiguration` now includes `pptx` and `json-evidence` in the
  `$supportedFormats` whitelist. These formats were added in v2.5.0 but omitted
  from validation, causing any config referencing them to be rejected.
- **New-AzureLocalRangerConfig YAML template has misindented fields (#263)** —
  `credentials.azure.method` and `behavior.promptForMissingRequired` in the
  generated YAML config template now have correct indentation, preventing YAML
  parse errors when the template is used as-is.

## v2.6.1 — TRAILHEAD Bug Fixes (P3 Live Validation)

Bug-fix release addressing failures discovered during TRAILHEAD live validation
against a 4-node Dell AX-760 Azure Local cluster.

### Fixed
- **Topology collector returns 0 nodes on partial WinRM failure (#259)** —
  `Invoke-RangerRemoteCommand` now executes each cluster node individually rather
  than batching all targets in one `Invoke-Command` call. A single-node Kerberos/
  Negotiate error (0x80090304) no longer aborts collection from healthy nodes.
- **licenseProfiles/default 404 causes transcript noise (#260)** —
  `Get-AzResource` for optional Arc license profiles now uses
  `-ErrorAction SilentlyContinue` so missing profiles (404) are returned as
  `not-found` status without being promoted to terminating errors.
- **Search-AzGraph 'Argument types do not match' (#261)** —
  `Get-RangerArmResourcesByGraph` now explicitly casts subscription and
  management-group arrays to `[string[]]`, fixing a type mismatch when
  subscription IDs originate from YAML parsing.

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
