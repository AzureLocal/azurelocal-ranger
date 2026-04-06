# OEM Integration

This domain explains vendor-specific tooling and lifecycle integrations tied to the Azure Local hardware platform.

## What Ranger Collects

The OEM-integration domain should document:

- OEM platform-management tooling such as Dell OpenManage, Lenovo XClarity, HPE tooling, or DataON MUST where applicable
- firmware compliance or catalog-comparison posture when available
- support-oriented signals such as lifecycle controller versions, license tiers, or update availability
- the absence of OEM tooling when the environment is effectively whitebox or unmanaged at the OEM layer

## Why It Matters

OEM tooling often holds the most actionable hardware lifecycle and support signals in a real environment. That information belongs in the complete estate story.

## Connectivity and Credentials

| Requirement | Purpose |
|---|---|
| Redfish or BMC reachability | Common source for OEM posture |
| BMC credential | Usually required |
| Optional host credential | Useful when OEM agents or integrations are visible from the OS |

## Default Behavior

This domain is optional by default. It should run when OEM endpoints or OEM tooling are configured and accessible.

## Variant Behavior

Variant changes here are usually secondary to hardware and networking changes, but Ranger should still document when a variant changes what OEM surfaces are expected or relevant.

## Evidence Boundaries

- **Direct discovery:** Redfish or OEM-exposed management data
- **Host-side validation:** detection of OEM agents or plugins installed on nodes
- **Manual/imported evidence:** operator-provided support contracts, firmware plans, or lifecycle notes when needed

## v1 and Future Boundaries

v1 should be Dell-first in practice, while documenting Lenovo, HPE, DataON, and whitebox handling clearly as either future or informative-only paths.