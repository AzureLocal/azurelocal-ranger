# Azure Local Ranger Product Direction

## Purpose

This document captures the intended product direction for Azure Local Ranger so planning decisions, documentation, repository structure, and future implementation all align to the same definition.

---

## Product Mission

Azure Local Ranger documents an Azure Local deployment as a complete system.

That means it must discover and describe:

- the on-prem Azure Local platform (cluster, nodes, hardware, storage, networking)
- the deployment model and operating variant (hyperconverged, switchless, rack-aware, disconnected, multi-rack, AD-backed, or local identity with Key Vault)
- the workloads and services running on it
- the Azure resources and Azure-connected services attached to that deployment
- the OEM hardware layer (iDRAC/BMC, BIOS, firmware, adapters, GPUs, storage HBAs)
- the supporting infrastructure the deployment depends on (identity, DNS, firewalls, switches)

**Runtime:** PowerShell 7.x minimum, 5.1 compatibility where feasible.
**Distribution:** PSGallery-distributable module.

---

## Primary Product Modes

Azure Local Ranger is planned around two primary modes of use. Both modes use the same discovery engine and collectors. The difference is in the output.

### 1. Current-State Documentation Mode

This is the ongoing discovery mode.

Teams run Ranger at any time to document what currently exists in an Azure Local environment. This supports assessment, troubleshooting, operational understanding, governance review, and drift analysis.

This mode answers:

- what the environment is
- how it is configured
- what it is hosting
- what Azure resources are connected to it
- what its current health and risk posture look like

The output is a structured discovery report and optional diagrams.

### 2. As-Built Documentation Mode

This is the handoff mode.

After a new Azure Local deployment is completed, the delivery team runs Ranger and generates a documentation package suitable for formal handoff to another team or customer.

This mode supports:

- project closure documentation
- customer handoff
- handoff from implementation to operations
- managed service onboarding
- support transition and operational readiness

The output is a polished as-built documentation package that goes beyond raw inventory. It includes narrative summaries, architecture diagrams, configuration deep-dives, and enough clarity that the receiving team does not need to rediscover the environment manually.

### Shared Discovery, Different Output

Both modes run the same collectors against the same targets. The as-built mode produces a richer, more formal documentation artifact. The current-state mode produces a leaner operational report. A user should not need to learn two different tools or two different workflows. The difference is a parameter, not a different product.

---

## What The As-Built Package Should Contain

The as-built package is a structured delivery artifact, not a thin export of raw inventory.

At a minimum, future planning should assume the as-built package includes:

- environment identity and deployment summary
- cluster, node, and platform configuration overview
- full hardware inventory per node (model, service tag, BIOS, firmware, NICs, MACs, GPUs, storage controllers, HBAs)
- storage and network architecture summaries
- workload and service inventory
- identity and security configuration overview
- Azure integration map (Arc registration, resource group topology, connected Azure services)
- OEM management layer summary (iDRAC/BMC configuration, firmware versions, management network details)
- architecture diagrams
- technical deep-dive reference material
- enough clarity and completeness for a receiving team to operate the environment without rediscovering it manually

---

## Discovery Methods

Ranger must support multiple discovery methods because the targets span different layers and network zones.

### OEM Hardware Discovery (Dell — Primary)

Dell is the primary OEM target because we have hardware to test against.

Discovery uses the Redfish REST API exposed by iDRAC. This pattern is already proven in the AzureLocal organization:

- `azurelocal-toolkit` contains `Get-DellServerInventory-FromiDRAC.ps1` which collects system info, BIOS attributes (~256), iDRAC attributes (~1,024), CPU, memory, storage, NICs, MACs, firmware inventory, PCIe devices, power supplies, and thermal data via Redfish endpoints.
- `azurelocal.github.io` documents the full Redfish discovery process under the hardware provisioning task runbook, including the three execution modes (iDRAC UI manual, orchestrated, and standalone).
- Output is structured JSON per node, keyed by service tag.

Ranger should adopt and extend this pattern. The existing Redfish endpoint coverage provides the baseline for what the hardware collector must discover:

| Endpoint | Data |
|----------|------|
| `/redfish/v1/Systems/System.Embedded.1` | System info, service tag |
| `/redfish/v1/Systems/System.Embedded.1/Bios` | BIOS attributes |
| `/redfish/v1/Managers/iDRAC.Embedded.1/Attributes` | iDRAC configuration |
| `/redfish/v1/Systems/System.Embedded.1/Processors` | CPU details |
| `/redfish/v1/Systems/System.Embedded.1/Memory` | DIMM details |
| `/redfish/v1/Systems/System.Embedded.1/Storage` | Disk and controller inventory |
| `/redfish/v1/Systems/System.Embedded.1/NetworkAdapters` | NIC inventory, MACs, driver/firmware |
| `/redfish/v1/Systems/System.Embedded.1/PCIeDevices` | GPUs, HBAs, add-in cards |
| `/redfish/v1/UpdateService/FirmwareInventory` | Firmware versions for all components |
| `/redfish/v1/Chassis/System.Embedded.1/Power` | Power supply details |
| `/redfish/v1/Chassis/System.Embedded.1/Thermal` | Thermal and fan status |
| `/redfish/v1/Managers/iDRAC.Embedded.1/EthernetInterfaces` | iDRAC NIC and MAC |

### OEM Hardware Discovery (Other Vendors — Future)

Other OEM vendors (HPE iLO, Lenovo XClarity, etc.) should be planned for but are not testable today. The collector architecture must be designed so that adding a new OEM vendor means adding a new collector module, not rewriting the discovery engine. Redfish is a standard protocol, so the endpoint structure will be similar but vendor-specific attributes and extensions will differ.

This is a future-release concern. Do not block v1 on multi-vendor OEM support.

### Cluster and OS-Level Discovery

Cluster configuration, node OS settings, storage, networking, Hyper-V, and workload inventory are collected via PowerShell remoting against the cluster nodes. This uses standard Windows Remote Management (WinRM) with `Invoke-Command` / `Enter-PSSession`.

### Azure Resource Discovery

Azure-side resources tied to the Azure Local deployment (Arc registration, resource groups, Azure services) are collected via Az PowerShell modules (`Connect-AzAccount`, `Get-AzResource`, etc.) or Azure CLI as a fallback.

### Network Infrastructure Discovery (Future)

Firewalls and switches are targets for future discovery. The exact method depends on vendor (SSH, REST API, SNMP). This must be planned as an optional, separately credentialed discovery domain.

The vendor landscape for network infrastructure is broad:

- **Firewalls:** Palo Alto (PAN-OS API), Fortinet (FortiOS REST API), Cisco ASA/FTD, pfSense, etc.
- **Switches:** Dell OS10 (REST/SSH), Cisco NX-OS (NX-API), Arista (eAPI), Mellanox, etc.

Each vendor requires its own collector module with vendor-specific authentication and API patterns. The architecture must accommodate this without requiring a monolithic rewrite for each new vendor.

For v1 planning, Ranger should treat this as a **hybrid discovery domain**:

- **Host-side validation** is in scope: validate the network and firewall posture that Azure Local depends on from the node and Azure control-plane perspective.
- **Direct device interrogation** is optional and vendor-specific: only run when the user explicitly provides network-device targets and credentials.
- **Manual input/import** must remain supported for designs where the network team will not allow direct interrogation of TOR switches or firewalls.

---

## Discovery Scope — Data Points

This section defines the specific data points each discovery domain collector must discover. These checklists are the authoritative reference for what "complete discovery" means for each domain. The tool must discover everything whether or not a feature is in use — absence of a feature is itself a finding.

---

### Deployment Variants & Topology Classification

Ranger must classify the deployment model before interpreting many of the lower-level findings. Azure Local is no longer a single-shape platform.

- Deployment type: hyperconverged, rack-aware, switchless storage fabric, disconnected operations, or multi-rack
- Identity mode: Active Directory-backed or workgroup/local identity with Azure Key Vault
- Control-plane mode: connected Azure control plane, disconnected local control plane, mixed/limited connectivity
- Storage architecture: Storage Spaces Direct, SAN-backed multi-rack storage, SOFS-present, Storage Replica-present
- Network architecture: switched ToR fabric, switchless full-mesh east-west, rack-aware, multi-rack managed networking
- Site and rack count, rack assignments, site assignments, and whether nodes are required to be co-racked for the chosen topology
- Azure connectivity model: public internet, proxy, ExpressRoute/VPN-assisted, disconnected
- Variant-specific prerequisites present or absent: custom location requirement, Arc resource bridge requirement, Key Vault requirement, and preview-specific multi-rack topology or connectivity markers

This topology classification should be persisted in the audit manifest and used to drive downstream validation logic, report wording, and diagram selection.

---

### Cluster & Node Foundation

**Cluster Identity**
- Cluster name, fully qualified domain name, Active Directory domain
- Cluster creation date
- Cluster functional level and upgrade status
- Azure Local solution version (full build string, OEM info string)
- Azure Local release train / feature update level
- Azure Local license type and registration status with Azure (registered, registration date, expiration date, billing status)
- Cluster operating model: AD-aware, local-identity/workgroup, disconnected-operations capable, rack-aware, or multi-rack
- Cluster validation state: last `Test-Cluster` run date, summary status, warnings/failures if retrievable
- Post-update state: cluster functional level, storage pool version, VM configuration version upgrade posture

**Node Inventory**
- Per-node: hostname, FQDN, state (Up/Down/Paused/Draining/Joining), uptime
- Per-node: OS name, OS version, OS build number, edition (Datacenter, Azure Stack HCI OS)
- Per-node: domain joined status, OU location
- Per-node: last boot time, installed roles and features list
- Per-node: workgroup state vs domain-joined state
- Per-node: SSH enabled status if required for Azure Arc / local identity operational model

**Cluster Quorum**
- Quorum model (NodeMajority, NodeAndDiskMajority, NodeAndCloudMajority, NodeAndFileShareMajority)
- Witness type and full configuration:
  - Cloud witness: storage account name, Azure endpoint, container, status, last access
  - Disk witness: disk ID, status, volume path
  - File share witness: share path, accessibility status
- Quorum vote assignment per node (does each node have a vote, any manual adjustments)
- Dynamic quorum enabled (yes/no)

**Fault Domains**
- Fault domain type (Site, Rack, Chassis, Node)
- Fault domain assignments per node
- Site awareness configured (yes/no), site definitions if multi-site stretch cluster

**Cluster Networks**
- Per cluster network: name, state (Up/Down/Partitioned), role (Cluster, ClusterAndClient, None), subnets, metric, auto-metric
- Network partitioning events (recent)

**Cluster Shared Volumes — Summary**
- Total CSV count, aggregate capacity, aggregate free space, aggregate percent free
- Any CSVs in redirected or maintenance mode

**Update & Patching State**
- Cluster-Aware Updating (CAU): configured (yes/no), updating mode (self-updating/remote), schedule, run profile, last run date/status
- Azure Local Lifecycle Manager / Solution Update: enabled, current version, target version, last update run date, status, pending updates, update readiness check results
- Per-node: last Windows Update install date, pending updates count, reboot pending (yes/no)
- Update run history: last 5 runs with date, version, status, duration, nodes completed/failed

**Cluster Event Log Summary**
- Critical and Error events from last 7 days aggregated across nodes from: System, Application, Microsoft-Windows-Health, Microsoft-Windows-FailoverClustering/Operational

---

### Hardware Inventory (Per Node)

**System Identification**
- Manufacturer (Dell, Lenovo, HPE, DataON, SuperMicro, other)
- Model name and number
- Serial number, asset tag, system SKU
- Hardware vendor classification flag (used to branch OEM-specific discovery)

