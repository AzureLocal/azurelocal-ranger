# Storage

This domain explains how storage is assembled, presented, and operating inside the Azure Local environment.

## What Ranger Collects

The storage domain should document:

- Storage Spaces Direct posture where applicable
- pool composition, health, and media layout
- cache and capacity relationships
- virtual disks, resiliency, and allocation posture
- CSV layout and ownership
- Storage Replica, QoS, and related storage features when configured
- repair jobs, faults, and health signals

## Manifest Sub-Domains

The v1 collector writes to these named sections of the `storage` manifest domain:

| Sub-domain | Content |
| --- | --- |
| `pools` | Storage pool inventory — health, operational status, size, and allocation |
| `physicalDisks` | Physical disk inventory — media type, serial number, health, and usage classification |
| `virtualDisks` | Virtual disk inventory — resiliency setting, health, size, and pool footprint |
| `volumes` | Volume inventory — drive letter, label, file system, health, and size |
| `csvs` | Cluster Shared Volume inventory — name, state, and owning node |
| `qos` | Storage QoS policy definitions and IOPS limits |
| `replica` | Storage Replica group replication state and sync signals |
| `summary` | Aggregate counts — pools, disks, virtual disks, volumes, CSVs, total capacity, and disk media types |

## Current Collector Depth

Current v1 collection also covers:

- Health-fault inventory for active storage issues.
- QoS policy and QoS flow detail when those features are enabled.
- Scrub, cache, and dedup posture for the S2D storage stack.
- Storage Replica group and partnership detail when replication is configured.

## Why It Matters

Storage is one of the most important parts of an Azure Local as-built package because it explains capacity, resiliency, and operational risk.

## Connectivity and Credentials

| Requirement | Purpose |
| --- | --- |
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

## Example Manifest Data

A successful collect produces entries like this:

```json
{
  "id": "storageNetworking",
  "status": "success",
  "domains": {
    "storage": {
      "pools": [
        { "name": "S2D on tplabs-clus01", "health": "Healthy", "operationalStatus": "OK",
          "size": 43980465111040, "allocated": 21474836480 }
      ],
      "physicalDisks": [
        { "friendlyName": "SAMSUNG MZWLL1T6HEHP", "mediaType": "SSD", "health": "Healthy",
          "usage": "CacheOrJournal", "serialNumber": "S3EVNX0K123456" }
      ],
      "volumes": [
        { "path": "\\\\?\\Volume{abc123}", "label": "ClusterPerformanceHistory",
          "health": "Healthy", "sizeGB": 10, "fileSystem": "ReFS" }
      ],
      "summary": { "poolCount": 1, "physicalDiskCount": 16, "volumeCount": 6,
                   "totalCapacityTB": 43.98, "ssdCount": 16, "hddCount": 0 }
    }
  }
}
```

## Common Findings

| Finding | Severity | What it means |
| --- | --- | --- |
| Physical disk in unhealthy state | Error | One or more drives are degraded or failed; resiliency may be reduced |
| Storage pool has active repair job | Warning | Data rebuild in progress; performance may be degraded and cluster is temporarily less resilient |
| Volume health not Healthy | Warning | A volume is degraded or has faults; investigate before running workloads |
| No CSVs detected | Info | Cluster Shared Volumes absent; expected in non-S2D or minimal configurations |
| Storage QoS not configured | Info | No QoS policies defined; workload IOPS are uncapped |

## Partial Status

`status: partial` on the storage collector means some sub-collectors failed. Common causes:

- QoS or Storage Replica query fails while pool, disk, and volume data succeeds — the inventory data is still valid
- One node is unreachable so per-node disk views are incomplete but the overall pool picture is accurate
- CSV state query times out — volumes and pool data still collected

Check `manifest.collectors[*].messages` to see exactly which sub-section returned incomplete data.

## Domain Dependencies

Depends on the cluster-and-node domain for a resolved node list. If cluster-and-node is `failed`, storage collection attempts may fail or return incomplete results.

## Evidence Boundaries

- **Direct discovery:** storage facts from cluster and Windows storage tooling
- **Host-side validation:** validation of access and posture from the node perspective
- **Manual/imported evidence:** optional storage-design artifacts when external arrays or shared services need additional context

## v1 and Future Boundaries

v1 should cover the local storage view required for current-state and as-built reporting.

Future work can deepen external-array, multi-rack preview, or continuity-specific storage collectors where required.