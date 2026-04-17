# Technical As-Built

- Cluster: azlocal-iic-01
- Mode: as-built
- Ranger Version: 2.1.0
- Generated: 04/06/2026 12:08:32
- Schema validation: passed or warnings only

## Table of Contents

- Document Control
- Run Summary
- Readiness Snapshot
- Environment Overview
- Topology and Operating Model
- Domain Coverage
- Node Inventory
- Collector Status
- Operational Risk Summary
- Workload Summary
- Capacity Summary
- Priority Recommendations
- VM Inventory
- VM Density Metrics
- Storage Pool Capacity
- ESU Enrollment
- Coverage Assessment
- Security Posture Summary
- Management Tool Coverage
- Cost & Licensing
- Cost & Licensing — Per Node
- Arc Extensions by Node
- Logical Networks
- Logical Network Subnets
- Storage Paths
- Arc Resource Bridge
- Custom Locations
- Arc Gateways
- Marketplace & Custom Images
- Arc Agent Versions
- VM Distribution by Node
- Domain Inventory
- Physical Disk Inventory
- Network Adapter Inventory
- Domain Summary
- Storage Resiliency
- Event Log Summary
- Security Audit
- Raw Data Appendix
- Installation Register (Bill of Materials)
- Per-Node Configuration Record
- Network Address Allocation Record
- Storage Configuration Record
- Identity and Security Record
- Azure Integration Record
- Validation Record
- Known Issues and Deviations
- Acceptance and Sign-Off

## Document Control

**Document Title**: Azure Local As-Built Documentation — azlocal-iic-01
**Package ID**: azlocal-iic-01-as-built-20260417T020638Z
**Report Tier**: technical
**Revision**: 1.0 (initial handoff)
**Classification**: CONFIDENTIAL — CUSTOMER DELIVERABLE
**Prepared By Azure Local Ranger v2.1.0**: 
**Prepared On**: 04/06/2026 12:08:32
**Schema Version**: 1.2.0-draft
**Document Status**: FINAL — AS-BUILT HANDOFF

## Run Summary

- Mode: as-built
- Generated: 04/06/2026 12:08:32
- Cluster: azlocal-iic-01
- Nodes: 3
- Collectors: 7/7 successful
- Artifacts currently recorded: 0

## Readiness Snapshot

- Schema validation: passed
- Critical findings: 0
- Warning findings: 2
- Informational findings: 2
- Successful collectors: 7 of 7
- Partial or failed collectors: 0

## Environment Overview

- VMs discovered: 5
- Azure resources discovered: 10
- Connected Azure auth method: service-principal
- Monitoring resources: 5
- Management services running: 4

## Topology and Operating Model

- Deployment type: hyperconverged
- Identity mode: ad
- Connectivity mode: connected
- Storage architecture: storage-spaces-direct
- Network architecture: switched
- Variant markers: connected

## Domain Coverage

- Cluster nodes: 3
- Cluster roles: 5
- Storage pools: 1
- Physical disks: 24
- Network adapters: 12
- VMs discovered: 5
- Azure resources: 10
- Alerting resources: 2
- Management services: 4

## Node Inventory

| Node | Model | State | OS | OS Version / Build | Logical CPUs | RAM (GiB) |
| --- --- --- --- --- --- --- |
| azl-iic-n01 | PowerEdge R760 | Up | Microsoft Azure Stack HCI | 10.0.25398.1189 | 64 | 512 |
| azl-iic-n02 | PowerEdge R760 | Up | Microsoft Azure Stack HCI | 10.0.25398.1189 | 64 | 512 |
| azl-iic-n03 | PowerEdge R760 | Up | Microsoft Azure Stack HCI | 10.0.25398.1189 | 64 | 512 |

## Collector Status

- hardware: success ()
- management-performance: success ()
- monitoring-observability: success ()
- storage-networking: success ()
- topology-cluster: success ()
- waf-assessment: success ()
- workload-identity-azure: success ()

## Operational Risk Summary

- Nodes not healthy: 0
- Unhealthy disks: 0
- High CPU nodes: 0
- Certificates expiring within 90 days: 1
- Azure Policy assignments: 2
- Schema warnings: 0
- Azure Advisor recommendations:  total, 3 high-impact

## Workload Summary

- Total VMs: 5
- Total nodes: 3
- AKS clusters: 1
- Arc-connected machines: 1
- Update compliance: No update resources tracked
- Licensing: IIC Platform Production
- VMs using Arc IP fallback: Not collected

