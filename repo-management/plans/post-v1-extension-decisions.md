# Post-V1 Extension Decisions

This document captures the explicit product decisions and boundary conditions for the post-v1 Azure Local Ranger backlog.

Its purpose is to close the planning and definition issues for future scope without pulling those features into the v1 implementation baseline.

## Decision Model

- v1 remains a PowerShell 7.x-first, jump-box or management-workstation-driven collection model.
- Post-v1 work may extend transport, evidence sources, and import paths, but it must preserve the manifest-first output contract.
- Any future implementation must stay opt-in when it introduces external device APIs, new trust boundaries, or non-host evidence sources.

## #25 Azure-Hosted Automation Worker Execution Model

Decision:
Azure-hosted execution is a valid post-v1 path, but it remains an alternate runner model rather than the default posture.

Supported future execution shapes worth considering first:

- Azure Automation Hybrid Worker running inside the customer-connected management boundary
- Azure VM or Azure Container Apps job running in a private network with line-of-sight to Azure Local endpoints
- GitHub-hosted orchestration only when a customer-managed relay or worker inside the trusted network performs the actual collection

Required network and identity assumptions:

- WinRM, Redfish, and Azure control-plane access must still be reachable from the hosted worker
- Secrets must resolve through managed identity, service principal, or a secure vault path; interactive prompting is not the preferred hosted model
- Hosted runs must emit the same manifest and package artifacts as workstation runs

Portability rules to preserve now:

- collector logic cannot assume an interactive desktop session
- credential resolution must remain separable from the collector implementations
- output rendering must remain decoupled from live collection

Explicit v1 exclusion:

- no Azure-hosted execution path is implemented in v1

## #26 Azure Arc Run Command Alternate Transport

Decision:
Arc Run Command is a limited-use optional future transport, not a replacement for WinRM and not a required v1 dependency.

Why:

- it depends on Azure registration, Arc agent health, RBAC, and command execution quotas
- it introduces different evidence-fidelity and latency characteristics than WinRM
- it is useful for constrained estates where WinRM is blocked, but only for domains that tolerate command fan-out and output-size limits

Candidate safe-use domains:

- lightweight node inventory
- service and policy posture checks
- selected monitoring and identity posture snapshots

Non-goals:

- not the default transport
- not required for disconnected estates
- not a prerequisite for core report or diagram generation

## #27 Direct Switch Interrogation

Decision:
Direct switch interrogation stays a future optional collector family with a separate opt-in configuration and credential boundary.

First implementation path when prioritized:

- vendor-specific adapters behind one normalized network-fabric evidence contract
- start with one vendor only after a concrete customer or lab target exists

Configuration and merge model:

- switch targets, credentials, and protocol details live in a dedicated config section
- direct switch evidence augments host-side networking evidence; it does not replace it
- reports and diagrams must label direct-fabric evidence separately from host-derived evidence

Explicit v1 exclusion:

- v1 networking stays host-centric

## #28 Direct Firewall Interrogation

Decision:
Direct firewall interrogation stays a future optional collector family with its own trust and safety boundary.

First implementation path when prioritized:

- a single vendor-specific adapter or a structured import path if direct APIs are too estate-specific

Configuration and merge model:

- firewall connection data and credentials stay isolated from host credentials
- firewall evidence complements proxy, DNS, route, and host-firewall posture already collected from Azure Local nodes
- outputs must differentiate host-side validation from direct device evidence

Explicit v1 exclusion:

- v1 does not query perimeter firewalls directly

## #29 Non-Dell OEM Hardware Support

Decision:
Non-Dell OEM support remains a separate future workstream with vendor-specific collectors mapped into the common hardware model.

Priority order when implementation starts:

- HPE
- Lenovo
- DataON and other Azure Local partner-specific variants

Normalization rules:

- shared hardware domains remain vendor-neutral in the manifest
- vendor-specific evidence remains preserved in raw evidence and OEM posture substructures
- no generic wording should imply parity before a vendor path actually exists

Explicit v1 exclusion:

- only Dell-first Redfish and OEM posture are implemented in v1

## #30 Disconnected and Limited-Connectivity Enrichment

Decision:
Disconnected and constrained-connectivity enrichment remains post-v1, but the v1 model must stay compatible with it.

Highest-value future enhancements:

- stronger local identity and PKI evidence
- local monitoring and update posture when Azure-side context is absent
- richer disconnected control-plane diagrams and recommendations
- clearer evidence provenance for missing Azure-side data

Architecture constraints preserved now:

- collectors can already emit partial status and findings without failing the full package
- cached manifest rendering works even when Azure-side enrichment is absent

Explicit v1 exclusion:

- no disconnected-only enrichment beyond the current baseline posture

## #31 Rack-Aware and Management-Cluster Enrichment

Decision:
Rack-aware and management-cluster enrichment stays post-v1 and remains distinct from the v1 variant classifier.

Future enrichments to target:

- richer rack and fault-domain relationship mapping
- management-cluster-specific control-plane and dependency views
- externalized network, storage, and management relationships beyond the current host-derived model

Constraints preserved now:

- v1 can label rack-aware posture when evidence exists
- v1 does not claim full management-cluster modeling

Explicit v1 exclusion:

- no management-cluster-specific collector logic is implemented in v1

## #32 Manual Import Workflows

Decision:
Manual import remains a future feature for externally governed environments where Ranger cannot interrogate every external system directly.

First import scenarios worth supporting:

- rack and cabling data
- firewall export summaries
- switch VLAN and subnet inventories
- support matrices or OEM compliance exports

Rules for future implementation:

- imported data must be labeled with source, timestamp, and provenance
- imported evidence must remain distinguishable from machine-collected evidence in reports and diagrams
- imported content must validate against an explicit schema before it enters the manifest

Explicit v1 exclusion:

- no manual import workflow is implemented in v1

## #33 Windows PowerShell 5.1 Compatibility

Decision:
Windows PowerShell 5.1 remains unsupported unless a future assessment proves that support can be added without distorting the PowerShell 7.x-first architecture.

Current blockers:

- PowerShell 7-oriented module behavior and modern cmdlet expectations
- inconsistent availability of newer runtime features and remoting behavior
- duplicated test burden and packaging complexity

Recommended support posture:

- continue to require PowerShell 7.x for v1 and near-term post-v1 work
- reassess 5.1 only if a concrete downstream dependency or customer requirement justifies the cost

## Outcome

The post-v1 backlog is now explicitly defined with bounded decisions, non-goals, and preserved architectural constraints.

That means the definition issues can close without implying that the future features themselves have already been implemented.