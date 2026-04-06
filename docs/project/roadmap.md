# Roadmap

Azure Local Ranger is being built in phases so the product boundary, execution model, and module architecture are stable before broad implementation begins.

Ranger supports two outcomes through one discovery engine:

- recurring current-state documentation
- formal as-built documentation for customer or operational handoff

## Current Phase

The repository has completed its documentation and architecture foundation phase and now has the non-live v1 implementation backlog completed in-repo.

That means the immediate priority is no longer proving that Ranger can exist structurally or filling in the remaining local implementation gaps. The immediate priority is validating the implementation against real environments and keeping post-v1 work explicitly separated.

## Phase 1: Product and Architecture Foundation

This phase locks the decisions that later implementation depends on.

Status: complete

Focus areas:

- product definition and scope boundary
- deployment-variant posture
- manifest contract and output model
- connectivity, authentication, and execution model
- internal module architecture and test strategy

## Phase 2: Documentation Foundation

This phase makes the public documentation and repo guidance match the actual product direction.

Status: complete

Focus areas:

- coherent site navigation and reading flow
- product, architecture, domain, output, and operator docs
- project roadmap and repository structure pages
- contributor guidance aligned to the current maturity level

Key documentation work is tracked in:

- [Tracker: documentation rollout from product-direction plan #14](https://github.com/AzureLocal/azurelocal-ranger/issues/14)
- [Publish project roadmap, repository structure, and contributor documentation #17](https://github.com/AzureLocal/azurelocal-ranger/issues/17)
- [Align docs navigation, cross-links, and publishing flow #18](https://github.com/AzureLocal/azurelocal-ranger/issues/18)

## Phase 3: V1 Runtime and Collector Delivery

Once the planning and documentation gates are locked, implementation can move into the v1 runtime and collector backlog.

Status: non-live implementation complete in-repo; live-environment validation still remains.

Main v1 tracks:

- orchestration and shared platform services
- topology and cluster foundation collectors
- Dell-first hardware collectors
- storage and networking collectors
- workload, identity, Azure integration, monitoring, management-tools, and performance collectors
- report generation and output packaging from the cached manifest
- diagram generation from the cached manifest

The completed v1 implementation tracks are:

- [Tracker: v1 discovery collector delivery #16](https://github.com/AzureLocal/azurelocal-ranger/issues/16)
- [Implement orchestration layer and shared platform services #19](https://github.com/AzureLocal/azurelocal-ranger/issues/19)
- [Implement topology and cluster foundation collectors #9](https://github.com/AzureLocal/azurelocal-ranger/issues/9)
- [Implement Dell OEM hardware inventory collectors #10](https://github.com/AzureLocal/azurelocal-ranger/issues/10)
- [Implement storage and networking collectors #11](https://github.com/AzureLocal/azurelocal-ranger/issues/11)
- [Implement workload, identity, and Azure integration collectors #12](https://github.com/AzureLocal/azurelocal-ranger/issues/12)
- [Implement monitoring and observability collectors #20](https://github.com/AzureLocal/azurelocal-ranger/issues/20)
- [Implement management-tools and performance baseline collectors #21](https://github.com/AzureLocal/azurelocal-ranger/issues/21)
- [Implement report generation and output packaging from cached manifest #22](https://github.com/AzureLocal/azurelocal-ranger/issues/22)
- [Implement diagram generation from cached manifest #23](https://github.com/AzureLocal/azurelocal-ranger/issues/23)
- [Tracker: core runtime and output delivery #24](https://github.com/AzureLocal/azurelocal-ranger/issues/24)

## Phase 4: Post-V1 Extension Backlog

Anything intentionally pushed out of v1 should remain visible as separate issues, not disappear into one umbrella bullet list.

Status: defined and deferred

Post-v1 extension backlog:

- [Tracker: post-v1 extension backlog #13](https://github.com/AzureLocal/azurelocal-ranger/issues/13)
- [Evaluate Azure-hosted automation worker execution model #25](https://github.com/AzureLocal/azurelocal-ranger/issues/25)
- [Investigate Azure Arc Run Command as an alternate collection transport #26](https://github.com/AzureLocal/azurelocal-ranger/issues/26)
- [Implement direct switch interrogation collectors #27](https://github.com/AzureLocal/azurelocal-ranger/issues/27)
- [Implement direct firewall interrogation collectors #28](https://github.com/AzureLocal/azurelocal-ranger/issues/28)
- [Implement non-Dell OEM hardware inventory support #29](https://github.com/AzureLocal/azurelocal-ranger/issues/29)
- [Add disconnected and limited-connectivity discovery enrichment #30](https://github.com/AzureLocal/azurelocal-ranger/issues/30)
- [Add multi-rack and management-cluster-specific discovery enrichment #31](https://github.com/AzureLocal/azurelocal-ranger/issues/31)
- [Add manual import workflows for externally governed environments #32](https://github.com/AzureLocal/azurelocal-ranger/issues/32)
- [Assess Windows PowerShell 5.1 compatibility without distorting the v1 architecture #33](https://github.com/AzureLocal/azurelocal-ranger/issues/33)

These items are now bounded by the decisions recorded in `repo-management/plans/post-v1-extension-decisions.md` and remain intentionally outside the v1 delivery baseline.

## Phase 5: Live-Estate Validation

Status: remaining open item

The final remaining implementation task is to run Ranger against a real Azure Local environment and reconcile the generated package against known environment facts.

## Guiding Rule

If a requirement is explicitly future-scope, it should stay visible in the roadmap and preferably have its own backlog item rather than surviving only as a sentence in architecture documentation.

## Read Next

- [Status](status.md)
- [Documentation Roadmap](documentation-roadmap.md)
- [Repository Structure](repository-structure.md)
- [Getting Started](../contributor/getting-started.md)