## Capacity Summary

- Storage total raw: 0 TiB
- Storage total usable: 0 TiB
- Storage used by workloads: 0 TiB (0% of usable)
- Storage reserve target: 0 TiB (0% of usable)
- Storage free usable: 0 TiB
- Projected safe allocatable: 0 TiB
- Thin provisioning ratio: Not computed
- vCPU:pCPU overcommit ratio: Not computed
- Memory overcommit ratio: Not computed
- Average VMs per node: N/A

## Priority Recommendations

- [WARNING] One or more node certificates expire within 90 days: Review certificate ownership and renew expiring node certificates before handoff.
- [WARNING] iDRAC firmware below recommended baseline on all nodes: Update iDRAC firmware via Dell OME or Lifecycle Controller during next maintenance window.
- [INFORMATIONAL] Azure Policy assignments discovered at resource group scope: Verify policy scope extends to arc resource group and monitor for compliance drift.
- [INFORMATIONAL] Cluster event history includes a transient network quorum warning: Review switch port configuration to confirm management NICs are on dedicated VLANs and bonded correctly.

## VM Inventory

| Name | State | vCPU | RAM (GiB) | Host Node | Generation |
| --- --- --- --- --- --- |
| avd-iic-sh01 | Running | 8 | 16 | azl-iic-n01 | 2 |
| avd-iic-sh02 | Running | 8 | 16 | azl-iic-n02 | 2 |
| avd-iic-sh03 | Running | 8 | 16 | azl-iic-n03 | 2 |
| arc-iic-vm01 | Running | 4 | 8 | azl-iic-n01 | 2 |
| arc-iic-vm02 | Running | 4 | 8 | azl-iic-n02 | 2 |

## VM Density Metrics

- VMs per node (average): N/A
- Highest-density node: N/A
- vCPU:pCPU overcommit ratio: Not computed
- Memory overcommit ratio: Not computed
- Arc-connected VMs: 
- VMs using Arc IP fallback: 
- Avg CPU utilization (all nodes): 38.3%
- Avg available memory (all nodes): 176 GiB

## Storage Pool Capacity

| Pool | Raw (GiB) | Usable (GiB) | Used (GiB) | Reserve (GiB) | Safe Alloc (GiB) | Posture |
| --- --- --- --- --- --- --- |
| — | 0 | 0 | 0 | 0 | 0 | — |

## ESU Enrollment

- Eligible Arc-connected VMs: 
- Enrolled in ESU: 
- Not enrolled in ESU: 
- Ineligible: 
- 

## Coverage Assessment

- Monitoring coverage (AMA): 100% (3 of 3 nodes have Azure Monitor Agent)
- Backup coverage estimate: 20% (based on backup items vs VM count)
- Defender for Cloud: Not confirmed or not collected
- WDAC policy: Not collected
- BitLocker status: Not collected
- Certificates expiring in <90 days: 1

## Security Posture Summary

- Secured-Core enabled nodes:  of 3
- Syslog forwarding nodes: 
- RBAC assignments at resource group: 1
- Policy assignments tracked: 2
- Policy exemptions: 
- Active Directory site: Not collected

## Management Tool Coverage

- WAC installed nodes:  of 3
- SCVMM agent nodes: 
- SCOM agent nodes: 
- Running management services: 4
- Third-party agent types:  (0)

## Cost & Licensing

- AHB status: Enabled
- Total physical cores: 96  |  AHB-covered: 96  |  Unenrolled: 0
- Current monthly cost: 960 USD @ 10/core/month
- AHB adoption: 100%
- Potential monthly savings (if remaining cores enrolled in AHB): 0 USD
- Pricing based on Azure Local public pricing (10 USD/physical core/month) as of 2026-04-16.
- For current rates, see: https://azure.microsoft.com/en-us/pricing/details/azure-local/

## Cost & Licensing — Per Node

| Node | Physical Cores | AHB Enabled | Monthly Cost (USD) | Monthly Saving (USD) |
| --- --- --- --- --- |
| azl-iic-n01 | 32 | Yes | 320 | 320 |
| azl-iic-n02 | 32 | Yes | 320 | 320 |
| azl-iic-n03 | 32 | Yes | 320 | 320 |

_Pricing as of 2026-04-16 — https://azure.microsoft.com/en-us/pricing/details/azure-local/_

## Arc Extensions by Node

