# Documentation Roadmap

This page explains how the Ranger documentation set is intended to mature over time.

The goal is not just to have many pages. The goal is to have a documentation site that guides a reader from product definition to implementation readiness without dead ends.

## Current Documentation Goal

The current goal is to make the public docs accurate, coherent, and implementation-ready before broad code delivery begins.

That means the documentation set should:

- define the product boundary clearly
- explain how Ranger runs
- explain what Ranger discovers and outputs
- explain the repo phase and contribution expectations
- make future work visible instead of hiding it in planning prose

## Phase 1: Product Truth

These pages establish what Ranger is and what it is not.

Main pages:

- [What Ranger Is](../what-ranger-is.md)
- [Ranger vs Scout](../ranger-vs-scout.md)
- [Scope Boundary](../scope-boundary.md)
- [Deployment Variants](../deployment-variants.md)

## Phase 2: Architecture and Operator Model

These pages explain the runtime, manifest, internal architecture, configuration model, and operator assumptions.

Main pages:

- [System Overview](../architecture/system-overview.md)
- [How Ranger Works](../architecture/how-ranger-works.md)
- [Audit Manifest](../architecture/audit-manifest.md)
- [Implementation Architecture](../architecture/implementation-architecture.md)
- [Configuration Model](../architecture/configuration-model.md)
- [Operator Guide](../operator/prerequisites.md)

## Phase 3: Discovery and Output Reference

These pages define what Ranger collects and what it produces.

Main page groups:

- [Discovery Domains](../discovery-domains/cluster-and-node.md)
- [Outputs](../outputs/diagrams.md)

## Phase 4: Project and Contributor Guidance

These pages explain how the repo is structured, what phase it is in, and what work contributors should do now.

Main pages:

- [Roadmap](roadmap.md)
- [Repository Structure](repository-structure.md)
- [Getting Started](../contributor/getting-started.md)
- [Contributing](../contributor/contributing.md)

## Phase 5: Implementation-Era Documentation

Once implementation starts in earnest, the docs should expand carefully rather than explode into placeholders.

Expected future additions:

- installation and prerequisites tied to real code
- usage examples tied to real commands
- sample configurations and sample manifests
- renderer and output examples tied to actual product behavior
- troubleshooting guided by real runtime behavior

## Documentation Discipline

Three rules matter:

1. public docs should reflect settled decisions, not raw planning churn
2. future-scope items should stay visible through roadmap and backlog references
3. navigation should lead readers from product definition to architecture to execution to contribution naturally

## Read Next

- [Roadmap](roadmap.md)
- [Repository Structure](repository-structure.md)
- [Getting Started](../contributor/getting-started.md)