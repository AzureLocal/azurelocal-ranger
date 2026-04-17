# VM Utilization

v2.5.0 (#125). The `vmUtilization` domain classifies virtual machines as idle, underutilized, or active and emits rightsizing proposals with estimated freed-resource savings.

## What Ranger Collects

Utilization data is read from `vm.utilization` sidecar files written alongside the VM inventory. When no sidecar data is available, VMs are classified as `unknown`. No additional WinRM calls are made by this analyzer.

- **Classification** — each VM is rated `idle`, `underutilized`, or `active` based on average and peak CPU and average memory utilization over the observation window
- **Rightsizing proposals** — idle and underutilized VMs receive a proposed vCPU and proposed memory value based on observed peak
- **Savings estimate** — aggregate freed vCPU and memory across all downsizable VMs

## Classification Thresholds

| Class | Avg CPU | Peak CPU | Notes |
| --- | --- | --- | --- |
| `idle` | < 5% | < 10% | Candidate for shutdown or consolidation |
| `underutilized` | < 20% | < 40% | Candidate for rightsizing |
| `active` | ≥ 20% or peak ≥ 40% | — | No action recommended |
| `unknown` | — | — | No utilization sidecar data available |

## Manifest Location

```
manifest.domains.vmUtilization
├── summary              # aggregates
│   ├── idleCount
│   ├── underutilizedCount
│   ├── activeCount
│   ├── unknownCount
│   ├── potentialFreedVCpu
│   └── potentialFreedMemoryGb
└── vms[]                # per-VM detail
    ├── name
    ├── hostNode
    ├── currentVCpu
    ├── currentMemoryGb
    ├── avgCpuPct
    ├── peakCpuPct
    ├── avgMemoryPct
    ├── classification    # idle | underutilized | active | unknown
    ├── proposedVCpu
    └── proposedMemoryGb
```

## Report Section

VM utilization appears in the **VM Utilization** section of the HTML and Markdown reports, and in the `powerbi/vm-utilization.csv` Power BI export.

## Related Domains

- [Virtual Machines](virtual-machines.md) — base VM inventory
- [Capacity Analysis](capacity-analysis.md) — cluster-level headroom derived from VM allocations