| Node | Name | Type | Publisher | Version | State |
| --- --- --- --- --- --- |
| azl-iic-n01 | AzureMonitorWindowsAgent | AzureMonitorWindowsAgent | Microsoft.Azure.Monitor | 1.22.2.0 | Succeeded |
| azl-iic-n01 | GuestConfigExtension | ConfigurationforWindows | Microsoft.GuestConfiguration | 1.29.78.0 | Succeeded |
| azl-iic-n01 | MicrosoftDefenderForServers | MDE.Windows | Microsoft.Azure.AzureDefenderForServers | 1.0 | Succeeded |
| azl-iic-n02 | AzureMonitorWindowsAgent | AzureMonitorWindowsAgent | Microsoft.Azure.Monitor | 1.22.2.0 | Succeeded |
| azl-iic-n02 | GuestConfigExtension | ConfigurationforWindows | Microsoft.GuestConfiguration | 1.29.78.0 | Succeeded |
| azl-iic-n02 | MicrosoftDefenderForServers | MDE.Windows | Microsoft.Azure.AzureDefenderForServers | 1.0 | Succeeded |
| azl-iic-n03 | AzureMonitorWindowsAgent | AzureMonitorWindowsAgent | Microsoft.Azure.Monitor | 1.22.2.0 | Succeeded |
| azl-iic-n03 | GuestConfigExtension | ConfigurationforWindows | Microsoft.GuestConfiguration | 1.29.78.0 | Succeeded |
| azl-iic-n03 | MicrosoftDefenderForServers | MDE.Windows | Microsoft.Azure.AzureDefenderForServers | 1.0 | Succeeded |

_AMA coverage: 100% of nodes. Failed extensions: 0._

## Logical Networks

| Name | VM Switch | DHCP | Subnets | State |
| --- --- --- --- --- |
| lnet-iic-mgmt-01 | ConvergedSwitch | No | 1 | Succeeded |
| lnet-iic-workload-01 | ConvergedSwitch | Yes | 1 | Succeeded |

## Logical Network Subnets

| Network | Subnet | Address Prefix | VLAN | IP Pools |
| --- --- --- --- --- |
| lnet-iic-mgmt-01 | subnet-management | 10.0.0.0/24 | 2203 | 1 |
| lnet-iic-workload-01 | subnet-workload | 10.0.2.0/24 | 2205 | 1 |

## Storage Paths

| Name | Path | Available (GB) | File System | State |
| --- --- --- --- --- |
| sp-iic-vmstore-01 | C:\ClusterStorage\csv-iic-azlocal-01-vmstore-01\ArcVmDisks | 1480 | CSVFS_ReFS | Succeeded |
| sp-iic-vmstore-02 | C:\ClusterStorage\csv-iic-azlocal-01-vmstore-02\ArcVmDisks | 1620 | CSVFS_ReFS | Succeeded |
| sp-iic-vmstore-03 | C:\ClusterStorage\csv-iic-azlocal-01-vmstore-03\ArcVmDisks | 1710 | CSVFS_ReFS | Succeeded |

## Arc Resource Bridge

| Name | Status | Version | Distro | Provisioning |
| --- --- --- --- --- |
| rb-iic-azlocal-01 |
| Connected |
| 1.5.23 |
| MOC-K8S |
| Succeeded |

## Custom Locations

| Name | Namespace | Location | State |
| --- --- --- --- |
| cl-iic-azlocal-01 |
| azlocal |
| eastus |
| Succeeded |

## Arc Gateways

| Name | Endpoint | Allowed Features | State |
| --- --- --- --- |
| arcgw-iic-01 |
| https://arcgw-iic-01.gw.arc.azure.com |
| * |
| Succeeded |

## Marketplace & Custom Images

| Name | Type | OS | Version | Size (GB) | State |
| --- --- --- --- --- --- |
| img-iic-ws2022-datacenter | Marketplace | Windows | 20348.2700.240906 | 127 | Succeeded |
| img-iic-rhel9-base | Custom | Linux | 9.4.1 | 24 | Succeeded |

## Arc Agent Versions

| Version | Node Count | Nodes |
| --- --- --- |
| 1.39.02750.1478 | 2 | azl-iic-n01, azl-iic-n02 |
| 1.38.02620.1234 | 1 | azl-iic-n03 |

_Drift status: warning. Latest: 1.39.02750.1478. Max behind: 1._

## VM Distribution by Node

