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

## Full Diagram Catalog

### Baseline Set (Diagrams 1–6)

Baseline diagrams render on most successful runs. They do not require special trigger conditions.

| # | Name | Purpose | Audience |
|---|---|---|---|
| 1 | Physical Architecture | Nodes, hardware summary, BMC, rack grouping, and physical adjacency | Executive, Management, Technical |
| 2 | Logical Network Topology | vSwitches, SET, intents, VLANs, subnets, SDN, and proxy path | Management, Technical |
| 3 | Storage Architecture | Pool, cache, virtual disks, CSVs, resiliency, and capacity posture | Management, Technical |
| 4 | VM Placement Map | VM-to-host placement, density, anti-affinity, and guest clusters | Management, Technical |
| 5 | Azure Arc Integration | Azure resource hierarchy, Arc Resource Bridge, custom location, extensions, and management flows | Executive, Management, Technical |
| 6 | Workload and Services Map | AVD, AKS, Arc VMs, monitoring stack, OEM tooling, backup, and DR relationships | Management, Technical |

### Extended Set (Diagrams 7–18)

Extended diagrams render only when the trigger condition is met.

| # | Name | Trigger Condition | Audience |
|---|---|---|---|
| 7 | Topology and Deployment Variant Map | Always in technical tier | Management, Technical |
| 8 | Identity, Trust, and Secret Flow | Local Key Vault identity mode detected | Management, Technical |
| 9 | Monitoring, Telemetry, and Alerting Flow | Monitoring domain collected | Executive, Management, Technical |
| 10 | Connectivity, Firewall, and Dependency Map | Always in technical tier | Management, Technical |
| 11 | Identity and Access Surface Map | Always in technical as-built | Management, Technical |
| 12 | Monitoring and Health Heatmap | Critical or warning findings present | Executive, Management |
| 13 | OEM Hardware and Firmware Posture | Hardware domain collected | Management, Technical |
| 14 | Backup, Recovery, and Continuity Map | Azure Backup or ASR detected | Executive, Management, Technical |
| 15 | Management Plane and Tooling Map | Always in technical tier | Executive, Management, Technical |
| 16 | Workload Family Placement Map | Multiple workload families detected | Management, Technical |
| 17 | Multi-Rack or Rack-Aware Fabric Map | Rack-aware deployment type detected | Management, Technical |
| 18 | Disconnected Operations Control Plane Map | Disconnected control plane mode detected | Management, Technical |

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
