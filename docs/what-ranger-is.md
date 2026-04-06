# What Ranger Is

This page is the canonical product definition for Azure Local Ranger. If anything elsewhere conflicts with this page, this page wins.

## Core Definition

Azure Local Ranger is a discovery, documentation, audit, and reporting solution for Azure Local.

It documents an Azure Local deployment as a complete system. That system includes:

- the on-prem infrastructure and Azure Local platform
- the workloads and platform services running on it
- the Azure resources and Azure services that exist because that deployment is connected to Azure

Ranger is deployment-first. It starts from the physical and logical reality of the Azure Local environment and follows every connection outward — into Azure, into identity, into networking, into the workloads the platform hosts.

## Two Primary Modes

Ranger serves two closely related but distinct use cases through the same discovery engine.

### 1. Current-State Documentation

Run Ranger at any time to document what currently exists.

This mode supports assessment, troubleshooting, operational understanding, governance review, and drift analysis. It answers:

- what the environment is
- how it is configured
- what it is hosting
- what Azure resources are connected to it
- what its current health and risk posture look like

The output is a structured discovery report and optional diagrams.

### 2. As-Built Handoff Documentation

Run Ranger after a deployment to produce a formal documentation package.

This mode supports project closure, customer handoff, operations onboarding, managed-service transition, and support readiness. The output is a polished as-built package that includes narrative summaries, architecture diagrams, configuration deep-dives, and enough clarity that the receiving team does not need to rediscover the environment manually.

### Same Discovery, Different Output

Both modes run the same collectors against the same targets. The as-built mode produces a richer, more formal artifact. The current-state mode produces a leaner operational report. The difference is a parameter, not a different product.

## Deployment-Variant Awareness

Azure Local is not a single-shape platform. Ranger is designed with explicit support for the range of Azure Local operating models:

- hyperconverged
- switchless storage fabric
- rack-aware
- local identity with Azure Key Vault (no Active Directory)
- disconnected operations
- multi-rack

The deployment variant materially changes what Ranger discovers, how it interprets findings, and what it includes in reports and diagrams. Ranger classifies the deployment model before interpreting lower-level data. See [Deployment Variants](deployment-variants.md) for details.

## Workload-Family Awareness

Ranger identifies the major workload families running on or through the Azure Local platform, including:

- Azure Virtual Desktop on Azure Local
- AKS hybrid
- Arc VMs
- Arc Data Services
- traditional Hyper-V virtual machines
- guest-clustered services

Deep workload-specific inspection is phased, but Ranger must identify whether each major workload family is present even in early releases.

## The System Boundary

Ranger discovers everything that makes up, runs on, secures, manages, monitors, or represents an Azure Local deployment. That spans several layers:

| Layer | What Ranger Covers |
|-------|-------------------|
| Physical platform | Nodes, hardware, firmware, BMC, NICs, disks, GPUs, TPM |
| Cluster and fabric | Cluster identity, quorum, fault domains, update posture, registration |
| Storage | S2D, pools, volumes, CSVs, SOFS, storage health and replication |
| Networking | Virtual switches, host vNICs, RDMA, ATC, SDN, DNS, proxy, firewall posture |
| Workloads | VM inventory, placement, density, Arc VM overlays, workload families |
| Identity and security | AD or local identity, certificates, BitLocker, WDAC, Defender, audit posture |
| Azure resources | Arc registration, resource bridge, custom location, policy, monitoring, update, backup |
| Azure services | AKS hybrid, AVD, Arc Data Services, HCI Insights, and related integrations |
| OEM and management | Dell/HPE/Lenovo tooling, WAC, SCVMM, SCOM, operational agents |
| Operational state | Health, performance baseline, event patterns, maintenance posture |

If the Azure Local deployment creates, depends on, or is governed by a resource, that resource is inside Ranger's boundary.

## Ranger Is Not

- a tenant-wide Azure inventory replacement for Azure Scout
- a basic host inventory utility
- a reporting-only layer without deep discovery
- a local-only datacenter tool that ignores Azure integration
- a generic Azure Arc browser with no platform understanding
- a tool that modifies or remediates the environment — Ranger is read-only

## Relationship To Azure Scout

Azure Scout explains an Azure tenant. Azure Local Ranger explains an Azure Local deployment.

They are sister solutions with different scopes. See [Ranger vs Scout](ranger-vs-scout.md) for the full comparison.

## What Ranger Lets Someone Answer

- What exactly is this Azure Local deployment?
- How is it physically built?
- How is it configured?
- What is it hosting?
- How healthy is it?
- How secure is it?
- Which Azure resources represent or govern it?
- Which Azure services are attached to it?
- What are the top operational and architectural risks?

If Ranger cannot answer those questions, the scope has drifted.

The repo should not pretend implementation is the main story yet. Right now, the main story is defining Ranger correctly so implementation starts from the right foundation.

## Read Next

- [Ranger vs Scout](ranger-vs-scout.md)
- [Scope Boundary](scope-boundary.md)
- [System Overview](architecture/system-overview.md)
- [Roadmap](project/roadmap.md)