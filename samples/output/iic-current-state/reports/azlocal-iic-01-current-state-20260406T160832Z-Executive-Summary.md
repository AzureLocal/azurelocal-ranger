# Executive Summary

- Cluster: azlocal-iic-01
- Mode: current-state
- Ranger Version: 1.5.0
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
- Operational Risk Summary
- Workload Summary
- Capacity Summary

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

## Recommendations

- [WARNING] One or more node certificates expire within 90 days: Review certificate ownership and renew expiring node certificates before handoff.
- [WARNING] iDRAC firmware below recommended baseline on all nodes: Update iDRAC firmware via Dell OME or Lifecycle Controller during next maintenance window.

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

