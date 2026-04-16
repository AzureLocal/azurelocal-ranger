# Performance Baseline

This domain captures short-horizon operational signals that help teams understand the current state of the environment.

It is a baseline, not a full long-term observability platform.

## What Ranger Collects

The performance-baseline domain should document:

- host CPU and memory utilization snapshots
- storage IOPS, throughput, latency, cache, and health-adjacent signals
- network throughput and error indicators
- active alert or Health Service summaries
- recent event patterns that materially affect interpretation of the current state

## Manifest Sub-Domains

The v1 collector writes to these named sections of the `performance` manifest domain:

| Sub-domain | Content |
| --- | --- |
| `nodes` | Per-node CPU utilization, memory pressure, and uptime snapshot |
| `compute` | Cluster-wide vCPU and memory allocation vs. capacity with overcommit indicators |
| `storage` | Storage IOPS, throughput, latency, and cache hit-ratio baselines |
| `networking` | Network throughput and adapter error counts |
| `outliers` | Nodes or workloads that significantly exceed utilization norms |
| `events` | Recent Health Service events and cluster health faults |
| `summary` | Aggregate performance risk signals — high-CPU nodes, high-memory nodes, and alert counts |

## Current Collector Depth

Current v1 collection also covers:

- RDMA and host-network performance counters where available.
- CSV cache and storage-latency context used for platform health interpretation.
- Event-log aggregation and outlier detection across the nodes.
- Point-in-time performance baselines that feed management and technical report sections.

## Why It Matters

Ranger should not stop at static inventory. A short-horizon operational baseline helps explain whether a healthy-looking design is currently under stress, degraded, or simply under-observed.

## Connectivity and Credentials

| Requirement | Purpose |
| --- | --- |
| WinRM / PowerShell remoting | Host-side performance and event data |
| Cluster credential | Required |
| Optional Azure credential | Useful for Azure Monitor, metrics, alerts, and HCI Insights correlation |

## Default Behavior

This domain should run by default when cluster credentials are available.

Azure-side observability overlays should be partial or skipped when Azure credentials are missing.

## Variant Behavior

### Hyperconverged

Baseline host, storage, and network metrics apply directly.

### Disconnected Operations

Monitoring paths differ because local control-plane observability matters more than public Azure telemetry assumptions.

### Multi-Rack Preview

Performance interpretation may need to respect managed networking and SAN-backed storage rather than assuming standard hyperconverged behaviors.

## Example Manifest Data

A successful collect produces entries like this:

```json
{
  "id": "managementPerformance",
  "status": "success",
  "domains": {
    "performance": {
      "nodes": [
        { "host": "tplabs-01-n01", "cpuUsagePercent": 12.4, "memoryUsedGB": 148,
          "memoryTotalGB": 256, "uptimeDays": 14 },
        { "host": "tplabs-01-n02", "cpuUsagePercent": 8.1, "memoryUsedGB": 132,
          "memoryTotalGB": 256, "uptimeDays": 14 }
      ],
      "storage": {
        "iopsRead": 4821, "iopsWrite": 2310,
        "latencyReadMs": 0.4, "latencyWriteMs": 0.6,
        "cacheHitRatePercent": 94.2
      },
      "outliers": [],
      "summary": { "highCpuNodeCount": 0, "highMemoryNodeCount": 0, "activeAlertCount": 0 }
    }
  }
}
```

## Common Findings

| Finding | Severity | What it means |
| --- | --- | --- |
| Node CPU utilization above 80% | Warning | Host is under significant compute load at time of collection; investigate workload distribution |
| Node memory utilization above 90% | Warning | Memory pressure detected; workload consolidation may be needed |
| Storage latency above threshold | Warning | Read or write latency is elevated; investigate cache hit rate and disk health |
| Storage cache hit rate below 80% | Warning | Cache is not effective; working set may exceed cache capacity |
| Active Health Service alerts | Warning | Cluster has open health faults; investigate before treating run data as a clean baseline |

## Partial Status

`status: partial` on the performance collector means:

- Per-node CPU/memory snapshots succeeded on some nodes but not others
- Azure Monitor overlay (HCI Insights, DCR state) failed while local performance counters succeeded — local baseline is still valid
- Event-log aggregation timed out while compute and storage metrics succeeded

Local performance snapshots are collected independently of Azure Monitor. Azure Monitor absence does not invalidate the on-premises performance baseline.

## Domain Dependencies

Depends on the cluster-and-node domain for a node list. Azure Monitor overlay sections also depend on valid `targets.azure` configuration and an active Azure credential.

## Evidence Boundaries

- **Direct discovery:** host-side utilization and event snapshots
- **Azure-side discovery:** Azure Monitor, alerts, DCRs, and HCI Insights context
- **Manual/imported evidence:** operator-supplied baselines or SLO context when needed

## v1 and Future Boundaries

v1 should provide a useful snapshot and anomaly framing.

It should not promise long-term trending, forecasting, or full APM-style workload performance analysis.