| Node | VM Count |
| --- --- |
| azl-iic-n01 | 2 |
| azl-iic-n02 | 2 |
| azl-iic-n03 | 1 |

_Balance: balanced  |  CV: 0.283  |  Status: warning_

## Domain Inventory

- Storage pools: 1
- Virtual disks: 3
- Cluster networks: 4
- Management tools: 4
- Monitoring components: 5
- Cluster roles: 5
- Replication entries: 0
- Update resources: 1

## Physical Disk Inventory

| Node | Model | Media Type | Size (GiB) | Health | Firmware |
| --- --- --- --- --- --- |
| azl-iic-n01 | PhysicalDisk 001 | NVMe | 1789 | Healthy | — |
| azl-iic-n01 | PhysicalDisk 002 | NVMe | 1789 | Healthy | — |
| azl-iic-n01 | PhysicalDisk 003 | NVMe | 1789 | Healthy | — |
| azl-iic-n01 | PhysicalDisk 004 | NVMe | 1789 | Healthy | — |
| azl-iic-n01 | PhysicalDisk 005 | NVMe | 1789 | Healthy | — |
| azl-iic-n01 | PhysicalDisk 006 | NVMe | 1789 | Healthy | — |
| azl-iic-n01 | PhysicalDisk 007 | NVMe | 1789 | Healthy | — |
| azl-iic-n01 | PhysicalDisk 008 | NVMe | 1789 | Healthy | — |
| azl-iic-n02 | PhysicalDisk 009 | NVMe | 1789 | Healthy | — |
| azl-iic-n02 | PhysicalDisk 010 | NVMe | 1789 | Healthy | — |
| azl-iic-n02 | PhysicalDisk 011 | NVMe | 1789 | Healthy | — |
| azl-iic-n02 | PhysicalDisk 012 | NVMe | 1789 | Healthy | — |
| azl-iic-n02 | PhysicalDisk 013 | NVMe | 1789 | Healthy | — |
| azl-iic-n02 | PhysicalDisk 014 | NVMe | 1789 | Healthy | — |
| azl-iic-n02 | PhysicalDisk 015 | NVMe | 1789 | Healthy | — |
| azl-iic-n02 | PhysicalDisk 016 | NVMe | 1789 | Healthy | — |
| azl-iic-n03 | PhysicalDisk 017 | NVMe | 1789 | Healthy | — |
| azl-iic-n03 | PhysicalDisk 018 | NVMe | 1789 | Healthy | — |
| azl-iic-n03 | PhysicalDisk 019 | NVMe | 1789 | Healthy | — |
| azl-iic-n03 | PhysicalDisk 020 | NVMe | 1789 | Healthy | — |
| azl-iic-n03 | PhysicalDisk 021 | NVMe | 1789 | Healthy | — |
| azl-iic-n03 | PhysicalDisk 022 | NVMe | 1789 | Healthy | — |
| azl-iic-n03 | PhysicalDisk 023 | NVMe | 1789 | Healthy | — |
| azl-iic-n03 | PhysicalDisk 024 | NVMe | 1789 | Healthy | — |

## Network Adapter Inventory

| Node | Adapter | Link Speed | Status | MAC Address | Driver |
| --- --- --- --- --- --- |
| azl-iic-n01 | NIC1 | 25000000000 | Up | 00:50:56:IIC:0:00 | — |
| azl-iic-n01 | NIC2 | 25000000000 | Up | 00:50:56:IIC:0:01 | — |
| azl-iic-n01 | NIC3 | 25000000000 | Up | 00:50:56:IIC:0:02 | — |
| azl-iic-n01 | NIC4 | 25000000000 | Up | 00:50:56:IIC:0:03 | — |
| azl-iic-n02 | NIC1 | 25000000000 | Up | 00:50:56:IIC:1:00 | — |
| azl-iic-n02 | NIC2 | 25000000000 | Up | 00:50:56:IIC:1:01 | — |
| azl-iic-n02 | NIC3 | 25000000000 | Up | 00:50:56:IIC:1:02 | — |
| azl-iic-n02 | NIC4 | 25000000000 | Up | 00:50:56:IIC:1:03 | — |
| azl-iic-n03 | NIC1 | 25000000000 | Up | 00:50:56:IIC:2:00 | — |
| azl-iic-n03 | NIC2 | 25000000000 | Up | 00:50:56:IIC:2:01 | — |
| azl-iic-n03 | NIC3 | 25000000000 | Up | 00:50:56:IIC:2:02 | — |
| azl-iic-n03 | NIC4 | 25000000000 | Up | 00:50:56:IIC:2:03 | — |

