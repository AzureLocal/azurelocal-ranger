# OEM Integration

This domain explains vendor-specific tooling and lifecycle integrations tied to the Azure Local hardware platform.

## What Ranger Collects

The OEM-integration domain should document:

- OEM platform-management tooling such as Dell OpenManage, Lenovo XClarity, HPE tooling, or DataON MUST where applicable
- firmware compliance or catalog-comparison posture when available
- support-oriented signals such as lifecycle controller versions, license tiers, or update availability
- the absence of OEM tooling when the environment is effectively whitebox or unmanaged at the OEM layer

## Manifest Sub-Domains

The v1 collector writes to these named sections of the `oemIntegration` manifest domain:

| Sub-domain | Content |
| --- | --- |
| `endpoints` | OEM management endpoint inventory — BMC addresses, node associations, and reachability |
| `managementPosture` | OEM platform-management tool detection — Dell OpenManage, Lenovo XClarity, HPE tooling, or absence of OEM management |

## Current Collector Depth

Current v1 collection also covers:

- Redfish-derived firmware and hardware signals needed for as-built inventory.
- Per-DIMM and GPU paths where the OEM interface exposes them.
- BMC certificate and management-endpoint metadata.
- Vendor-specific corroboration that complements host-side hardware discovery.

## Why It Matters

OEM tooling often holds the most actionable hardware lifecycle and support signals in a real environment. That information belongs in the complete estate story.

## Connectivity and Credentials

| Requirement | Purpose |
| --- | --- |
| Redfish or BMC reachability | Common source for OEM posture |
| BMC credential | Usually required |
| Optional host credential | Useful when OEM agents or integrations are visible from the OS |

## Default Behavior

This domain is optional by default. It should run when OEM endpoints or OEM tooling are configured and accessible.

## Variant Behavior

Variant changes here are usually secondary to hardware and networking changes, but Ranger should still document when a variant changes what OEM surfaces are expected or relevant.

## Example Manifest Data

A successful collect produces entries like this:

```json
{
  "id": "oemIntegration",
  "status": "success",
  "domains": {
    "oemIntegration": {
      "endpoints": [
        { "host": "idrac-node-01.contoso.com", "reachable": true, "vendor": "Dell" },
        { "host": "idrac-node-02.contoso.com", "reachable": true, "vendor": "Dell" }
      ],
      "managementPosture": {
        "vendor": "Dell",
        "toolingDetected": "OpenManage Enterprise",
        "openManageVersion": "3.10.0",
        "lifecycleControllerVersion": "6.10.30.20"
      }
    }
  }
}
```

## Common Findings

| Finding | Severity | What it means |
| --- | --- | --- |
| BMC endpoint unreachable | Warning | One or more iDRAC/BMC endpoints did not respond; hardware and OEM data is incomplete for those nodes |
| OpenManage Enterprise not detected | Info | Dell OEM management layer is absent or not discoverable; lifecycle and firmware catalog data unavailable |
| Lifecycle Controller version below minimum | Warning | LC firmware may be missing features required by current iDRAC or operating-system management paths |
| No OEM management tooling detected | Info | Environment has no detected OEM management platform; all hardware lifecycle is managed directly via BMC/Redfish |

## Partial Status

`status: partial` on the OEM-integration collector means:

- Some BMC endpoints were reachable while others were not; reachable nodes have full OEM data, unreachable nodes show as skipped
- OEM management tool detection succeeded but license or version detail queries failed

This domain is optional by default. If no BMC targets are configured, it reports `skipped`, not `partial` or `failed`.

## Domain Dependencies

Independent of WinRM-based collectors. Requires BMC endpoints in `targets.bmc` and a valid `credentials.bmc` to produce meaningful data. Benefits from the hardware domain for firmware corroboration but runs independently.

## Evidence Boundaries

- **Direct discovery:** Redfish or OEM-exposed management data
- **Host-side validation:** detection of OEM agents or plugins installed on nodes
- **Manual/imported evidence:** operator-provided support contracts, firmware plans, or lifecycle notes when needed

## v1 and Future Boundaries

v1 should be Dell-first in practice, while documenting Lenovo, HPE, DataON, and whitebox handling clearly as either future or informative-only paths.