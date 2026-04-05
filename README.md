# Azure Local Ranger

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Docs: MkDocs Material](https://img.shields.io/badge/docs-MkDocs%20Material-0f766e)](docs/index.md)
[![PowerShell: 7.x](https://img.shields.io/badge/PowerShell-7.x-3b82f6)](https://github.com/PowerShell/PowerShell)

Azure Local Ranger is the planned sister solution to Azure Scout for Azure Local environments.

Azure Scout explains an Azure tenant. Azure Local Ranger is meant to explain an Azure Local deployment end to end: the on-prem platform, the workloads running on it, and the Azure resources and Azure-connected services that exist because that Azure Local environment is registered, managed, monitored, or extended through Azure.

Ranger is intended to support two major use cases equally well:

- ongoing estate documentation for teams that need to understand what they currently have
- high-quality as-built documentation for teams handing a newly deployed Azure Local environment to another team, customer, or managed service owner

## What Ranger Is

Azure Local Ranger is intended to be a deep discovery, documentation, audit, and reporting product for Azure Local.

Its job is to produce a complete, structured, explainable picture of an Azure Local estate, including:

- physical infrastructure and node hardware
- cluster and platform configuration
- storage topology and health
- host and logical networking
- virtual machines and workload placement
- identity, certificates, and security posture
- Arc, Azure integration, and Azure-side resource relationships
- OEM tooling and operational management platforms
- performance baseline and operational state

That means Ranger is not just an on-prem inventory tool and not just an Azure inventory tool. It is the product that connects both sides into one Azure Local system view.

## Relationship To Azure Scout

Azure Local Ranger complements [Azure Scout](https://github.com/thisismydemo/azure-scout), but it does not duplicate it.

- Azure Scout is broad and cloud-centric. It inventories Azure tenant resources, Entra ID, permissions, cost, policy, and related cloud services.
- Azure Local Ranger is deep and deployment-centric. It inventories the Azure Local platform itself, the workloads running on it, and the Azure resources directly tied to that Azure Local deployment.

The two products should feel related in quality, tone, structure, and output philosophy, but their scopes are different.

## The Core Scope Boundary

Ranger should discover everything that makes up, runs on, secures, manages, monitors, or represents an Azure Local deployment.

That includes three major scope areas:

### 1. The On-Prem Azure Local Platform

- cluster identity and node state
- hardware, firmware, BMC, disks, NICs, TPM, and host security settings
- storage pools, volumes, CSVs, SOFS, and storage health
- virtual switches, host networking, RDMA, ATC, SDN, DNS, proxy, and firewall posture

### 2. The Workloads And Services Running On It

- virtual machine inventory and placement
- VM storage and networking configuration
- workload density and overcommit posture
- guest clustering and platform services running on the estate
- operational tooling such as WAC, SCVMM, SCOM, backup agents, and OEM management products

### 3. The Azure Resources Tied To That Azure Local Deployment

- Arc registration and cluster resource identity
- resource group, subscription, region, custom location, and resource bridge context
- Arc extensions and Azure management integrations
- Azure Monitor, Log Analytics, Update Manager, Policy, Backup, ASR, and similar attached services
- Azure-side logical resources and governance objects that belong to that Azure Local environment

This Azure-side scope is essential. Ranger should not stop at the edge of the datacenter. If Azure Local creates, depends on, or is governed by Azure resources, those resources are part of Ranger's system boundary.

## What Ranger Is Not

Ranger is not:

- a generic Azure tenant crawler
- a copy of Azure Scout with different branding
- a node-local script collection with no normalized output model
- a reports-only project
- a diagrams-only project
- an Azure-only inventory solution that ignores the local fabric

## Product Intent

The target product should allow an engineer, architect, operator, or assessor to answer questions like:

- What exactly is this Azure Local deployment?
- How is it physically built?
- How is the cluster configured?
- How is storage designed and how healthy is it?
- How is networking structured across host, storage, compute, and SDN layers?
- What workloads are running here and where are they placed?
- What is the security posture of the hosts and cluster?
- Which Azure resources represent, govern, monitor, or extend this deployment?
- Which Azure-connected services are running on or through this environment?
- What risks, drift, or operational issues are visible right now?

If Ranger cannot answer those questions, it is not fulfilling its purpose.

## Planned Output Model

Ranger is expected to produce a normalized audit model first and then use that model for output generation.

The intended output story is:

- structured audit data that represents the Azure Local deployment as a complete system
- diagrams that explain physical, logical, storage, workload, and Azure integration relationships
- reports for executive, management, and technical audiences
- polished as-built documentation packages suitable for project handoff and customer delivery
- regeneration of reports and diagrams from cached audit data without requiring live cluster access

## Current State Of This Repository

This repository is currently in a planning and documentation stage.

It contains:

- the initial repository skeleton
- public project documentation
- a root PowerShell module shell and module manifest
- GitHub Actions workflows for documentation deployment and validation
- empty implementation directories tracked with `.gitkeep`
- an internal restructure plan for correcting the current information architecture

It intentionally does not yet contain:

- functional collector implementations
- collectors
- report templates
- diagram builders
- sample audit payloads

## Start Here

- [Project Overview](docs/index.md)
- [What Ranger Is](docs/what-ranger-is.md)
- [Ranger vs Scout](docs/ranger-vs-scout.md)
- [Scope Boundary](docs/scope-boundary.md)
- [Roadmap](docs/project/roadmap.md)
- [Architecture](docs/architecture/system-overview.md)
- [Audit Manifest](docs/architecture/audit-manifest.md)
- [Repository Structure](docs/project/repository-structure.md)
- [As-Built Package](docs/outputs/as-built-package.md)
- [Discovery Domains](docs/discovery-domains)
- [Repo Restructure Plan](repo-management/plans/azure-local-ranger-restructure-plan.md)

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).