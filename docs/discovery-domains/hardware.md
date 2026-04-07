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
|---|---|
| `nodes` | Per-node hardware inventory — manufacturer, model, serial number, service tag, BIOS, firmware, BMC version, processors, memory, NIC, and disk controller |
| `firmware` | Concatenated firmware posture across nodes — BIOS, BMC, NIC, and disk controller versions |
| `security` | Hardware-layer security posture — Secure Boot state, TPM version, UEFI mode, and virtualization extensions |
| `summary` | Aggregate counts and vendor summary — node models, processor families, and disk counts |

## Why It Matters

Hardware facts affect:

- supportability and handoff quality
- firmware and OEM-management coverage
- storage interpretation
- physical network interpretation
- platform security posture

## Connectivity and Credentials

| Requirement | Purpose |
|---|---|
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

## Evidence Boundaries

- **Direct discovery:** Redfish / BMC evidence
- **Host-side validation:** limited device corroboration from Windows when available
- **Manual/imported evidence:** asset records or rack placement details when direct BMC access is unavailable

## v1 and Future Boundaries

v1 should prioritize Dell Redfish discovery and a stable normalized hardware model.

Other OEM-specific collectors should be documented as future additions rather than implied to exist already.