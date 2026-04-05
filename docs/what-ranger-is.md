# What Ranger Is

Azure Local Ranger is the planned sister product to Azure Scout for Azure Local environments.

This page defines the intended product clearly, because the success of the repository depends on getting the boundary right before implementation starts.

## Core Definition

Azure Local Ranger is a discovery, documentation, audit, and reporting solution for Azure Local.

Its purpose is to produce a complete picture of an Azure Local deployment as a single connected system.

That system includes:

- the on-prem infrastructure and Azure Local platform
- the workloads and platform services running on it
- the Azure resources and Azure services that exist because that Azure Local deployment is connected to Azure

That full scope is the point of Ranger.

## Two Primary Product Uses

Ranger should be designed to serve two closely related but distinct use cases.

### 1. Ongoing Environment Documentation

An operations, engineering, governance, or support team should be able to run Ranger at any time to document what currently exists.

This use case is about understanding the present state of the environment:

- what has been deployed
- how it is configured
- what is running
- what Azure resources are attached to it
- what its current health and risk posture look like

This is the recurring documentation and assessment use case.

### 2. As-Built Handoff Documentation

Ranger should also support a deployment completion and handoff scenario.

After a new Azure Local environment is deployed, the delivery team should be able to run Ranger and produce a complete as-built documentation package for handoff to:

- a customer
- another internal department
- an operations team
- a managed services team
- a support or governance function

That package should be accurate, structured, and ready to explain what was delivered.

It should not feel like a raw inventory export. It should feel like proper as-built documentation backed by discovery.

## What As-Built Means For Ranger

For Ranger, as-built documentation should mean more than a dump of technical properties.

It should aim to provide:

- a documented statement of what was deployed
- clear architecture diagrams
- workload and service placement views
- Azure integration and dependency views
- configuration summaries suitable for future operations teams
- enough technical depth that someone inheriting the solution does not need to rediscover the platform manually

This is one of the most important product intents for Ranger, because Azure Local deployments are often handed from build teams to operational ownership shortly after implementation.

## Ranger Is Not Just "Azure Scout For On-Prem"

That description is too small and it misses the most important part of the product.

Ranger is not only about servers, clusters, switches, or storage inside the datacenter. It must also understand the Azure representation of that environment. If Azure Local is registered in Azure, managed through Arc, monitored through Azure Monitor, governed by Policy, updated through Azure Update Manager, or connected to services like AKS hybrid or AVD, those Azure resources belong to Ranger's discovery boundary.

So Ranger is not only local discovery. It is Azure Local estate discovery.

## Relationship To Azure Scout

Azure Scout and Azure Local Ranger should be sister products, but they do different jobs.

### Azure Scout

Azure Scout is cloud-first. It inventories Azure tenant resources, Entra ID objects, permissions, policy, cost, and related cloud services across the tenant scope.

### Azure Local Ranger

Azure Local Ranger is deployment-first. It inventories one Azure Local environment in depth, including both its on-prem reality and its Azure-connected footprint.

### Together

Together the two products should provide a full estate story:

- Azure Scout explains the Azure tenant and cloud-side posture.
- Azure Local Ranger explains the Azure Local deployment and the Azure-side resources attached to that deployment.

That is why Ranger is a sister solution, not a duplicate solution.

## The Correct System Boundary

The cleanest way to describe Ranger's scope is this:

Ranger should discover everything that makes up, runs on, secures, manages, monitors, or represents an Azure Local deployment.

That breaks down into several layers.

## 1. Physical Platform Discovery

Ranger should be able to explain what the environment physically is.

That means discovering and documenting:

- nodes
- manufacturer and model
- serial numbers and asset data
- BIOS and firmware
- BMC management interfaces
- processors and memory topology
- GPUs when present
- physical NICs and their capabilities
- physical disks and their role in the platform
- TPM and host security hardware state

This is the physical truth of the environment.

## 2. Azure Local Cluster And Fabric Discovery

Ranger should be able to explain how the Azure Local platform is built.

That means discovering and documenting:

- cluster identity
- domain and naming context
- node state and membership
- cluster version and release train
- quorum design and witness details
- fault domains
- update posture and maintenance history
- platform registration state

This is the platform truth of the environment.

## 3. Storage Discovery

Ranger should be able to explain how storage is assembled, presented, and operating.

That means discovering and documenting:

- S2D state and health
- pool composition and media distribution
- cache and capacity relationships
- virtual disks and resiliency model
- CSV layout and ownership
- SOFS where present
- repair jobs, alerts, and storage health signals
- QoS and replication features where configured

