# Project Status

## Current Release Track — v2.6.5

AzureLocalRanger v2.6.5 — Credential UX & Discovery Hardening — closes 19 first-run friction and reliability issues found during live tplabs validation. Key improvements: credential prompts now name the target system and expected account format (#302); WinRM starts silently during preflight (#303); domain credential reuses the cluster credential when unconfigured (#304); Arc auto-discovery extracts per-node FQDNs from `properties.dnsFqdn` (#308); node FQDN resolution follows a 4-step chain (#306); cluster auto-selection prints a numbered menu for multi-cluster subscriptions (#309); Azure discovery runs to completion before any on-prem WinRM session opens (#310); node inventory no longer overwrites FQDNs set by auto-discovery (#311); BMC endpoints are prompted interactively when missing (#312); LLDP uses `Get-NetLldpNeighbor` with WMI fallback (#313); `-NetworkDeviceConfigs` is now a direct CLI parameter (#314); directory paths are recursively expanded to config files (#315); the hardware collector no longer appears as `skipped` when no BMC is configured (#316); `tenantId` is auto-filled from the active Az session after cluster discovery (#317); the log bootstrapping gap is closed — config load, auto-discovery, and validation entries now appear in every run log (#318); interactive sessions now prompt for run mode when `-OutputMode` is not supplied (#319); `-Debug`/`-Verbose` now correctly elevate log file verbosity to debug level (#320); `-Debug`/`-Verbose` entries now appear in both the running terminal and the log file — `Write-RangerLog` forces `$VerbosePreference = 'Continue'` locally via a module-scope flag set from `Invoke-AzureLocalRanger` (#328); the BMC credential is now prompted immediately after BMC IP entry instead of after the WinRM cluster credential (#326); the interactive BMC prompt now stores IPs as `{ host }` objects so the hardware collector can actually read them (#324); `-NetworkDeviceConfigs` paths are wrapped as `{ path }` objects so the networking parser no longer warns "missing path field" (#325); the `-Debug`/`-Verbose` preference-variable propagation bug is definitively fixed — detection moved to `$PSBoundParameters` in `Invoke-AzureLocalRanger` and injected through structural overrides so `ranger.log` actually receives debug entries (#322); Arc node discovery no longer throws "Argument types do not match" when subscription/resource-group values come from YAML parsing (#327); BMC Redfish requests now use `-Authentication Basic` so iDRAC endpoints respond instead of returning 401 (#329); the run-complete hashtable no longer auto-prints to the terminal — a clean collector-outcome summary is emitted instead (#330); WAF rule SEC-007 no longer warns about `amaCoveragePct` being null when AMA is simply not deployed — the expected-absent case is now logged at debug level (#331); external module verbose output (Invoke-RestMethod HTTP tracing, PackageManagement, CIM) is now captured in `ranger.log` when running with `-Debug`/`-Verbose` — a `global:Write-Verbose` proxy mirrors the existing `global:Write-Warning` proxy (#332); the hardware collector no longer probes iDRAC IPs with WinRM when no matching cluster node FQDN was resolved — VBS/DeviceGuard/OMI sub-collection is skipped with a debug log entry instead of a 45-second TCP timeout (#333); imported switch and firewall configs from `-NetworkDeviceConfigs` now appear in the technical report as **Imported Switch Configurations** and **Imported Firewall Configurations** table sections (#334). Milestone: [#32](https://github.com/AzureLocal/azurelocal-ranger/milestone/32). v2.6.4 — First-Run UX Patch — remains the previous release.

## Previous Release — v2.6.4 — First-Run UX Patch

AzureLocalRanger v2.6.4 — First-Run UX Patch — fixes a structural-placeholder leak in `Get-RangerDefaultConfig` that blocked the 2-field / zero-config invocation path advertised in v2.6.3. Bare `Invoke-AzureLocalRanger` (and `-SubscriptionId x -TenantId y` alone) now complete the run — `Get-RangerDefaultConfig` no longer ships scaffold values for `environment.name`, `clusterName`, `cluster.fqdn`, `azure.subscriptionId`/`tenantId`/`resourceGroup`, and so on; `Invoke-RangerInteractiveInput` now re-runs `Invoke-RangerAzureAutoDiscovery` between prompts so answering subscription + tenant unlocks `Select-RangerCluster` on the next pass; and `Get-RangerMissingRequiredInputs` lists Azure identifiers before auto-discoverable fields (#300). v2.6.3 — First-Run UX — remains the previous release.

## Previous Release — v2.6.3 — First-Run UX

AzureLocalRanger v2.6.3 — First-Run UX — drops the required-input floor to two fields (tenantId + subscriptionId), fills in the rest via Azure Arc auto-discovery, and rebuilds the setup wizard with full credential-method coverage and a proper YAML serializer. Key additions: cluster node auto-discovery from Arc (#294); three-field minimum invocation that works without a config file (#296); two-field cluster auto-select enumerating HCI clusters in the subscription with `RANGER-DISC-*` / `RANGER-AUTH-*` error codes (#297); scope-gated BMC / switch / firewall credential prompting (#295); wizard overhaul covering all six Azure auth methods, GUID validation, BMC section, review screen, overwrite guard, and the YAML-writes-as-JSON bug fix (#291); and the kv-ranger credential leak fix in the default config (#292). v2.6.2 — TRAILHEAD Bug Fixes — remains the previous release.

## Previous Release — v2.6.2 — TRAILHEAD Bug Fixes

AzureLocalRanger v2.6.2 — TRAILHEAD Bug Fixes (P7 Regression) — fixes two issues found during TRAILHEAD P7 regression: `Test-RangerConfiguration` now accepts `pptx` and `json-evidence` in the output format whitelist (#262); and the YAML config template generated by `New-AzureLocalRangerConfig` now has correctly indented `credentials.azure.method` and `behavior.promptForMissingRequired` fields (#263). v2.6.1 — TRAILHEAD Bug Fixes — remains the previous release.

## Previous Release — v2.6.1 — TRAILHEAD Bug Fixes

AzureLocalRanger v2.6.1 — TRAILHEAD Bug Fixes (P3 Live Validation) — fixes three failures discovered during TRAILHEAD live validation against a 4-node Dell AX-760 Azure Local cluster: `Invoke-RangerRemoteCommand` now executes each cluster node individually so a single Kerberos/Negotiate failure (0x80090304) no longer aborts collection from healthy nodes (#259); `Get-AzResource` for optional Arc license profiles now uses `-ErrorAction SilentlyContinue` so missing `licenseProfiles/default` resources are handled as `not-found` without transcript noise (#260); and `Get-RangerArmResourcesByGraph` now casts subscription and management-group arrays to `[string[]]`, fixing a type mismatch when subscription IDs originate from YAML parsing (#261). v2.5.0 — Extended Platform Coverage — remains the previous release.

## Previous Release — v2.5.0 — Extended Platform Coverage

AzureLocalRanger v2.5.0 — Extended Platform Coverage — closes the long-standing operator backlog with workload/cost intelligence, multi-cluster orchestration, and presentation-ready output. Key additions: capacity headroom analyzer with per-node + cluster totals and Healthy/Warning/Critical status (#128); idle / underutilized VM detection with rightsizing proposals (#125); storage efficiency analysis surfacing dedup and thin-provisioning coverage (#126); SQL / Windows Server license inventory for compliance reporting (#127); `Invoke-AzureLocalRangerEstate` multi-cluster rollup with per-cluster + estate-level summary (#129); PowerPoint `.pptx` output format built directly via `System.IO.Packaging` with no Office dependency (#80); and `Import-RangerManualEvidence` for merging hand-collected evidence into the audit manifest with provenance labels (#32). v2.3.0 — Cloud Publishing — remains the previous release.

## Previous Release — v2.3.0 — Cloud Publishing

AzureLocalRanger v2.3.0 — Cloud Publishing — pushes Ranger run packages to Azure Blob Storage and streams distilled telemetry to Log Analytics Workspace after every run, with no code changes required if the runner has Storage Blob Data Contributor. Key additions: `Publish-RangerRun` command with Managed Identity / Entra RBAC / Key-Vault SAS auth chain and SHA-256 idempotency (#244); `_catalog/{cluster}/latest.json` + `_catalog/_index.json` catalog blobs updated per run (#245); cloud publishing guide + samples (#246); `RangerRun_CL` and `RangerFinding_CL` rows posted to a DCE/DCR pair via the Logs Ingestion API (#247). v2.2.0 — WAF Compliance Guidance — remains the previous release.

## Previous Release — v2.2.0 — WAF Compliance Guidance

AzureLocalRanger v2.2.0 — WAF Compliance Guidance — is the previous release. It turns the WAF score from a static grade into an actionable roadmap: every rule now carries a structured `remediation` block (rationale, steps, sample PowerShell, effort, impact, dependencies, docs URL — #236); a new Compliance Roadmap bucket ranks failing rules into Now / Next / Later tiers by `priorityScore = (weight × severity × impact) / effort` (#241); a Gap-to-Goal projection emits a greedy fix plan showing the projected score after closing the top N findings (#242); a per-pillar Compliance Checklist section ships a sign-able handoff artefact with one subsection per WAF pillar (#238); and a new public `Get-RangerRemediation` command emits copy-pasteable `.ps1` / markdown / checklist remediation scripts, substituting `$ClusterName` / `$ResourceGroup` / `$SubscriptionId` / `$Region` / `$NodeName` from the manifest with `-Commit` for live cmdlets (#243). v2.1.0 — Preflight Hardening — remains the previous release.

## Previous Release — v2.1.0 — Preflight Hardening

AzureLocalRanger v2.1.0 — Preflight Hardening — closes the three auth / preflight gaps identified against v2.0.0 so RBAC and credential problems surface up-front instead of mid-run: per-resource-type ARM probe (#235), deep WinRM CIM probe (#234), and an Azure Advisor read probe (#233). All three probes are skipped in fixture mode.

## Previous Release — v2.0.0 — Extended Collectors & WAF Intelligence

AzureLocalRanger v2.0.0 — Extended Collectors & WAF Intelligence — lands seven new Arc-surface collectors (per-node extensions, logical networks + subnets, storage paths, custom locations, Arc Resource Bridge, Arc Gateway, marketplace + custom images), Azure Hybrid Benefit cost and savings analysis with dated pricing footer, VM distribution balance via coefficient-of-variation, Arc agent + OS version grouping with drift detection, weighted WAF scoring (rule weight 1–3 + warning-as-half-weight + score thresholds), hot-swap WAF config via `Export-RangerWafConfig` / `Import-RangerWafConfig`, a `json-evidence` raw-inventory output format, concurrent-collection and empty-data reliability guards, automatic required-module install/update on startup, portrait/landscape PDF switching, and conditional status-cell coloring across all tables.

## Previous Release — v1.6.0 — Platform Intelligence

AzureLocalRanger v1.6.0 — Platform Intelligence — lands auto-discovery of resource group and cluster FQDN (from Azure Arc and from on-prem TrustedHosts / DNS fallbacks), a multi-method Azure auth chain (service-principal-cert, tenant-matching context reuse, sovereign-cloud), a dedicated pre-run permission audit (`Test-RangerPermissions` with `-SkipPreCheck` opt-out), cross-RG node fallback, Azure Resource Graph single-query discovery, graceful degradation on partial Azure permissions, file-based progress IPC for background runspaces, high-fidelity PDF rendering via headless Edge, DOCX OOXML tables, XLSX formula-injection safety, a Power BI CSV + star-schema export, and graduated WAF threshold scoring.

```powershell
Install-Module AzureLocalRanger -Force
Import-Module AzureLocalRanger
```

| Area | State |
| --- | --- |
| Module structure | ✅ Complete |
| Core orchestration | ✅ Complete |
| Identity collectors | ✅ Complete |
| Networking collectors | ✅ Complete |
| Storage collectors | ✅ Complete |
| Azure integration collectors | ✅ Complete |
| Hyper-V collectors | ✅ Complete |
| GPO collectors | ✅ Complete |
| Manifest assembly | ✅ Complete |
| Arc Run Command transport | ✅ Complete — auto/winrm/arc transport modes, Az.ConnectedMachine fallback |
| Disconnected discovery | ✅ Complete — pre-run connectivity matrix, graceful skip, posture classification |
| Spectre TUI progress | ✅ Complete — PwshSpectreConsole live bars, Write-Progress fallback, CI-safe |
| Interactive wizard | ✅ Complete — Invoke-RangerWizard guided config + run |
| Full config parameter coverage | ✅ Complete — every config key is a runtime parameter on Invoke-AzureLocalRanger |
| Operator guide docs | ✅ Complete — First Run, Wizard Guide, Configuration Reference, Understanding Output |
| HTML report rebuild | ✅ Complete — type-aware table/kv/sign-off rendering, inventory tables (#168) |
| Diagram engine quality | ✅ Complete — group containers, per-kind styles, SVG + draw.io (#140) |
| PDF output | ✅ Complete — cover page, type-aware plain-text sections (#96) |
| WAF Assessment integration | ✅ Complete — Azure Advisor + manifest rule engine, 23 built-in rules (#94) |
| Pester test suite | ✅ 129 tests passing (76 baseline + 28 v2.0.0 + 8 v2.1.0 + 17 v2.2.0) |
| Field validation (TRAILHEAD) | ✅ v1.4.2 gate closed — all 7 collectors, 76/76 Pester, 33-file output, WAF rule engine confirmed. v1.5.0 is a doc-quality stabilisation on the same engine |
| As-built document redesign | ✅ Complete — Installation and Configuration Record with per-node/network/storage/Azure/identity/validation/deviations records (#193) |
| Mode differentiation (as-built vs current-state) | ✅ Complete — distinct tier titles, classification banners, subtitles, mode-specific section suppression (#194) |
| HTML report visual quality | ✅ Complete — inline architecture diagrams, fixed-layout tables, severity callouts, print CSS, sign-off signature lines (#192) |
| Report output (HTML/Markdown/JSON/DOCX/XLSX/PDF) | ✅ Complete |
| Diagram output (SVG/draw.io) | ✅ Complete |
| PSGallery release | ✅ `2.1.0` on PSGallery; `2.2.0` ready for publish |
| Azure auto-discovery (RG + FQDN) | ✅ Complete — Arc-first with TrustedHosts / DNS on-prem fallback (#196, #197, #203) |
| Multi-method Azure auth chain | ✅ Complete — SPN cert, SPN secret, MI, device-code, existing-context with tenant-match reuse, sovereign-cloud env (#200) |
| Pre-run permission audit | ✅ Complete — `Test-RangerPermissions`, default-on with `-SkipPreCheck` opt-out (#202, #212) |
| Cross-RG node/VM fallback | ✅ Complete — Arc machines query with subscription-wide fallback (#204) |
| Azure Resource Graph fast path | ✅ Complete — `Search-AzGraph` single query with Get-AzResource fallback (#205) |
| Graceful ARM degradation | ✅ Complete — error classifier, skipped-resources tracker, `behavior.failOnPartialDiscovery` gate (#206) |
| Headless-browser PDF | ✅ Complete — Edge / Chrome `--print-to-pdf` with plain-text fallback (#207) |
| Word (DOCX) OOXML tables | ✅ Complete — `table` / `kv` / `sign-off` render as real Word tables (#208) |
| Power BI CSV + star-schema | ✅ Complete — nodes/volumes/pools/health-checks/adapters + `_relationships.json` (#210) |
| Graduated WAF scoring | ✅ Complete — threshold bands, named aggregate calculations (#214) |
| Arc-first node inventory | ✅ Complete |
| Domain auto-detection | ✅ Complete |
| Parameter-first input model | ✅ Complete |
| File-based logging | ✅ Complete |

## Operation TRAILHEAD

Field validation is structured as **Operation TRAILHEAD** — an eight-phase test cycle covering preflight, authentication, connectivity, individual collectors, data quality, reporting, and end-to-end scenarios. The gate issue remains the milestone-close checkpoint.

## Roadmap

See the [Roadmap](roadmap.md) for post-v1 work, including PowerPoint output, firewall collector expansion, and richer operator experiences.

## Changelog

See the [Changelog](changelog.md) for a full version history.
