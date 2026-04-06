# Cluster and Node

This domain establishes the core identity and operating state of the Azure Local instance.

Almost every other domain depends on this one. If Ranger cannot describe the cluster correctly, the rest of the environment story becomes unreliable.

## What Ranger Collects

The cluster-and-node domain should document:

- cluster identity, FQDN, domain or workgroup posture, and release information
- node inventory, state, uptime, OS version, and role posture
- quorum and witness configuration
- fault-domain layout such as rack awareness
- cluster-network summary and CSV summary
- update posture, patch state, and recent update history
- recent critical and error event summary
- Azure registration state where it directly describes the cluster itself

## Why It Matters

This domain is the control point for:

- topology classification
- node-to-workload relationships
- platform health interpretation
- update and maintenance posture
- variant-specific behavior such as local identity, disconnected operations, or rack-aware layouts

## Connectivity and Credentials

| Requirement | Purpose |
|---|---|
| WinRM / PowerShell remoting to cluster nodes | Primary collection path |
| Cluster credential | Required for cluster and node collection |
| Azure credential | Optional when cluster registration state or Azure-side platform context is included |

## Default Behavior

This is a core domain. If the cluster credential is available, Ranger should run it by default.

If WinRM reachability is unavailable, the domain should report `failed` or `partial` with a clear reason rather than blocking the rest of the run.

## Variant Behavior

### Hyperconverged

This is the baseline shape. Cluster identity, node posture, networks, and update state behave as the standard case.

### Rack-Aware

Ranger should surface rack assignments, fault-domain configuration, and any placement implications.

### Local Identity with Azure Key Vault

Ranger should document workgroup posture, `ADAware` state, and any operational differences from domain-joined environments.

### Disconnected Operations

Ranger should distinguish the cluster’s local control-plane posture from a normal connected Azure Local deployment.

### Multi-Rack Preview

Ranger should note that the environment is not a standard hyperconverged deployment and should preserve preview-specific topology markers separately.

## Evidence Boundaries

- **Direct discovery:** cluster and node facts from WinRM and cluster tooling
- **Host-side validation:** some health or endpoint checks from the node perspective
- **Manual/imported evidence:** optional supplemental site or rack metadata when the environment does not expose enough structure directly

## v1 and Future Boundaries

v1 should cover the cluster and node data needed for accurate current-state and as-built documentation.

Future work can deepen disconnected-operations and multi-rack-specific inspection once those paths are proven and testable.