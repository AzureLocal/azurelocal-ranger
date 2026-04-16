# Azure Local Ranger

![Azure Local Ranger — Know your ground truth.](assets/images/azurelocalranger-banner.svg)

> *Know your ground truth.*

Azure Local Ranger is a discovery, documentation, audit, and reporting solution for Azure Local.

Its purpose is to document an Azure Local deployment as a complete system — the on-prem platform, the workloads running on it, and the Azure resources that represent, manage, monitor, or extend that deployment.

Ranger supports two primary modes of use:

- **Current-state documentation** — run at any time to document what exists, how something is configured, and what its current health and risk posture looks like.
- **As-built handoff documentation** — run after a deployment to produce a structured documentation package suitable for customer handoff, operations onboarding, or managed-service transition.

Both modes use the same discovery engine. The difference is a parameter, not a different product.

Ranger is designed with explicit support for the range of Azure Local operating models — hyperconverged, switchless, rack-aware, local identity with Azure Key Vault, disconnected operations, and future multi-rack scenarios. It does not silently assume one cluster shape.

## Recommended Reading Flow

If you are new to Ranger, the cleanest path through the docs is:

1. product definition
2. architecture and operator model
3. discovery domains and outputs
4. roadmap and repository structure
5. contributor guidance

## Current Project Phase

AzureLocalRanger is at **v1.2.0**. This release delivers the UX & Transport milestone: Arc Run Command transport, disconnected/semi-connected discovery, Spectre.Console TUI progress display, and the interactive configuration wizard (`Invoke-RangerWizard`).

```powershell
Import-Module .\AzureLocalRanger.psd1 -Force
Invoke-AzureLocalRanger -ConfigPath .\ranger.yml
```

See the [Prerequisites](prerequisites.md), [Quickstart](operator/quickstart.md), and [Command Reference](operator/command-reference.md) pages for installation and first-run instructions.

## Where To Start

| Audience | Start Here |
|----------|------------|
| Everyone | [What Ranger Is](what-ranger-is.md) |
| Everyone | [Ranger vs Scout](ranger-vs-scout.md) |
| Everyone | [Scope Boundary](scope-boundary.md) |
| Everyone | [Deployment Variants](deployment-variants.md) |
| Architects and operators | [Architecture Overview](architecture/system-overview.md) |
| Architects and operators | [Discovery Domain Pages](discovery-domains/cluster-and-node.md) |
| Project and repo readers | [Roadmap](project/roadmap.md) |
| Project and repo readers | [Documentation Roadmap](project/documentation-roadmap.md) |
| Project and repo readers | [Repository Structure](project/repository-structure.md) |
| Contributors | [Getting Started](contributor/getting-started.md) |
| Contributors | [Contributing](contributor/contributing.md) |