**BIOS & Firmware**
- BIOS vendor, version string, release date
- UEFI mode enabled (yes/no)
- Secure Boot enabled (yes/no)

**Out-of-Band Management / BMC**
- Controller type: Dell iDRAC, Lenovo XCC/IMM, HPE iLO, IPMI generic, none detected
- BMC IP address (IPv4 and/or IPv6)
- BMC firmware version
- BMC FQDN if registered in DNS
- BMC SSL certificate expiration (if retrievable)
- IPMI/Redfish accessible (yes/no)

**Processors**
- CPU model string, manufacturer (Intel/AMD)
- Architecture (x64)
- Base clock speed, max turbo (if retrievable)
- Physical sockets populated, cores per socket, total physical cores, logical processors (hyperthreading)
- Virtualization extensions: Intel VT-x / AMD-V enabled
- L2 cache per core, L3 cache total

**Memory**
- Total physical memory installed (GB)
- Total memory slots available vs populated
- Memory channels populated vs available
- Per-DIMM detail: slot location, capacity (GB), speed (MT/s), manufacturer, part number, serial number, type (DDR4/DDR5), rank, configured voltage
- Total memory bandwidth (theoretical)

**GPU / Accelerators**
- GPU present (yes/no)
- Per GPU: manufacturer, model, VRAM capacity, driver version, driver date
- GPU Partitioning (GPU-P) capable (yes/no)
- Discrete Device Assignment (DDA) capable (yes/no)
- NVIDIA vGPU / AMD MxGPU profiles available (if applicable)

**Physical Network Adapters**
- Per NIC: device name, manufacturer, model, PCI slot/bus location
- Driver version, driver date, firmware version
- Link speed (1/10/25/40/100 GbE), media type (RJ45, SFP+, SFP28, QSFP)
- MAC address
- RDMA capable (yes/no), RDMA protocol supported (RoCE v1, RoCE v2, iWARP)
- SR-IOV capable (yes/no), max VFs
- RSS capable, VMQ capable, VMMQ/vRSS capable
- Wake-on-LAN enabled
- Team membership (SET team or NIC team association)
- Physical connection status (up/down/disconnected)

**Physical Disks**
- Per disk: manufacturer, model, serial number, firmware version
- Media type (NVMe, SSD SATA, SSD SAS, HDD SAS, HDD SATA)
- Bus type (NVMe, SAS, SATA)
- Capacity (raw GB/TB)
- Physical slot/location (if available from enclosure services)
- Health status (Healthy, Warning, Unhealthy, Unknown)
- Operational status
- Wear indicator / percentage used (NVMe/SSD)
- Temperature (if retrievable)
- Usage classification: Cache tier, Capacity tier, Journal, Boot, Unassigned
- Storage pool membership (pool name or unassigned)
- Canpool status (eligible for pool, why/why not if ineligible)
- Power-on hours, total bytes written (if retrievable via SMART/NVMe health)

**Boot Device**
- Boot disk identified (device name, type, capacity)
- Boot mode (UEFI, Legacy)
- OS partition layout (EFI System Partition, MSR, OS, Recovery)

**TPM**
- TPM present (yes/no)
- TPM version (1.2 / 2.0)
- TPM manufacturer
- TPM status (ready, not ready, ownership taken)

**Virtualization-Based Security**
- VBS enabled (yes/no)
- Credential Guard enabled (yes/no)
- HVCI (Hypervisor-enforced Code Integrity) enabled (yes/no), enforcement mode

---

### Storage

**Storage Spaces Direct**
- S2D enabled (yes/no)
- S2D health state (Healthy, Warning, Unhealthy)
- Storage subsystem name and model
- Cache state (enabled/disabled/degraded)

**Storage Pool**
- Pool name, health status, operational status
- Total capacity (raw), allocated capacity, unallocated capacity
- Provisioned capacity vs physical capacity (thin provisioning ratio)
- Resiliency setting defaults (mirror/parity/columns)
- Fault domain awareness level (PhysicalDisk, StorageEnclosure, StorageScaleUnit/Node)
- Read cache enabled (yes/no), read cache size
- Media type composition: count and total capacity per media type (NVMe, SSD, HDD)

**Cache Configuration**
- Cache enabled (yes/no)
- Cache behavior mode (ReadOnly, WriteOnly, ReadWrite)
- Cache devices list (device IDs, capacity each)
- Cache-to-capacity ratio
- Cache device binding mode (per-node or auto)
- Cache journal size

**Virtual Disks / Volumes**
- Per virtual disk: friendly name, GUID, size (virtual), footprint size (physical), provisioning type
- Resiliency type: two-way mirror, three-way mirror, mirror-accelerated parity, single parity, dual parity, nested mirror-accelerated parity
- Number of data copies, number of columns, interleave size
- Health status, operational status
- File system type (ReFS, CSVFS_ReFS, NTFS)
- ReFS integrity streams enabled (yes/no)
- Deduplication enabled (yes/no), dedup savings ratio, last optimization time
- Tiering enabled (yes/no), tier descriptions and sizes
- Volume accessible from all nodes (yes/no)

**Cluster Shared Volumes (Detail)**
- Per CSV: name, volume path, friendly name
- File system, block size
- Owner node, state (Online, Offline, InMaintenance, Redirected)
- Redirected access mode (BlockRedirected, FileSystemRedirected, None) — why if redirected
- Total size, free space, percent free
- CSV cache enabled (yes/no), CSV cache size allocated

**Scale-Out File Server (SOFS)**
- SOFS cluster role present (yes/no)
- File server name(s) and client access point(s)
- Per share: share name, local path, share type (ContinuouslyAvailable or Standard)
- Share permissions (ACL: who has what access)
- NTFS permissions on underlying folder
- Share quotas configured (yes/no), quota details
- SMB encryption required on share (yes/no)
- ABE (Access-Based Enumeration) enabled per share

**Storage Health**
- Active storage faults (fault type, description, faulting object, severity, recommended action)
- Storage repair jobs: running (type, progress, affected object), pending, completed (last 5)
- Last integrity scrub date, scrub schedule, last scrub results
- Disk retirement alerts (any disks flagged for retirement)
- Pool capacity alerts (approaching thresholds)
- Storage maintenance mode status

**Storage QoS**
- Storage QoS enabled at cluster level (yes/no)
- QoS policies defined (name, policy type, MinIOPS, MaxIOPS, MinBandwidth, MaxBandwidth)
- QoS policy assignments (which VMs/VHDs assigned to which policies)
- QoS flow status summary

**Storage Replica**
- Storage Replica configured (yes/no)
- Replication partnerships (source group, destination group, destination server/cluster)
- Replication mode (synchronous/asynchronous)
- Replication status, health, bytes remaining to sync
- Test failover history

---

### Networking

**Adapter Qualification & Driver Compliance**
- Per physical adapter: Windows Server Catalog role qualification (Management, Compute Standard/Premium, Storage Standard/Premium) where determinable
- Unsupported inbox driver detection (DriverProvider = Microsoft)
- Adapter driver provider, driver filename, and whether the installed driver matches OEM guidance
- SET symmetry validation across teamed adapters: vendor, model, speed, configuration parity
- Unsupported teaming detection (LBFO or non-SET methods)
- Live Migration transport mode (SMB, Compression, RDMA) and SMB bandwidth limit configuration where set

**Virtual Switches**
- Per vSwitch: name, switch type (External, Internal, Private)
- SET (Switch Embedded Teaming) enabled (yes/no)
- SET team members (physical NIC names), load balancing algorithm (HyperVPort, Dynamic)
- SR-IOV enabled (yes/no)
- Bandwidth reservation mode (Weight, Absolute, Default, None)
- Default flow minimum bandwidth weight
- IOV weight, IOV queue pairs available
- Extensions installed (name, vendor, enabled, running)
- Management OS vNICs attached

**Network ATC**
- Network ATC feature installed and operational (yes/no)
- Per intent: intent name, intent type(s) (Management, Compute, Storage, StretchedCluster — can be combined)
- Per intent: intent name, intent type(s) (Management, Compute, Storage — can be combined)
- Per intent: assigned physical adapters, provisioning status, configuration status (Success, InProgress, Failed, Retrying)
- Per intent override values:
  - VLAN IDs
  - Jumbo frame (MTU size)
  - RDMA enabled, RDMA protocol (RoCEv2, iWARP)
  - NetworkDirect technology
  - Bandwidth percentage reservations (SMB, Live Migration, default)
  - Cluster network name
  - Adapter property overrides (any non-default adapter settings)
- ATC global override settings
- ATC health status, compliance check results, last compliance check date

**Host Virtual NICs**
- Per host vNIC: name, connected virtual switch, VLAN ID
- IP address, subnet mask, default gateway (if applicable)
- DNS servers assigned
- RDMA enabled (yes/no), RDMA operational state (up/down/degraded)
- MAC address (dynamic or static)
- Min/max bandwidth settings
- Live Migration network (yes/no)
- Management network (yes/no)

**Management Network**
- Per-node: management IP, subnet mask, default gateway
- Per-node: DNS servers (primary, secondary, tertiary), DNS suffix, DNS suffix search list
- WINS configured (yes/no), WINS servers
- Management VLAN ID
- Management network adapter name(s)

**Storage Networks**
- Per storage network/subnet: purpose (SMB storage traffic), subnet, VLAN ID
- RDMA enabled (yes/no)
- RDMA protocol in use (RoCE v1, RoCE v2, iWARP)
- MTU / Jumbo frames configured (packet size)
- DCBX willing mode, PFC (Priority Flow Control) enabled and configured priorities
- ETS (Enhanced Transmission Selection) traffic class configuration and bandwidth allocation
- SMB Multichannel enabled (yes/no), connections per interface
- SMB Direct (RDMA) operational (yes/no), connection status
- SMB signing required (yes/no), SMB encryption required (yes/no)
- Per-node storage adapter IP assignments
- Storage fabric design validation: same-subnet congestion risk vs per-fabric VLAN/subnet separation
- RDMA protocol consistency across peers (all iWARP or all RoCE)
- Traffic class allocation validation: system, RDMA, and default traffic classes

**Physical Fabric / ToR Compliance**
- Top-of-rack switch model, OS version, and validated-vendor status if obtainable directly or supplied manually
- LLDP enabled state and required TLV visibility (Port VLAN ID, VLAN Name, Link Aggregation, ETS Config, ETS Recommendation, PFC Configuration, Maximum Frame Size)
- VLAN support and compliance with IEEE 802.1Q requirements
- DCB/PFC compliance with IEEE 802.1Qbb requirements
- ETS compliance with IEEE 802.1Qaz requirements
- MTU compliance for the chosen traffic model and SDN usage
- BGP support/configuration where SDN compute traffic requires it
- DHCP relay presence where PXE or deployment flow depends on it
- East-west fabric classification: switched or switchless full-mesh
- Same-rack / same-ToR compliance for hyperconverged deployments where applicable

**Compute Networks**
- VLANs available for VM traffic
- Default VLAN behavior (trunk, access, none)
- VM network isolation configuration

**Software Defined Networking (SDN)**
- SDN deployed (yes/no)
- **Network Controller:** deployment status, node count, node list, REST API endpoint/FQDN, REST API certificate (issuer, expiration, thumbprint), NC health state, NC software version, Southbound communication status, infrastructure VLAN/subnet
- **SLB Multiplexer:** deployed (yes/no), count, per-MUX status, VIP pools, BGP peering status, MUX health
- **RAS Gateway:** deployed (yes/no), count, gateway pool configuration, type (S2S VPN, GRE, L3 Forwarding), per-gateway status, connections active, BGP routing status
- **SDN Diagnostics:** overall health, NC-managed resource counts, last diagnostic run

