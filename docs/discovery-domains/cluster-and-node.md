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

## Manifest Sub-Domains

The v1 collector writes to these named sections of the `clusterNode` manifest domain:

| Sub-domain | Content |
| --- | --- |
| `cluster` | Cluster identity, FQDN, domain posture, domain functional level, and operating system |
| `nodes` | Node inventory — name, state, uptime, OS version, role posture, and site membership |
| `quorum` | Quorum configuration, witness type, and witness path or resource |
| `faultDomains` | Rack or fault-domain assignments when configured |
| `networks` | Cluster network objects and role summary |
| `roles` | Cluster roles and their owner node assignments |
| `csvSummary` | Cluster shared volume count, state, and owning nodes |
| `updatePosture` | Node patch compliance, pending updates, and last assessment timestamp |
| `eventSummary` | Recent critical and error event digest from cluster and node event logs |
| `healthSummary` | Cluster and node health roll-up — node counts by state |
| `nodeSummary` | Aggregate node count, OS version spread, and uptime range |
| `faultDomainSummary` | Rack count and node distribution across fault domains |
| `networkSummary` | Cluster network count and role breakdown |

## Current Collector Depth

Current v1 collection also covers:

- Cluster-Aware Updating posture and owner data where available.
- Solution-update and lifecycle-manager signals that affect the maintenance story.
- Arc-backed node-resolution and cluster-registration context used to reconcile Azure and WinRM views.
- Unreachable-node findings when configured nodes do not answer over WinRM.

## Why It Matters

This domain is the control point for:

- topology classification
- node-to-workload relationships
- platform health interpretation
- update and maintenance posture
- variant-specific behavior such as local identity, disconnected operations, or rack-aware layouts

## Connectivity and Credentials

| Requirement | Purpose |
| --- | --- |
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

## Example Manifest Data

A successful collect produces entries like this in `manifest.collectors`:

```json
{
  "id": "clusterNode",
  "status": "success",
  "domains": {
    "clusterNode": {
      "cluster": {
        "name": "tplabs-clus01",
        "fqdn": "tplabs-clus01.contoso.com",
        "domain": "contoso.com",
        "osVersion": "10.0.26200",
        "registrationState": "Registered"
      },
      "nodes": [
        { "name": "tplabs-01-n01", "state": "Up", "uptimeDays": 14, "osVersion": "10.0.26200" },
        { "name": "tplabs-01-n02", "state": "Up", "uptimeDays": 14, "osVersion": "10.0.26200" }
      ],
      "quorum": { "type": "NodeAndFileShareMajority", "witnessPath": "\\\\dc01\\quorum" },
      "healthSummary": { "nodesUp": 4, "nodesDown": 0, "overallState": "Normal" }
    }
  }
}
```

## Common Findings

| Finding | Severity | What it means |
| --- | --- | --- |
| Node unreachable over WinRM | Warning | A configured node did not respond during collection; data for that node is absent |
| Cluster not Arc-registered | Info | Azure-side Arc cluster resource is missing; Azure integration collectors will be limited |
| Nodes on different OS versions | Warning | Mixed OS versions detected; may indicate a stalled update cycle |
| CAU not configured | Info | Cluster-Aware Updating is absent; patching may be manual |
| Quorum witness unreachable | Warning | File share or cloud witness could not be validated |

## Partial Status

`status: partial` on the cluster-and-node collector means one or more sub-collectors failed while others succeeded. Common causes:

- One or more nodes unreachable (node sub-collector returns partial data; cluster-level facts still collected)
- CAU or update posture query times out (main cluster and node inventory still complete)
- Arc registration context unavailable (cluster facts collected; Azure-side Arc context absent)

In all partial cases, the data that was collected is valid and can be used. Check `manifest.collectors[*].messages` for the specific sub-section that failed.

## Domain Dependencies

The cluster-and-node domain is a prerequisite for almost everything else. Collectors for storage, networking, VMs, and identity all depend on a valid node list from this domain. If it fails entirely, expect cascading `failed` or `partial` status on downstream collectors.

## Evidence Boundaries

- **Direct discovery:** cluster and node facts from WinRM and cluster tooling
- **Host-side validation:** some health or endpoint checks from the node perspective
- **Manual/imported evidence:** optional supplemental site or rack metadata when the environment does not expose enough structure directly

## v1 and Future Boundaries

v1 should cover the cluster and node data needed for accurate current-state and as-built documentation.

Future work can deepen disconnected-operations and multi-rack-specific inspection once those paths are proven and testable.
