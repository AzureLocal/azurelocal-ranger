# Azure Integration

This domain explains the Azure-side footprint of the Azure Local deployment.

It is the domain that keeps Ranger from becoming a local-only inventory tool.

## What Ranger Collects

The Azure-integration domain should document:

- Arc registration and cluster resource identity
- subscription, resource group, region, custom location, and Arc Resource Bridge context
- Azure extensions and control-plane health relevant to Azure Local
- Azure Monitor, Log Analytics, alerts, Update Manager, Backup, ASR, and Policy relationships
- Azure Local VM management prerequisites and control-plane dependencies
- Azure-connected workload families such as AKS, AVD, Arc VMs, and Arc Data Services where present

## Manifest Sub-Domains

The v1 collector writes to these named sections of the `azureIntegration` manifest domain:

| Sub-domain | Content |
|---|---|
| `arcCluster` | Arc registration ID, subscription, resource group, region, connected agent version, and cluster identity |
| `resourceBridge` | Arc Resource Bridge deployment state, appliance VM identity, and custom location binding |
| `customLocations` | Custom location name, namespace, and supported resource types |
| `extensions` | Installed Azure Arc cluster extensions, versions, provisioning state, and auto-upgrade posture |
| `arcMachines` | Arc-enabled machine resources for the Azure Local nodes — agent version, connectivity, and policy compliance |
| `monitoring` | AMA deployment, DCR and DCE associations, Log Analytics Workspace binding, and Azure Monitor health |
| `updateManager` | Azure Update Manager policy assignment, patch compliance status, and scheduled assessment state |
| `backup` | Azure Backup vault associations, protected items, and last backup signals |
| `siteRecovery` | Azure Site Recovery replication state, protected VMs, and failover readiness where configured |
| `policy` | Azure Policy assignments that directly govern the Azure Local cluster or its Arc-enrolled nodes |

## Why It Matters

Azure Local creates and depends on Azure-side resources. Those resources are part of the documented deployment and must appear in Ranger outputs.

## Connectivity and Credentials

| Requirement | Purpose |
|---|---|
| Azure credential | Required for Azure-side discovery |
| Optional cluster credential | Useful when Azure-side findings need to be correlated to cluster state |

## Default Behavior

This is a core domain when Azure credentials are available.

If Azure credentials are missing, the domain should be skipped with a reason rather than producing an incomplete or misleading Azure story.

## Variant Behavior

### Connected Hyperconverged

This is the baseline Azure-integration model.

### Local Identity with Azure Key Vault

Ranger should reflect Key Vault-backed secret storage, required managed identity access, and any tool compatibility boundaries called out by Microsoft documentation.

### Disconnected Operations

The Azure-integration model changes substantially. Ranger should document the local control-plane services and clearly distinguish them from public Azure dependencies.

### Multi-Rack Preview

Current Microsoft documentation describes preview-specific Azure-managed networking and platform layers for multi-rack. Ranger should preserve those as a variant-specific Azure-integration posture.

## Evidence Boundaries

- **Direct discovery:** Azure resources and relationships from Azure APIs
- **Host-side corroboration:** cluster-side checks that confirm whether Azure-facing platform components exist and are healthy
- **Manual/imported evidence:** operator-supplied architectural notes where Azure-side context alone is insufficient

## v1 and Future Boundaries

v1 should cover the Azure resources that directly represent, manage, monitor, or extend the Azure Local deployment.

It should not drift into unrelated tenant-wide inventory. That belongs to Azure Scout.