**SDN Virtual Networks**
- Per virtual network: name, resource ID, address spaces, subnets (name, prefix, ACLs, route tables), peerings, logical network association
- Virtual network health

**SDN Network Security Groups (NSGs)**
- Per NSG: name, resource ID
- Per rule: name, priority, direction (Inbound/Outbound), action (Allow/Deny), protocol, source prefix/port, destination prefix/port, logging enabled
- NSG associations (which subnets or NICs)
- Effective rules per VM NIC (if computable)

**SDN Load Balancers**
- Per LB: name, resource ID, frontend VIP(s), backend pool members
- Health probes (protocol, port, interval, threshold)
- Load balancing rules (protocol, frontend port, backend port, persistence, idle timeout)
- Outbound NAT rules

**SDN Access Control Lists**
- Per ACL: name, rules (priority, protocol, action, direction, source/dest), associations

**Logical Networks (Azure / Arc Side)**
- Per logical network: name, resource ID, VLAN ID, subnets (address prefix, IP allocation method — DHCP/Static)
- IP address pools (start, end, allocated count, available count)
- DNS servers, default gateway configured in logical network
- Custom location association
- Network function for VM provisioning via Arc

**Proxy Configuration**
- Per-node: proxy configured (yes/no)
- Proxy type: WinHTTP, environment variable, PAC file
- Proxy address and port
- Proxy bypass list
- Proxy authentication required (yes/no)
- Proxy authentication mode (none/basic/NTLM/Kerberos) where determinable
- Arc and Azure control-plane bypass requirements satisfied (yes/no)
- Arc Private Link Scopes unsupported state detected and flagged
- Public endpoint resolution posture for Arc-required endpoints

**DNS Configuration**
- Per-node: DNS client settings (all server IPs, suffix, search list, devolution)
- DNS conditional forwarders configured on any local DNS if nodes also run DNS
- DNS zone and A-record posture for local-identity/workgroup deployments where applicable

**Windows Firewall**
- Per-node: firewall profile status per profile (Domain, Private, Public — enabled/disabled)
- Azure Local required ports audit: check that all documented required firewall rules are present and enabled (HCI cluster communication, WinRM, SMB, Live Migration, storage, WAC, Arc agent, etc.)
- Custom or third-party firewall rules detected
- Internal rules audit for documented Azure Local ports and protocols, including TCP 30301, WinRM 5985/5986, SMB 445, cluster 3343, Hyper-V 6600/2179, RPC 135 and dynamic ports, NTP 123, ICMP, and required AD ports when domain-joined
- Outbound endpoint posture: region-specific Azure Local endpoint set, Arc-enabled servers, Azure Arc resource bridge, AKS, AVD, AMA, Defender, and OEM allowlists
- HTTPS inspection state (must be disabled for Azure Local)
- On-prem firewall path count / segmentation summary when traffic traverses multiple firewalls

---

### Virtual Machines

**VM Inventory**
- Per VM: name, VM ID (GUID), generation (1 or 2), state (Running, Off, Saved, Paused, Starting, Saving, Stopping, FastSaved, etc.)
- Per VM: creation time, uptime (if running), configuration version
- Per VM: VM notes/description field
- Total VM count, running count, stopped count

**VM Compute**
- Per VM: virtual processor count, processor compatibility mode, NUMA spanning, NUMA node assignments
- Per VM: resource metering enabled (yes/no), measured CPU/memory if enabled
- Per VM: automatic start action (Nothing, StartIfPreviouslyRunning, AlwaysStart), start delay (seconds), automatic stop action (Save, TurnOff, Shutdown)

**VM Memory**
- Per VM: dynamic memory enabled (yes/no)
- If dynamic: startup memory, minimum memory, maximum memory, memory buffer percentage, memory priority
- If static: assigned memory
- Per VM: current memory demand (if running), memory status

**VM Storage / Disks**
- Per VM per disk: controller type (IDE/SCSI), controller number, location (LUN)
- Per disk: VHD/VHDX path, current file size, maximum disk size
- Per disk: format (VHD/VHDX), type (Fixed, Dynamic, Differencing)
- Per disk: parent path (if differencing)
- Per disk: QoS policy assigned (yes/no)
- Shared VHDX (yes/no)
- Per VM: total storage footprint (sum of current file sizes)
- Storage controller pass-through disks (if any)

**VM Networking**
- Per VM per NIC: name, connected switch, VLAN ID (access mode or trunk mode with allowed VLANs)
- Per NIC: MAC address, MAC address type (Static/Dynamic)
- Per NIC: DHCP guard (yes/no), Router guard (yes/no), MAC address spoofing (yes/no)
- Per NIC: port mirroring mode (None, Source, Destination)
- Per NIC: bandwidth management (minimum/maximum Mbps)
- Per NIC: SR-IOV enabled (yes/no), SR-IOV weight, IOV queue pairs
- Per NIC: device naming (yes/no)
- Per NIC: IP addresses observed (if guest data exchange available)

**VM Integration Services**
- Per VM: integration services version, upgrade available (yes/no)
- Per VM: individual IC status — Heartbeat (OK/Error/NoContact), Time Synchronization (enabled/disabled), Data Exchange (KVP enabled/disabled), Shutdown (enabled/disabled), VSS (enabled/disabled), Guest Services (enabled/disabled)
- Guest OS name and version (from data exchange if available)

**VM Placement & Availability**
- Per VM: current owner node
- Per VM: preferred owners list (if configured)
- Per VM: anti-affinity group membership (group name)
- Per VM: cluster role name, cluster role state
- Per VM: failover/failback policy (if configured)
- Per VM: drain behavior on node shutdown (if configured)

**VM Checkpoints (Snapshots)**
- Per VM: checkpoint count, checkpoint tree (parent/child relationships)
- Per checkpoint: name, creation time, type (Production/Standard), file path, size
- Total checkpoint storage consumed per VM

**VM Replication**
- Per VM: Hyper-V Replica configured (yes/no)
- If yes: replication state (Replicating, Suspended, FailedOver, etc.), replication health (Normal, Warning, Critical)
- Replication mode (primary/replica/extended), replication frequency
- Primary server, replica server
- Last replication time, missed replication count

**Arc VM Integration**
- Per VM: Arc Connected Machine agent installed (yes/no)
- Agent version, provisioning state, last heartbeat time
- Arc extensions installed on VM (name, publisher, version, status)
- Guest management enabled (yes/no)
- Azure resource ID for the Arc VM

**VM Images & Gallery**
- Marketplace images downloaded to cluster: per image — name, publisher, offer, SKU, version, OS type, download date, size, status
- Custom VM images in Arc image gallery: per image — name, OS type, generation, size, source (upload/capture), creation date
- ISO files available on cluster storage (discovered by location)

**VM Resource Utilization Summary (Aggregate)**
- Total VMs, running VMs, stopped VMs
- Total vCPUs allocated (all VMs), total pCPUs available (all nodes) → vCPU:pCPU overcommit ratio
- Total memory allocated (all VMs), total physical memory (all nodes) → memory overcommit ratio
- Total VM storage consumed (sum of all VHD/VHDX current sizes)
- Average VMs per node, highest-density node, lowest-density node

**Guest Clusters**
- Guest failover clusters detected (yes/no) — discovered via shared VHDX or known cluster VM name patterns
- Per guest cluster: cluster name, member VM names, cluster roles/workloads

---

### Identity & Security

**Active Directory**
- Cluster computer object (CNO): name, OU, distinguished name, SPN list
- Per-node computer object: OU, distinguished name
- Virtual Computer Objects (VCOs) created by cluster roles: name, OU
- AD site membership per node

**Cluster Identity & Arc Authentication**
- Cluster service account model (LocalSystem, dedicated gMSA, etc.)
- Azure Arc identity model: system-assigned managed identity (current model) vs legacy SPN/App Registration
- If legacy App Registration: Application ID, display name, secret expiration date, required API permissions, credential count
- Managed identity object ID, associated Azure resource

**Azure RBAC**
- Role assignments on the Arc cluster resource: per assignment — role name, principal name, principal type (User/Group/SP), scope
- Role assignments inherited from resource group or subscription
- Custom role definitions in use (name, permissions)

**Entra ID Integration**
- Entra hybrid join status per node (hybrid joined, Entra joined, not joined)
- Entra Kerberos (AADKERB) configured (yes/no), service principal status, domain configuration
- Entra ID authentication for cluster management (configured/not)

**Local Identity with Azure Key Vault (Deployment Variant)**
- Identity mode: Active Directory-backed vs local identity with Azure Key Vault
- Workgroup cluster status confirmed (yes/no)
- `ADAware` cluster parameter state (0=None, 1=AD, 2=Local Identity)
- Cluster Key Vault resource, vault URI, subscription, resource group, and region
- Key Vault secret backup extension installed status on Arc-enabled nodes
- Key Vault secret backup extension health/provisioning state
- Managed identity and required Key Vault role assignments present (including Key Vault Secrets Officer)
- Backup secret location updated/rotated history where retrievable
- Recovery admin secret presence/backup status
- Local identity operational prerequisites: same local admin credential across nodes, static IP usage, DNS zone/A record readiness
- Tool compatibility findings for local identity mode: Windows Admin Center unsupported, SCVMM limited/unsupported, MMC tools mixed compatibility

**Certificates**
- Cluster communication certificates: per cert — subject, issuer, thumbprint, expiration date, key length, self-signed vs CA-issued, store location
- Arc agent certificates: per node — thumbprint, expiration, issuing CA
- SSL/TLS certificates (WAC, API endpoints, etc.): subject, issuer, thumbprint, expiration, SAN entries
- Certificates expiring within 30/60/90 days flagged
- Certificate template info if CA-issued

**Secret Creation, Rotation, and Backup**
- Internal certificate/secret auto-rotation enabled state
- Last rotation time, next expected rotation, and failed rotation state if retrievable
- Certificate validity monitoring/alert state
- Secret backup target and backup health status
- Key Vault alert conditions present (for example, inaccessible vault or missing vault) when using local identity with Key Vault

**CredSSP**
- Per-node: CredSSP server role enabled (yes/no)
- Per-node: CredSSP client role enabled (yes/no), delegated server list
- CredSSP finding: flag if enabled as a security concern with recommendation

**BitLocker**
- Per volume per node: BitLocker enabled (yes/no)
- Encryption method (XTS-AES-128, XTS-AES-256, etc.)
- Protection status (Protected, Unprotected)
- Key protector types (TPM, TPM+PIN, RecoveryPassword, ADAccountOrGroup)
- Recovery key escrowed to AD (yes/no)
- Encryption percentage (if encrypting/decrypting)

**Secured-Core Server**
- Secured-core enabled (yes/no)
- DRTM (Dynamic Root of Trust for Measurement) enabled (yes/no)
- System Guard Secure Launch enabled (yes/no)
- Firmware protection enabled (yes/no) — UEFI runtime page protection
- VBS running (yes/no)
- HVCI enforced (yes/no), enforcement mode (Audit/Enforce)

**Windows Defender Application Control (WDAC)**
- WDAC policy applied (yes/no)
- Policy enforcement mode (Audit/Enforce)
- Policy version / policy ID
- Supplemental policies present (yes/no)
- WDAC event log violations summary (last 7 days)

**Syslog / SIEM Forwarding**
- Syslog forwarding enabled (yes/no)
- Destination server(s), port(s), and transport (TCP/UDP)
- Encryption enabled (yes/no)
- Authentication mode (unidirectional/bidirectional/none) where configured
- Payload format validation (CEF / RFC3164)
- Per-host forwarding agent status