This is the storage truth of the environment.

## 4. Networking Discovery

Ranger should be able to explain how the environment is wired and logically segmented.

That means discovering and documenting:

- physical and virtual networking relationships
- virtual switches and SET
- host vNICs
- management, storage, and compute networks
- RDMA and DCB-related posture
- Network ATC intents and compliance
- SDN components and overlays where deployed
- logical networks, policy objects, and related constructs
- DNS, proxy, and firewall context

This is the network truth of the environment.

## 5. Workload Discovery

Ranger should be able to explain what the Azure Local platform is hosting.

That means discovering and documenting:

- VM inventory
- compute and memory allocation
- disk and network configuration
- placement and anti-affinity
- replication and checkpoints
- Arc-managed VM context where applicable
- guest cluster hints when discoverable
- aggregate workload density and overcommit posture

This is the workload truth of the environment.

## 6. Identity And Security Discovery

Ranger should be able to explain who and what the environment trusts, how it is secured, and where risk may exist.

That means discovering and documenting:

- AD and cluster object placement
- cluster identity model
- Entra and Arc identity relationships
- Azure RBAC tied to the environment
- certificates and TLS-related posture
- BitLocker and secured-core signals
- WDAC, Defender, audit policy, and local admin posture

This is the security truth of the environment.

## 7. Azure Resource Discovery For Azure Local

This is the part that differentiates Ranger from a generic datacenter inventory tool.

Ranger should discover the Azure resources that exist because this Azure Local environment is connected to Azure.

That includes:

- Arc resource identity
- subscription, resource group, and region context
- custom location and resource bridge
- Arc extensions
- Azure Policy assignments tied to the environment
- Azure Monitor and Log Analytics resources used by the environment
- Update Manager, backup, DR, and related service attachments
- resource providers, logical networks, images, or similar Azure-side objects specific to the deployment

This is the Azure truth of the environment as it relates to Azure Local.

## 8. Azure Services Running On Or Through Azure Local

Ranger should also explain Azure-connected services that are deployed on top of or tightly bound to the Azure Local platform.

That includes examples such as:

- AKS hybrid
- Azure Virtual Desktop on Azure Local
- Arc VMs
- Arc Data Services
- Azure Monitor integrations
- HCI Insights
- Update, backup, and disaster recovery integrations

These are not just optional extras. In many environments, they are a major part of why Azure Local exists.

## 9. OEM And Operational Tooling

Ranger should describe how the platform is actually managed in practice.

That means documenting:

- OEM integrations such as Dell, Lenovo, HPE, or DataON management tooling
- Windows Admin Center
- SCVMM and SCOM where present
- third-party operational agents and tools when they are relevant to supportability or governance

This is the management truth of the environment.

## 10. Operational State And Health

Ranger should not stop at static inventory.

It should also establish an operational baseline that helps answer:

- how busy the hosts are
- whether storage is healthy or degraded
- whether network issues are visible
- whether important faults or event patterns are active
- whether update or maintenance posture is lagging

This is the operational truth of the environment.

## What Ranger Will Eventually Produce

Ranger is not just about discovery. It is about usable understanding.

The future product should produce:

- normalized audit data describing the full Azure Local environment
- diagrams that explain physical, logical, storage, workload, and Azure relationships
- reports for executive, management, and technical audiences
- findings that help teams prioritize risk, drift, and remediation
- as-built documentation outputs suitable for handoff after a deployment

## What Ranger Should Let Someone Answer

When mature, Ranger should let someone answer all of the following without manually piecing together data from many tools:

- What exactly is this Azure Local environment?
- How is it physically built?
- How is it configured?
- What is it hosting?
- How healthy is it?
- How secure is it?
- Which Azure resources represent or govern it?
- Which Azure services are attached to it?
- What are the top operational and architectural risks?

If the product cannot answer those questions, then the scope has drifted away from what Ranger is supposed to be.

## What Ranger Is Not

Ranger is not:

- a tenant-wide Azure inventory replacement for Azure Scout
- a basic host inventory utility
- a reporting-only layer without deep discovery
- a local-only datacenter tool that ignores Azure integration
- a generic Azure Arc browser with no platform understanding

## What This Means For The Repository

The repository should be organized around this exact product identity.

That means the repo should prioritize:

- a clear product definition
- a clear scope boundary
- a documentation model that explains why Azure Local and Azure-side discovery both belong here
- a repository structure that supports implementation later without confusing the current design phase

The repo should not pretend implementation is the main story yet. Right now, the main story is defining Ranger correctly so implementation starts from the right foundation.