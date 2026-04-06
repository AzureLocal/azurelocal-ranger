# Product Plan Implementation Tracker

This is the canonical internal tracker for comparing the Azure Local Ranger product plan to the implementation currently committed in the repository.

Use this file as the working source of truth for delivery status, audit updates, and the remaining live-validation gap.

## How To Use This Tracker

- Update this file when implementation materially changes.
- Keep post-v1 items out of the main delivery gap count unless scope is explicitly pulled forward.
- Prefer concrete evidence such as files, tests, and issue closures over vague prose.
- Use `docs/project/status.md` for the public summary and keep the full engineering audit here.

## Status Legend

| Status | Meaning |
| --- | --- |
| Aligned | Delivered in a way that matches the current product-plan expectation closely enough to treat it as complete for this phase |
| Mostly aligned | Delivered at the intended architectural level, but still missing some depth, richness, or breadth from the plan |
| Partial | Implemented only at a baseline level and still visibly short of the product-plan expectation |
| Planned later | Explicitly deferred to post-v1 and not counted as a current delivery miss |

## Verification Reference

Current implementation validation used for this audit:

| Item | Value |
| --- | --- |
| Commit | `7a27ff7` |
| Test command | `Import-Module .\AzureLocalRanger.psd1 -Force; Invoke-Pester -Path .\tests -PassThru` |
| Latest validated result | `12 passed, 0 failed` |
| Runtime/output issues | `#19`, `#22`, `#23`, `#24` closed after local completion and verification |
| Discovery issues | `#9`, `#10`, `#11`, `#12`, `#16`, `#20`, `#21` closed after local completion and verification |
| Post-v1 definition issues | `#13`, `#25`-`#33` closed after decision documentation was captured |
| Remaining open issue | `#34` |

## Current Backlog State

| Scope | State |
| --- | --- |
| Non-live v1 implementation backlog | Complete and closed |
| Post-v1 definition backlog | Documented, deferred, and closed as planning issues |
| Live validation backlog | Open in `#34` |

## Overall Audit

| Plan Area | Product Plan Expectation | Current State | Status | Notes |
| --- | --- | --- | --- | --- |
| Product architecture | One public module with orchestration, shared services, collectors, and output layers | Delivered in `AzureLocalRanger.psd1`, `AzureLocalRanger.psm1`, `Modules/Core/20-Runtime.ps1`, `Modules/Private/10-Utilities.ps1`, `Modules/Public/10-Commands.ps1`, `Modules/Internal/01-Definitions.ps1` | Aligned | This is one of the strongest matches to the plan. |
| Manifest-first design | Collect once, render later from cached manifest only | Delivered | Aligned | Runtime saves `manifest/audit-manifest.json` via `Modules/Core/10-Manifest.ps1`; reports and diagrams consume cached manifest only. |
| Runtime/orchestration | Config loading, validation, credential resolution, domain selection, execution ordering, manifest assembly, persistence | Delivered | Aligned | This scope is complete for non-live validation and was closed under `#19`. |
| Selective domain execution | Include/exclude support; optional domains skipped by default; per-collector status in manifest | Delivered | Mostly aligned | Include/exclude and optional-skip behavior exist; variant-specific deep lighting is still fairly lightweight. |
| Connectivity model | WinRM, Redfish, Az/CLI for v1; Arc Run Command investigated later | Delivered for v1 basics | Mostly aligned | WinRM, Redfish, and Azure context/CLI paths exist. Arc Run Command is still not implemented, which is acceptable because the plan marks it as investigation rather than v1 dependency. |
| Authentication strategy | Parameter, Key Vault URI, interactive prompt; Azure support for interactive, service principal, managed identity, existing context | Delivered for non-live scope | Aligned | Existing context, managed identity, service principal, device-code interactive login, and Azure CLI fallback are now implemented in the runtime path. |
| Discovery breadth | Topology, cluster, hardware, storage, networking, VMs, identity/security, Azure integration, monitoring, management tools, performance | Delivered across six grouped collectors | Mostly aligned | Breadth is there, but several domains are still shallower than the plan's full data inventory. |
| Current-state mode | Leaner operational discovery output | Delivered | Aligned | Supported through mode plus cached output flow. |
| As-built mode | Richer formal handoff package from same discovery engine | Delivered for non-live scope | Mostly aligned | The shared pipeline and richer cached outputs are in place; live-estate proof still remains in `#34`. |
| Report generation | 3 tiers, self-contained HTML and Markdown, findings, branding, TOC, deep audience-specific content | Delivered for non-live scope | Aligned | Reports now include richer readiness, topology, recommendation, and technical depth sections from cached manifests only; the remaining question is live-estate fidelity in `#34`. |
| Diagram generation | Baseline plus extended catalog, selection rules, skip behavior, draw.io XML, richer environment diagrams | Delivered for non-live scope | Aligned | Diagram models now include richer domain-specific nodes, relationships, details, and extended output selection while remaining cached-manifest driven; live-estate correctness is still tracked in `#34`. |
| Testing strategy | Collector isolation, integration coverage, cached-manifest output tests, schema boundary, degraded and skip behavior | Delivered for non-live scope | Aligned | The suite now covers standalone schema validation, degraded collector scenarios, cached outputs, and end-to-end fixture packaging. |
| Documentation workstream | Public docs, operator docs, contributor docs, architecture docs, domain docs, output docs, diagrams | Delivered | Aligned | The docs foundation is present under `docs/`, including architecture, operator, contributor, outputs, and domain pages. |
| Live environment proof | Real Azure Local validation, not just mocked and fixture validation | Not done in this session | Partial | Current validation is strong fixture-backed testing, but not live-estate execution. |