**Security Defaults & Drift Control**
- Security defaults enabled state
- Drift control enabled state
- Drift control refresh cadence (expected 90-minute remediation interval)
- Secured-core posture monitored at deployment and runtime (yes/no)

**Security Baseline**
- Azure Local security baseline assessment: compliant/non-compliant/not assessed
- Drift detection results: settings that deviate from recommended baseline (setting name, current value, recommended value)
- Windows Defender Antivirus: per-node — enabled, real-time protection status, definition version, last scan date/type, exclusions configured
- Microsoft Defender for Cloud: agent deployed per node (yes/no), onboarded (yes/no), plan tier
- Microsoft Defender for Cloud plan detail (basic/foundational posture only vs Defender for Servers-enabled)

**Local Administrator Audit**
- Per-node: local Administrators group membership (member names, types — user/group/builtin, domain)
- Unexpected or non-standard members flagged

**Built-In Local Accounts**
- Well-known built-in Administrator (`RID 500`) enabled/disabled state
- Built-in Guest (`RID 501`) enabled/disabled state
- Presence of a customer-created local admin separate from the well-known built-in account

**Audit Policy**
- Per-node: audit policy configuration by category (Account Logon, Account Management, Detailed Tracking, DS Access, Logon/Logoff, Object Access, Policy Change, Privilege Use, System) — success/failure auditing enabled for each

---

### Azure Integration

**Arc Registration**
- Cluster registered with Azure (yes/no)
- Arc cluster resource ID, subscription ID, subscription name, resource group name, Azure region
- Per-node Arc Connected Machine agent: version, status (Connected/Disconnected/Error), last connected time
- Connectivity method: direct, proxy, private link
- Arc agent proxy configuration (if any)

**Arc Resource Bridge**
- Deployed (yes/no)
- Resource bridge name, Azure resource ID
- Status (Running, Offline, ProvisioningFailed, Upgrading)
- Resource bridge version, Kubernetes version
- Custom location: name, resource ID, status, namespace
- Resource providers registered for Azure Local workloads
- Resource bridge appliance VM location on cluster

**Azure Local VM Management Control Plane**
- Infrastructure logical network present and healthy (yes/no)
- One-to-one mapping between custom location and Arc resource bridge namespace
- Azure Local VM management cluster extension/controller installed and healthy
- ARM-manageable workload resources present: storage paths, VM images, logical networks, NICs, VHDs, NSGs
- VM image source types in use: Azure Marketplace, Azure Storage account, local share
- Logical network immutability constraints noted and validated (gateway, IP pools, address space, VLAN, virtual switch)
- IPv4-only constraint observed for Azure Local VMs
- Azure CLI / `stack-hci-vm` management path in use (yes/no)

**Arc Extensions**
- Per-node per extension: extension name, publisher, type, type handler version, provisioning state (Succeeded, Failed, Updating), auto-upgrade minor version (yes/no), settings summary, status message, last updated date
- Extension compliance: expected extensions vs installed, missing extensions flagged
- Full configuration snapshot for platform-critical extensions retained where safe to do so

**Azure Services Running on Azure Local**

Ranger should detect likely workload families even when deep workload-specific inspection is phased later. At minimum it must identify whether the Azure Local control plane is hosting or managing each major workload family.

**Workload Family Detection**
- Azure Local VM management resources present (yes/no)
- AKS / Arc-enabled Kubernetes present (yes/no)
- Azure Virtual Desktop present (yes/no)
- Arc VMs present (yes/no)
- Arc Data Services present (yes/no)
- IoT Operations present (yes/no)
- Microsoft 365 Local workload family indicators present (yes/no)
- Other Azure control-plane-managed workload families detected and flagged for follow-up

**AKS (Azure Kubernetes Service) Hybrid:**
- AKS enabled on cluster (yes/no)
- Per AKS cluster: name, Azure resource ID, Kubernetes version, provisioning state
- Node pools: count, per pool — name, VM size, node count, OS type (Linux/Windows), mode (System/User)
- Networking: CNI model (Calico/Flannel/Azure CNI), load balancer (MetalLB/HAProxy/other), control plane IP, pod CIDR, service CIDR
- Arc-enabled Kubernetes: connected (yes/no), Arc agent version, compliance state
- Add-ons / extensions: monitoring, policy, GitOps, etc.
- Total resource consumption (vCPU, memory, storage) across all AKS clusters

**AVD (Azure Virtual Desktop):**
- AVD deployed on Azure Local (yes/no)
- Per host pool: name, type (Pooled/Personal), Azure resource ID
- Session hosts: count, per host — name, status (Available/Unavailable/Shutdown), sessions (current/max), agent version, last heartbeat, OS version
- Scaling plan associated (yes/no), scaling plan configuration
- Load balancing: algorithm (BreadthFirst/DepthFirst), max session limit
- FSLogix: configured (yes/no), profile container location (path), VHDX type, storage location (local CSV, Azure Files, NetApp), Cloud Cache configured (yes/no)
- Registration: token status, expiration
- Application groups and published apps/desktops

**Arc VMs:**
- Total Arc-managed VMs provisioned via Arc
- Per Arc VM: name, provisioning state, guest management enabled, VM size, connected status
- Arc VM guest attestation status

**Arc Data Services:**
- Deployed (yes/no)
- Data controller: name, namespace, connection mode (direct/indirect), version
- SQL Managed Instance count, per instance: name, tier, vCores, storage, status
- PostgreSQL count, per instance: name, workers, status

**IoT Operations:**
- Deployed (yes/no)
- IoT Operations instance details if present

**Microsoft 365 Local:**
- Microsoft 365 Local indicators present (yes/no)
- Exchange Server, SharePoint Server, and Skype for Business workload indicators detected
- Connected vs disconnected operating model for Microsoft 365 Local deployment
- Placement summary across Azure Local instances where identifiable

**Monitoring & Observability**

**Azure Edge Telemetry and Diagnostics Extension:**
- `AzureEdgeTelemetryAndDiagnostics` extension installed (yes/no)
- Extension version, provisioning state, health status
- Extension required for Metrics coverage satisfied (yes/no)

**Azure Monitor Agent (AMA):**
- Per-node: AMA installed (yes/no), version, provisioning state, health status
- Data Collection Rules (DCRs) assigned: per DCR — name, data sources (performance counters, event logs, custom logs, syslog), destinations (Log Analytics workspace, Metrics, Storage), transform KQL
- Data Collection Endpoints (DCEs): name, endpoint URI, region

**HCI Insights:**
- Enabled (yes/no)
- Log Analytics workspace associated (name, workspace ID, region)
- Insights data types flowing: health, performance, inventory
- Last data received timestamp
- Health monitoring signals: what signals are active, any stale signals
- Single-cluster and multi-cluster workbook availability
- Feature workbook availability (for example ReFS dedup/compression, OEM hardware where available)

**Log Analytics:**
- Workspace connected (yes/no)
- Workspace name, workspace ID, resource group, region
- Per-node: agent communication status (healthy, unhealthy, not reporting)
- Data types collected (Perf, Event, Heartbeat, etc.)
- Daily data ingestion volume (if retrievable)
- Data freshness / last ingestion timestamp by major signal type

**Metrics & Diagnostics:**
- Platform metrics enabled (yes/no)
- Diagnostic settings configured on Arc cluster resource: per setting — name, destination (Log Analytics, Storage Account, Event Hub), categories enabled
- Custom metrics collection configured (yes/no)
- Azure Monitor Metrics coverage active via Azure Local extensions (yes/no)
- Metrics retention / query posture acknowledged (93-day retention, 30-day chart limit where relevant to reporting design)
- Recommended platform metric set available for nodes, drives, volumes, VHDs, VMs, and network adapters

**Azure Alerts:**
- Alert rules targeting the cluster resource or resource group: per rule — name, description, condition/signal, threshold, severity (0-4), action group(s), enabled status, last triggered
- Health alert coverage from OS Health Service categories (storage, network, compute, configuration, capacity)
- Log alert rules present (yes/no)
- Metric alert rules present (yes/no)
- Recommended alert templates enabled (yes/no)
- Action groups configured and mapped to alert rules

**Health Service**
- OS Health Service enabled/visible via Azure Monitor (yes/no)
- Active health issues grouped by category
- Health issue count and severity summary
- Last observed health signal refresh time

**Azure Update Manager**
- Enabled (yes/no)
- Per-node: assessment status (Compliant, Pending, NotAssessed), last assessment time
- Pending updates: per update — KB, classification (Critical, Security, UpdateRollup, etc.), severity
- Overall compliance percentage
- Maintenance configurations assigned (name, schedule, reboot setting, scope)
- Scheduled maintenance windows (next window date/time)

**Azure Backup**
- Backup configured for VMs on cluster (yes/no)
- Agent type: MARS agent, Azure Backup Server (MABS), DPM
- Per protected item: name, last backup date/time, last backup status, policy name, recovery points count
- Vault name, vault resource group
- Backup health: any failed backups in last 7 days

**Azure Site Recovery (ASR)**
- ASR configured (yes/no)
- Recovery Services vault name, region
- Replication health: per replicated VM — name, replication state, replication health, RPO, last test failover date, failover readiness
- Recovery plans: name, VM count, last test failover

**Azure Policy**
- Policies assigned at cluster resource, resource group, or subscription scope: per assignment — policy name, definition type (BuiltIn/Custom), effect (Audit/Deny/DeployIfNotExists/etc.), compliance state
- Non-compliant policy details: resource, policy, reason for non-compliance
- Policy exemptions (if any)
- Initiative/policy set assignments

**Cost & Licensing**
- Azure Local billing model (per-physical-core, subscription-based)
- Total physical core count for billing
- Azure Hybrid Benefit enabled (yes/no), benefit type (Windows Server, SQL Server)
- Azure subscription type (EA, CSP, Pay-As-You-Go, etc.)
- Estimated monthly Azure cost for cluster services (if computable from meters)

**Disconnected Operations**
- Disconnected operations deployed or planned (yes/no)
- Dedicated management cluster present and healthy (yes/no)
- Disconnected appliance status, location, and capacity posture
- Local control-plane services present: ARM, RBAC, managed identity, Arc-enabled servers, Azure Local VMs, AKS if supported, Azure Container Registry, Azure Key Vault, Azure Policy
- Disconnected monitoring/log collection path available
- Eligibility / sovereign or remote-site operating reason noted if this variant is present

**Multi-Rack Deployments**
- Multi-rack deployment detected (yes/no)
- Main rack plus compute-rack count and topology summary
- SAN-backed storage presence and health summary
- Managed networking via Azure APIs / ARM present (yes/no)
- Azure ExpressRoute or equivalent northbound connectivity present
- Multi-rack preview limitations or feature gating noted

---

### OEM & Vendor Integration

Branched based on hardware vendor detected in the Hardware Inventory collector.

**Dell**
- OpenManage Integration for Microsoft Azure Local: installed (yes/no), version, status, health
- Dell APEX Cloud Platform for Azure Local: integration status, version
- iDRAC integration: per-node iDRAC version, license level (Express/Enterprise/Datacenter), remote services available
- Dell Lifecycle Controller version per node
- Dell firmware compliance: current firmware catalog version, last catalog update, per-component firmware compliance status (compliant/non-compliant/unknown), pending firmware updates
- Dell Support Assist: agent installed (yes/no), version, collection status, ProSupport Plus entitlement status
- Dell Update packages available/pending

**Lenovo**
- XClarity Integrator for Azure Local: installed (yes/no), version
- XClarity Controller (XCC) per node: version, license level
- Firmware compliance: catalog-based comparison, per-component status
- Lenovo update status

