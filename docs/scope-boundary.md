# Scope Boundary

This page defines what belongs inside Azure Local Ranger's discovery and documentation boundary.

The goal is to keep the product focused and prevent scope drift in either direction.

## Core Rule

Azure Local Ranger should discover everything that makes up, runs on, secures, manages, monitors, or represents an Azure Local deployment.

That includes both local and Azure-side components when they are part of the same Azure Local system story.

## In Scope

## 1. Physical Platform

In scope:

- node hardware
- system manufacturer and model
- BIOS and firmware details
- BMC and out-of-band management context
- processors, memory, disks, NICs, GPUs, TPM
- Secure Boot and host hardware-backed security state

## 2. Azure Local Cluster And Fabric

In scope:

- cluster identity and node membership
- quorum and witness design
- fault domains
- cluster networking
- CSV and platform state
- version, release train, registration, update posture

## 3. Storage, Networking, And Virtualization

In scope:

- S2D, pools, volumes, CSVs, SOFS
- virtual switches, SET, host vNICs, RDMA, ATC, SDN
- VM inventory, placement, disks, networking, replication, and platform service relationships

## 4. Identity, Security, And Operations

In scope:

- AD and identity placement
- certificates and TLS posture
- BitLocker, secured-core, WDAC, Defender, audit posture
- operational management tooling such as WAC, OEM tooling, SCVMM, SCOM, and relevant third-party agents
- health, performance, and operational event signals

## 5. Azure Resources Attached To Azure Local

In scope:

- Arc registration and cluster resource identity
- resource group, subscription, and regional placement for the Azure Local deployment
- Arc Resource Bridge and custom location
- Arc extensions
- Azure Policy assignments and role assignments specific to that deployment
- Azure Monitor, Log Analytics, Update Manager, Backup, ASR, and similar services tied to the environment
- Azure logical resources that exist specifically because of the Azure Local deployment

## 6. Azure Services Running On Or Through Azure Local

In scope:

- AKS hybrid
- AVD on Azure Local
- Arc VMs
- Arc Data Services
- Azure-connected monitoring and update services
- Azure-side service context that is part of the Azure Local platform story

## Out Of Scope

The following areas are outside Ranger's intended boundary unless they are directly part of the Azure Local deployment being documented.

## 1. Tenant-Wide Azure Discovery

Out of scope:

- unrelated subscriptions
- unrelated resource groups
- generic tenant-wide Azure inventory
- broad Entra ID discovery not tied to the Azure Local deployment

That belongs to Azure Scout.

## 2. Generic Datacenter Discovery Unrelated To Azure Local

Out of scope:

- standalone virtualization platforms not part of the Azure Local deployment
- unrelated physical infrastructure in the same datacenter
- adjacent systems that do not participate in the Azure Local platform or its managed service boundary

## 3. Non-Documentation Change Automation

Out of scope:

- changing cluster configuration
- remediation or drift correction
- patching systems
- reconfiguring Azure resources
- lifecycle actions that modify the platform

Ranger should remain read-only.

## 4. Full CMDB Replacement

Out of scope:

- acting as the system of record for every operational object in the organization
- replacing enterprise CMDB processes
- becoming a general-purpose inventory platform for unrelated systems

## Decision Test

When deciding whether something belongs in Ranger, ask:

- Is it part of the Azure Local deployment?
- Does it run on, manage, secure, monitor, or represent that deployment?
- Would a receiving team need this information to understand or operate the environment?

If the answer is yes, it likely belongs in Ranger.

If the information is only broadly about Azure tenant posture or unrelated infrastructure, it likely belongs elsewhere.
