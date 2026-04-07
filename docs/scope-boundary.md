# Scope Boundary

This page defines what belongs inside Azure Local Ranger's discovery and documentation boundary and how different kinds of evidence are classified.

It is the guardrail for future implementation decisions. If a proposed feature does not fit the boundary described here, it does not belong in Ranger.

## Core Rule

Azure Local Ranger discovers everything that makes up, runs on, secures, manages, monitors, or represents an Azure Local deployment.

That includes both local and Azure-side components when they are part of the same Azure Local system story.

## Discovery Tiers

Not all discovery targets are reached the same way. Ranger classifies evidence into four tiers based on how data is obtained.

### Tier 1 — Direct Discovery

Ranger connects to the target and collects data directly.

This is the primary discovery method for:

- cluster nodes via PowerShell remoting (WinRM)
- OEM hardware via Redfish REST API (iDRAC, iLO, XCC)
- Azure resources via Az PowerShell or Azure CLI

Direct discovery produces authoritative, machine-collected evidence.

### Tier 2 — Host-Side Validation

Ranger cannot connect to the external device directly, but it validates the posture from the cluster-node perspective.

This applies to:

- TOR switch connectivity verified from the host (link state, LLDP neighbour data)
- firewall and proxy posture validated by testing required endpoints from the node
- DNS resolution and reachability tested from the host

Host-side validation produces indirect but useful evidence about infrastructure Ranger cannot interrogate directly.

### Tier 3 — Optional Direct Device Discovery

When the user explicitly provides targets and credentials, Ranger can interrogate third-party devices directly.

This applies to:

- TOR switches (vendor-specific REST, SSH, or NX-API)
- firewalls (PAN-OS API, FortiOS REST, etc.)
- other network or infrastructure devices the user opts into

This tier is always opt-in, never assumed. Each vendor requires its own collector module.

### Tier 4 — Manual or Imported Evidence

For infrastructure that cannot be discovered automatically, Ranger accepts manually provided data or structured imports.

This applies to:

- network designs from the network team
- firewall rule sets provided as exports
- site or rack assignment data when physical topology is not discoverable
- any other evidence the user provides that Ranger should include in the audit

Manual evidence is included in the manifest and marked as imported so it is distinguishable from machine-collected data.

#### Tier 4 Scope Decision — Two Separate Workflows

Within Tier 4, two distinct workflows exist and are treated separately. This boundary was formally established as part of [Decision #52](https://github.com/AzureLocal/azurelocal-ranger/issues/52).

**Workflow A — Offline Static Config Parsing (in scope for v1)**

Ranger can accept structured config outputs exported from devices it cannot interrogate directly — for example, a network switch config file or firewall export — and parse specific, well-understood fields from those files using a hints-based import pattern.

This applies when:

- the evidence source is a named, well-structured file format (e.g. a JSON export, a vendor-specific config export)
- Ranger knows which fields to extract and what they mean
- the import is triggered by the user providing a file path, not by Ranger discovering data automatically

This capability is tracked as [#36 — offline config import](https://github.com/AzureLocal/azurelocal-ranger/issues/36) and is in scope for v1.

**Workflow B — General Manual Import with Evidence Provenance (post-v1)**

A broader capability to accept arbitrary user-provided evidence — including freeform text, screenshots, or structured data with unknown schema — and track it with explicit provenance metadata (who provided it, when, from what source, with what confidence level) is a different and more complex problem.

This applies when:

- the evidence is not a known structured format
- the import requires user-defined metadata about how the evidence was gathered
- the manifest must record the provenance so downstream consumers understand the data quality

This capability is tracked as [Decision #32 — manual import workflow](https://github.com/AzureLocal/azurelocal-ranger/issues/32) and is explicitly deferred to post-v1.

**Why they are separate:** Workflow A (static config parsing) is a constrained, well-defined extension of the Redfish/WinRM discovery model — the "source" is just a file instead of a live endpoint. Workflow B (general manual import with provenance) requires a fundamentally different evidence model and has significant UX surface area. Conflating them would block v1 shipping while waiting for a complex feature that is not required for the core use case.

## In Scope

### 1. Physical Platform

- node hardware, manufacturer, model, serial number, asset data
- BIOS, firmware, BMC, out-of-band management interfaces
- processors, memory, disks, NICs, GPUs, TPM
- Secure Boot and host hardware-backed security state

### 2. Azure Local Cluster and Fabric

- cluster identity, node membership, quorum, witness, fault domains
- cluster networking, CSV state, version, release train, registration
- update posture and maintenance history

### 3. Storage, Networking, and Virtualization

- S2D, pools, volumes, CSVs, SOFS, storage health, replication
- virtual switches, SET, host vNICs, RDMA, ATC, SDN, logical networks
- VM inventory, placement, disks, networking, workload density

### 4. Identity, Security, and Operations

- AD or local identity model, cluster identity mode
- certificates, TLS posture, BitLocker, secured-core, WDAC, Defender
- WAC, OEM tooling, SCVMM, SCOM, operational agents
- health, performance baseline, event patterns

### 5. Azure Resources Attached to Azure Local

- Arc registration, cluster resource identity
- resource group, subscription, region, custom location, resource bridge
- Arc extensions, Azure Policy, RBAC specific to the deployment
- Azure Monitor, Log Analytics, Update Manager, Backup, ASR
- Azure logical resources that exist because of the Azure Local deployment

### 6. Azure Services Running On or Through Azure Local

- AKS hybrid, AVD on Azure Local, Arc VMs, Arc Data Services
- Azure-connected monitoring and update services
- HCI Insights and related integrations

## Out of Scope

### 1. Tenant-Wide Azure Discovery

- unrelated subscriptions and resource groups
- generic tenant-wide Azure inventory
- broad Entra ID discovery not tied to the deployment

That belongs to Azure Scout.

### 2. Generic Datacenter Discovery

- standalone virtualization platforms not part of Azure Local
- unrelated physical infrastructure in the same datacenter
- adjacent systems outside the Azure Local deployment boundary

### 3. Change Automation

- modifying cluster configuration
- remediation or drift correction
- patching, reconfiguration, or lifecycle actions

Ranger is read-only.

### 4. Full CMDB Replacement

- acting as the system of record for every operational object in the organisation
- replacing enterprise CMDB processes
- general-purpose inventory for unrelated systems

## Decision Test

When deciding whether something belongs in Ranger, ask:

1. Is it part of the Azure Local deployment?
2. Does it run on, manage, secure, monitor, or represent that deployment?
3. Would a receiving team need this information to understand or operate the environment?

If the answer is yes, it belongs in Ranger. If the information is only about Azure tenant posture broadly or unrelated infrastructure, it belongs elsewhere.

## Read Next

- [Deployment Variants](deployment-variants.md)
- [Discovery Domains](discovery-domains/cluster-and-node.md)
- [Outputs](outputs/diagrams.md)
- [Roadmap](project/roadmap.md)