## Domain Summary

- Node manufacturers: Dell Inc. (3)
- Storage media types: NVMe (24)
- Adapter states: Up (12)
- VM generations: 2 (5)
- Azure resource types: Microsoft.AzureStackHCI/clusters (1), Microsoft.DesktopVirtualization/hostPools (1), Microsoft.HybridCompute/machines (3), Microsoft.ResourceConnector/appliances (1), Microsoft.ExtendedLocation/customLocations (1), Microsoft.RecoveryServices/vaults (1)
- Monitoring: telemetry=1, AMA=3, DCR=1
- Performance: avg CPU=38.3%, avg available memory=176 GiB
- ESU: eligible=, enrolled=, not enrolled=

## Storage Resiliency

- Total raw: 0 GiB (0 TiB)
- Total usable (after resiliency): 0 GiB (0 TiB)
- Resiliency overhead: N/A% of raw
- Reserve target: 0 GiB  |  Safe allocatable: 0 GiB

## Event Log Summary

- No events recorded in this collection window.

## Security Audit

| Area | Item | Value |
| --- --- --- |
| Certificates | Total tracked | 1 |
| Certificates | Expiring within 90 days | 1 |
| Policy | Assignments | 2 |
| Policy | Exemptions |  |
| Policy | Non-compliant |  |
| Identity | AD CNO objects tracked | 1 |
| Identity | RBAC assignments at RG scope | 1 |
| Workload Protection | Backup items tracked | 1 |
| Workload Protection | ASR protected items | 1 |
| Endpoint | Defender for Cloud enabled | Not confirmed |
| Endpoint | Secured-Core enabled nodes |  of 3 |
| Endpoint | WDAC policy | Not collected |
| Endpoint | BitLocker | Not collected |

## Raw Data Appendix

- The complete collection manifest (ranger-manifest.json) is included in this package.
- It contains the full raw evidence from all collectors, including every data point used to generate this report.
- To regenerate reports from the saved manifest without re-running discovery, use:
-   Invoke-AzureLocalRanger -ManifestPath <path-to-manifest.json> -OutputPath <output-folder>
- Manifest schema version: 1.2.0-draft
- Collection completed: 04/06/2026 12:08:32
- Ranger version: 2.1.0

## Installation Register (Bill of Materials)

| Hostname | FQDN | Manufacturer | Model | Serial | BIOS at Deployment | OS Installed | OS Build |
| --- --- --- --- --- --- --- --- |
| azl-iic-n01 | azl-iic-n01.iic.local | Dell Inc. | PowerEdge R760 | Not recorded | 2.10.0.0 | Microsoft Azure Stack HCI | 10.0.25398.1189 |
| azl-iic-n02 | azl-iic-n02.iic.local | Dell Inc. | PowerEdge R760 | Not recorded | 2.10.0.0 | Microsoft Azure Stack HCI | 10.0.25398.1189 |
| azl-iic-n03 | azl-iic-n03.iic.local | Dell Inc. | PowerEdge R760 | Not recorded | 2.10.0.0 | Microsoft Azure Stack HCI | 10.0.25398.1189 |

_Each unit listed above was installed and commissioned as part of this deployment. Serial numbers are recorded as discovered at handoff; missing values indicate the collector could not access the field._

## Per-Node Configuration Record

| Node | State at Handoff | Logical CPUs | Installed Memory | Domain Joined | BIOS Version |
| --- --- --- --- --- --- |
| azl-iic-n01 | Up | 64 | 512 GiB | iic.local | 2.10.0.0 |
| azl-iic-n02 | Up | 64 | 512 GiB | iic.local | 2.10.0.0 |
| azl-iic-n03 | Up | 64 | 512 GiB | iic.local | 2.10.0.0 |

_Each node was configured with the values above at the time of deployment._

## Network Address Allocation Record

| Cluster Network | Role | Network Address | Mask | Metric | State |
| --- --- --- --- --- --- |
| Management | Cluster + Client (Management) | 10.0.0.0 | 255.255.255.0 | 100 | Up |
| Storage-1 | Cluster Only (Storage) | 10.0.1.0 | 255.255.255.0 | 200 | Up |
| Storage-2 | Cluster Only (Storage) | 10.0.1.128 | 255.255.255.128 | 200 | Up |
| Workload | Cluster + Client (Workload) | 10.0.2.0 | 255.255.255.0 | 300 | Up |

