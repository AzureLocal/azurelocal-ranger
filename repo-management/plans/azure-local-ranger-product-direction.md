# Azure Local Ranger Product Direction

## Purpose

This document captures the intended product direction for Azure Local Ranger so planning decisions, documentation, repository structure, and future implementation all align to the same definition.

## Product Mission

Azure Local Ranger should document an Azure Local deployment as a complete system.

That means it must discover and describe:

- the on-prem Azure Local platform
- the workloads and services running on it
- the Azure resources and Azure-connected services attached to that deployment

## Primary Product Modes

Azure Local Ranger should be planned around two primary modes of use.

### 1. Current-State Documentation Mode

This is the ongoing discovery mode.

Teams should be able to run Ranger at any time to document what currently exists in an Azure Local environment. This supports assessment, troubleshooting, operational understanding, governance review, and drift analysis.

This mode should answer:

- what the environment is
- how it is configured
- what it is hosting
- what Azure resources are connected to it
- what its current health and risk posture look like

### 2. As-Built Documentation Mode

This is the handoff mode.

After a new Azure Local deployment is completed, the delivery team should be able to run Ranger and generate a documentation package suitable for formal handoff to another team or customer.

This mode should support:

- project closure documentation
- customer handoff
- handoff from implementation to operations
- managed service onboarding
- support transition and operational readiness

## What The As-Built Package Should Contain

The as-built package should not be treated as a thin export of raw inventory. It should be a structured delivery artifact.

At a minimum, future planning should assume the as-built package includes:

- environment identity and deployment summary
- cluster, node, and platform configuration overview
- storage and network architecture summaries
- workload and service inventory
- Azure integration map
- architecture diagrams
- technical deep-dive reference material
- enough clarity and completeness for a receiving team to operate the environment without rediscovering it manually

## Planning Implications

This product direction has implications for every major design area.

### Manifest Design

The audit manifest must support both recurring operational reporting and formal as-built outputs.

### Diagram Design

Diagrams should be designed for both technical analysis and handoff-quality documentation.

### Reporting Design

Reports should support both audience-tiered operational reporting and a polished as-built package.

### Repository Design

The repository should be structured as both:

- a public MkDocs documentation site intended for GitHub Pages publication
- a future PowerShell module repository intended for PSGallery publication

That means public docs should stay concept-driven and the future implementation tree should stay module-oriented.

### Prioritization

Implementation sequencing should prioritize the discovery domains most essential for accurate as-built documentation:

- cluster and node
- hardware
- storage
- networking
- Azure integration

## Public Story

The public-facing roadmap should communicate that Ranger is being built for both ongoing documentation and as-built handoff documentation.

That requirement is part of the product identity, not a future enhancement idea.

The public docs should also make it obvious that Ranger is a MkDocs and GitHub Pages-style documentation repo in parallel with being a future PowerShell module repo.