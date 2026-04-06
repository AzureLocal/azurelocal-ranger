# Product Plan Implementation Tracker

This is the canonical internal tracker for comparing the Azure Local Ranger product plan to the implementation currently committed in the repository.

Use this file as the working source of truth for delivery status, audit updates, and remaining non-post-v1 gaps.

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
| Commit | `e294211` |
| Test command | `Import-Module .\AzureLocalRanger.psd1 -Force; Invoke-Pester -Path .\tests -PassThru` |
| Latest validated result | `8 passed, 0 failed` |
| Runtime/output issues closed | `#19`, `#22`, `#23`, `#24` |
| Discovery issues closed | `#9`, `#10`, `#11`, `#12`, `#20`, `#21`, `#16` |

## Overall Audit

| Plan Area | Product Plan Expectation | Current State | Status | Notes |
| --- | --- | --- | --- | --- |
| Product architecture | One public module with orchestration, shared services, collectors, and output layers | Delivered in `AzureLocalRanger.psd1`, `AzureLocalRanger.psm1`, `Modules/Core/20-Runtime.ps1`, `Modules/Private/10-Utilities.ps1`, `Modules/Public/10-Commands.ps1`, `Modules/Internal/01-Definitions.ps1` | Aligned | This is one of the strongest matches to the plan. |
| Manifest-first design | Collect once, render later from cached manifest only | Delivered | Aligned | Runtime saves `manifest/audit-manifest.json` via `Modules/Core/10-Manifest.ps1`; reports and diagrams consume cached manifest only. |
| Runtime/orchestration | Config loading, validation, credential resolution, domain selection, execution ordering, manifest assembly, persistence | Delivered | Aligned | This is the core of closed issue `#19`. |
| Selective domain execution | Include/exclude support; optional domains skipped by default; per-collector status in manifest | Delivered | Mostly aligned | Include/exclude and optional-skip behavior exist; variant-specific deep lighting is still fairly lightweight. |
| Connectivity model | WinRM, Redfish, Az/CLI for v1; Arc Run Command investigated later | Delivered for v1 basics | Mostly aligned | WinRM, Redfish, and Azure context/CLI paths exist. Arc Run Command is still not implemented, which is acceptable because the plan marks it as investigation rather than v1 dependency. |
| Authentication strategy | Parameter, Key Vault URI, interactive prompt; Azure support for interactive, service principal, managed identity, existing context | Partially delivered | Partial | Parameter override, Key Vault URI, and prompt flow exist. Azure auth breadth is thinner than the plan: existing context and managed identity are present, but service principal and explicit interactive `Connect-AzAccount` flow are not fully implemented. |
| Discovery breadth | Topology, cluster, hardware, storage, networking, VMs, identity/security, Azure integration, monitoring, management tools, performance | Delivered across six grouped collectors | Mostly aligned | Breadth is there, but several domains are still shallower than the plan's full data inventory. |
| Current-state mode | Leaner operational discovery output | Delivered | Aligned | Supported through mode plus cached output flow. |
| As-built mode | Richer formal handoff package from same discovery engine | Delivered structurally, not fully in depth | Partial | The mode exists, but the outputs are not yet as rich as the plan's handoff vision. |
| Report generation | 3 tiers, self-contained HTML and Markdown, findings, branding, TOC, deep audience-specific content | Delivered at baseline level | Partial | The three tiers exist in `Modules/Outputs/Reports/10-Reports.ps1`, but the actual report depth is much lighter than the plan describes. |
| Diagram generation | Baseline plus extended catalog, selection rules, skip behavior, draw.io XML, richer environment diagrams | Delivered at baseline engine level | Partial | All planned diagram names and selection rules are wired in `Modules/Internal/01-Definitions.ps1` and `Modules/Outputs/Diagrams/10-Diagrams.ps1`, but rendered content is still simplified compared to the plan's detailed diagram vision. |
| Testing strategy | Collector isolation, integration coverage, cached-manifest output tests, schema boundary, degraded and skip behavior | Delivered in meaningful part | Mostly aligned | Tests exist in `tests/unit/Config.Tests.ps1`, `tests/unit/Runtime.Tests.ps1`, `tests/unit/Outputs.Tests.ps1`, and `tests/integration/EndToEnd.Tests.ps1`. What is still thin is dedicated schema-boundary testing and broader degraded and live scenario coverage. |
| Documentation workstream | Public docs, operator docs, contributor docs, architecture docs, domain docs, output docs, diagrams | Delivered | Aligned | The docs foundation is present under `docs/`, including architecture, operator, contributor, outputs, and domain pages. |
| Live environment proof | Real Azure Local validation, not just mocked and fixture validation | Not done in this session | Partial | Current validation is strong fixture-backed testing, but not live-estate execution. |

