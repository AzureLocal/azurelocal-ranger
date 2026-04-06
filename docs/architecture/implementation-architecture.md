# Implementation Architecture

Azure Local Ranger is intended to ship as one public PowerShell module, but it should be built internally as small, testable components with clean boundaries.

This page documents the logical implementation architecture before broad module development begins.

## Design Goals

The internal design must support:

- independent collectors that can run, fail, or be skipped independently
- one normalized manifest contract between collection and rendering
- outputs rendered from cached data only
- independent test boundaries for collectors, orchestration, schema validation, reports, and diagrams
- future growth into optional and variant-specific domains without a rewrite

## Layered Model

![Implementation architecture](../assets/diagrams/ranger-implementation-architecture.svg)

Ranger should be structured in four layers.

### 1. Orchestration Layer

This is the public entry point and run coordinator.

Responsibilities:

- parse parameters and config
- resolve credentials
- determine domain include/exclude behavior
- classify topology and operating variant
- establish execution order
- collect per-domain results
- assemble and persist the manifest
- invoke output renderers against cached data

This layer owns the run, but it should not contain domain-specific collection logic.

### 2. Shared Platform Services

These are reusable services that many collectors depend on.

Responsibilities:

- logging and structured status reporting
- session creation and teardown for WinRM
- Redfish client helpers
- Azure context and token helpers
- retry, timeout, and error normalization
- schema shaping and object normalization
- evidence and provenance helpers
- artifact naming and output-path helpers

These services are the stability layer that keeps collectors focused on domain behavior.

### 3. Domain Collectors

Each discovery domain should be implemented as its own collector boundary.

Planned collectors include:

- topology and deployment-variant classification
- cluster and node
- hardware
- storage
- networking
- virtual machines
- identity and security
- Azure integration
- monitoring and observability
- OEM management
- management tools
- performance baseline

Each collector should:

- accept only the credentials and settings it actually needs
- return normalized results plus raw evidence metadata
- report `success`, `partial`, `failed`, `skipped`, or `not-applicable`
- avoid reaching into other collectors directly

### 4. Output Layer

The output layer consumes saved manifest data.

Responsibilities:

- manifest export
- report generation
- diagram generation
- current-state package generation
- as-built package generation

This layer must not perform live discovery. If an output needs data that is missing, it should mark the output unavailable or skip it with a reason.

## Module Layout

The repo’s planned PowerShell module layout should reflect those boundaries.

| Area | Purpose |
|---|---|
| `Modules/Public` | Public entry points and exported commands |
| `Modules/Private` | Internal helper functions not exported |
| `Modules/Core` | Orchestration, manifest assembly, shared runtime services |
| `Modules/Collectors` | Discovery-domain logic |
| `Modules/Outputs/Reports` | Report renderers |
| `Modules/Outputs/Diagrams` | Diagram renderers and asset helpers |
| `Modules/Internal` | Shared internal models and utilities |

## Boundaries That Must Stay Clean

Several boundaries should be treated as non-negotiable.

### Collection vs Rendering

Collectors gather evidence. Renderers explain it. The renderers do not reconnect to targets.

### Raw Evidence vs Normalized Facts

Collectors can preserve raw evidence references, but they should hand the rest of the system normalized data and explicit provenance.

### Azure vs Cluster vs OEM Credentials

Credential scopes are not interchangeable. A cluster credential is not assumed to grant domain access. An Azure credential is not assumed to grant BMC access.

### Core vs Optional Domains

Optional domains such as direct switch or firewall interrogation must remain opt-in and must not complicate the standard run path.

## Testing Boundaries

The implementation architecture exists mainly to keep Ranger testable.

| Boundary | What should be tested |
|---|---|
| Collector unit tests | Domain-specific parsing, normalization, and status handling |
| Shared service tests | Key Vault parsing, retry logic, session helpers, error normalization |
| Schema tests | Manifest shape and required fields |
| Orchestration tests | Domain selection, credential routing, collector sequencing |
| Output tests | Report and diagram rendering from saved manifests |
| Acceptance examples | Representative saved manifests for realistic environment shapes |

## Delivery Sequence

The preferred implementation order is:

1. shared services and manifest schema
2. topology classification and orchestration
3. one collector domain at a time
4. manifest-backed output generation only after the manifest is stable

That sequence keeps Ranger from collapsing into a monolithic script that is hard to reason about and harder to test.
