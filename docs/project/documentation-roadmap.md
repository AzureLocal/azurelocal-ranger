# Documentation Roadmap

This page tracks the maturity and completion status of every page in the Ranger documentation site.
It is intended for contributors and maintainers who want to understand which areas need attention.

See [Roadmap](roadmap.md) for feature and release tracking, and [Getting Started](../contributor/getting-started.md) for how to contribute documentation.

## Maturity Key

| Badge | Meaning |
| --- | --- |
| `complete` | Reflects current implementation, reviewed, no known gaps |
| `draft` | Functional content exists; may have gaps relative to current implementation or collector depth |
| `stub` | Placeholder — structure exists but full content has not yet been written |

---

## Home

| Page | Path | Maturity | Notes |
| --- | --- | --- | --- |
| Home | `docs/index.md` | `draft` | Overview and quick-start links; collector depth not yet reflected |

---

## Product

| Page | Path | Maturity | Notes |
| --- | --- | --- | --- |
| What Ranger Is | `docs/what-ranger-is.md` | `complete` | Core value proposition, audience definitions, non-goals |
| Ranger vs Scout | `docs/ranger-vs-scout.md` | `draft` | Positioning complete; may need update after v1 feature set is locked |
| Scope Boundary | `docs/scope-boundary.md` | `draft` | Tier model defined; Tier 4 offline config parsing vs. manual import distinction needs final wording (tracked as [#52](https://github.com/AzureLocal/azurelocal-ranger/issues/52)) |
| Deployment Variants | `docs/deployment-variants.md` | `complete` | All four variants (local, Azure VM, GitHub Actions, Automation) documented |

---

## Architecture

| Page | Path | Maturity | Notes |
| --- | --- | --- | --- |
| System Overview | `docs/architecture/system-overview.md` | `draft` | High-level diagram present; collector depth enhancements from v0.5-v1 not yet reflected |
| How Ranger Works | `docs/architecture/how-ranger-works.md` | `complete` | Runtime flow, manifest-first pipeline, safe-action pattern — accurate to current implementation |
| Audit Manifest | `docs/architecture/audit-manifest.md` | `complete` | Schema contract, domain structure, versioning, and validation workflow |
| Implementation Architecture | `docs/architecture/implementation-architecture.md` | `complete` | Module layout, layering, orchestrator/collector/output separation |
| Configuration Model | `docs/architecture/configuration-model.md` | `complete` | Full config file reference including credential map and Key Vault refs |
| Repository Design | `docs/architecture/repository-design.md` | `draft` | Folder tree accurate; contributor flow section needs expansion |

---

## Discovery Domains

| Page | Path | Maturity | Notes |
| --- | --- | --- | --- |
| Cluster and Node | `docs/discovery-domains/cluster-and-node.md` | `draft` | CAU depth, LCM/Solution Update stack, Arc registration, and pending updates added in v0.5+ — docs not yet updated |
| Hardware | `docs/discovery-domains/hardware.md` | `draft` | Per-DIMM, GPU, VBS sub-components, BMC SSL cert, and physical disk slot data added in v0.5+ — docs not yet updated |
| Storage | `docs/discovery-domains/storage.md` | `draft` | Health faults, QoS flows, SOFS ACL/ABE/quotas, Storage Replica depth added in v0.5+ — docs not yet updated |
| Networking | `docs/discovery-domains/networking.md` | `draft` | DCB/RDMA depth, ATC override detail, and LLDP detection added in v0.5+ — docs not yet updated |
| Virtual Machines | `docs/discovery-domains/virtual-machines.md` | `draft` | VM checkpoints, SR-IOV NIC depth, and guest cluster heuristic added in v0.5+ — docs not yet updated |
| Identity and Security | `docs/discovery-domains/identity-and-security.md` | `draft` | BitLocker protector types, WDAC detail, Defender AV depth, Entra hybrid join added in v0.5+ — docs not yet updated |
| Azure Integration | `docs/discovery-domains/azure-integration.md` | `draft` | ARB detail, AKS clusters, AVD host pools, policy compliance, ASR, Backup added in v0.5+ — docs not yet updated |
| OEM Integration | `docs/discovery-domains/oem-integration.md` | `draft` | Redfish hardware collection described; GPU and per-DIMM Redfish paths need documentation |
| Management Tools | `docs/discovery-domains/management-tools.md` | `draft` | WAC TLS cert, third-party agent discovery, SCVMM/SCOM depth added in v0.5+ — docs not yet updated |
| Performance Baseline | `docs/discovery-domains/performance-baseline.md` | `draft` | RDMA counters, CSV cache stats, multi-source event log analysis, drive latency outliers added in v0.5+ — docs not yet updated |

---

## Outputs

| Page | Path | Maturity | Notes |
| --- | --- | --- | --- |
| Diagrams | `docs/outputs/diagrams.md` | `draft` | All 18 diagrams catalogued; audience and tier metadata accurate; Mermaid-source examples not yet added |
| Reports | `docs/outputs/reports.md` | `draft` | Three-tier structure described; report section inventory may be out of date relative to current template |
| As-Built Package | `docs/outputs/as-built-package.md` | `draft` | Package structure described; zip assembly and manifest versioning need expansion |

---

## Operator Guide

| Page | Path | Maturity | Notes |
| --- | --- | --- | --- |
| Prerequisites | `docs/operator/prerequisites.md` | `complete` | Module, PowerShell, WinRM, and Redfish prerequisites covered |
| Authentication | `docs/operator/authentication.md` | `complete` | All five auth methods with examples and Key Vault syntax |
| Configuration | `docs/operator/configuration.md` | `draft` | Core config fields covered; new collector config keys need documentation |
| Troubleshooting | `docs/operator/troubleshooting.md` | `complete` | Common error patterns and remediation steps |

---

## Project

| Page | Path | Maturity | Notes |
| --- | --- | --- | --- |
| Roadmap | `docs/project/roadmap.md` | `complete` | v0.5.0 shipped features, v1.0.0 targets, and post-v1 backlog |
| Documentation Roadmap | `docs/project/documentation-roadmap.md` | `complete` | This page |
| Repository Structure | `docs/project/repository-structure.md` | `draft` | Tree current as of v0.5.0; Modules/Outputs/Templates may need annotation |
| Changelog | `docs/project/changelog.md` | `stub` | Currently only a placeholder — full release changelog not yet written |

---

## Contributor

| Page | Path | Maturity | Notes |
| --- | --- | --- | --- |
| Getting Started | `docs/contributor/getting-started.md` | `stub` | Placeholder; step-by-step dev environment setup not yet written |
| Simulation Testing | `docs/contributor/simulation-testing.md` | `complete` | Synthetic manifest workflow, fixture update process, and Pester test invocation |
| Template Authoring | `docs/contributor/template-authoring.md` | `complete` | Template token reference, audience targeting, and diagram generation patterns |
| Contributing | `docs/contributor/contributing.md` | `stub` | PR and issue guidelines outline; community norms section not yet written |

---

## Prioritisation Notes

Pages most in need of content work, in priority order:

1. **All Discovery Domain pages** — v0.5.0 added significant collector depth across all six collectors. Every domain page should be updated to reflect the new data fields before the v1.0.0 release.
2. **Changelog** — A structured changelog will be required for PSGallery publication.
3. **Getting Started (Contributor)** — New contributors cannot onboard without this page.
4. **Configuration** — New collector config keys should be documented before v1.0.0.
5. **Scope Boundary** — The Tier 4 offline config parsing decision (see [#52](https://github.com/AzureLocal/azurelocal-ranger/issues/52)) should be recorded before shipping.
