# Management Summary

- Cluster: azlocal-iic-01
- Mode: current-state
- Ranger Version: 1.4.2
- Generated: 04/06/2026 12:08:32
- Schema validation: passed or warnings only

## At-a-Glance Health Status

- ● GREEN — Overall Health
- ● GREEN — Azure Integration
- ○ UNKNOWN — Security Posture
- ● GREEN — Monitoring Coverage

## Table of Contents

- Run Summary
- Readiness Snapshot
- Health Status
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
- WAF Assessment — Scorecard
- WAF Assessment — Azure Advisor Recommendations

## Run Summary

- Mode: current-state
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

## Health Status

- Overall health: GREEN ( critical,  warning findings)
- Azure integration: GREEN (10 Azure resources discovered)
- Security posture: GRAY (Secured-Core enabled on  node(s))
- Monitoring coverage: GREEN (100% of nodes have Azure Monitor Agent)

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

| Node | Model | State | OS | OS Build | CPU Sockets | RAM (GiB) |
| --- --- --- --- --- --- --- |
| azl-iic-n01 |
| PowerEdge R760 |
| Up |
| — |
| — |
| — |
| 512 |
| azl-iic-n02 |
| PowerEdge R760 |
| Up |
| — |
| — |
| — |
| 512 |
| azl-iic-n03 |
| PowerEdge R760 |
| Up |
| — |
| — |
| — |
| 512 |

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
- Licensing: Not collected
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
| avd-iic-sh01 |
| Running |
| 8 |
| 16 |
| azl-iic-n01 |
| 2 |
| avd-iic-sh02 |
| Running |
| 8 |
| 16 |
| azl-iic-n02 |
| 2 |
| avd-iic-sh03 |
| Running |
| 8 |
| 16 |
| azl-iic-n03 |
| 2 |
| arc-iic-vm01 |
| Running |
| 4 |
| 8 |
| azl-iic-n01 |
| 2 |
| arc-iic-vm02 |
| Running |
| 4 |
| 8 |
| azl-iic-n02 |
| 2 |

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
| — |
| 0 |
| 0 |
| 0 |
| 0 |
| 0 |
| — |

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

## WAF Assessment — Scorecard

| Pillar | Score | Status | Rules Passing | Top Finding |
| --- --- --- --- --- |
| Reliability |
| 67% |
| Needs Attention |
| 4 / 6 |
| Cluster quorum is configured |
| Security |
| 17% |
| At Risk |
| 1 / 6 |
| Secured-Core is enabled on cluster nodes |
| Cost Optimization |
| 50% |
| Needs Attention |
| 1 / 2 |
| ESU-eligible VMs are enrolled in Extended Security Updates |
| Operational Excellence |
| 33% |
| At Risk |
| 2 / 6 |
| Azure Monitor alert rules are defined |
| Performance Efficiency |
| 67% |
| Needs Attention |
| 2 / 3 |
| Storage utilization is within safe limits |

_Overall WAF score: 43% (10 of 23 rules passing). Evaluated from saved manifest — no re-collection required._

## WAF Assessment — Azure Advisor Recommendations

| Pillar | Impact | Finding | Recommendation |
| --- --- --- --- |
| — |
| High |
| System.Collections.Specialized.OrderedDictionary |
| — |
| — |
| High |
| System.Collections.Specialized.OrderedDictionary |
| — |
| — |
| High |
| System.Collections.Specialized.OrderedDictionary |
| — |
| — |
| Medium |
| System.Collections.Specialized.OrderedDictionary |
| — |
| — |
| Medium |
| System.Collections.Specialized.OrderedDictionary |
| — |
| — |
| Medium |
| System.Collections.Specialized.OrderedDictionary |
| — |
| — |
| Medium |
| System.Collections.Specialized.OrderedDictionary |
| — |
| — |
| Medium |
| System.Collections.Specialized.OrderedDictionary |
| — |

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

