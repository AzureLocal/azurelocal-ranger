# Deployment Variants

Azure Local is not a single-shape platform. The operating model, identity mode, connectivity posture, and storage architecture vary across deployments, and those differences materially change what Ranger discovers, how it interprets findings, and what it includes in reports and diagrams.

This page explains the supported and planned Azure Local deployment variants so the rest of the documentation does not silently assume one cluster shape.

## Why Variants Matter

Many Azure Local discovery assumptions break when the deployment model changes:

- A switchless cluster has no TOR switches to validate against.
- A local-identity deployment has no Active Directory to query.
- A disconnected cluster may not have Azure Arc control-plane access.
- A multi-rack deployment has preview-specific topology and connectivity characteristics that single-rack deployments do not.

Ranger must classify the deployment variant before interpreting lower-level findings. The variant classification drives downstream validation logic, report wording, and diagram selection.

## Deployment Types

### Hyperconverged

The standard Azure Local model. Compute, storage, and networking converge on the same set of nodes using Storage Spaces Direct. This is the most common deployment shape and the baseline Ranger tests against.

### Switchless Storage Fabric

Nodes are connected in a full-mesh east-west storage network using direct RDMA links, with no TOR switches for storage traffic. Management and compute traffic still use switched networks. This changes the network discovery model — there are no storage-network switches to validate, and the storage fabric topology is point-to-point.

### Rack-Aware

Fault domains are assigned by rack rather than by node. Storage and placement decisions account for rack boundaries. Ranger must discover rack assignments and validate that fault domain configuration matches the physical topology.

### Disconnected Operations

The cluster operates without persistent connectivity to Azure. The local control plane handles lifecycle operations that normally require the Azure control plane. Ranger must detect this mode and adjust Azure-side discovery expectations accordingly — some Azure resource queries will not return data or will return stale data.

### Multi-Rack

A preview Azure Local deployment model delivered as preintegrated racks. Current Microsoft documentation describes one main rack for network aggregation and SAN storage plus several compute racks, with managed networking exposed through Azure APIs and ARM.

- storage is not S2D — it is SAN-backed and externally managed
- the current preview architecture includes Azure ExpressRoute connectivity
- the network fabric is rack-aware and managed through Azure-provisioned network resources

Ranger must detect multi-rack deployments and adapt storage, networking, and management discovery accordingly.

## Identity Modes

### Active Directory-Backed

The cluster and nodes are domain-joined. Cluster objects exist in AD. This is the traditional identity model and enables the broadest set of discovery paths (domain trust, WinRM with Kerberos, GPO-driven configuration).

### Local Identity with Azure Key Vault

The cluster operates without Active Directory. Identity and secrets are managed locally with Azure Key Vault providing credential and certificate storage. This mode changes how Ranger authenticates, how it discovers identity posture, and what AD-related findings are expected to be absent (absence is not a failure in this mode).

## Control-Plane Modes

### Connected

The cluster has persistent connectivity to the Azure control plane. Arc registration, Azure lifecycle management, update orchestration, and monitoring flow through Azure normally. Ranger can perform full Azure-side discovery.

### Disconnected

The cluster operates with limited or no Azure connectivity. Local control-plane components handle operations that would normally require Azure. Ranger must detect this and degrade Azure-side discovery gracefully — missing Azure data is expected, not an error.

### Mixed or Limited Connectivity

The cluster has intermittent or proxy-mediated connectivity to Azure. Some Azure services may be reachable while others are not. Ranger should attempt Azure-side discovery and report what succeeded and what was unreachable, without treating partial results as failures.

## Storage Architectures

| Model | Description | Ranger Impact |
|-------|-------------|---------------|
| Storage Spaces Direct (S2D) | Converged storage on cluster nodes | Standard storage discovery path |
| SAN-backed (multi-rack) | External SAN storage, no S2D | S2D collectors return no data; storage discovery shifts to Azure-managed storage resources |
| SOFS-present | Scale-Out File Server role active | Additional file-share and SMB discovery |
| Storage Replica-present | Synchronous or asynchronous replication between sites or volumes | Replication partnership and site-awareness discovery |

## Network Architectures

| Model | Description | Ranger Impact |
|-------|-------------|---------------|
| Switched ToR fabric | Standard east-west and north-south switching | Full network validation including ToR switch posture |
| Switchless full-mesh | Direct RDMA links between nodes for storage | No storage-switch validation; storage network is point-to-point |
| Rack-aware | Multiple racks with rack-level fault domains | Rack assignment and inter-rack fabric validation |
| Multi-rack managed networking | Azure-provisioned network resources across racks | Network discovery includes Azure-managed network objects |

## Azure Connectivity Models

| Model | Description | Ranger Impact |
|-------|-------------|---------------|
| Public internet | Direct outbound connectivity to Azure endpoints | Standard Azure-side discovery |
| Proxy | Outbound traffic routes through an HTTP proxy | Proxy configuration is a discovery finding; endpoint reachability tested through proxy |
| ExpressRoute or VPN | Private connectivity to Azure | Ranger discovers the connectivity path; some Azure endpoints may differ |
| Disconnected | No Azure connectivity | Azure-side discovery gracefully degraded; findings reflect disconnected posture |

## Variant-Specific Prerequisites

Some deployment variants introduce prerequisites that are not present in standard hyperconverged deployments. Ranger checks for their presence or absence:

- **Custom location** — required for Arc VM management and some Azure service deployments
- **Arc resource bridge** — required for Arc VM management
- **Multi-rack preview topology markers** — main rack, compute racks, SAN-backed storage, managed networking
- **Azure Key Vault** — required for local-identity deployments

The presence or absence of these prerequisites is itself a finding that Ranger records in the audit manifest.

## How Variants Affect Reports and Diagrams

Ranger uses the classified deployment variant to:

- select the correct diagram templates (switchless diagrams differ from switched diagrams)
- adjust report wording (a missing AD finding is expected in local-identity mode, not a warning)
- include or exclude sections that are irrelevant to the detected variant
- validate that the discovered configuration is consistent with the classified deployment model

## Read Next

- [System Overview](architecture/system-overview.md)
- [How Ranger Works](architecture/how-ranger-works.md)
- [Discovery Domains](discovery-domains/cluster-and-node.md)
- [Outputs](outputs/diagrams.md)
