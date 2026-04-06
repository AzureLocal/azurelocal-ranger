# Ranger vs Scout

Azure Local Ranger and Azure Scout are sister solutions. They complement each other, but they solve different problems at different scopes.

This page exists to prevent scope confusion before contributors start writing design or code.

## The Core Distinction

| | Azure Scout | Azure Local Ranger |
|---|---|---|
| **Scope** | Azure tenant — broad and cloud-centric | Azure Local deployment — deep and deployment-centric |
| **Starting point** | The Azure control plane | The physical Azure Local environment |
| **Covers** | ARM resources, Entra ID, permissions, policy, cost, cloud services across the tenant | On-prem platform, workloads, Azure resources tied to one Azure Local deployment |
| **Boundary** | Tenant-wide | Deployment-wide (local + Azure-side) |

## Azure Scout

Azure Scout inventories an Azure tenant. It is broad by design:

- Azure resource inventory across subscriptions and resource groups
- Entra ID objects, identity controls, and permissions
- Azure Policy, governance, and compliance signals
- cost and consumption data
- cloud-side service posture

Scout answers: *What exists in this Azure tenant and what does its posture look like?*

## Azure Local Ranger

Azure Local Ranger inventories one Azure Local deployment in depth:

- physical infrastructure and node hardware
- cluster configuration and platform state
- storage, networking, and compute fabric
- workloads and their placement
- identity, security, and operational posture
- Azure resources that represent, manage, monitor, or extend that specific deployment
- Azure services running on or through that deployment (AKS hybrid, AVD, Arc VMs, etc.)

Ranger answers: *What exactly is this Azure Local deployment, how is it built, what is it hosting, and what Azure resources are attached to it?*

## How They Work Together

Together the two products provide a full estate story:

- **Azure Scout** explains the Azure tenant and cloud-side posture.
- **Azure Local Ranger** explains the Azure Local deployment and its Azure-connected footprint.

There is an intentional overlap zone: the Azure resources that belong to an Azure Local deployment (Arc registration, resource bridge, policy assignments, monitoring resources, etc.) are visible to both tools. Scout sees them as part of the tenant. Ranger sees them as part of the deployment.

That overlap is by design — the same resources need to appear in both contexts to tell a complete story from either direction.

## Practical Rule

- If the question is about the Azure tenant broadly → Azure Scout.
- If the question is about a specific Azure Local deployment and anything attached to it → Ranger.

## Shared Design Philosophy

Although their scopes differ, the two products align on:

- documentation-first product framing
- normalized output model
- reports designed for understanding, not just raw data export
- diagrams as a core part of the product
- clear audience targeting for outputs
- public docs via MkDocs and GitHub Pages

## Read Next

- [What Ranger Is](what-ranger-is.md)
- [Scope Boundary](scope-boundary.md)
- [System Overview](architecture/system-overview.md)
- [Getting Started](contributor/getting-started.md)
