# License Inventory

v2.5.0 (#127). The `licenseInventory` domain enumerates guest SQL Server and Windows Server instances for compliance reporting and Azure Hybrid Benefit (AHB) eligibility assessment.

## What Ranger Collects

Data is derived from the azure-integration and virtual-machines collector outputs. Guest OS and SQL detection relies on Arc guest inventory and Azure Resource Graph data — no additional WinRM calls into guest VMs are made.

- **SQL Server instances** — edition, version, core count, license model, AHB eligibility per instance
- **Windows Server instances** — edition, version, core count, license model per VM
- **AHB eligibility summary** — count of VMs eligible for but not enrolled in Azure Hybrid Benefit
- **Core totals** — aggregate licensed core counts across SQL and Windows Server

## Manifest Location

```
manifest.domains.licenseInventory
├── summary
│   ├── sqlInstanceCount
│   ├── sqlCoreTotal
│   ├── sqlAhbEligibleCount      # enrolled in AHB
│   ├── sqlAhbUnenrolledCount    # eligible but not enrolled
│   ├── windowsServerVmCount
│   └── windowsServerCoreTotal
├── sqlInstances[]
│   ├── vmName
│   ├── edition                  # Developer | Standard | Enterprise | Express
│   ├── version                  # e.g. 16.0 (SQL 2022)
│   ├── cores
│   ├── licenseModel             # LicenseIncluded | AzureHybridBenefit | BasePrice
│   └── ahbEligible
└── windowsServerInstances[]
    ├── vmName
    ├── edition                  # Datacenter | Standard | Essentials
    ├── version
    ├── cores
    └── licenseModel
```

## Report Section

License inventory appears in the **License Inventory** section of the HTML and Markdown reports, and in the `powerbi/license-inventory.csv` Power BI export.

## Related Pages

- [Azure Integration](azure-integration.md) — Arc guest inventory and AHB status
- [Virtual Machines](virtual-machines.md) — guest VM inventory
- [Cloud Publishing](../operator/cloud-publishing.md) — stream `RangerRun_CL` records including AHB adoption to Log Analytics