## Domain-By-Domain Audit

| Domain | Plan Intent | Delivered Now | Status | Gap Against Full Plan |
| --- | --- | --- | --- | --- |
| Deployment topology and variant classification | Detect hyperconverged, switchless, local identity, disconnected, rack-aware, multi-rack and use it to drive behavior | Topology fields exist and drive outputs | Mostly aligned | Detection is still relatively simple and partly hint-driven; deep multi-rack and disconnected behavior is not fully realized. |
| Cluster and node foundation | Cluster identity, release, registration, node inventory, quorum, fault domains, networks, update and validation posture, events, health | Implemented in `Modules/Collectors/10-TopologyClusterCollector.ps1` | Aligned | Release, licensing, registration, lifecycle, and validation-report context are now included in the cluster payload. |
| Dell hardware | Redfish-based hardware inventory and OEM posture | Implemented in `Modules/Collectors/20-HardwareCollector.ps1` | Mostly aligned | Dell OEM posture now captures update-service, lifecycle-controller, support signals, and compliance hints; deeper per-vendor breadth remains future OEM work. |
| Storage | Pools, disks, cache, virtual disks, volumes, CSVs, SOFS, QoS, replica, storage health | Implemented in `Modules/Collectors/30-StorageNetworkingCollector.ps1` | Mostly aligned | Storage tiers, resiliency defaults, jobs, and richer capacity posture are now included for non-live validation scope. |
| Networking | Adapters, vSwitches, ATC, host vNICs, proxy, DNS, firewall, SDN, host-side validation | Implemented in `Modules/Collectors/30-StorageNetworkingCollector.ps1` | Mostly aligned | IP, route, VLAN, proxy, DNS, firewall, and SDN host-side evidence are now normalized together for report and diagram use. |
| Virtual machines | VM inventory, placement, config, replication, guest clustering, network and storage context | Implemented in `Modules/Collectors/40-WorkloadIdentityAzureCollector.ps1` | Mostly aligned | Integration-service and deeper replication context are now included; guest-cluster enrichment remains bounded by non-live host-side evidence. |
| Identity and security | AD-backed and local-identity posture, certificates, CredSSP, BitLocker, Defender, WDAC, secured-core, admin audit, audit policy | Implemented in `Modules/Collectors/40-WorkloadIdentityAzureCollector.ps1` | Mostly aligned | AD, AppLocker, secure boot, and Key Vault reference context are now included alongside the baseline posture. |
| Azure integration | Arc resources, resource groups, policy, backup, update, workload families, control-plane context | Implemented in `Modules/Collectors/40-WorkloadIdentityAzureCollector.ps1` | Mostly aligned | Resource bridge, custom locations, extensions, Arc machines, and site recovery context are now modeled where retrievable. |
| Monitoring and observability | Telemetry extension, AMA, DCR, DCE, HCI insights, alerts, health, Update Manager context | Implemented in `Modules/Collectors/50-MonitoringCollector.ps1` | Mostly aligned | Solid v1 baseline; still less rich than the full product-plan story. |
| OEM integration | Dell management and firmware posture relevant to Azure Local | Implemented alongside hardware collector | Mostly aligned | Dell-specific management, lifecycle, firmware, and compliance-adjacent posture are now modeled for non-live scope; broader vendor depth remains post-v1. |
| Management tools | WAC, SCVMM, SCOM, OEM tools, third-party agents | Implemented in `Modules/Collectors/60-ManagementPerformanceCollector.ps1` | Mostly aligned | Tool-state discovery, summary shaping, and management-plane interpretation are in place for non-live reporting and handoff. |
| Performance baseline | Compute, storage, network baseline plus event and outlier interpretation | Implemented in `Modules/Collectors/60-ManagementPerformanceCollector.ps1` | Mostly aligned | Baseline metrics, summaries, outliers, and event context are now shaped for non-live reporting; live-estate proof remains separate. |

## Output Audit

