# Diagrams

Diagrams are first-class Ranger outputs. They are not decorative extras.

They exist to make architecture, relationships, and operational boundaries visible faster than tables alone can do.

## Diagram Rendering Rule

Diagrams render from the cached audit manifest. They do not perform live discovery.

If required data is missing, the diagram should be skipped or marked unavailable with a clear reason rather than rendered with guessed data.

## Source and Export Format

When diagrams materially improve clarity, Ranger documentation should prefer draw.io source files exported to SVG.

Planned asset layout:

- `docs/assets/diagrams/*.drawio` for editable source
- `docs/assets/diagrams/*.svg` for published output and embedding

## Baseline Diagram Set

The baseline set should be available for most meaningful runs.

| Diagram | Purpose |
|---|---|
| Physical Architecture | Nodes, hardware summary, BMC, rack grouping, and physical adjacency |
| Logical Network Topology | vSwitches, SET, intents, VLANs, subnets, SDN, and proxy path |
| Storage Architecture | Pool, cache, virtual disks, CSVs, resiliency, and capacity posture |
| VM Placement Map | VM-to-host placement, density, anti-affinity, and guest clusters |
| Azure Arc Integration | Azure resource hierarchy, Arc Resource Bridge, custom location, extensions, and management flows |
| Workload and Services Map | AVD, AKS, Arc VMs, monitoring stack, OEM tooling, backup, and DR relationships |

## Extended Diagram Set

The extended set should be available when the environment is complex or the output mode is more formal.

| Diagram | Use case |
|---|---|
| Topology and Deployment Variant Map | switchless, rack-aware, local identity, disconnected, or multi-rack environments |
| Identity, Trust, and Secret Flow | AD, managed identity, Key Vault, RecoveryAdmin, RBAC, and certificate paths |
| Monitoring, Telemetry, and Alerting Flow | AMA, DCRs, DCEs, Log Analytics, metrics, alerts, syslog, and third-party flows |
| Connectivity, Firewall, and Dependency Map | jump box, WinRM, Redfish, Azure egress, proxy, and endpoint groups |
| Identity and Access Surface Map | cluster identities, custom location, Arc identities, RBAC scope, and trust boundaries |
| Monitoring and Health Heatmap | domain or node health summary for executive outputs |
| OEM Hardware and Firmware Posture | per-node firmware, BMC, OEM tooling, and compliance state |
| Backup, Recovery, and Continuity Map | Azure Backup, ASR, Storage Replica, Hyper-V Replica, and protected workloads |
| Management Plane and Tooling Map | WAC, SCVMM, SCOM, Azure portal, CLI, OEM tools, and automation entry points |
| Workload Family Placement Map | workload families across nodes, racks, or clusters |
| Multi-Rack or Rack-Aware Fabric Map | rack aggregation, SAN/shared storage boundaries, managed networking spans |
| Disconnected Operations Control Plane Map | local control plane, policy, Key Vault, registry, and appliance surfaces |

## Selection Rules

Diagram generation should follow clear rules:

1. baseline diagrams for most successful current-state and as-built runs
2. extended diagrams only when the detected features justify them
3. variant-specific diagrams only when the environment shape requires them
4. skip diagrams whose required evidence is missing

Examples:

- do not generate a multi-rack fabric map for a standard hyperconverged cluster
- do not generate a Key Vault secret-flow diagram unless local identity with Key Vault is detected or explicitly documented
- do not generate a detailed Azure integration diagram if Azure-side discovery was skipped

## Audience Subsets

### Executive Subset

Executive outputs usually need only a small subset such as:

- Physical Architecture
- Azure Arc Integration
- Monitoring and Health Heatmap
- Backup, Recovery, and Continuity Map

### Technical Subset

Technical and as-built outputs can include most or all applicable diagrams.

## Diagram Standards

All diagrams should include:

- title
- cluster or environment label
- generation timestamp
- Ranger version watermark

Diagram outputs should remain legible, consistent, and obviously product documentation rather than scratch engineering sketches.
