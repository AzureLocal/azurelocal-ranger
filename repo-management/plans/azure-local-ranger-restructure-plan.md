# Azure Local Ranger Repo Restructure Plan

## Purpose

This plan restructures the repository so it reflects what Azure Local Ranger actually is.

The current repo is serviceable as a placeholder, but it is too generic, too shallow in its framing, and too focused on future implementation folders without first making the product definition obvious. The documentation currently starts with generic architecture language before it clearly establishes the system boundary, relationship to Azure Scout, and the fact that Ranger covers both the Azure Local platform and the Azure resources attached to it.

## Current Problems

### 1. The Product Definition Is Buried

The repo has been describing Ranger as an Azure Local auditing tool, but the most important part of the scope has not been front-loaded strongly enough: Ranger must document the full Azure Local estate, including the Azure resources created by or connected to that deployment.

It also has not been explicit enough that Ranger is intended to serve both recurring documentation needs and formal as-built handoff documentation after a deployment.

### 2. The Docs Start In The Wrong Place

The docs jump into architecture and generic planning language before answering the foundational questions:

- what Ranger is
- why it exists
- how it differs from Azure Scout
- what belongs in scope
- what does not belong in scope

### 3. The Repo Structure Needed To Reflect A Real PowerShell Module

The earlier `src` placeholder structure was too generic for a PowerShell module repository. Since Ranger is intended to become a real publishable PowerShell module and public MkDocs site, the repo needed a more deliberate implementation layout and a stronger public documentation flow.

### 4. There Is No Internal Planning Area

Most related repos in this workspace use a `repo-management` area for plans and internal project artifacts. Ranger did not have that, which made it harder to keep public product docs separate from internal restructuring work.

## Restructure Goals

The repo should be reorganized so that:

1. the product identity is unmistakable within the first few files a contributor reads
2. the system boundary is documented before implementation details
3. public docs are organized around understanding the product, not just future code folders
4. internal planning has a proper home
5. future implementation can grow into the repo without requiring another major documentation rewrite
6. the as-built documentation and handoff use case is treated as a first-class product requirement rather than an afterthought

## Recommended Information Architecture

### Public-Facing Documentation

The public docs should be ordered like this:

1. what Ranger is
2. how it relates to Azure Scout
3. what belongs in scope
4. how the architecture should work
5. what discovery domains exist
6. what outputs the product should generate
7. how contributors should think about the implementation roadmap

Those docs should also make it obvious that Ranger is meant for both day-two documentation and post-deployment as-built handoff documentation.

### Internal Planning Content

The internal repo-management area should hold:

- restructure plans
- implementation sequencing plans
- architecture decisions
- backlog grooming notes
- schema and naming proposals

That material is useful, but it should not crowd the public docs landing path.

## Target Repo Shape

The recommended near-term target is:

```text
azurelocal-ranger/
├── README.md
├── LICENSE
├── CHANGELOG.md
├── .gitignore
├── mkdocs.yml
├── docs/
│   ├── index.md
│   ├── what-ranger-is.md
│   ├── ranger-vs-scout.md
│   ├── scope-boundary.md
│   ├── architecture/
│   ├── discovery-domains/
│   ├── outputs/
│   ├── project/
│   ├── contributor/
│   └── assets/
├── repo-management/
│   └── plans/
├── Modules/
│   ├── Public/
│   ├── Private/
│   ├── Collectors/
│   ├── Core/
│   ├── Outputs/
│   │   ├── Reports/
│   │   └── Diagrams/
│   └── Internal/
├── tests/
├── samples/
└── branding/
```

## Recommended Next-Level Docs Structure

Once the team is ready to improve the docs further, the next iteration should likely split public docs into clearer conceptual groupings.

A stronger long-term documentation model would look like this:

```text
docs/
├── index.md
├── what-ranger-is.md
├── ranger-vs-scout.md
├── scope-boundary.md
├── architecture/
│   ├── system-overview.md
│   ├── audit-manifest.md
│   ├── collector-model.md
│   └── output-model.md
├── discovery-domains/
│   ├── cluster-and-node.md
│   ├── hardware.md
│   ├── storage.md
│   ├── networking.md
│   ├── virtual-machines.md
│   ├── identity-and-security.md
│   ├── azure-integration.md
│   ├── oem-integration.md
│   ├── management-tools.md
│   └── performance-baseline.md
├── outputs/
│   ├── diagrams.md
│   ├── reports.md
│   └── findings-model.md
├── contributor/
│   ├── getting-started.md
│   ├── implementation-roadmap.md
│   └── contributing.md
└── assets/
```

