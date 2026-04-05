# Azure Local Ranger

Azure Local Ranger is the planned discovery and documentation solution for Azure Local estates.

Its purpose is to explain an Azure Local deployment as one connected system, including the local platform, the workloads running on it, and the Azure resources that represent, manage, monitor, or extend that deployment.

## The Short Version

Azure Scout explains Azure.

Azure Local Ranger should explain Azure Local in full, which means:

- the on-prem platform
- the workloads hosted on that platform
- the Azure resources and Azure-connected services attached to that platform

That is the core purpose of this repo.

## Why This Matters

An Azure Local environment is not just a cluster and not just a set of Azure Arc resources. It is a connected estate.

To understand it properly, a team needs one product that can document:

- how the environment is physically built
- how the cluster is configured
- how storage and networking are designed
- what is running on the platform
- what security and operational posture looks like
- how the deployment is represented and managed in Azure

## What To Read First

- [What Ranger Is](what-ranger-is.md)
- [Ranger vs Scout](ranger-vs-scout.md)
- [Scope Boundary](scope-boundary.md)
- [Roadmap](project/roadmap.md)
- [Architecture](architecture/system-overview.md)
- the discovery-domain pages under `docs/discovery-domains/`
- [Diagrams](outputs/diagrams.md)
- [Reports](outputs/reports.md)

## Current Repository State

This repository is currently in a design and documentation phase. The structure is present, but implementation has not started yet.

The immediate goal is to define the product clearly enough that future implementation work can be organized around the right scope and the right repository layout.