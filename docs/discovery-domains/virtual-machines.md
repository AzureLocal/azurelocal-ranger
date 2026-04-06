# Virtual Machines

This domain explains what the Azure Local platform is actually hosting.

Ranger should describe VM inventory and placement, but it should also recognize larger workload families that are using the platform.

## What Ranger Collects

The virtual-machine domain should document:

- VM inventory, state, generation, and ownership
- CPU, memory, disk, and network configuration
- host placement, anti-affinity, and failover posture
- checkpoints, replication, and density or overcommit indicators
- Arc VM overlays where present
- guest-cluster hints when discoverable
- workload-family presence such as AVD, AKS, Arc VMs, Arc Data Services, or Microsoft 365 Local indicators

## Why It Matters

Platform inventory is not enough. Operators and receiving teams need to understand what the cluster is actually running and how those workloads are distributed.

## Connectivity and Credentials

| Requirement | Purpose |
|---|---|
| WinRM / PowerShell remoting | Primary Hyper-V and cluster-side VM discovery |
| Cluster credential | Required |
| Azure credential | Needed when Arc VM or Azure-managed workload overlays are in scope |

## Default Behavior

This is a core domain and should run when cluster credentials are available.

Azure-managed overlays can be partial when Azure credentials are not available.

## Variant Behavior

### Hyperconverged

Standard VM inventory and placement applies.

### Rack-Aware

Ranger should reflect rack placement and any local-availability behavior when it is visible.

### Disconnected Operations

Workload control may be mediated through the local control plane rather than the public Azure control plane. Ranger should preserve that distinction.

### Multi-Rack Preview

Multi-rack preview changes the placement and networking context of workloads. Ranger should treat that as a variant-specific interpretation layer, not as the baseline VM model.

## Evidence Boundaries

- **Direct discovery:** Hyper-V and cluster facts from the nodes
- **Azure-side discovery:** Arc VM or Azure-managed workload overlays from Azure APIs
- **Manual/imported evidence:** optional workload ownership or service mapping supplied by the operator

## v1 and Future Boundaries

v1 should identify major workload families and accurately document VM placement.

It should not imply deep in-guest application inspection for every workload type in the first release.