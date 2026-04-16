# Networking

This domain explains how the Azure Local environment is physically and logically connected.

Networking is also where Ranger must be clearest about the difference between host-side validation and optional direct device interrogation.

## What Ranger Collects

The networking domain should document:

- virtual switches, SET, host vNICs, and IP configuration
- management, storage, and compute network structure
- RDMA, DCB, and Network ATC posture
- SDN components and logical network constructs where deployed
- DNS, proxy, and firewall posture that Azure Local depends on
- endpoint reachability that affects Azure Arc, monitoring, update, and workload management

## Manifest Sub-Domains

The v1 collector writes to these named sections of the `networking` manifest domain:

| Sub-domain | Content |
| --- | --- |
| `nodes` | Per-node networking raw snapshot, indexed by host name |
| `clusterNetworks` | Cluster network objects, roles, and address ranges |
| `adapters` | Physical and virtual network adapters across all nodes |
| `vSwitches` | Hyper-V virtual switches and their team member adapters |
| `hostVirtualNics` | Host management virtual NICs bound to vSwitches |
| `intents` | Network ATC intent definitions, storage, and compute intent markers |
| `dns` | DNS client server addresses per interface and node |
| `ipAddresses` | IPv4 addresses, prefix lengths, and interface associations |
| `routes` | IPv4 routing table entries (first 50 per node) |
| `vlan` | VLAN configuration from management OS virtual adapters |
| `proxy` | HTTP proxy configuration as observed from each node |
| `firewall` | Windows Firewall profile state (Public, Private, Domain) per node |
| `sdn` | Network Controller discovery results when SDN is deployed |
| `switchConfig` | Switch configuration imported from vendor config files when `networkDeviceConfigs` hints are provided |
| `firewallConfig` | Firewall ACL configuration imported from vendor config files when `networkDeviceConfigs` hints are provided |
| `summary` | Aggregate counts — nodes, adapters, vSwitches, intents, DNS servers, VLANs |

## Current Collector Depth

Current v1 collection also covers:

- DCB and RDMA posture for host adapters and virtual NIC relationships.
- Network ATC intent and override detail when intent-driven networking is configured.
- LLDP or neighbour-discovery evidence where the host exposes it.
- Firewall, proxy, DNS, and route posture needed for platform and Azure connectivity review.

## Why It Matters

Inherited Azure Local environments are frequently hard to understand because the networking assumptions are implicit. Ranger should make those assumptions explicit.

## Connectivity and Credentials

| Requirement | Purpose |
| --- | --- |
| WinRM / PowerShell remoting | Primary host-network and SDN discovery path |
| Cluster credential | Required |
| Optional switch or firewall targets and credentials | Future direct device interrogation |

## Default Behavior

The networking domain is core and should run by default when cluster credentials are available.

Direct switch or firewall interrogation should stay optional and off by default.

## Variant Behavior

### Hyperconverged

Standard switched management, storage, and compute networking is the baseline case.

### Switchless

Ranger should explicitly describe the absence of storage-network switches and model storage links as direct east-west paths.

### Rack-Aware

Ranger should surface rack boundaries, local-availability implications, and any host-network assumptions driven by rack placement.

### Local Identity with Azure Key Vault

Identity mode changes some management-tool expectations, but host networking, DNS, and endpoint reachability remain essential.

### Disconnected Operations

Azure public-cloud reachability assumptions change significantly. Ranger should explain local control-plane networking separately from connected Azure egress.

### Multi-Rack Preview

Current Microsoft documentation describes managed networking through Azure APIs and ARM for multi-rack preview. Ranger should reflect that as a different networking posture from customer-managed hyperconverged networking.

## Example Manifest Data

A successful collect produces entries like this:

```json
{
  "id": "storageNetworking",
  "status": "success",
  "domains": {
    "networking": {
      "vSwitches": [
        { "name": "ConvergedSwitch", "switchType": "External", "teamingMode": "SwitchIndependent",
          "loadBalancingAlgorithm": "HyperVPort", "teamMembers": ["NIC1","NIC2"] }
      ],
      "intents": [
        { "name": "Compute_Management_Storage", "trafficType": ["Compute","Management","Storage"],
          "adapter": ["NIC1","NIC2"] }
      ],
      "clusterNetworks": [
        { "name": "Cluster Network 1", "role": "ClusterAndClient", "addressFamily": "IPv4",
          "address": "192.168.211.0", "prefixLength": 24 }
      ],
      "summary": { "nodeCount": 4, "vSwitchCount": 1, "intentCount": 1, "dnsServerCount": 2 }
    }
  }
}
```

## Common Findings

| Finding | Severity | What it means |
| --- | --- | --- |
| RDMA not enabled on storage adapters | Warning | Storage traffic is running over TCP rather than RDMA; latency and throughput may be suboptimal |
| Network ATC intent not configured | Info | Networking is manually configured rather than intent-driven; drift risk is higher |
| Asymmetric adapter count across nodes | Warning | Nodes have different numbers of physical adapters; check for missing or failed hardware |
| Windows Firewall disabled on any profile | Warning | Host firewall is off; expected in some environments but worth documenting |
| Proxy configured on nodes | Info | Outbound traffic routes through a proxy; verify Azure endpoints are reachable |

## Partial Status

`status: partial` on the networking collector typically means:

- One or more nodes were unreachable so their per-node network snapshot is missing; cluster network and vSwitch data still collected
- SDN discovery failed while host-side networking data succeeded — SDN sub-section is absent but all other networking facts are valid
- Switch or firewall config import failed when `networkDeviceConfigs` hints were provided

## Domain Dependencies

Depends on the cluster-and-node domain for a resolved node list. Independent of the storage sub-collector — storage and networking share a collector but each sub-domain can succeed or fail independently.

## Evidence Boundaries

- **Direct discovery:** host-network and SDN facts from the nodes
- **Host-side validation:** endpoint reachability, DNS resolution, firewall posture as observed from the host side
- **Optional direct device interrogation:** future switch or firewall API / SSH collection when explicitly configured
- **Manual/imported evidence:** network designs or ACL exports provided by the operator

## v1 and Future Boundaries

v1 should emphasize host-side networking truth and endpoint dependency validation.

Direct device interrogation belongs to optional future collectors unless the operator explicitly configures those targets and the vendor path is supported.