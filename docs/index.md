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

AzureLocalRanger is at **v2.2.0**. Install from PSGallery:

```powershell
Install-Module AzureLocalRanger -Scope CurrentUser -Force
Import-Module AzureLocalRanger

# First-time run — pass -Wizard to be walked through a config interactively
Invoke-AzureLocalRanger -Wizard

# Subsequent runs — point at the saved config (or omit for inline prompts)
Invoke-AzureLocalRanger -ConfigPath .\ranger.yml
```

## Where To Start

!!! tip "New here?"
    Start with the [First Run](operator/first-run.md) guide — it takes you from install to finished output in six steps with no decisions to make.

| Audience | Start Here |
| --- | --- |
| **New operators** | [First Run](operator/first-run.md) |
| **Returning operators** | [Command Reference](operator/command-reference.md) — common scenarios |
| **Configuring a new environment** | [Wizard Guide](operator/wizard-guide.md) |
| **Reading your results** | [Understanding Output](operator/understanding-output.md) |
| **Config file questions** | [Configuration Reference](operator/configuration-reference.md) |
| Everyone | [What Ranger Is](what-ranger-is.md) |
| Everyone | [Scope Boundary](scope-boundary.md) |
| Architects and operators | [Architecture Overview](architecture/system-overview.md) |
| Architects and operators | [Discovery Domain Pages](discovery-domains/cluster-and-node.md) |
| Project and repo readers | [Roadmap](project/roadmap.md) |
| Contributors | [Getting Started](contributor/getting-started.md) |
