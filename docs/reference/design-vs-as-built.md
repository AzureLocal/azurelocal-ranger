# Design versus as-built

`Compare-RangerDesign` answers "does what was built match what was designed?" from a Ranger manifest and a design record. It is read-only and works offline.

```powershell
# Compare a finished run with the instance's infrastructure.yml (schema 5, the one environment file of the toolkit registry)
Compare-RangerDesign -ManifestPath .\manifest\audit-manifest.json -DesignPath .\infrastructure.yml -OutputPath .\compare

# Day 2: run it again whenever you want the drift report. Ranger compares; it never writes to the file or the registry.

# Add the comparison to the reports
Export-AzureLocalRangerReport -ManifestPath .\manifest\audit-manifest.json -DesignPath .\infrastructure.yml -Formats html,markdown,docx

# Export the snapshot that Azure Local Trailwright's As-built compare reads
Export-AzureLocalRangerReport -ManifestPath .\manifest\audit-manifest.json -Formats as-built-snapshot
```

`-OutputPath` writes `design-comparison.json` (`design-comparison.v1`) and `design-comparison.html` (a self-contained section). With `-DesignPath`, `Export-AzureLocalRangerReport` adds a **Design vs as-built** section to the technical reports.

## Result

Each row has an area, an item, the design value, the as-built value, a status, a severity and, where Microsoft documents the item, a Learn link.

| Status | Meaning | Severity |
| --- | --- | --- |
| `match` | Design and build agree | ok |
| `drift` | Both have it and it differs, or the build has something the design does not | warning; error for release, identity model, witness type, node set, intent traffic, volume resiliency, subscription |
| `missing` | The design has it and the build does not | error |
| `not-captured` | The snapshot has no data for it, so nothing is claimed | info |
| `not-comparable` | The design record holds no section Ranger compares (a file cut for another tool, a stub). One row `design` / `record`; `summary.comparable` is `false` and `coveragePercent` is 0 | warning |

The summary also reports `coveragePercent`, the share of design items the snapshot could actually be compared on, so a clean result with low coverage is visible.

## Design record shapes

| Kind | File | Read from |
| --- | --- | --- |
| `infrastructure` | The toolkit's `infrastructure.yml` (schema 5), the full file or its ranger cut | `cluster.name` and `witness.type`, `deployment.solution_version` (else `provisioning.os_version`), `hardware.sbe.version`, `scenario.identity`, `identity.active_directory.domain_fqdn`, `azure.subscription_id` and `resource_group`, `nodes[]` (`name`, `serial_number`, `bmc.ip_address` and `type`, `management.ip_address` or the management `network_adapters[]` port, `storage_ips`), `networking.management` (`dns_servers`, `vlan_id`), `networking.vlans[]`, `networking.intents[]`, `networking.logical_networks[]`, `storage.volumes[]`, `sdn.*` |
| `infrastructure` (schema 4) | A Trailwright `infrastructure.yml` of schema 4.0.0, the layout before schema 5. A reader for one more release, with a warning | `_metadata.azure_local_release`, `azure_platform.*`, `identity.mode`, `compute.*`, `networking.*`, `infrastructure_network.dns_servers`, `storage.volumes[]`, `sdn.*` |
| `environment` | The retired deploy automation environment file (`environment.yml`). A reader for one more release, with a warning | `cluster_name`, `subscription_id`, `release.azure_local_version`, `release.sbe_version`, `identity.model`, `witness.type`, `nodes[]`, `vlans{}`, `intents[]`, `qos`, `ip_plan.dns_servers`, `storage.volumes[]`, `sdn`, `logical_networks[]` |
| `snapshot` | An `as-built-snapshot.v1` file used as the design (for example a golden build) | The snapshot fields below |

## Field-path mapping

The mapping was built from the collectors' code and the fixtures. Manifest paths on the left are where Ranger writes the value today; where a real run and the older synthetic fixture differ, both are listed.