**HPE**
- HPE Environment Manager for Azure Local: installed (yes/no), version
- iLO per node: version, license level (Standard/Advanced/Premium)
- HPE OneView integration: connected (yes/no), OneView server, managed status
- Firmware compliance via SPP (Service Pack for ProLiant): current SPP version, compliance status

**DataON**
- DataON MUST (Monitoring, Understanding, Supporting, Troubleshooting): installed (yes/no), version, monitoring status
- DataON S2D-related management tools

**Other / Whitebox**
- Flag absence of OEM-specific management tools
- Note as informational finding — no vendor integration detected, recommend manual firmware management process

---

### Management Tools

**Windows Admin Center (WAC)**
- WAC deployed (yes/no)
- WAC version, build number
- Gateway mode: standalone, gateway service, Azure-managed (Azure portal WAC)
- URL and port (e.g., `https://wac.contoso.com:443`)
- Azure registration: registered (yes/no), Azure resource ID, tenant ID
- Installed extensions: per extension — name, publisher, version, enabled
- Active cluster connection: registered (yes/no), last connection status, stale connection detection
- TLS certificate: subject, issuer, expiration, thumbprint
- Authentication mode (CredSSP, Kerberos, certificate)

**System Center VMM**
- SCVMM managing this cluster (yes/no)
- VMM server name, VMM version/build
- Host group assignment
- VMM agent version per node
- VMM-managed VM count, VM templates, VM networks

**System Center Operations Manager (SCOM)**
- SCOM agent installed per node (yes/no)
- Agent version per node
- Management group name, management server
- HCI-related management packs installed (name, version)
- Agent health status, last heartbeat
- Active SCOM alerts for cluster nodes

**Third-Party Agents & Tools**
- Discovery of common backup/DR agents: Veeam Agent, Commvault, Zerto, Rubrik, Cohesity, Nakivo — per node (installed yes/no, version, service status)
- Discovery of common monitoring agents: SolarWinds, Datadog, Splunk UF, Prometheus exporters — per node (installed yes/no, version, service status)
- Other notable third-party services running on nodes (antivirus other than Defender, configuration management agents like SCCM/Intune, etc.)

---

### Performance Baseline

**Compute Performance**
- Per-node: CPU utilization average and peak over collection snapshot (e.g., 5-minute sample)
- Per-node: memory utilization — total physical, available, committed bytes, committed ratio
- Per-node: Hyper-V Hypervisor Logical Processor % Total Run Time
- Cluster aggregate: average CPU and memory utilization

**Storage Performance**
- Per-node: storage IOPS (read, write, total), throughput (read MB/s, write MB/s), latency (avg read, avg write, max read, max write)
- Cluster aggregate storage performance
- CSV cache hit ratio per CSV (if CSV cache enabled)
- S2D cache performance: cache hits, cache misses, cache hit ratio
- Per-volume performance (if per-volume counters available)

**Network Performance**
- Per physical adapter: bytes sent/sec, bytes received/sec, current bandwidth utilization %
- Per RDMA adapter: RDMA bytes sent/sec, RDMA bytes received/sec, RDMA connections
- Per adapter: packets outbound errors, packets received errors, packets outbound discards, packets received discards
- SMB Direct: bytes sent/sec, bytes received/sec (RDMA path performance)

**Cluster Health**
- Active health faults: per fault — fault type, severity (Critical, Warning, Degraded), description, faulting object type, faulting object name, recommended action
- Historical fault count (last 7 days)
- Cluster validation report: last run date, warnings/failures summary (if available)

**Event Log Analysis**
- Critical and Error event counts from last 7 days per source:
  - System, Application
  - Microsoft-Windows-Health/Operational
  - Microsoft-Windows-StorageSpaces-Driver/Operational
  - Microsoft-Windows-FailoverClustering/Operational
  - Microsoft-Windows-SDDC-Management/Operational
  - Microsoft-Windows-Hyper-V-VMMS-Admin, Microsoft-Windows-Hyper-V-Worker-Admin
  - Microsoft-Windows-StorageReplica/Admin (if SR configured)
- Top recurring event IDs with count and sample message

**Storage Health Check**
- Storage pool rebuild/rebalance: currently running (yes/no), type, progress, ETA
- Disk retirement pending count
- Storage job queue (pending jobs, type, priority)
- Drive latency outliers (drives significantly slower than peers)

---

## Connectivity Model

### Where Ranger Runs

Ranger should be designed to run from a management workstation or jump box that has network access to all required targets. This is important because:

- Cluster nodes may not have direct access to the OOB/BMC network where iDRAC lives.
- The management workstation or jump box typically sits on both the management network and the OOB network.
- Running directly on a cluster node limits what can be discovered and may not reach all targets.

The recommended execution model is: **run Ranger from a jump box or management workstation that has access to the management network, the OOB network, and Azure.**

### Supported Connectivity Methods

| Method | Use Case | Status |
|--------|----------|--------|
| Remote PowerShell (WinRM) | Cluster node and OS-level discovery from a jump box | Primary method, plan for v1 |
| Redfish REST API (HTTPS) | OEM hardware / iDRAC / BMC discovery | Primary method, plan for v1 |
| Az PowerShell / Azure CLI | Azure resource and Arc registration discovery | Primary method, plan for v1 |
| Azure Arc Run Command | Alternative for cluster-node discovery when WinRM is not available | Investigate, not proven in the org yet |
| SSH / REST / SNMP | Network device discovery (switches, firewalls) | Future, vendor-dependent |

### Arc Run Command — Open Investigation

Azure Arc Run Command (`Invoke-AzConnectedMachineRunCommand`) is a potential alternative for reaching cluster nodes without direct WinRM access. This is not currently used anywhere in the AzureLocal organization. It should be investigated as a secondary connectivity path, but v1 should not depend on it.

---

## Authentication Strategy

Authentication is one of the most complex areas because Ranger connects to many different targets, each with different credential requirements.

### Credential Resolution Order

Ranger should follow the credential resolution pattern already established across the AzureLocal organization:

1. **Parameter** — if a credential is passed directly via `-Credential` or a target-specific parameter, use it immediately.
2. **Azure Key Vault** — if a Key Vault reference is provided (via config or `keyvault://` URI), resolve the credential from Key Vault. Try `Az.KeyVault` module first, fall back to `az keyvault secret show` CLI.
3. **Interactive prompt** — if no credential is available from parameter or Key Vault, fall back to `Get-Credential` with a descriptive prompt.

This three-tier pattern is already implemented in `azurelocal-toolkit` (see `keyvault-helper.ps1` and `Get-DellServerInventory-FromiDRAC.ps1`) and documented in `azurelocal-avd` scripting standards.

### Key Vault URI Format

The organization uses a `keyvault://<vault-name>/<secret-name>[/<version>]` URI format for referencing secrets in configuration files. Ranger should adopt this same pattern. The resolution helpers (`ConvertFrom-KeyVaultUri`, `Get-SecretFromUri`, `Resolve-KeyVaultSecrets`) already exist in the toolkit and can be reused or adapted.

### Azure Authentication Methods

For Azure-side discovery, Ranger must support:

| Method | Use Case |
|--------|----------|
| Interactive login (`Connect-AzAccount`) | Ad-hoc runs from a workstation |
| Service principal with client secret | Automated or scheduled runs |
| Managed identity | Runs from Azure-hosted infrastructure |
| Existing Az context | When the user is already authenticated |

Service principal secrets and managed identity configuration should be stored in or resolved from Key Vault.

### Multi-Target Credential Map

This is the critical design challenge. Ranger connects to fundamentally different systems, each with its own credential:

| Target | Credential Type | Example |
|--------|----------------|---------|
| Azure (Az modules) | Service principal, managed identity, or interactive login | Azure subscription access for Arc, resource groups, services |
| Cluster nodes (WinRM) | Domain credential or local admin | `Invoke-Command` to cluster nodes |
| Active Directory / domain | Domain credential with appropriate read access | Identity and security discovery |
| iDRAC / BMC (Redfish) | Local BMC credential (typically `root`) | Redfish API basic auth |
| Firewalls (future) | Vendor-specific credential | SSH key, API token, or local account |
| Switches (future) | Vendor-specific credential | SSH key, SNMP community, or local account |

Ranger must accept and manage all of these independently. The user must be able to provide credentials for each target separately, either via parameters, configuration file with Key Vault references, or interactive prompts.

### Credential Configuration Model

The recommended approach is a configuration object or file where each target type has its own credential section:

```yaml
credentials:
  azure:        # service principal, managed identity, or interactive
  cluster:      # domain credential or keyvault:// URI
  idrac:        # BMC credential or keyvault:// URI
  domain:       # domain credential or keyvault:// URI
  firewall:     # vendor credential or keyvault:// URI   (optional)
  switch:       # vendor credential or keyvault:// URI   (optional)
```

Each credential section should independently follow the three-tier resolution: parameter, Key Vault, then interactive prompt.

---

## Selective Domain Execution

Ranger must be compartmentalized. The user must be able to choose which discovery domains to run and which to skip.

### Why This Matters

- Not every environment has accessible iDRAC or BMC endpoints.
- Not every user has credentials for firewalls or switches.
- Not every environment runs the same Azure Local operating model; disconnected, multi-rack, workgroup/local-identity, and hyperconverged deployments must be handled differently.
- Some runs may only need cluster and Azure discovery, not hardware.
- The as-built mode may need everything; a quick operational check may only need a subset.
- Most of the time, operators will not have the rights or network access to scan firewalls and switches. These domains must not block or complicate a standard run.

### Default Behavior

Domains that require credentials the user has not provided should be **skipped by default**, not failed. The principle is:

- **Core domains** (Cluster, Storage, Networking, VMs, Azure Integration) run by default if the required credential is available.
- **Optional domains** (Firewalls, Switches, OEM Hardware) are skipped by default unless the user explicitly provides credentials and/or target information for them.
- **Variant-specific domains** (Disconnected Operations, Multi-Rack, Local Identity with Key Vault deep inspection) should light up only when the topology classification or user input indicates that they are relevant.
- If a domain is included but its credential or target is missing, the collector reports `skipped` in the audit manifest with a clear reason — it does not error or block the run.

This means a user can run Ranger with nothing more than a cluster credential and get useful output. Additional domains light up only when the user opts in by providing the relevant credentials and targets.

### Domain Selection Parameters

Ranger should support domain selection through parameters like:

- **Include list** — run only the specified domains (e.g., `-IncludeDomain Cluster, Hardware, Azure`)
- **Exclude list** — run everything except the specified domains (e.g., `-ExcludeDomain Firewall, Switch`)
- **Default** — if neither is specified, run all domains the user has provided credentials for; skip the rest

Each collector should report its own status in the audit manifest: `success`, `partial`, `failed`, `skipped`, or `not-applicable`. This is already defined in the audit manifest design.

### Discovery Domains

