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
|---|---|
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

## Why It Matters

Inherited Azure Local environments are frequently hard to understand because the networking assumptions are implicit. Ranger should make those assumptions explicit.

## Connectivity and Credentials

| Requirement | Purpose |
|---|---|
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

## Evidence Boundaries

- **Direct discovery:** host-network and SDN facts from the nodes
- **Host-side validation:** endpoint reachability, DNS resolution, firewall posture as observed from the host side
- **Optional direct device interrogation:** future switch or firewall API / SSH collection when explicitly configured
- **Manual/imported evidence:** network designs or ACL exports provided by the operator

## v1 and Future Boundaries

v1 should emphasize host-side networking truth and endpoint dependency validation.

Direct device interrogation belongs to optional future collectors unless the operator explicitly configures those targets and the vendor path is supported.