| Snapshot field | Manifest path | Environment file key (retired) | infrastructure.yml key (schema 5) | Rule |
| --- | --- | --- | --- | --- |
| `cluster.name` | `domains.clusterNode.cluster.name`, else `target.clusterName` | `cluster_name` | `cluster.name` | case-insensitive equal |
| `cluster.release` | `domains.clusterNode.updatePosture.solutionUpdateEnv.CurrentVersion` or `.Version`; `-Release` overrides | `release.azure_local_version` | `deployment.solution_version`, else `provisioning.os_version` (`12.2611.1004.9`) | full version equal; a four-digit train matches `12.<train>.*` |
| `cluster.sbeVersion` | `domains.clusterNode.solutionUpdateDetail.currentSbeVersion`, else `solutionUpdateEnv.CurrentSbeVersion` / `SbeVersion` | `release.sbe_version`, else `sbe.version` | `hardware.sbe.version` | equal |
| `azure.subscriptionId` | `target.subscriptionId` | `subscription_id` | `azure.subscription_id` | equal (error on drift) |
| `azure.resourceGroup` | `target.resourceGroup` | none | `azure.resource_group` | equal |
| `identity.model` | `topology.identityMode` (`ad`, `local-key-vault`) | `identity.model` (`ad-joined`, `hybrid` -> `active-directory`; `local-identity-keyvault` -> `local-identity-key-vault`) | `scenario.identity` (`active_directory`, `local_identity`) | equal |
| `identity.domain` | `domains.clusterNode.cluster.domain` (AD only) | none | `identity.active_directory.domain_fqdn` (Active Directory only) | equal (warning on drift) |
| `witness.type` | `domains.clusterNode.quorum.witnessDetail.type`, else `quorum.quorumType` (`CloudWitness` -> `cloud`, `FileShareWitness` -> `file-share`) | `witness.type` (`fileshare` -> `file-share`) | `cluster.witness.type` (`cloud`, `file_share`, `none`) | equal |
| `nodes[].name` | `domains.clusterNode.nodes[].name` | `nodes[].name` | `nodes[].name` | short name, case-insensitive; set compared both ways |
| `nodes[].serial` | `domains.hardware.nodes[].serialNumber`, else `serviceTag` | `nodes[].service_tag` | `nodes[].serial_number` | equal |
| `nodes[].managementIp` | `domains.networking.nodes[].hostVirtualNics[]` where `isManagementNic` (flat `hostVirtualNics` / `ipAddresses` only when they carry a node) | `nodes[].management_ip` | `nodes[].management.ip_address`, else the `nodes[].network_adapters[]` port with the role `management` | equal |
| `nodes[].storageIps` | host vNICs named `*smb*` or `*storage*` | `nodes[].storage_ips{smb1,smb2}` | `nodes[].storage_ips` | set equal |
| `nodes[].bmcIp` | `domains.oemIntegration.endpoints[].ip`, else `hardware.nodes[].ipmiAddress` | `nodes[].bmc_ip` | `nodes[].bmc.ip_address` | equal |
| `nodes[].bmcType` | `domains.oemIntegration.managementPosture[].managerModel` (iDRAC, iLO, XClarity), else the manufacturer | none | `nodes[].bmc.type` | equal (warning on drift) |
| `vlans[].id` | `domains.networking.nodes[].vlan[].AccessVlanId` (management OS adapters), else host vNIC `vlanId` | `vlans{}.id` | `networking.vlans[].id`, plus `networking.management.vlan_id` when it is above 0 | by id; extras are warnings |
| `intents[].name` | `domains.networking.nodes[].intents[].Name` | `intents[].name` | `networking.intents[].name` | by name, then by traffic set |
| `intents[].traffic` | `Is*Intent` flags and `intentOverrides[].isManagementIntent`; older shape `trafficType[]` | `intents[].traffic_types` | `networking.intents[].traffic` | set equal (error on drift) |
| `intents[].adapters` | `domains.networking.nodes[].intentOverrides[].adapters` | `intents[].adapters` | `networking.intents[].adapters` (through `nodes[0].network_adapters[].os_name_override` when the port has one) | set equal (warning; design port labels can differ from OS names) |
| `intents[].jumbo` | smallest `mtuSize` of the intent's adapters | `intents[].overrides.jumbo_packet`, else `qos.jumbo_frame_size` (storage) | none | equal |
| `intents[].rdma` | `rdmaCapable` / `rdmaEnabled` on the intent's adapters | `intents[].overrides.rdma_enabled` or `rdma_protocol` set | none | equal; capability is not configuration, so treat a match as indicative |
| `intents[].qos` | `domains.networking.nodes[].dcb.trafficClasses[]` named SMB / storage / cluster | `qos.storage_priority`, `qos.storage_bandwidth_percent` | none | equal |
| `volumes[].name` | `domains.storage.virtualDisks[].friendlyName` | `storage.volumes[].name` | `storage.volumes[].name` | by name; platform volumes in the build are info |
| `volumes[].sizeGiB` | `virtualDisks[].sizeGiB` (older shape: `size` bytes / 1 GiB) | `storage.volumes[].size_gb` (read as GiB) | `storage.volumes[].size_gib` | within 1 percent or 1 GiB |
| `volumes[].resiliency` | `resiliencySettingName` plus `numberOfDataCopies` (Mirror 2 -> `two-way`, 3 -> `three-way`, 4 -> `nested-two-way` on two nodes else `four-way`; Parity -> `parity`) | `two-way-mirror` -> `two-way` ... | `storage.volumes[].resiliency` (`two_way`, `three_way`, `four_way`, `parity`, `nested_two_way` and the accelerated parity values) | equal (error on drift) |
| `dnsServers` | `domains.networking.dns[].ServerAddresses` | `ip_plan.dns_servers` | `networking.management.dns_servers` | set equal |
| `sdn.enabled` | `domains.networking.sdn[].sdn.deployed` (any node) | `sdn.enabled` | `sdn.enabled` | equal |
| `sdn.prefix` | not captured | `sdn.prefix` | `sdn.prefix` | not-captured unless supplied |
| `sdn.logicalNetworks[]` | `domains.networking.logicalNetworks[]` (`name`, first subnet `vlan` and `addressPrefix`) | `logical_networks[]` | `networking.logical_networks[]` (`name`, `vlan_id`, `address_prefix`) | by name, then VLAN and subnet |

