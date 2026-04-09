# How Ranger Works

Azure Local Ranger runs from a management workstation or jump box, connects to the targets the operator has access to, normalizes discovery results into a cached manifest, and renders reports or diagrams from that cached data.

This page explains the runtime model in plain English.

## The Short Version

Ranger does four things in order:

1. Validates the execution environment, configuration, and credentials.
2. Connects to each selected discovery domain by using the right protocol for that target.
3. Normalizes the collected evidence into one audit manifest.
4. Generates outputs from the cached manifest instead of re-querying the environment.

That separation is deliberate. Collection and rendering are different phases.

## Where Ranger Should Run

Ranger should run from a management workstation or jump box that can reach:

- the Azure Local management network
- the out-of-band or BMC network when hardware discovery is required
- Azure endpoints for Arc, resource discovery, monitoring, and policy

Running directly on a cluster node is not the preferred model because cluster nodes do not necessarily have access to every target that Ranger needs, especially BMC endpoints and some Azure-side management paths.

## Runner Posture

Ranger should treat runner locations in three tiers.

| Runner location | Posture | Why |
|---|---|---|
| Management workstation or jump box | Preferred | Best chance of reaching WinRM, Redfish, and Azure from one place |
| Azure-hosted automation worker with approved network reach | Supported future posture | Useful for scheduled Azure-side and hybrid runs when the worker can still reach cluster targets |
| Cluster node | Avoid by default | Usually has the wrong trust and reachability boundaries for full-estate discovery |

## Connectivity Methods

Ranger uses different protocols for different domains.

| Method | What it is used for | v1 posture |
|---|---|---|
| WinRM / PowerShell remoting | Cluster, node, storage, networking, VM, management-tool, and performance collection | Primary |
| Redfish REST API | Dell-first OEM hardware and BMC discovery | Primary |
| Az PowerShell / Azure CLI | Azure-side discovery for Arc, policy, monitoring, update, backup, and related services | Primary |
| Azure Arc Run Command | Alternative path when WinRM is unavailable | Investigate, not a v1 dependency |
| Vendor SSH / REST / SNMP | Direct switch and firewall interrogation | Optional future domain |

## Target Addressing and Credential Routing

Ranger should route credentials by target type and domain intent, not by one global login.

| Domain or target area | Primary addressing model | Primary credential | Optional supporting credential | Default posture |
|---|---|---|---|---|
| Cluster, storage, networking, VMs, management tools, performance | Cluster FQDN and node names | Cluster WinRM credential | Azure credential for Azure overlays | Core |
| Identity and security | Cluster nodes plus AD domain context when applicable | Cluster credential and, when needed, domain read credential | Azure credential for RBAC, policy, or Key Vault context | Core |
| Hardware and OEM integration | Explicit BMC or iDRAC endpoints | BMC / Redfish credential | Cluster credential for limited host-side corroboration | Optional |
| Azure integration and monitoring overlays | Subscription, resource group, Azure Local instance, custom location, related Azure resources | Azure credential | Cluster credential for local corroboration | Core when Azure target is configured |
| Direct switch or firewall interrogation | Explicit operator-supplied device endpoints | Vendor-specific device credential | None by default | Optional future |
| Manual or imported evidence | Operator-supplied files or metadata | None | None | Optional |

That routing model is important because a valid Azure login does not imply WinRM access, and a valid cluster credential does not imply BMC or network-device access.

## Credentials and Authentication

Ranger is multi-target and multi-credential by design. It must treat Azure, cluster, domain, and BMC authentication as separate concerns.

The planned credential resolution order is:

1. parameter input
2. Key Vault reference via `keyvault://<vault>/<secret>`
3. interactive prompt

Azure authentication can use an existing Az context, interactive login, service principal, or managed identity. Cluster and domain discovery use Windows credentials appropriate for WinRM and directory read access. Dell-first hardware discovery uses Redfish credentials for iDRAC.

See [Operator Authentication](../operator/authentication.md) and [Configuration Model](configuration-model.md) for details.

## Domain Selection

Ranger is compartmentalized. Operators can run only the discovery domains they need.

The default behavior is:

- run core domains when the required credential is available
- skip optional domains when targets or credentials are missing
- light up variant-specific domains only when the detected topology or explicit configuration makes them relevant

A skipped domain is not treated as a failed run. The manifest records why it was skipped.

## Domain Classes

Ranger should classify domains in four buckets so execution behavior is predictable.

| Domain class | Meaning | Default behavior |
|---|---|---|
| Core | Main Azure Local platform domains needed for a meaningful run | Run when required targets and credentials exist |
| Optional | Valuable but not required to understand the estate | Skip unless the needed targets and credentials are configured |
| Variant-specific | Applies only to certain topologies or identity modes | Run only when the detected or hinted variant justifies it |
| Future-only | Not part of the current supported release | Do not run in v1 |

Examples:

- cluster, storage, networking, workload, identity, and Azure-integration domains are core
- BMC, OEM, and direct network-device interrogation are optional
- disconnected or multi-rack deep inspection is variant-specific
- Arc Run Command-based collection remains an investigation item and not a v1 dependency

## Runtime Flow

![Ranger operator journey](../assets/diagrams/ranger-operator-journey.svg)

A normal run follows this sequence:

1. **Merge input sources**
   Ranger merges runtime parameters, config-file values, and interactive prompts into one resolved config object.
2. **Resolve credentials**
   Ranger resolves Azure, cluster, domain, and BMC credentials independently.
3. **Select domains and validate targets**
   Ranger applies include/exclude filters, verifies required targets, and decides which collectors can run.
4. **Classify topology**
   Ranger determines whether the environment is hyperconverged, switchless, rack-aware, local identity with Azure Key Vault, disconnected, or multi-rack preview.
5. **Collect by domain**
4. **Collect by domain**
6. **Normalize into the manifest**
5. **Normalize into the manifest**
7. **Persist artifacts**
6. **Persist artifacts**
8. **Render outputs**
   Reports, Office-format deliverables, diagrams, and package exports consume the saved manifest rather than live targets.
   Reports, diagrams, and package exports consume the saved manifest rather than live targets.

## Current-State and As-Built Modes

Ranger supports two modes through the same runtime model.

### Current-State Documentation

This mode produces a leaner operational output focused on what exists now, what is healthy, what is missing, and what needs attention.

### As-Built Documentation

This mode produces a richer handoff package with narrative structure, diagram selection tuned for transfer-of-ownership, and a more formal output layout.

The difference is in rendering and package structure, not a different discovery engine.

## Graceful Degradation

Ranger should still produce useful output when some targets are unreachable.

Collectors report one of these states:

- `success`
- `partial`
- `failed`
- `skipped`
- `not-applicable`

That allows a run to document what was successfully observed without flattening every non-ideal condition into a binary success-or-failure result.

Unavailable required targets should mark the affected core domain as `failed` or `partial`. Missing optional targets or credentials should result in `skipped`, not in a global run failure.

## Read-Only Contract

Ranger is a documentation and audit tool. It should not change cluster configuration, modify Azure resources, rotate secrets, or remediate drift.

Any generated recommendation belongs in findings and documentation, not in automatic enforcement.

## Operator Reading Path

Operators should read these pages together:

- [System Overview](system-overview.md)
- [Configuration Model](configuration-model.md)
- [Operator Prerequisites](../operator/prerequisites.md)
- [Operator Authentication](../operator/authentication.md)
- [Operator Configuration](../operator/configuration.md)
- [Operator Troubleshooting](../operator/troubleshooting.md)