| Domain | Connectivity | Credential Target | v1 Scope | Default |
|--------|-------------|-------------------|----------|---------|
| Deployment Topology and Variant Classification | WinRM + Azure APIs | Cluster and/or Azure | Yes | Run if core credential provided |
| Cluster and Node | WinRM | Cluster | Yes | Run if credential provided |
| Hardware (Dell) | Redfish API | iDRAC | Yes | Skip unless iDRAC targets + credential provided |
| Hardware (Other OEM) | Redfish API | Vendor BMC | Future | Skip |
| Storage | WinRM | Cluster | Yes | Run if credential provided |
| Networking | WinRM | Cluster | Yes | Run if credential provided |
| Virtual Machines | WinRM | Cluster | Yes | Run if credential provided |
| Identity and Security | WinRM + Domain | Domain | Yes | Run if credential provided |
| Local Identity with Key Vault | WinRM + Azure APIs | Cluster + Azure | Yes when variant detected | Skip unless topology indicates it |
| Azure Integration | Az PowerShell | Azure | Yes | Run if credential provided |
| Azure Local VM Management Control Plane | WinRM + Az PowerShell | Cluster + Azure | Yes | Run if credential provided |
| Monitoring and Observability | WinRM + Az PowerShell | Cluster + Azure | Yes | Run if credential provided |
| OEM Management Layer | Redfish API | iDRAC | Yes (Dell only) | Skip unless iDRAC targets + credential provided |
| Management Tools | WinRM | Cluster | Yes | Run if credential provided |
| Performance Baseline | WinRM | Cluster | Yes | Run if credential provided |
| Disconnected Operations | Local control plane + WinRM | Variant-specific | Future / variant-specific | Skip unless detected or explicitly configured |
| Multi-Rack | Azure APIs + variant-specific tooling | Azure / variant-specific | Future / variant-specific | Skip unless detected or explicitly configured |
| Firewalls | SSH / REST / SNMP | Firewall | Future | Skip unless explicitly configured |
| Switches | SSH / REST / SNMP | Switch | Future | Skip unless explicitly configured |

---

## Documentation Requirements

### Public Module Documentation Must Be Exceptionally Clear

Ranger connects to many different targets using different credentials over different protocols. The public documentation for running the module must be extremely clear about:

- what credentials are needed for each target
- how to provide them (parameter, config file, Key Vault, interactive)
- what network access is required from the machine running Ranger
- exactly what each discovery domain collects and from where
- how to select or skip domains
- the recommended execution environment (jump box with access to management + OOB + Azure)
- how deployment variants change prerequisites and outputs (hyperconverged vs disconnected vs local identity with Key Vault vs multi-rack)
- which findings come from host-side validation versus direct device interrogation versus manual input/import
- how Azure Local-specific constraints affect operations (for example HTTPS inspection unsupported, Arc Private Link Scopes unsupported, Windows Admin Center unsupported in local-identity/Key Vault mode)
- how current-state mode differs from as-built mode in terms of output
- what happens when a credential is missing or a target is unreachable (graceful degradation)

This is not optional clarity. The multi-target, multi-credential nature of Ranger makes poor documentation a hard blocker for adoption.

### Documentation Structure

The public docs site should cover:

1. **What Ranger is** — product identity, scope, and relationship to Azure Scout
2. **How to run it** — prerequisites, execution environment, installation, quick start
3. **Authentication guide** — every credential target, every resolution method, Key Vault setup, examples
4. **Discovery domain reference** — one page per domain explaining what is collected, from where, with what credential, and what output to expect
5. **Output reference** — what the current-state report contains vs. what the as-built package contains
6. **Configuration reference** — how to set up a Ranger configuration file with targets, credentials, and domain selection
7. **Topology and deployment-variant guide** — hyperconverged, switchless, rack-aware, disconnected, local identity with Key Vault, and multi-rack considerations
8. **Troubleshooting** — common connectivity and credential issues

### Documentation Workstream

Documentation should not wait until the module is feature-complete. Ranger needs a parallel documentation track so users and contributors can understand the shape of the product before every collector exists.

The recommended documentation sequence is:

1. **Pre-implementation product docs**
  - what Ranger is
  - what problem it solves
  - what discovery domains are planned
  - how Ranger differs from Azure Scout
  - what the expected outputs are
  - what deployment variants and operating models Ranger must handle
2. **Architecture and planning docs**
  - internal collector architecture
  - manifest/output model
  - credential and connectivity model
  - domain boundaries and phased implementation priorities
3. **Early operator docs**
  - prerequisites
  - execution environment guidance
  - authentication and config model
  - supported domain-selection behavior
4. **Collector-by-collector docs**
  - add or deepen reference pages as each domain becomes real and testable
5. **Output docs**
  - report tiers
  - diagram types
  - export formats
  - interpretation guidance for findings and severities

This means yes: some public documentation should be updated before implementation begins in earnest. The early docs should describe the product direction, planned behavior, boundaries, and intended outputs clearly enough that contributors and early users understand what Ranger is being built to do.

### Pre-Implementation Documentation Matrix

The following documentation matrix should drive the first documentation pass before major implementation begins.

| Page | Action | Audience | Purpose | Minimum Content |
|------|--------|----------|---------|-----------------|
| `docs/index.md` | Update | All | Landing page for the project | concise product definition, current maturity, main doc paths, current priorities |
| `docs/what-ranger-is.md` | Update | All | Canonical product definition | product mission, system boundary, current-state vs as-built, deployment-first positioning |
| `docs/ranger-vs-scout.md` | Update | All | Clarify sibling-product boundary | what Scout does, what Ranger does, overlap, how they complement each other |
| `docs/scope-boundary.md` | Update | All | Define what is in and out of scope | direct discovery vs host-side validation vs optional direct device discovery vs manual input |
| `docs/deployment-variants.md` | Create | Operators, Architects, Contributors | Explain Azure Local operating models | hyperconverged, switchless, rack-aware, disconnected, local identity with Key Vault, multi-rack |
| `docs/architecture/system-overview.md` | Update | Architects, Contributors | High-level execution model | discovery flow, manifest-first model, cached output generation, graceful degradation |
| `docs/architecture/how-ranger-works.md` | Create | Operators, Architects | Plain-English runtime model | where Ranger runs, connectivity methods, credentials, domain selection, output flow |
| `docs/architecture/audit-manifest.md` | Update | Architects, Contributors | Define the central data contract | manifest sections, collector status model, topology/identity/control-plane metadata, evidence types |
| `docs/architecture/implementation-architecture.md` | Create | Contributors | Define internal module structure | orchestration layer, shared services, domain collectors, output layer, testing boundaries |
| `docs/architecture/configuration-model.md` | Create | Operators, Contributors | Define future config shape | targets, credentials, include/exclude domains, optional device config, output settings |
| `docs/architecture/repository-design.md` | Update | Contributors | Align repo story to the implementation plan | docs repo + PowerShell module repo, internal modular structure, folder responsibilities |
| `docs/discovery-domains/cluster-and-node.md` | Update | Operators, Architects | Domain reference | what is collected, why it matters, required access, output summary |
| `docs/discovery-domains/hardware.md` | Update | Operators, Architects | Domain reference | Dell-first Redfish path, OEM scope, hardware findings model |
| `docs/discovery-domains/storage.md` | Update | Operators, Architects | Domain reference | S2D/SOFS/replica scope, health and capacity interpretation |
| `docs/discovery-domains/networking.md` | Update | Operators, Architects | Domain reference | host networking, ToR validation model, firewall/proxy posture, SDN/logical networks |
| `docs/discovery-domains/virtual-machines.md` | Update | Operators, Architects | Domain reference | VM inventory, placement, Arc VM overlays, guest signals |
| `docs/discovery-domains/identity-and-security.md` | Update | Operators, Security, Architects | Domain reference | AD vs local identity, Key Vault mode, certificates, WDAC, Defender, syslog, drift control |
| `docs/discovery-domains/azure-integration.md` | Update | Operators, Architects | Domain reference | Arc, resource bridge, custom location, Azure services, monitoring, policy, update, backup |
| `docs/discovery-domains/oem-integration.md` | Update | Operators, Architects | Domain reference | Dell-first vendor integration plan, future OEM boundaries |
| `docs/discovery-domains/management-tools.md` | Update | Operators | Domain reference | WAC, SCVMM, SCOM, tool compatibility, local-identity limitations |
| `docs/discovery-domains/performance-baseline.md` | Update | Operators, Architects | Domain reference | baseline metrics, Azure Monitor metrics, health and anomaly framing |
| `docs/outputs/diagrams.md` | Update | All | Define diagram set and generation policy | baseline diagrams, extended diagrams, selection logic, output format |
| `docs/outputs/reports.md` | Update | All | Define report tiers | audience, content depth, findings model, rendering rules |
| `docs/outputs/as-built-package.md` | Update | All | Define handoff package contents | package structure, required artifacts, expected polish level |
| `docs/project/roadmap.md` | Update | All | Public phased roadmap | documentation phase, architecture phase, collector phases, output phases, advanced domains |
| `docs/project/documentation-roadmap.md` | Create | Contributors | Track documentation-first work | pre-build pages, update order, doc maturity states, ownership |
| `docs/project/repository-structure.md` | Update | Contributors | Explain file/folder layout | docs groups, module groups, repo-management role |
| `docs/contributor/getting-started.md` | Update | Contributors | Set contributor expectations | what to read first, what work is wanted now, what not to build yet |
| `docs/contributor/contributing.md` | Update | Contributors | Define contribution standards | planning-first workflow, documentation-before-code expectations, review boundaries |

The first documentation pass should prioritize the pages that define the product, the system boundary, the execution model, the audit manifest, and the public roadmap. Discovery-domain detail pages should then be deepened in place rather than recreated elsewhere.

### Documentation Implementation Order

The documentation matrix above defines **what** pages are needed. The following ordered plan defines **when** to create or update them and **why** that order matters.

#### Phase 1: Product Truth

This phase establishes the public definition of the product before architecture or implementation details start drifting.

1. **Update `docs/index.md`**
  - Make the home page the authoritative landing page.
  - Add a concise statement of product purpose, current project phase, and where different audiences should go next.
  - This page should quickly route readers to product, architecture, output, and contributor documentation.
2. **Update `docs/what-ranger-is.md`**
  - Lock the canonical product definition.
  - Include the deployment-first posture, Azure-connected boundary, current-state vs as-built usage, and workload-family awareness.
  - This page should answer "what is Ranger?" without requiring other pages.
3. **Update `docs/ranger-vs-scout.md`**
  - Remove ambiguity between Ranger and Scout.
  - Clarify tenant-wide Azure discovery vs Azure Local deployment discovery.
  - This page prevents scope confusion before contributors start writing design or code.
4. **Update `docs/scope-boundary.md`**
  - Define the operational boundary in precise terms.
  - Separate direct discovery, host-side validation, optional direct third-party device discovery, and manual/imported evidence.
  - This page becomes the guardrail for future implementation decisions.
5. **Create `docs/deployment-variants.md`**
  - Explain the supported and planned Azure Local operating models: hyperconverged, switchless, rack-aware, local identity with Key Vault, disconnected operations, and multi-rack.
  - Call out why these variants materially change discovery and documentation behavior.
  - This page ensures the rest of the docs do not silently assume one cluster shape.

#### Phase 2: Architecture Truth

This phase translates the product definition into the runtime and implementation model.

6. **Update `docs/architecture/system-overview.md`**
  - Expand it into the main architecture summary.
  - Document discovery flow, normalization, manifest assembly, collector status handling, and cached output generation.
  - Keep it high-level and readable.
7. **Create `docs/architecture/how-ranger-works.md`**
  - Write the plain-English runtime explanation.
  - Cover execution environment, connectivity methods, credential model, selective domain execution, and output generation from cached data.
  - This page is for operators and architects, not only contributors.
8. **Update `docs/architecture/audit-manifest.md`**
  - Define the central schema boundary.
  - Include manifest sections, collector status values, topology/identity/control-plane metadata, and distinction between live evidence, derived findings, and imported/manual evidence.
  - This page must stabilize before meaningful implementation begins.
9. **Create `docs/architecture/implementation-architecture.md`**
  - Define the internal module plan in contributor language.
  - Cover orchestration layer, shared services, domain collectors, output layer, testing boundaries, and why live discovery must stay decoupled from output generation.
