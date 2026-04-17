# Storage Efficiency

v2.5.0 (#126). The `storageEfficiency` domain surfaces per-volume deduplication and thin-provisioning posture so operators can identify wasted space and dedup candidates.

## What Ranger Collects

Data is derived from the storage-networking collector output — no additional WinRM calls are made.

- **Dedup state** — enabled or disabled per volume
- **Dedup ratio** — logical saved GiB vs. raw consumed GiB
- **Saved GiB** — estimated storage reclaimed by deduplication
- **Thin-provisioning coverage** — ratio of thinly provisioned volumes to total volume count
- **Waste class tag** — each volume is tagged `over-provisioned`, `dedup-candidate`, or `none`

## Waste Class Tags

| Tag | Meaning |
| --- | --- |
| `dedup-candidate` | Dedup is not enabled but volume type/workload suggests it would yield savings |
| `over-provisioned` | Volume allocated size is significantly larger than consumed size |
| `none` | No obvious efficiency opportunity detected |

## Manifest Location

```
manifest.domains.storageEfficiency
├── summary
│   ├── totalVolumes
│   ├── dedupEnabledCount
│   ├── thinProvisionedCount
│   ├── totalSavedGib
│   └── thinProvisioningCoverage   # pct of volumes that are thin
└── volumes[]
    ├── name
    ├── pool
    ├── sizeGb
    ├── allocatedGb
    ├── usedGb
    ├── dedupEnabled
    ├── dedupRatio
    ├── savedGib
    ├── thinProvisioned
    └── wasteClass                 # over-provisioned | dedup-candidate | none
```

## Report Section

Storage efficiency appears in the **Storage Efficiency** section of the HTML and Markdown reports, and in the `powerbi/storage-efficiency.csv` Power BI export.

## Related Domains

- [Storage](storage.md) — pool and disk inventory
- [Capacity Analysis](capacity-analysis.md) — cluster-level storage headroom
