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
| --- | --- |
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

## Current Collector Depth

Current v1 collection also covers:

- Arc Resource Bridge, custom location, and extension state used to explain Azure-side platform control.
- AKS, Arc data, backup, and recovery overlays derived from Azure resource inventory.
- Policy-compliance and monitoring context tied directly to the Azure Local deployment.
- Workload-family signals inferred from Azure resources rather than a dedicated AVD host-pool collector.

## Why It Matters

Azure Local creates and depends on Azure-side resources. Those resources are part of the documented deployment and must appear in Ranger outputs.

## Connectivity and Credentials

| Requirement | Purpose |
| --- | --- |
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

## Example Manifest Data

A successful collect produces entries like this:

```json
{
  "id": "azureIntegration",
  "status": "success",
  "domains": {
    "azureIntegration": {
      "arcCluster": {
        "resourceId": "/subscriptions/00000000.../resourceGroups/rg-azlocal-prod-01/providers/Microsoft.AzureStackHCI/clusters/tplabs-clus01",
        "region": "eastus",
        "connectedAgentVersion": "1.38.0",
        "registrationState": "Registered"
      },
      "extensions": [
        { "name": "AzureMonitorWindowsAgent", "version": "1.22.0",
          "provisioningState": "Succeeded", "autoUpgrade": true },
        { "name": "MicrosoftDefenderAtCloudServer", "version": "1.0.0",
          "provisioningState": "Succeeded" }
      ],
      "monitoring": {
        "amaDeployed": true,
        "logAnalyticsWorkspaceId": "/subscriptions/.../workspaces/law-tplabs"
      },
      "updateManager": { "policyAssigned": true, "complianceState": "Compliant" }
    }
  }
}
```

## Common Findings

| Finding | Severity | What it means |
| --- | --- | --- |
| Arc cluster not registered | Error | Cluster has no Azure Arc registration; all Azure-side management and monitoring is unavailable |
| Arc extension in failed state | Warning | One or more extensions failed to install or update; Azure features may be degraded |
| Azure Monitor agent not deployed | Warning | No AMA on cluster nodes; Azure Monitor, HCI Insights, and Defender for Cloud signals are absent |
| No Azure Policy assigned | Info | No policy governance on this cluster; compliance posture is undocumented from Azure perspective |
| Arc Resource Bridge not deployed | Info | Arc VMs and Arc Data Services are not available on this cluster |

## Partial Status

`status: partial` on the azure-integration collector means:

- Some Azure sub-collectors failed (e.g., ASR query throws) while core Arc and extension data succeeded
- Azure credential was available but lacked permissions to one specific resource type (e.g., Backup vault)
- Resource Bridge or custom location queries returned no data because those features aren't deployed

The Arc cluster registration, extension, and monitoring sections are the most critical. Backup, ASR, and policy sections failing partially is usually expected in environments that don't use all Azure services.

## Domain Dependencies

Requires an active Azure credential and valid `targets.azure` configuration. No dependency on WinRM — collects entirely from Azure APIs. Some sections correlate with data from the cluster-and-node domain (node list for Arc machine matching).

## Evidence Boundaries

- **Direct discovery:** Azure resources and relationships from Azure APIs
- **Host-side corroboration:** cluster-side checks that confirm whether Azure-facing platform components exist and are healthy
- **Manual/imported evidence:** operator-supplied architectural notes where Azure-side context alone is insufficient

## v1 and Future Boundaries

v1 should cover the Azure resources that directly represent, manage, monitor, or extend the Azure Local deployment.

It should not drift into unrelated tenant-wide inventory. That belongs to Azure Scout.