10. **Create `docs/architecture/configuration-model.md`**
  - Define the intended config shape before code hardens it prematurely.
  - Cover targets, credentials, include/exclude domains, optional switch/firewall targets, output settings, and variant-specific configuration.
11. **Update `docs/architecture/repository-design.md`**
  - Align repository story to the implementation architecture.
  - Explain how the docs tree, PowerShell module tree, repo-management docs, and output assets fit together.

#### Phase 3: Project And Contributor Execution

This phase makes the plan actionable for people contributing to the repo.

12. **Update `docs/project/roadmap.md`**
  - Turn theme-level roadmap text into explicit phases.
  - Include documentation-first work, architecture/schema work, collector phases, output phases, and advanced/future domains.
  - Show both sequencing and priorities.
13. **Create `docs/project/documentation-roadmap.md`**
  - Track the documentation workstream as its own deliverable.
  - Include page maturity states, create/update order, ownership expectations, and when each page should deepen alongside implementation.
14. **Update `docs/project/repository-structure.md`**
  - Reflect the intended long-term structure rather than only the current file tree.
  - Show where product docs, architecture docs, discovery-domain docs, module code, outputs, and contributor material belong.
15. **Update `docs/contributor/getting-started.md`**
  - Tell contributors what to read first and what kinds of work are currently wanted.
  - Emphasize that product definition and documentation stability come before bulk implementation.
16. **Update `docs/contributor/contributing.md`**
  - Define planning-first contribution expectations.
  - Cover documentation-before-code expectations where relevant, review boundaries, and the need to avoid placeholder implementation.

#### Phase 4: Discovery Domain Reference Pass

Once the product and architecture truth are stable, deepen the domain reference pages in place. These pages should explain what each domain collects, why it matters, what access it needs, and what outputs/findings it should influence.

17. **Update `docs/discovery-domains/cluster-and-node.md`**
  - Cluster identity, node state, update posture, variant/topology context.
18. **Update `docs/discovery-domains/hardware.md`**
  - Dell-first Redfish strategy, hardware posture, BMC scope, OEM boundaries.
19. **Update `docs/discovery-domains/storage.md`**
  - S2D, virtual disks, CSVs, storage health, storage replica, continuity implications.
20. **Update `docs/discovery-domains/networking.md`**
  - Host networking, ToR validation model, firewall/proxy posture, SDN/logical networks, endpoint dependencies.
21. **Update `docs/discovery-domains/virtual-machines.md`**
  - VM inventory, placement, Arc VM overlays, workload-family context, guest signals.
22. **Update `docs/discovery-domains/identity-and-security.md`**
  - AD vs local identity, Key Vault mode, certificates, WDAC, Defender, syslog, drift control.
23. **Update `docs/discovery-domains/azure-integration.md`**
  - Arc, resource bridge, custom location, Azure services, monitoring, policy, update, backup, recovery, disconnected/multi-rack ties.
24. **Update `docs/discovery-domains/oem-integration.md`**
  - Dell-first vendor plan, OEM tooling posture, compliance and firmware visibility, future vendor model.
25. **Update `docs/discovery-domains/management-tools.md`**
  - WAC, SCVMM, SCOM, OEM tools, Azure portal/CLI paths, tool compatibility limitations.
26. **Update `docs/discovery-domains/performance-baseline.md`**
  - Baseline metrics, Health Service relationships, Azure Monitor metrics and workbook posture, anomaly interpretation.

#### Phase 5: Output Reference Pass

Once the manifest and domain pages are stable enough, define the output model fully.

27. **Update `docs/outputs/diagrams.md`**
  - Document baseline vs extended diagrams, selection rules, audience subsets, and output/rendering expectations.
28. **Update `docs/outputs/reports.md`**
  - Document report tiers, expected depth, finding severities, and rendering principles.
29. **Update `docs/outputs/as-built-package.md`**
  - Define the complete handoff package: what is always included, what is conditional, and what level of polish is expected.

#### Phase 6: Navigation And Publishing Alignment

After the page set is confirmed, align the site navigation and supporting project docs.

30. **Update `mkdocs.yml` navigation**
  - Add the new pages in the correct information architecture.
  - Avoid doing this too early; nav churn should follow page confirmation, not precede it.
31. **Validate cross-links and reading flow**
  - Ensure that product pages lead naturally to architecture pages, then to domain pages, then to outputs and contributor docs.
32. **Review landing-page summaries and section intros**
  - Make sure each docs section has a clear purpose and does not duplicate another section.

### Documentation Delivery Rules

The following rules should govern the documentation workstream:

- Product-definition pages must stabilize before architecture pages are treated as final.
- Architecture pages must stabilize before domain pages are deepened heavily.
- Domain pages should deepen in place; avoid spawning duplicate planning pages for the same topic.
- Output docs should describe what the product is intended to produce, but should not fake implementation details that do not yet exist.
- Contributor docs must match the actual phase of the repository; they should not imply the project is farther along than it is.
- Navigation updates should follow page creation, not lead it.

### Documentation Done Criteria

The pre-implementation documentation pass should be considered complete only when:

- the product story is stable and unambiguous
- deployment variants are explicitly documented
- the runtime and manifest model are documented clearly enough to guide implementation
- contributors have a clear reading path and contribution boundary
- every existing nav page either has meaningful content or has been consciously deferred/reworked
- the docs site explains both what Ranger will do and how it is planned to be built

---

## Diagram Generation

All diagrams generated as draw.io-compatible XML (.drawio) using mxGraph format. Output location: `docs/assets/diagrams/`. Optional PNG export alongside XML for embedding in MkDocs pages.

**Color Coding Legend (consistent across all diagrams):**
- Blue: Compute / Hyper-V
- Green: Storage / S2D
- Orange: Networking
- Purple: Azure / Arc
- Gray: Physical Hardware
- Red: Health Warnings / Issues
- Teal: Workloads & Services

**Every diagram includes:** title, cluster name, generation timestamp, tool version watermark.

### Diagram Strategy

Ranger should not assume that six diagrams are enough for every environment. The right model is a **diagram suite** with:

- a **baseline set** generated for most runs
- an **extended set** generated when the environment is complex enough to justify it
- an **executive subset** for summary reporting
- a **technical subset** for deep-dive and as-built handoff outputs

Not every run needs every diagram, but the product must be designed to support a larger diagram catalog than the initial baseline.

### Diagram Selection Rules

- Small/simple environments can generate only the baseline set.
- Complex environments should generate the baseline set plus extended diagrams based on detected features.
- Variant-specific environments should light up matching diagrams, for example disconnected operations, local identity with Key Vault, or multi-rack.
- If a required data source is missing, the diagram should be skipped with a clear reason rather than producing misleading content.

### Baseline Diagram Set

The following diagrams should be treated as the baseline diagram set for current-state and as-built output.

### Diagram 1: Physical Architecture

Nodes as boxes with hardware summary (CPU cores, RAM, disk count/capacity, NIC count). Physical NIC layout per node showing port speeds. TOR switch connections (from LLDP or manual input). BMC/out-of-band management network. Rack or site fault domain grouping. Server model and serial for identification.

### Diagram 2: Logical Network Topology

Network ATC intents visualized (Management, Compute, Storage) with adapter assignments. VLANs and subnets mapped. Virtual switches with SET team members. Storage networks with RDMA protocol annotations. Management and compute network separation. SDN components if deployed (Network Controller, SLB MUX, RAS Gateway). Logical networks from Arc. Proxy path if configured.

### Diagram 3: Storage Architecture

Storage pool layout with fault domain boundaries. Cache tier devices ↔ capacity tier devices relationships. Virtual disk / volume → CSV → node ownership mapping. Resiliency type annotations per volume (two-way mirror, three-way mirror, MAP, etc.). SOFS shares and access paths. Capacity utilization heat indicators (green/yellow/red by percent used). Storage Replica partnerships if configured.

### Diagram 4: VM Placement Map

VMs grouped by current host node. Resource sizing per VM (vCPU, memory, storage footprint). Network connectivity per VM (which switch, which VLAN). Anti-affinity group visualization. Per-node resource utilization bars (CPU, memory, storage). Overcommit ratio notation per node. Guest clusters highlighted.

### Diagram 5: Azure Arc Integration

Azure subscription → resource group → Arc cluster resource hierarchy. Arc Resource Bridge and Custom Location relationship. Extensions tree per node. Connected Azure services (AKS, AVD, Arc VMs, Data Services). Monitoring data flow arrows (AMA → DCR → Log Analytics / Metrics). Management data flow (Update Manager, Policy, Backup, ASR). Identity flow (managed identity, RBAC).

### Diagram 6: Workload & Services Map

All Azure services running on the cluster (AKS clusters, AVD host pools, Arc VMs). Monitoring stack (Azure Monitor, HCI Insights, Log Analytics, SCOM). Backup and DR (Azure Backup, ASR, third-party). OEM management integrations (OpenManage, XClarity, etc.). WAC / SCVMM / SCOM connections. Third-party tool connections.

### Extended Diagram Set

The following diagrams should be added to the catalog for larger, more complex, or more formal as-built documentation packages.

### Diagram 7: Topology & Deployment Variant Map

Show the Azure Local operating model clearly: hyperconverged, switchless, rack-aware, local identity with Key Vault, disconnected operations, or multi-rack. Include site boundaries, rack boundaries, preview-specific multi-rack topology relationships where relevant, switchless/full-mesh indicators, and whether the control plane is connected or disconnected.

### Diagram 8: Identity, Trust & Secret Flow

Show trust and credential relationships: Active Directory, Entra, managed identity, service principal if used, Key Vault, certificate-backed communication, RecoveryAdmin / backup secret paths, and RBAC scope relationships. This is especially important for local identity with Key Vault and hybrid control-plane scenarios.

### Diagram 9: Monitoring, Telemetry & Alerting Flow

Show how data leaves the environment and where it lands: AzureEdgeTelemetryAndDiagnostics, AMA, DCRs, DCEs, Log Analytics, Metrics, Workbooks, Alerts, Action Groups, syslog/SIEM forwarding, and any third-party monitoring tools detected.

### Diagram 10: Connectivity, Firewall & Dependency Map

Show the management workstation or jump box, WinRM paths, Redfish paths, Azure egress paths, proxy path, OEM endpoint dependencies, required outbound endpoint groups, and major internal ports/protocol flows. This should also flag whether traffic traverses one or more firewalls and whether HTTPS inspection or unsupported Arc network patterns are present.

### Diagram 11: Identity and Access Surface Map

Show cluster identities, CNO/VCOs, Arc resource identities, custom location, resource bridge, Azure RBAC scopes, domain/OU placement, and any local identity operating mode. This is complementary to the trust/secret flow diagram but focuses on control and access boundaries.

### Diagram 12: Monitoring & Health Heatmap

Provide a visual health summary by domain or node: compute, storage, networking, identity/security, Azure integration, OEM layer, monitoring, and management tools. This is useful for executive and management outputs where a full architecture diagram is too dense.

### Diagram 13: OEM Hardware & Firmware Posture

Show per-node firmware/BIOS/BMC summary, OEM tool integration status, firmware compliance posture, and component health at a glance. This is particularly valuable in hardware handoff and support scenarios.

### Diagram 14: Backup, Recovery & Continuity Map

Show Azure Backup, ASR, Storage Replica, Hyper-V Replica, backup agents, recovery vaults, replication directions, and major protected/unprotected workload groups. This gives a fast continuity view that would otherwise be buried in tables.

### Diagram 15: Management Plane & Tooling Map