_Cluster networks were assigned and configured as recorded above during deployment._

## Storage Configuration Record

| Storage Pool | Raw Capacity | Usable Capacity | Health at Handoff |
| --- --- --- --- |
| S2D on azlocal-iic-01 | 43068 GiB | — | Healthy |

_Storage pools and their capacities were provisioned at deployment as shown. CSV and virtual-disk details are included in the delivery-registers workbook._

## Identity and Security Record

**Identity mode**: ad
**Active Directory site**: Not collected
**Secured-Core nodes enrolled**:  of 3
**BitLocker**: Not collected
**WDAC policy**: Not collected
**Certificates tracked**: 1
**Certificates expiring <90d**: 1
**RBAC assignments at RG scope**: 1

## Azure Integration Record

**Tenant ID**: 00000000-0000-0000-0000-000000000000
**Subscription ID**: 33333333-3333-3333-3333-333333333333
**Resource Group**: rg-iic-compute-01
**Arc-connected machines**: 1
**AKS clusters**: 1
**Azure Monitor Agents**: 3
**Backup items**: 1
**ASR protected items**: 1

## Validation Record

**Validation report**: See cluster-validation report artifact (Test-Cluster output)
**Collectors run**: 7
**Collectors successful**: 7
**Collectors partial**: 0
**Collectors failed**: 0
**Schema validation**: Passed
**Critical findings**: 0
**Warning findings**: 2

## Known Issues and Deviations

| Severity | Item | Deviation | Remediation Path |
| --- --- --- --- |
| WARNING | One or more node certificates expire within 90 days | Identity posture data indicates certificate on azl-iic-n01 expires within 90 days. | Review certificate ownership and renew expiring node certificates before handoff. |
| WARNING | iDRAC firmware below recommended baseline on all nodes | OEM integration data shows iDRAC firmware at 7.10.30.00. The recommended baseline is 7.20 or later. | Update iDRAC firmware via Dell OME or Lifecycle Controller during next maintenance window. |

_Deviations listed below were documented at handoff. Items are accepted as-built unless explicitly marked for follow-up remediation._

## Acceptance and Sign-Off

| Role | Name | Date | Signature |
| --- | --- | --- | --- |
| Implementation Engineer | | | |
| Technical Reviewer | | | |
| Customer Representative | | | |

## Recommendations

- [WARNING] One or more node certificates expire within 90 days: Review certificate ownership and renew expiring node certificates before handoff.
- [WARNING] iDRAC firmware below recommended baseline on all nodes: Update iDRAC firmware via Dell OME or Lifecycle Controller during next maintenance window.
- [INFORMATIONAL] Azure Policy assignments discovered at resource group scope: Verify policy scope extends to arc resource group and monitor for compliance drift.
- [INFORMATIONAL] Cluster event history includes a transient network quorum warning: Review switch port configuration to confirm management NICs are on dedicated VLANs and bonded correctly.

## Findings

### [WARNING] One or more node certificates expire within 90 days
Identity posture data indicates certificate on azl-iic-n01 expires within 90 days.

Current state: 1 certificate expiring within 90 days
Recommendation: Review certificate ownership and renew expiring node certificates before handoff.
Affected components: azl-iic-n01

### [WARNING] iDRAC firmware below recommended baseline on all nodes
OEM integration data shows iDRAC firmware at 7.10.30.00. The recommended baseline is 7.20 or later.

Current state: iDRAC firmware 7.10.30.00
Recommendation: Update iDRAC firmware via Dell OME or Lifecycle Controller during next maintenance window.
Affected components: azl-iic-n01, azl-iic-n02, azl-iic-n03

### [INFORMATIONAL] Azure Policy assignments discovered at resource group scope
2 policy assignments are enforcing tagging and security control auditing.

Current state: 2 policy assignments active
Recommendation: Verify policy scope extends to arc resource group and monitor for compliance drift.
Affected components: rg-iic-compute-01

### [INFORMATIONAL] Cluster event history includes a transient network quorum warning
A Management network quorum warning event was recorded on 2026-04-06. Cluster recovered automatically.

Current state: single event logged; cluster healthy
Recommendation: Review switch port configuration to confirm management NICs are on dedicated VLANs and bonded correctly.
Affected components: azlocal-iic-01

