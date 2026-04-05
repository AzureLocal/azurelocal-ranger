# Ranger vs Scout

Azure Local Ranger and Azure Scout are sister solutions, but they are not interchangeable and they should not be documented as if they solve the same problem.

## The Short Difference

- Azure Scout explains an Azure tenant.
- Azure Local Ranger explains an Azure Local deployment.

That sounds simple, but it matters because the scope, depth, and system boundary are different.

## Azure Scout

Azure Scout is cloud-first.

Its job is to discover and report on Azure and Entra ID at the tenant level. It is broad in scope and designed to inventory resources, identities, permissions, policies, and related cloud-side posture across Azure.

Azure Scout answers questions like:

- What exists in this Azure tenant?
- What ARM resources are deployed?
- What Entra ID objects and identity controls exist?
- What permissions, governance, policy, and cost signals are visible?

## Azure Local Ranger

Azure Local Ranger is deployment-first.

Its job is to discover and document one Azure Local environment in depth, including:

- the local platform itself
- the workloads hosted on it
- the Azure resources tied to that deployment

Azure Local Ranger answers questions like:

- What exactly is this Azure Local environment?
- How is it built and configured?
- What is it hosting?
- How healthy and secure is it?
- Which Azure resources represent, manage, or extend it?

## Scope Comparison

### Azure Scout Scope

Azure Scout is broad across the tenant.

It covers:

- Azure resource inventory
- Entra ID inventory
- governance and permissions
- policy and posture
- cloud-side reporting across many Azure categories

### Ranger Scope

Ranger is deep within a deployment boundary.

It covers:

- physical hardware and node inventory
- cluster and platform configuration
- storage and network architecture
- workload and virtualization inventory
- host and platform security posture
- OEM and management tooling
- Azure resources attached to the Azure Local deployment
- Azure-connected services running on or through that deployment

## How They Work Together

These tools should be complementary.

Azure Scout provides the wide tenant view.
Azure Local Ranger provides the deep Azure Local estate view.

Together they allow teams to understand both:

- the Azure environment at large
- the Azure Local deployment in full detail

## Why The Difference Matters

If Ranger is described too loosely, it risks becoming either:

- a weak copy of Azure Scout
- a local-only inventory tool that ignores the Azure side of Azure Local

Both would be wrong.

Ranger must sit in the middle: deeply local, but Azure-aware wherever Azure is part of the Azure Local deployment story.

## Shared Design Philosophy

Although their scopes differ, Ranger should align with Azure Scout in several ways:

- strong documentation-first product framing
- normalized output model
- useful reports rather than raw dumps only
- diagrams as part of understanding, not just decoration
- clear audience targeting for outputs
- professional public docs via MkDocs and GitHub Pages

## Practical Rule

A good rule of thumb is:

- If the question is about the Azure tenant broadly, it belongs to Azure Scout.
- If the question is about a specific Azure Local deployment and anything attached to it, it belongs to Ranger.