## Known limits

- The flattened networking collections (`domains.networking.adapters`, `intents`, `dns`, `vlan`) lose the node name in real runs; Ranger reads the per-node `domains.networking.nodes[]` and only falls back to the flat lists when a list carries a `node` field.
- Intent adapters are compared as sets of names. A design that uses port labels (`Port1`) and an OS that reports `Embedded NIC 1` shows a warning, not an error.
- `nested-two-way` is inferred from four data copies on a two-node cluster. A cluster with a different layout reports the raw copy count as `four-way`.
- A jumbo or RDMA match uses the adapters' reported capability and MTU, not the Network ATC override setting.
- `hybrid` identity is compared as Active Directory; hybrid-specific requirements are not checked.
- The witness type is compared, not the witness storage account or share.

## as-built-snapshot.v1

`ConvertTo-RangerAsBuiltSnapshot` (and `-Formats as-built-snapshot`) writes the document that Azure Local Trailwright's As-built compare reads. The core fields (`schema`, `capturedAt`, `source`, `cluster.name`, `cluster.release`, `identity`, `witness`, `nodes`, `vlans`, `intents`, `volumes`, `dnsServers`) follow Trailwright's contract. The extras (`cluster.sbeVersion`, `cluster.osBuild`, `azure`, `nodes[].bmcType`, `nodes[].bmcIp`, `intents[].jumbo/rdma/qos`, `sdn`) are optional and ignored by readers that do not know them. The JSON Schema is [as-built-snapshot.v1.schema.json](as-built-snapshot.v1.schema.json).

```json
{
  "schema": "as-built-snapshot.v1",
  "capturedAt": "2026-10-15T09:20:00.0000000Z",
  "source": { "tool": "ranger", "version": "2.7.0", "note": "manifest schema 1.1.0-draft" },
  "cluster": { "name": "example-azl-01", "release": "12.2611.1004.9", "sbeVersion": "4.1.2312.5" },
  "identity": { "model": "active-directory", "domain": "lab.example.com" },
  "witness": { "type": "cloud" },
  "nodes": [ { "name": "node1", "serial": "EXAMPLE-0001", "managementIp": "192.0.2.11", "bmcType": "idrac" } ],
  "vlans": [ { "id": 100 } ],
  "intents": [ { "name": "Management_Compute", "traffic": ["management", "compute"], "adapters": ["pNIC01", "pNIC02"] } ],
  "volumes": [ { "name": "workloads", "sizeGiB": 1024, "resiliency": "three-way" } ],
  "dnsServers": ["192.0.2.10"]
}
```
