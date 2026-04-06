# Status

Azure Local Ranger now has its v1 implementation foundation committed in the repository.

That means the runtime, manifest pipeline, grouped collectors, cached report generation, cached diagram generation, and fixture-backed tests are all present. It does **not** mean every detail from the long-form product-direction plan is fully realized yet.

## Current Position

| Area | Status | Summary |
| --- | --- | --- |
| Architecture and documentation foundation | Complete | Product, architecture, operator, output, contributor, and domain docs are in place |
| V1 runtime and collector implementation | Complete | Core runtime/output tracks and v1 collector tracks are implemented and closed in the backlog |
| Testing foundation | Complete | Fixture-backed unit and integration tests are in place for runtime and cached outputs |
| Product-plan richness and polish | In progress | Several plan areas still need deeper data depth, richer reports, richer diagrams, and live-environment proving |
| Post-v1 extension backlog | Deferred by design | Future-scope items remain tracked separately and are not part of the current implementation baseline |

## Delivered Now

- One public PowerShell module with layered internal architecture
- Manifest-first runtime with cached output generation
- V1 collectors for topology/cluster, hardware, storage/networking, workload/identity/Azure, monitoring, and management/performance
- HTML and Markdown report generation from saved manifests
- Draw.io-compatible diagram generation from saved manifests
- Public docs and contributor/operator guidance aligned to the current architecture
- Fixture-backed Pester coverage for config, runtime, outputs, and end-to-end package generation

## Still Being Refined

These areas are inside the product plan but still not at full intended depth:

- richer report content and handoff polish
- richer diagram semantics and environment-specific detail
- deeper collector payload coverage in several domains
- broader Azure authentication support
- live environment validation beyond fixture-backed testing

## Explicitly Deferred To Post-V1

The following areas are intentionally tracked outside the current implementation baseline:

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