## Domain-By-Domain Audit

| Domain | Plan Intent | Delivered Now | Status | Gap Against Full Plan |
| --- | --- | --- | --- | --- |
| Deployment topology and variant classification | Detect hyperconverged, switchless, local identity, disconnected, rack-aware, multi-rack and use it to drive behavior | Topology fields exist and drive outputs | Mostly aligned | Detection is still relatively simple and partly hint-driven; deep multi-rack and disconnected behavior is not fully realized. |
| Cluster and node foundation | Cluster identity, release, registration, node inventory, quorum, fault domains, networks, update and validation posture, events, health | Implemented in `Modules/Collectors/10-TopologyClusterCollector.ps1` | Partial | Missing fuller release, licensing, and lifecycle detail plus stronger `Test-Cluster` style validation history. |
| Dell hardware | Redfish-based hardware inventory and OEM posture | Implemented in `Modules/Collectors/20-HardwareCollector.ps1` | Partial | Good baseline, but not full endpoint depth from the plan: PCIe, power, thermal, broader management, and compliance details are not all normalized yet. |
| Storage | Pools, disks, cache, virtual disks, volumes, CSVs, SOFS, QoS, replica, storage health | Implemented in `Modules/Collectors/30-StorageNetworkingCollector.ps1` | Partial | Core coverage is there, but cache config, deeper storage-health posture, and richer capacity and resiliency modeling are thinner than the plan. |
| Networking | Adapters, vSwitches, ATC, host vNICs, proxy, DNS, firewall, SDN, host-side validation | Implemented in `Modules/Collectors/30-StorageNetworkingCollector.ps1` | Partial | Good host-side baseline; missing deeper network topology detail such as richer VLAN and subnet mapping, fabric dependency modeling, and broader logical-network and Arc networking depth. |
| Virtual machines | VM inventory, placement, config, replication, guest clustering, network and storage context | Implemented in `Modules/Collectors/40-WorkloadIdentityAzureCollector.ps1` | Partial | The basics are there; the plan's full VM depth is not. |
| Identity and security | AD-backed and local-identity posture, certificates, CredSSP, BitLocker, Defender, WDAC, secured-core, admin audit, audit policy | Implemented in `Modules/Collectors/40-WorkloadIdentityAzureCollector.ps1` | Partial | Covers several major signals, but WDAC, secured-core, richer AD and object modeling, and deeper local-identity and Key Vault flows are still incomplete. |
| Azure integration | Arc resources, resource groups, policy, backup, update, workload families, control-plane context | Implemented in `Modules/Collectors/40-WorkloadIdentityAzureCollector.ps1` | Partial | Resource discovery exists, but resource bridge, custom locations, extension-version detail, and fuller Azure-side topology are still shallow. |
| Monitoring and observability | Telemetry extension, AMA, DCR, DCE, HCI insights, alerts, health, Update Manager context | Implemented in `Modules/Collectors/50-MonitoringCollector.ps1` | Mostly aligned | Solid v1 baseline; still less rich than the full product-plan story. |
| OEM integration | Dell management and firmware posture relevant to Azure Local | Implemented alongside hardware collector | Partial | Present, but not yet the deep compliance, catalog, and support posture the plan describes. |
| Management tools | WAC, SCVMM, SCOM, OEM tools, third-party agents | Implemented in `Modules/Collectors/60-ManagementPerformanceCollector.ps1` | Partial | Tool and service discovery exists, but management-plane relationship depth is still limited. |
| Performance baseline | Compute, storage, network baseline plus event and outlier interpretation | Implemented in `Modules/Collectors/60-ManagementPerformanceCollector.ps1` | Partial | Good baseline collection, but not yet the deep technical and per-node analysis described by the plan. |

