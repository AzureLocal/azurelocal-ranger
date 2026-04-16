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
| --- | --- |
| `tools` | Detected management services — Windows Admin Center, SCVMM, SCOM, OEM tooling, and third-party agents |
| `agents` | Per-node agent inventory — installed agents, versions, and connection state |
| `summary` | Count of running management services and identified control surfaces |

## Current Collector Depth

Current v1 collection also covers:

- Windows Admin Center presence, service state, and certificate signals where visible.
- Third-party agent inventory for backup, monitoring, and operations tooling.
- SCVMM and SCOM presence indicators for environments that still carry those agents.
- Service-level roll-ups used to explain management-plane coverage in the reports.

## Why It Matters

An environment is managed through tools, not just through cluster objects. Ranger should document that operational reality so a receiving team knows which control surfaces matter.

## Connectivity and Credentials

| Requirement | Purpose |
| --- | --- |
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

## Example Manifest Data

A successful collect produces entries like this:

```json
{
  "id": "managementPerformance",
  "status": "success",
  "domains": {
    "managementTools": {
      "tools": [
        { "name": "Windows Admin Center", "detected": true, "serviceState": "Running",
          "version": "2311.0.0.0", "port": 443 },
        { "name": "SCVMM", "detected": false },
        { "name": "SCOM", "detected": false }
      ],
      "agents": [
        { "node": "tplabs-01-n01", "name": "Microsoft Monitoring Agent", "version": "10.20.18053",
          "state": "Running" },
        { "node": "tplabs-01-n01", "name": "Azure Monitor Agent", "version": "1.22.0",
          "state": "Running" }
      ],
      "summary": { "managementServicesDetected": 1, "totalAgentsDetected": 8 }
    }
  }
}
```

## Common Findings

| Finding | Severity | What it means |
| --- | --- | --- |
| Windows Admin Center service stopped | Warning | WAC is installed but not running; management via WAC is unavailable |
| Windows Admin Center not detected | Info | WAC is absent from this environment; cluster is managed through other surfaces |
| Legacy MMA agent detected alongside AMA | Info | Both old and new monitoring agents are installed; the old agent may be redundant |
| SCVMM detected | Info | SCVMM is part of the management surface; document its version and connection state |
| No management tooling detected | Info | No WAC, SCVMM, SCOM, or third-party tooling; cluster is managed solely through PowerShell and Azure portal |

## Partial Status

`status: partial` on the management-tools collector means:

- Agent inventory succeeded on some nodes but not others (node unreachable)
- Service detection succeeded but WAC certificate or version queries failed

Core tool detection (WAC present/absent, service state) is usually complete even when version or configuration detail fails.

## Domain Dependencies

Depends on the cluster-and-node domain for a node list. Independent of storage, networking, and Azure collectors.

## Evidence Boundaries

- **Direct discovery:** host-side detection of management and operational tooling
- **Azure-side discovery:** Azure-registered management surfaces where applicable
- **Manual/imported evidence:** operator-supplied process notes when management happens outside discoverable tooling

## v1 and Future Boundaries

v1 should document what tools are present and how they relate to the environment.

It should not attempt to become a complete runbook or process-mining system for every operational workflow.