| Output Area | Plan | Current State | Status | Main Gap |
| --- | --- | --- | --- | --- |
| Manifest | Stable audit contract and collector status model | Delivered in `Modules/Core/10-Manifest.ps1` and `Modules/Internal/01-Definitions.ps1` | Aligned | The manifest now has a standalone schema contract in `repo-management/contracts/manifest-schema.json` and runtime validation against it. |
| Report tiers | Executive, Management, Technical; rich, branded, audience-specific | Delivered in `Modules/Outputs/Reports/10-Reports.ps1` | Mostly aligned | Structure, navigation, recommendations, and audience-specific sections are materially richer now; live-estate proof remains the last unresolved question. |
| Diagram catalog | 6 baseline plus 12 extended diagrams with variant-aware selection | Delivered in `Modules/Internal/01-Definitions.ps1` and `Modules/Outputs/Diagrams/10-Diagrams.ps1` | Aligned | Catalog, selection rules, and richer domain-specific models are implemented for cached-manifest generation. |
| Package assembly | Manifest, reports, diagrams, package README, package index | Delivered | Aligned | This matches the runtime and output track well. |
| As-built package depth | Formal handoff-grade package with narrative clarity and completeness | Only baseline structural support today | Partial | The pipeline can build it, but the content is not yet at full handoff-grade richness. |

## Testing Audit

| Testing Expectation From Plan | Current State | Status |
| --- | --- | --- |
| Each collector executable in isolation | Collector functions are individually callable; fixtures support isolated use | Mostly aligned |
| Collectors unit-testable with mocked inputs | Fixture-backed strategy exists across healthy and degraded scenarios | Mostly aligned |
| Orchestration integration-tested across multiple collectors | Delivered in `tests/integration/EndToEnd.Tests.ps1` | Aligned |
| Reports and diagrams tested from saved manifests only | Delivered in `tests/unit/Outputs.Tests.ps1` | Aligned |
| Schema validation as its own test boundary | Standalone manifest schema contract plus runtime and test validation | Aligned |
| Failed and skipped collectors do not break successful ones | Runtime status model supports this in `Modules/Core/20-Runtime.ps1` | Mostly aligned |

## Documentation And Project-State Audit

| Area | Current State | Status | Notes |
| --- | --- | --- | --- |
| Public docs foundation | Delivered in `docs/` and `mkdocs.yml` | Aligned | Product, architecture, operator, outputs, contributor, and project docs are present. |
| Roadmap accuracy | Updated public roadmap exists in `docs/project/roadmap.md` | Aligned | It now reflects that only live-estate validation remains open and that post-v1 definition work is documented and deferred. |
| Public status summary | Delivered in `docs/project/status.md` | Aligned | This is the public-facing summary page. |
| Canonical internal tracker | Delivered in this file | Aligned | This file is the engineering source of truth for plan-vs-implementation comparison. |

## Remaining Work Checklist

All non-live work from the previously open backlog has been completed locally and verified with the fixture-backed test suite.

The only remaining item is live-estate validation.

| Priority | Item | Current State | Status | Suggested Next Move |
| --- | --- | --- | --- | --- |
| 1 | Validate against a real Azure Local environment | Not done in this session; tracked in `#34` | Not completed | Run Ranger against a live estate and compare collected output to the plan and expected docs package. |

## Explicit Post-V1 Items

These items are intentionally deferred and were closed as planning and decision records. They remain future implementation areas, not current delivery misses.

| Item | Backlog Reference | Status |
| --- | --- | --- |
| Azure-hosted automation worker execution model | `#25` | Defined and deferred |
| Azure Arc Run Command alternate transport | `#26` | Defined and deferred |
| Direct switch interrogation | `#27` | Defined and deferred |
| Direct firewall interrogation | `#28` | Defined and deferred |
| Non-Dell OEM support | `#29` | Defined and deferred |
| Disconnected and limited-connectivity enrichment beyond current baseline | `#30` | Defined and deferred |
| Rack-aware and management-cluster-specific enrichment beyond current baseline | `#31` | Defined and deferred |
| Manual import workflows | `#32` | Defined and deferred |
| Windows PowerShell 5.1 compatibility assessment | `#33` | Defined and deferred |

## What This Means

If the benchmark is the baseline implementation targeted by the original v1 runtime and discovery delivery tracks, that baseline exists in the repo.

If the benchmark is the full long-form product-direction plan, the correct reading is:

1. The non-live v1 implementation backlog is complete locally and test-verified.
2. The breadth of the intended discovery surface is present and materially deeper than the earlier baseline.
3. Cached reports, diagrams, schema validation, and degraded-scenario tests are now part of the verified baseline.
4. The post-v1 backlog remains separate, documented, and deferred by explicit decision rather than vague scope.

The remaining non-post-v1 gap is:

1. live-estate validation

## Update Rule

When new work is delivered:

1. Update the relevant row in the audit tables.
2. Move any resolved item out of the remaining non-post-v1 checklist.
3. Keep post-v1 items in their own section unless scope has explicitly changed.