## Output Audit

| Output Area | Plan | Current State | Status | Main Gap |
| --- | --- | --- | --- | --- |
| Manifest | Stable audit contract and collector status model | Delivered in `Modules/Core/10-Manifest.ps1` and `Modules/Internal/01-Definitions.ps1` | Mostly aligned | Contract exists, but schema is still draft-level and not formalized as a separately validated schema artifact. |
| Report tiers | Executive, Management, Technical; rich, branded, audience-specific | Delivered in `Modules/Outputs/Reports/10-Reports.ps1` | Partial | Structure exists; content richness, branding, navigation, recommendation depth, and plan-specific sections are still lighter than intended. |
| Diagram catalog | 6 baseline plus 12 extended diagrams with variant-aware selection | Delivered in `Modules/Internal/01-Definitions.ps1` and `Modules/Outputs/Diagrams/10-Diagrams.ps1` | Mostly aligned | Catalog and rules exist, but the actual visual models are still simplified abstractions. |
| Package assembly | Manifest, reports, diagrams, package README, package index | Delivered | Aligned | This matches the runtime and output track well. |
| As-built package depth | Formal handoff-grade package with narrative clarity and completeness | Only baseline structural support today | Partial | The pipeline can build it, but the content is not yet at full handoff-grade richness. |

## Testing Audit

| Testing Expectation From Plan | Current State | Status |
| --- | --- | --- |
| Each collector executable in isolation | Collector functions are individually callable; fixtures support isolated use | Mostly aligned |
| Collectors unit-testable with mocked inputs | Fixture-backed strategy exists, but test coverage is still organized around config, runtime, output, and end-to-end flow more than one-test-per-collector | Partial |
| Orchestration integration-tested across multiple collectors | Delivered in `tests/integration/EndToEnd.Tests.ps1` | Aligned |
| Reports and diagrams tested from saved manifests only | Delivered in `tests/unit/Outputs.Tests.ps1` | Aligned |
| Schema validation as its own test boundary | Validation logic exists, but not as a strong independent schema and test asset | Partial |
| Failed and skipped collectors do not break successful ones | Runtime status model supports this in `Modules/Core/20-Runtime.ps1` | Mostly aligned |

## Documentation And Project-State Audit

| Area | Current State | Status | Notes |
| --- | --- | --- | --- |
| Public docs foundation | Delivered in `docs/` and `mkdocs.yml` | Aligned | Product, architecture, operator, outputs, contributor, and project docs are present. |
| Roadmap accuracy | Updated public roadmap exists in `docs/project/roadmap.md` | Mostly aligned | It now reflects completed foundation and v1 implementation, but should continue to be updated as remaining non-post-v1 work moves. |
| Public status summary | Delivered in `docs/project/status.md` | Aligned | This is the public-facing summary page. |
| Canonical internal tracker | Delivered in this file | Aligned | This file is the engineering source of truth for plan-vs-implementation comparison. |

## Remaining Non-Post-V1 Work Checklist

These items are still inside the product plan and are not part of the explicit post-v1 backlog.

