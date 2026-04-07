# Management Tools

This domain explains how the environment is actually managed in practice.

## What Ranger Collects

The management-tools domain should document:

- Windows Admin Center deployment and extension posture
- SCVMM and SCOM integration when present
- Azure portal or Azure CLI-based management surfaces where relevant
- notable third-party management, backup, recovery, or monitoring agents detected on the nodes
- tool compatibility limitations for the current identity or operating variant

## Manifest Sub-Domains

The v1 collector writes to these named sections of the `managementTools` manifest domain:

| Sub-domain | Content |
|---|---|
| `tools` | Detected management services — Windows Admin Center, SCVMM, SCOM, OEM tooling, and third-party agents |
| `agents` | Per-node agent inventory — installed agents, versions, and connection state |
| `summary` | Count of running management services and identified control surfaces |

## Why It Matters

An environment is managed through tools, not just through cluster objects. Ranger should document that operational reality so a receiving team knows which control surfaces matter.

## Connectivity and Credentials

| Requirement | Purpose |
|---|---|
| WinRM / PowerShell remoting | Host-side discovery of installed and connected tooling |
| Cluster credential | Required |
| Optional Azure credential | Helpful where management surfaces are Azure-hosted or Azure-registered |

## Default Behavior

This domain should run by default when cluster credentials are available because it is low-friction host-side discovery and often high value for handoff.

## Variant Behavior

### Local Identity with Azure Key Vault

Current Microsoft documentation states that Windows Admin Center is not supported in Azure Key Vault-based identity environments and SCVMM support is limited or unsupported. Ranger should call those boundaries out clearly.

### Disconnected Operations

Ranger should distinguish public-Azure management tools from the local disconnected control-plane management surfaces.

### Multi-Rack Preview

Current Microsoft documentation emphasizes Azure portal, ARM, and Azure CLI management for multi-rack preview. Ranger should describe that as a different management posture from standard hyperconverged environments.

## Evidence Boundaries

- **Direct discovery:** host-side detection of management and operational tooling
- **Azure-side discovery:** Azure-registered management surfaces where applicable
- **Manual/imported evidence:** operator-supplied process notes when management happens outside discoverable tooling

## v1 and Future Boundaries

v1 should document what tools are present and how they relate to the environment.

It should not attempt to become a complete runbook or process-mining system for every operational workflow.