That grouped structure is now the correct public-facing direction for the repo because it reads properly in MkDocs and is a better fit for GitHub Pages publication.

## Recommended Repo Changes By Phase

## Phase 1: Fix The Product Framing

### Goal

Make the repo immediately understandable.

### Changes

- rewrite `README.md`
- add a dedicated `docs/what-ranger-is.md`
- update the docs landing page to route readers into the right conceptual order
- update MkDocs navigation so the product-definition page appears before architecture

### Result

Anyone opening the repo will understand that Ranger is the full Azure Local estate discovery product, not just a generic audit tool.

## Phase 2: Separate Public Docs From Internal Planning

### Goal

Keep public product docs clean while giving planning artifacts a real home.

### Changes

- introduce `repo-management/plans/`
- place restructure and sequencing plans there
- keep public docs focused on product explanation and user-facing concepts

### Result

The repo stops mixing public documentation with internal project management intent.

## Phase 3: Refactor The Docs Around Product Logic

### Goal

Reorganize docs to match the actual way people need to understand Ranger.

### Changes

- move from a flat navigation model to a conceptual model
- add explicit pages for Ranger vs Scout and scope boundary
- rename or regroup collector docs under discovery-domain language
- make outputs and implementation roadmap separate sections
- align the public docs for MkDocs and GitHub Pages consumption rather than local placeholder reading only

### Result

The docs become easier to navigate and more faithful to the product story.

## Phase 4: Align The Implementation Layout To A Real Module

### Goal

Make the repo structure look like a future PowerShell module repository rather than a generic source placeholder.

### Changes

- replace the earlier `src` placeholder with a `Modules/` layout
- reserve clear areas for public commands, private helpers, collectors, core logic, and outputs
- align the future implementation shape more closely with Azure Scout's module-oriented structure

### Result

The repo is easier to understand for contributors and better aligned with future PSGallery publication.

## Phase 5: Start Implementation Only After Scope Lock

### Goal

Avoid writing code against a vague or shifting product definition.

### Changes

- define the audit manifest shape
- define naming and status conventions
- sequence the first collector implementations
- begin code only once the product definition and docs structure are stable enough

### Result

Implementation starts from an explicit model rather than from guesses or fragmented requirements.

## Immediate Recommendations

These are the most useful immediate next steps after this plan:

1. finalize the product-definition language in README and docs
2. add a `Ranger vs Scout` document
3. add a `Scope Boundary` document
4. refine collector pages so each describes purpose, inputs, outputs, and Azure-side dependencies
5. produce an implementation roadmap for phase-one collector work
6. explicitly plan for an as-built documentation package and handoff workflow in the public roadmap
7. keep GitHub Pages publication as the public documentation delivery model

## Product Requirement: As-Built Documentation

Ranger should be planned as both a recurring discovery tool and an as-built documentation generator.

That means the product roadmap should assume the future solution can support:

- documenting an existing environment at any time
- producing a polished documentation package immediately after a deployment
- generating diagrams and narrative-ready output suitable for handoff
- providing enough accuracy and completeness that receiving teams do not need to reverse-engineer the deployment after transition

This requirement should shape report design, diagram design, manifest design, and prioritization of the first implementation phases.

## What Should Not Happen Yet

The team should avoid these actions until the product definition and repository direction are agreed:

- adding PowerShell files just to make the repo look complete
- inventing function signatures before the manifest model is defined
- building report or diagram output code before the scope boundary is stable
- treating Azure-side resource discovery as optional or secondary

## Success Criteria For The Restructure

The repo restructure is successful when:

- the README explains Ranger accurately within the first screen
- the docs clearly state that Ranger includes both Azure Local and Azure-side deployment resources
- contributors can tell the difference between public documentation and internal planning artifacts
- the docs flow matches the product story
- future implementation has an obvious place to start without forcing another repo rethink