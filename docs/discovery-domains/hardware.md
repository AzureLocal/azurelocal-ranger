# Hardware

This domain documents the physical reality of the Azure Local platform.

It is Dell-first for v1 because Redfish-based Dell inventory is already proven inside the AzureLocal organization, but the model must stay open to other OEMs later.

## What Ranger Collects

The hardware domain should document:

- manufacturer, model, serial number, service tag, and asset identity
- BIOS, firmware, UEFI, Secure Boot, TPM, and virtualization posture
- BMC identity and reachability
- processors, memory, DIMM layout, and accelerators where present
- physical NIC inventory and capabilities
- physical disks and storage-controller posture
- hardware vendor classification used by OEM-specific discovery or reporting

## Manifest Sub-Domains

The v1 collector writes to these named sections of the `hardware` manifest domain:

| Sub-domain | Content |
| --- | --- |
| `nodes` | Per-node hardware inventory — manufacturer, model, serial number, service tag, BIOS, firmware, BMC version, processors, memory, NIC, and disk controller |
| `firmware` | Concatenated firmware posture across nodes — BIOS, BMC, NIC, and disk controller versions |
| `security` | Hardware-layer security posture — Secure Boot state, TPM version, UEFI mode, and virtualization extensions |
| `summary` | Aggregate counts and vendor summary — node models, processor families, and disk counts |

## Current Collector Depth

Current v1 collection also covers:

- Per-DIMM memory inventory and slot-level population detail where the host or Redfish path exposes it.
- GPU and accelerator discovery when present in host inventory or OEM endpoints.
- Host VBS and hardware security posture alongside TPM and Secure Boot state.
- BMC certificate and firmware metadata used for handoff and operational review.

## Why It Matters

Hardware facts affect:

- supportability and handoff quality
- firmware and OEM-management coverage
- storage interpretation
- physical network interpretation
- platform security posture

## Connectivity and Credentials

| Requirement | Purpose |
| --- | --- |
| HTTPS to BMC or iDRAC endpoints | Primary hardware-discovery path |
| Redfish credential | Required for Dell-first v1 discovery |
| Optional cluster credential | Useful for limited host-side corroboration when BMC access is absent |

## Default Behavior

Hardware discovery is optional by default because many operators will not have BMC targets or BMC credentials available.

If BMC details are not configured, the domain should report `skipped`, not failed.

## Variant Behavior

### Hyperconverged and Rack-Aware

Standard per-node hardware inventory applies.

### Local Identity with Azure Key Vault

Identity mode does not fundamentally change the hardware collector, but it can affect which operator tools are available to reach the nodes afterward.

### Disconnected Operations

Disconnected operation changes the control plane, not the BMC protocol. Hardware discovery still depends on local network reachability to the BMC layer.

### Multi-Rack Preview

Multi-rack preview changes the physical topology and storage assumptions. Hardware inventory remains important, but some platform architecture interpretation moves into the variant and networking domains.

## Example Manifest Data

A successful collect produces entries like this:

```json
{
  "id": "hardware",
  "status": "success",
  "domains": {
    "hardware": {
      "nodes": [
        {
          "host": "tplabs-01-n01",
          "manufacturer": "Dell Inc.",
          "model": "PowerEdge AX-760",
          "serialNumber": "ABC1234",
          "serviceTag": "ABC1234",
          "biosVersion": "1.5.4",
          "bmcVersion": "6.10.30.20",
          "processors": [{ "model": "Intel Xeon Gold 6338", "cores": 32, "count": 2 }],
          "memoryGB": 256,
          "secureBoot": true,
          "tpmVersion": "2.0"
        }
      ],
      "summary": { "nodeCount": 4, "manufacturer": "Dell Inc.", "model": "PowerEdge AX-760" }
    }
  }
}
```

## Common Findings

| Finding | Severity | What it means |
| --- | --- | --- |
| One or more Redfish endpoints returned 404 | Warning | Redfish endpoint not supported by this firmware version; hardware data is incomplete for affected nodes |
| BMC firmware below recommended version | Warning | iDRAC firmware may be missing features or have known issues; consider updating |
| Secure Boot disabled | Warning | Host is not in a secured-core posture; relevant for compliance and security documentation |
| TPM not present or version 1.2 | Warning | TPM 2.0 required for BitLocker and some Azure Arc features |
| Mixed hardware models in cluster | Info | Nodes are not uniform; note for capacity planning and supportability |

## Partial Status

`status: partial` means Redfish data was returned for some nodes but not all, or some Redfish endpoints returned errors (typically 404):

- BMC unreachable for one node — that node's hardware data is absent; others are complete
- Specific Redfish endpoint (e.g., `PCIeDevices`) returned 404 — host-level inventory is complete but that sub-section is missing
- WinRM fallback succeeded for basic hardware facts but Redfish-only data (BMC firmware, DIMM detail) is absent

A warning finding is added to the manifest when Redfish endpoints return errors. Check `manifest.collectors[*].messages` for the specific endpoint and HTTP status code.

## Domain Dependencies

Independent of other collectors — hardware discovery runs against BMC endpoints directly. Does benefit from having the node list resolved by the cluster-and-node domain for host-to-BMC correlation.

## Evidence Boundaries

- **Direct discovery:** Redfish / BMC evidence
- **Host-side validation:** limited device corroboration from Windows when available
- **Manual/imported evidence:** asset records or rack placement details when direct BMC access is unavailable

## v1 and Future Boundaries

v1 should prioritize Dell Redfish discovery and a stable normalized hardware model.

Other OEM-specific collectors should be documented as future additions rather than implied to exist already.