Show WAC, SCVMM, SCOM, OEM tools, Azure portal, Azure CLI, automation entry points, and any unsupported or limited management paths for the current variant. This helps explain how the environment is actually managed, not just how it is deployed.

### Diagram 16: Workload Family Placement Map

Show major workload families by host, rack, site, or cluster boundary: core VMs, AVD, AKS, Arc VMs, Arc Data Services, IoT Operations, Microsoft 365 Local indicators, and major guest clusters. This is different from VM placement because it operates at the workload-family layer.

### Diagram 17: Multi-Rack or Rack-Aware Fabric Map

For rack-aware or multi-rack environments, show rack aggregation, SAN/shared storage boundaries where applicable, managed networking spans, ExpressRoute/upstream connectivity, rack-local workloads, and failure-domain segmentation.

### Diagram 18: Disconnected Operations Control Plane Map

For disconnected environments, show the local control plane, management cluster, appliance, local policy/RBAC/Key Vault/registry surfaces, and how workloads and management operations stay inside the boundary.

### Executive Diagram Subset

The executive output should generally prefer a small subset such as:

- Physical Architecture
- Azure Arc Integration
- Monitoring & Health Heatmap
- Backup, Recovery & Continuity Map

### Technical As-Built Diagram Subset

The technical as-built package should be able to include most or all baseline diagrams plus any extended diagrams triggered by discovered features.

---

## Report Generation

Three report tiers generated from the same cached audit JSON. Output as self-contained HTML (inline CSS, embedded logo, no external dependencies) and Markdown. Report generators consume JSON only — they never connect to the cluster.

**Report Standards (all tiers):**
- Version watermark on every page (tool version, generation timestamp, cluster name)
- Consistent branding (logo, color scheme)
- Findings classified: Critical (immediate action required), Warning (should address), Informational (awareness), Good (compliant/healthy)
- Each finding includes: title, description, affected component(s), current state, recommendation, reference link to Microsoft documentation where applicable
- Table of contents / navigation for longer reports

### Report Tier 1: Executive Summary

**Audience:** CIO, VP, C-level stakeholders
**Length:** 2-3 pages
**Tone:** Business language, minimal jargon, visual-heavy

Content: cluster identity/purpose, node count, total compute capacity (cores, RAM), total usable storage capacity, overall health status (green/yellow/red traffic light), Azure integration status (traffic light), key risk areas (top 5 critical/warning findings — one sentence each with business impact), workload summary (VM count, AKS clusters, AVD pools — one line each), licensing/billing summary, cost optimization opportunities, update compliance status (current/behind), 3-5 strategic recommendations.

Visual elements: health gauges, capacity utilization donuts/bars, traffic light indicators, summary tables.

### Report Tier 2: Management Summary

**Audience:** IT Directors, IT Managers, Team Leads
**Length:** 8-12 pages
**Tone:** Technical but accessible, table-driven

Content: everything in Executive, plus: VM density metrics (VMs per node, vCPU:pCPU ratio, memory overcommit ratio), storage utilization detail (per-volume capacity, growth trend indicators, days until capacity threshold), network architecture overview (VLAN summary, RDMA status, SDN status), backup and DR coverage assessment (what's protected, what's not, RPO/RTO summary), update compliance detail (per-node patch status, pending updates), security posture summary (Secured-core, BitLocker, WDAC, Defender status per node, certificate expirations within 90 days), monitoring coverage assessment (what's monitored, what's missing), OEM integration status and firmware compliance, management tool coverage (WAC, SCVMM, SCOM — connected/stale/missing), top 10 recommendations prioritized by business impact and effort.

### Report Tier 3: Technical Deep Dive

**Audience:** Infrastructure Architects, Systems Engineers, Azure Local specialists
**Length:** 30-80+ pages depending on environment complexity
**Tone:** Dense, data-complete, annotated

Content: every data point from every collector, organized into chapters matching the collector structure. Full hardware inventory tables (per-node, per-component with serial numbers, firmware versions). Complete VM inventory with all properties in sortable tables. Network configuration detail (every vSwitch property, every vNIC, every ATC intent with overrides, every SDN component, every NSG rule, every logical network). Storage pool math (raw capacity → usable capacity showing resiliency overhead, cache allocation, per-volume breakdown). Full security audit (every certificate with expiration countdown, every policy setting, every baseline deviation, every local admin member). Azure integration deep dive (every extension version, every policy assignment, every DCR, every alert rule). OEM integration details (firmware versions vs catalog, management tool health). Performance baseline data with per-node breakdowns and anomaly callouts. Event log analysis with top recurring errors and correlation. Complete findings and recommendations with severity ratings (Critical/Warning/Informational/Good). Raw data appendix or link to exported JSON.

---

## Planning Implications

### Manifest Design

The audit manifest must support both recurring operational reporting and formal as-built outputs. It must also track per-domain collector status so partial runs are clearly represented.

The manifest must also capture:

- deployment topology and operating variant
- identity model (AD-backed vs local identity with Key Vault)
- control-plane mode (connected vs disconnected)
- host-side validation findings versus direct device discovery findings versus manual/imported evidence
- Azure Local platform components that underpin workload management, monitoring, and policy

### Diagram Design

See the **Diagram Generation** section above for the baseline and extended diagram catalog, color coding legend, selection rules, and output format. Diagrams should be designed for both technical analysis and handoff-quality documentation.

### Reporting Design

See the **Report Generation** section above for the full three-tier specification (Executive Summary, Management Summary, Technical Deep Dive). Reports should support both audience-tiered operational reporting and a polished as-built package. The difference between modes should be output formatting and depth, not a different discovery pipeline.

### Collector Design

Each collector must be:

- independently executable (can run alone or be skipped)
- independently credentialed (takes its own credential, does not assume another domain's credential)
- independently reportable (reports its own status to the manifest)
- read-only (never modifies the target)
- gracefully degrading (partial results are better than no results; inaccessible targets do not crash the run)
- topology-aware (behavior and validation must adjust based on hyperconverged, disconnected, local-identity, or multi-rack deployment mode)
- able to distinguish host-side compliance validation from direct third-party device interrogation

### Internal Module Architecture

Ranger should be delivered as one public PowerShell module, but built internally as a set of small, testable components rather than one large script.

The preferred internal architecture is:

1. **Orchestration layer**
  - public entry points that parse parameters
  - configuration loading and validation
  - credential resolution
  - domain selection
  - collector execution order
  - manifest assembly and persistence
2. **Shared platform services**
  - logging
  - status/result modeling
  - WinRM session handling
  - Redfish client helpers
  - Azure context/session helpers
  - retry/timeouts/error normalization
  - schema normalization and object shaping
3. **Domain collectors**
  - topology collector
  - cluster/node collector
  - hardware collector
  - storage collector
  - networking collector
  - virtual machine collector
  - identity/security collector
  - Azure integration collector
  - monitoring/observability collector
  - OEM management collector
  - management tools collector
  - performance collector
4. **Output layer**
  - JSON manifest export
  - report generators
  - diagram generators
  - markdown/html export helpers

The output layer must consume the cached manifest only. It must not perform live discovery itself.

### Testing Strategy Implications

This modular design exists primarily to make development, testing, and troubleshooting practical.

- each collector should be executable in isolation
- each collector should be unit-testable with mocked inputs
- orchestration should be integration-tested across multiple collectors
- report and diagram generators should be tested from saved manifests, not live environments
- schema validation should be treated as its own test boundary
- failed or skipped collectors must not invalidate successful collectors from the same run

### Repository Design

The repository is structured as both:

- a public MkDocs documentation site intended for GitHub Pages publication
- a future PowerShell module repository intended for PSGallery publication

Public docs stay concept-driven. The implementation tree stays module-oriented under `Modules/`.

### Prioritization

Implementation sequencing should prioritize the discovery domains most essential for accurate as-built documentation:

1. Deployment Topology and Cluster/Node Classification
2. Hardware (Dell / Redfish)
3. Networking and Endpoint / Firewall Posture
4. Storage
5. Azure Integration and Azure Local VM Management Control Plane
6. Monitoring and Observability
7. Identity and Security, including local identity with Key Vault

OEM multi-vendor support, direct firewall interrogation, direct switch interrogation, disconnected-operations deep inspection, and multi-rack-specific collectors are explicitly future-release items, but their data model must be planned now.

### Delivery Sequence

The preferred build sequence is:

1. establish the shared services and manifest schema first
2. implement topology classification and core orchestration
3. add one collector domain at a time
4. validate each collector independently before wiring it into broader runs
5. start report and diagram generation only after the manifest shape is stable
6. deepen collector-specific documentation as each domain becomes real

This keeps Ranger testable from the start and avoids locking the team into a brittle monolithic implementation.

---

## Existing Patterns To Reuse

The AzureLocal organization already has proven implementations that Ranger should adopt rather than reinvent:

| Pattern | Source | What To Reuse |
|---------|--------|---------------|
| Credential resolution (3-tier) | `azurelocal-toolkit/scripts/common/utilities/helpers/keyvault-helper.ps1` | `ConvertFrom-KeyVaultUri`, `Get-SecretFromUri`, `Resolve-KeyVaultSecrets` |
| `keyvault://` URI format | `azurelocal-toolkit/config/variables/` | URI schema and resolution logic |
| Dell Redfish discovery | `azurelocal-toolkit/scripts/common/discovery/Get-DellServerInventory-FromiDRAC.ps1` | Endpoint coverage, cert handling, JSON output model |
| iDRAC credential config | `azurelocal-toolkit/config/variables/variables.example.yml` | Config structure with Key Vault references |
| Service principal auth | `azurelocal.github.io` auth setup appendix | `Connect-AzAccount -ServicePrincipal` pattern |
| Scripting standards | `azurelocal-avd/docs/standards/scripting.md` | Parameter naming, credential resolution order |

---

## Dependencies

### Required PowerShell Modules (for collection)

- FailoverClusters
- Hyper-V
- Storage
- NetAdapter
- NetTCPIP
- DnsClient
- Az.StackHCI or Az.ConnectedMachine
- NetworkATC (if available on target)

### Optional Modules

- Az.Accounts, Az.Resources, Az.Monitor (for deep Azure-side data)
- SDDC Diagnostics (for health data)

### No External Dependencies For

- Diagram generation (pure XML string construction)
- Report generation (inline HTML/CSS string templating)
- Core module operation

### Documentation

- MkDocs + mkdocs-material theme

---

## Public Story

The public-facing roadmap should communicate that Ranger is being built for both ongoing documentation and as-built handoff documentation.

That requirement is part of the product identity, not a future enhancement idea.

The public docs should also make clear:

- Ranger is a multi-target discovery tool that connects to cluster nodes, OEM hardware, Azure, and supporting infrastructure
- Ranger is deployment-variant aware and must handle hyperconverged, switchless, rack-aware, disconnected, local-identity, and multi-rack environments differently
- authentication and credential management are first-class design concerns, not afterthoughts
- discovery domains are modular and independently selectable
- Azure Local control-plane components such as Arc Resource Bridge, custom locations, monitoring extensions, and workload-management resources are part of the environment definition and must be documented
- the recommended execution environment is a management workstation or jump box with broad network access
- Dell is the primary OEM target for v1; other vendors are planned but require hardware access to develop against
- firewalls and switches are hybrid discovery targets: host-side validation is essential, direct device interrogation is optional and skipped by default unless the user explicitly provides credentials and configuration for them
- workload family detection matters even before deep workload-specific collectors exist; Ranger must at least identify major workload planes such as AKS, AVD, Arc VMs, Arc Data Services, IoT Operations, and Microsoft 365 Local when present