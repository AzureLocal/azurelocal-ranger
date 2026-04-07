# Storage

This domain explains how storage is assembled, presented, and operating inside the Azure Local environment.

## What Ranger Collects

The storage domain should document:

- Storage Spaces Direct posture where applicable
- pool composition, health, and media layout
- cache and capacity relationships
- virtual disks, resiliency, and allocation posture
- CSV layout and ownership
- SOFS, Storage Replica, and QoS features when configured
- repair jobs, faults, and health signals

## Manifest Sub-Domains

The v1 collector writes to these named sections of the `storage` manifest domain:

| Sub-domain | Content |
|---|---|
| `pools` | Storage pool inventory — health, operational status, size, and allocation |
| `physicalDisks` | Physical disk inventory — media type, serial number, health, and usage classification |
| `virtualDisks` | Virtual disk inventory — resiliency setting, health, size, and pool footprint |
| `volumes` | Volume inventory — drive letter, label, file system, health, and size |
| `csvs` | Cluster Shared Volume inventory — name, state, and owning node |
| `qos` | Storage QoS policy definitions and IOPS limits |
| `sofs` | Scale-Out File Server share inventory when SOFS is deployed |
| `replica` | Storage Replica group replication state and sync signals |
| `summary` | Aggregate counts — pools, disks, virtual disks, volumes, CSVs, total capacity, and disk media types |

## Why It Matters

Storage is one of the most important parts of an Azure Local as-built package because it explains capacity, resiliency, and operational risk.

## Connectivity and Credentials

| Requirement | Purpose |
|---|---|
| WinRM / PowerShell remoting | Primary storage discovery path |
| Cluster credential | Required |

## Default Behavior

This is a core domain. If the cluster credential is present, Ranger should run it by default.

## Variant Behavior

### Hyperconverged

Storage discovery is S2D-centric and should document pools, cache, virtual disks, and CSVs.

### Switchless

Storage-network interpretation changes because the storage fabric is point-to-point rather than switch-based.

### Rack-Aware

Ranger should surface fault-domain implications in how storage is described.

### Disconnected Operations

Disconnected control-plane mode does not remove the need for local storage discovery, but Azure-side storage integrations may differ.

### Multi-Rack Preview

Multi-rack preview is not the same as standard S2D hyperconverged storage. Ranger should preserve SAN-backed or shared-storage characteristics separately rather than forcing them into an S2D-only interpretation.

## Evidence Boundaries

- **Direct discovery:** storage facts from cluster and Windows storage tooling
- **Host-side validation:** validation of access and posture from the node perspective
- **Manual/imported evidence:** optional storage-design artifacts when external arrays or shared services need additional context

## v1 and Future Boundaries

v1 should cover the local storage view required for current-state and as-built reporting.

Future work can deepen external-array, multi-rack preview, or continuity-specific storage collectors where required.