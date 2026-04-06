# Status

Azure Local Ranger now has its v1 implementation foundation committed in the repository.

That means the runtime, manifest pipeline, grouped collectors, cached report generation, cached diagram generation, schema-validation boundary, and fixture-backed tests are all present. The only remaining open implementation item is validation against a real Azure Local environment.

## Current Position

| Area | Status | Summary |
| --- | --- | --- |
| Architecture and documentation foundation | Complete | Product, architecture, operator, output, contributor, and domain docs are in place |
| V1 runtime and collector implementation | Complete | Core runtime/output tracks and v1 collector tracks are implemented and locally verified |
| Testing foundation | Complete | Fixture-backed unit and integration tests, degraded-scenario tests, standalone manifest-schema validation, and simulation testing framework are in place (18 passing tests) |
| Product-plan richness and polish | Complete for non-live scope | Remaining implementation work is now limited to live-environment proving |
| Post-v1 extension backlog | Defined, documented, and deferred | Future-scope items are documented explicitly and their definition issues are complete |

## Delivered Now

- One public PowerShell module with layered internal architecture
- Manifest-first runtime with cached output generation
- V1 collectors for topology/cluster, hardware, storage/networking, workload/identity/Azure, monitoring, and management/performance
- HTML and Markdown report generation from saved manifests with richer audience-specific sections
- Draw.io-compatible diagram generation from saved manifests with deeper domain modeling (18 defined diagrams across baseline and extended tiers)
- Standalone manifest schema contract and runtime validation against that contract
- Public docs and contributor/operator guidance aligned to the current architecture
- Fixture-backed Pester coverage for config, runtime, outputs, degraded scenarios, and end-to-end package generation (18 passing tests)
- Scout-style simulation testing framework driven by a pre-committed IIC synthetic manifest — full render pipeline validated without any live connections

## Remaining Open Item

The only remaining GitHub issue and implementation item still open is:

- live environment validation beyond fixture-backed testing in #34

## Explicitly Deferred To Post-V1

The following areas are intentionally defined and deferred outside the current implementation baseline:

- direct switch interrogation
- direct firewall interrogation
- non-Dell OEM support
- Azure Arc Run Command alternate transport
- deeper disconnected and multi-rack enrichment
- manual import workflows
- Windows PowerShell 5.1 compatibility assessment

## Read Next

- [Roadmap](roadmap.md)
- [Repository Structure](repository-structure.md)
- [Documentation Roadmap](documentation-roadmap.md)
