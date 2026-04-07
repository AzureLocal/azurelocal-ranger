# Roadmap

This page outlines what has shipped, what is next, and where Ranger is heading.
Community contributions are welcome — see [Contributing](../contributor/contributing.md) to get involved.

Ranger supports two outcomes through one discovery engine:

- **Current-state** — recurring operational snapshot of a live Azure Local deployment
- **As-built** — formal documentation package for customer or operational handoff

## Current Release — v0.5.0

Released April 2026. Pre-release ahead of PSGallery `1.0.0`.

| Area | What shipped |
| --- | --- |
| Module architecture | One public module (`AzureLocalRanger.psd1`) with layered orchestration, collectors, shared services, and output generators |
| Manifest-first runtime | Collect once into `audit-manifest.json`; all reports and diagrams render from that cache only |
| Collectors | Six grouped collectors: topology/cluster, Dell/Redfish hardware, storage/networking, workload/identity/Azure, monitoring, management/performance |
| Report generation | Three-tier HTML and Markdown reports (executive, management, technical) from saved manifest |
| Diagram generation | 18 draw.io-compatible diagrams (6 baseline + 12 extended) with variant-aware selection and SVG output |
| Schema contract | Standalone manifest schema v1.1.0-draft with runtime validation and test boundary |
| Authentication | Five methods: existing context, managed identity, device-code, service principal, Azure CLI fallback |
| Key Vault credential refs | `keyvault://` URI pattern resolved at runtime — no secrets in config files |
| `-OutputPath` parameter | User-controlled export destination overrides the config default |
| Testing | 18 Pester tests: schema, degraded scenarios, cached outputs, end-to-end, and 7 simulation tests against a synthetic IIC 3-node fixture |
| Simulation framework | Full output pipeline validated without live connections via `New-RangerSyntheticManifest.ps1` and committed fixture |
| Public documentation | Product, architecture, operator, discovery domain, output, and contributor docs under `docs/` |

## Next Release — v1.0.0 (PSGallery)

Focus: live-estate proof, PSGallery publish, and polish.

| Item | Detail | Status |
| --- | --- | --- |
| Live environment validation | Run Ranger against a real Azure Local cluster and reconcile generated package against known facts ([#34](https://github.com/AzureLocal/azurelocal-ranger/issues/34)) | 🔵 In progress |
| PSGallery publish | Publish `AzureLocalRanger` module to PowerShell Gallery at `1.0.0` | 🔵 Planned |
| As-built mode report differentiation | Mode-specific report sections so `as-built` output differs meaningfully from `current-state` | 🔵 Planned |
| Topology collector summary fields | Compute `csvSummary`, `updatePosture`, and `eventSummary` objects currently collected as raw evidence only | 🔵 Planned |
| Network device config import ([#36](https://github.com/AzureLocal/azurelocal-ranger/issues/36)) | Import switch and firewall config from external sources for environments where direct interrogation is not possible | 🔵 Planned |
| Output template improvements ([#38](https://github.com/AzureLocal/azurelocal-ranger/issues/38)) | Richer output template definitions aligned to full collector data inventory | 🔵 Planned |
| Docs audit ([#37](https://github.com/AzureLocal/azurelocal-ranger/issues/37)) | Verify all public docs reflect the current implementation and remove any planning-era stale content | 🔵 Planned |

## Post-v1 Backlog

These items are intentionally deferred outside the `1.0.0` baseline. Each has a tracked decision record.

| Item | Detail | Issue |
| --- | --- | --- |
| Azure-hosted automation worker | Run Ranger from an Azure Automation account or hosted runner without a local PowerShell session | [#25](https://github.com/AzureLocal/azurelocal-ranger/issues/25) |
| Arc Run Command transport | Use Azure Arc Run Command as an alternate collection channel for environments where WinRM is blocked | [#26](https://github.com/AzureLocal/azurelocal-ranger/issues/26) |
| Direct switch interrogation | Collect switch configuration directly via SSH/RESTCONF/NETCONF rather than host-side evidence only | [#27](https://github.com/AzureLocal/azurelocal-ranger/issues/27) |
| Direct firewall interrogation | Collect firewall policy directly from the appliance | [#28](https://github.com/AzureLocal/azurelocal-ranger/issues/28) |
| Non-Dell OEM support | Hardware inventory modules for HPE, Lenovo, and other OEM vendors beyond Dell/Redfish | [#29](https://github.com/AzureLocal/azurelocal-ranger/issues/29) |
| Disconnected enrichment | Richer discovery for environments with limited or no Azure connectivity | [#30](https://github.com/AzureLocal/azurelocal-ranger/issues/30) |
| Multi-rack and management cluster enrichment | Deployment-variant-specific discovery depth for rack-scale and stretched cluster topologies | [#31](https://github.com/AzureLocal/azurelocal-ranger/issues/31) |
| Manual import workflows | Accept externally gathered data for environments where automated collection is not authorized | [#32](https://github.com/AzureLocal/azurelocal-ranger/issues/32) |
| Windows PowerShell 5.1 compatibility | Assess and implement compatibility without distorting the PowerShell 7 architecture | [#33](https://github.com/AzureLocal/azurelocal-ranger/issues/33) |

## Long-term Vision

Azure Local Ranger aims to be the definitive open-source documentation and audit tool for Azure Local deployments — useful to:

- **Platform engineers** who need a reliable, repeatable record of how a deployment is built and configured
- **Operations teams** who need a fast current-state snapshot before changes or incidents
- **Architects** designing expansions, migrations, or new workloads on top of an existing environment
- **Managed service providers** who need consistent, client-ready as-built packages across multiple customer sites

The tool will remain open-source, PowerShell-native, and output-friendly — no agents, no portals, no licensing fees.

## Suggest a Feature

Open an issue at [github.com/AzureLocal/azurelocal-ranger/issues](https://github.com/AzureLocal/azurelocal-ranger/issues) with the label `enhancement`.

Pull requests are welcome — see [Contributing](../contributor/contributing.md) for guidelines.

## Read Next

- [Repository Structure](repository-structure.md)
- [Getting Started](../contributor/getting-started.md)
- [Changelog](changelog.md)
