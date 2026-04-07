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
|---|---|
| `nodes` | Per-node CPU utilization, memory pressure, and uptime snapshot |
| `compute` | Cluster-wide vCPU and memory allocation vs. capacity with overcommit indicators |
| `storage` | Storage IOPS, throughput, latency, and cache hit-ratio baselines |
| `networking` | Network throughput and adapter error counts |
| `outliers` | Nodes or workloads that significantly exceed utilization norms |
| `events` | Recent Health Service events and cluster health faults |
| `summary` | Aggregate performance risk signals — high-CPU nodes, high-memory nodes, and alert counts |

## Why It Matters

Ranger should not stop at static inventory. A short-horizon operational baseline helps explain whether a healthy-looking design is currently under stress, degraded, or simply under-observed.

## Connectivity and Credentials

| Requirement | Purpose |
|---|---|
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

## Evidence Boundaries

- **Direct discovery:** host-side utilization and event snapshots
- **Azure-side discovery:** Azure Monitor, alerts, DCRs, and HCI Insights context
- **Manual/imported evidence:** operator-supplied baselines or SLO context when needed

## v1 and Future Boundaries

v1 should provide a useful snapshot and anomaly framing.

It should not promise long-term trending, forecasting, or full APM-style workload performance analysis.