| Priority | Item | Current State | Status | Suggested Next Move |
| --- | --- | --- | --- | --- |
| 1 | Deepen report content and handoff polish | Report engine exists, but outputs are still baseline | Not completed | Expand executive, management, and technical report sections to match the plan more closely, including stronger findings narrative, navigation, and visual polish. |
| 2 | Deepen diagram semantics and environment detail | Diagram engine and catalog exist, but models are simplified | Not completed | Enrich diagram models for fabric, storage, Azure hierarchy, trust flow, and management-plane relationships. |
| 3 | Expand cluster foundation payload depth | Collector exists, but lifecycle and validation detail is light | Not completed | Add release, licensing, validation history, and richer lifecycle context. |
| 4 | Expand Dell hardware payload depth | Collector exists, but endpoint normalization is not yet exhaustive | Not completed | Add fuller Redfish and OEM coverage including PCIe, thermal, power, and deeper compliance posture. |
| 5 | Expand storage payload depth | Collector exists, but cache, health, and resiliency detail are thin | Not completed | Add cache configuration, richer health signals, and clearer resiliency and capacity modeling. |
| 6 | Expand networking payload depth | Collector exists, but topology and fabric depth is limited | Not completed | Add richer VLAN, subnet, dependency, and logical-network modeling where retrievable. |
| 7 | Expand VM and workload payload depth | Collector exists, but plan-level data richness is not there yet | Not completed | Add guest clustering, deeper replication context, integration-service detail, and stronger workload correlation. |
| 8 | Expand identity and security coverage | Major signals exist, but not the full plan depth | Not completed | Add WDAC, secured-core, richer AD and OU posture, and stronger local-identity and secret-flow context. |
| 9 | Expand Azure integration depth | Core discovery exists, but control-plane detail is thinner than planned | Not completed | Add resource bridge, custom locations, richer extension detail, and stronger topology mapping. |
| 10 | Expand management-tools and performance depth | Baseline data exists | Not completed | Add richer tool-state relationships, deeper baselines, and better interpretation for handoff and reporting use. |
| 11 | Broaden Azure authentication support | Existing context and managed identity exist | Not completed | Add first-class service principal and explicit interactive Azure login flow. |
| 12 | Formalize schema validation boundary | Manifest contract is draft and implicit in code | Not completed | Create a stronger standalone schema and test asset and validate payload contracts independently. |
| 13 | Add broader degraded-scenario test coverage | Fixtures exist, but scenario breadth is still limited | Not completed | Add dedicated tests for partial, failed, skipped, and degraded collector states across more domains. |
| 14 | Validate against a real Azure Local environment | Not done in this session | Not completed | Run Ranger against a live estate and compare collected output to the plan and expected docs package. |

## Explicit Post-V1 Items

These items are intentionally deferred and should stay tracked through the separate post-v1 backlog rather than being treated as current delivery misses.

| Item | Backlog Reference | Status |
| --- | --- | --- |
| Azure-hosted automation worker execution model | `#25` | Planned later |
| Azure Arc Run Command alternate transport | `#26` | Planned later |
| Direct switch interrogation | `#27` | Planned later |
| Direct firewall interrogation | `#28` | Planned later |
| Non-Dell OEM support | `#29` | Planned later |
| Disconnected and limited-connectivity enrichment beyond current baseline | `#30` | Planned later |
| Multi-rack and management-cluster-specific enrichment beyond current baseline | `#31` | Planned later |
| Manual import workflows | `#32` | Planned later |
| Windows PowerShell 5.1 compatibility assessment | `#33` | Planned later |

## What This Means

If the benchmark is the issues that were explicitly targeted for the v1 runtime and discovery delivery tracks, the work is complete.

If the benchmark is the full long-form product-direction plan, the correct reading is:

1. The v1 implementation foundation is complete.
2. The breadth of the intended discovery surface is present.
3. The depth and polish of the final product vision are not yet complete.
4. The post-v1 backlog remains separate and should stay separate.

The most important non-post-v1 gaps are:

1. richer report output
2. richer diagram output
3. deeper collector payloads across several domains
4. broader Azure authentication support
5. live-estate validation

## Update Rule

When new work is delivered:

1. Update the relevant row in the audit tables.
2. Move any resolved item out of the remaining non-post-v1 checklist.
3. Keep post-v1 items in their own section unless scope has explicitly changed.
