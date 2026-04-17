# Capacity Analysis

v2.5.0 (#128). The `capacityAnalysis` domain surfaces per-node and cluster-level resource headroom so operators can identify constrained nodes before they become a problem.

## What Ranger Collects

Ranger derives capacity headroom from the data already collected by the cluster and storage-networking collectors — no additional WinRM calls are made. The analyzer runs after collection and before rendering.

- **vCPU headroom** — total logical processors vs. vCPUs allocated to running VMs, per node and cluster total
- **Memory headroom** — total physical memory vs. memory assigned to running VMs, per node and cluster total
- **Storage headroom** — total pool capacity vs. allocated volume size, per pool
- **Status thresholds** — each dimension is rated `Healthy`, `Warning`, or `Critical` based on remaining headroom percentage

## Manifest Location

```
manifest.domains.capacityAnalysis
├── clusterSummary        # cluster-wide totals and status
│   ├── vCpu             # { total, allocated, free, freePct, status }
│   ├── memory           # { total, allocated, free, freePct, status }
│   └── storage          # { total, allocated, free, freePct, status }
├── nodes[]              # per-node breakdown (same shape as clusterSummary)
│   ├── name
│   ├── vCpu
│   └── memory
└── storagePools[]       # per-pool breakdown
    ├── name
    ├── size
    └── allocated
```

## Status Thresholds

| Dimension | Healthy | Warning | Critical |
| --- | --- | --- | --- |
| vCPU free % | ≥ 25% | 10–24% | < 10% |
| Memory free % | ≥ 20% | 10–19% | < 10% |
| Storage free % | ≥ 20% | 10–19% | < 10% |

## Report Section

Capacity headroom appears in the **Capacity & Headroom** section of the HTML and Markdown reports, and in the `powerbi/capacity-analysis.csv` Power BI export.

## Related Domains

- [Storage](storage.md) — pool and disk inventory that feeds the analyzer
- [Cluster and Node](cluster-and-node.md) — node inventory and VM placement
- [Virtual Machines](virtual-machines.md) — VM vCPU and memory allocations
