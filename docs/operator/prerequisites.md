# Operator Prerequisites

This page explains how to install AzureLocalRanger from source today, where it should run, what it needs to reach, and what must be in place before starting a run. For the canonical prerequisite checklist, see [Prerequisites](../prerequisites.md).

## Operator Journey

![Operator Journey](../assets/diagrams/ranger-operator-journey.svg)

## Quick-start Checklist

Complete these steps once before your first run:

- [ ] PowerShell 7.x installed on the execution machine
- [ ] `Import-Module` from a local clone (or install from PSGallery once publication is complete)
- [ ] `Test-AzureLocalRangerPrerequisites -InstallPrerequisites` passes all checks
- [ ] WinRM TrustedHosts configured to include cluster node IPs and cluster VIP
- [ ] Azure context established (`Connect-AzAccount`) or service-principal provided in config
- [ ] Config file generated and required fields filled in

See the sections below for details on each step.

---

## Installation

### From PSGallery (after publication)

```powershell
Install-Module AzureLocalRanger -Scope CurrentUser
```

### From source (current path)

```powershell
git clone https://github.com/AzureLocal/azurelocal-ranger.git
cd azurelocal-ranger
Import-Module ./AzureLocalRanger.psd1 -Force
```

### Validate prerequisites after install

The `-InstallPrerequisites` switch automatically installs RSAT ActiveDirectory and the required Az PowerShell modules when they are missing. An elevated (Administrator) session is required.

```powershell
# Check without installing
Test-AzureLocalRangerPrerequisites

# Check and auto-install missing components (elevated session required)
Test-AzureLocalRangerPrerequisites -InstallPrerequisites
```

The command outputs a table showing which checks passed and which need attention.

### Generate a config file

```powershell
New-AzureLocalRangerConfig -Path C:\ranger\ranger.yml
```

Open the file and fill in every field marked `[REQUIRED]`. See [Configuration](configuration.md) for a complete field reference.

---

## Recommended Execution Environment

Run Ranger from a management workstation or jump box that can reach the required targets.

The recommended machine should have network access to:

- the Azure Local management network
- the out-of-band or BMC network when hardware discovery is required
- Azure endpoints used for Arc, monitoring, policy, backup, and related services

Running directly on a cluster node is not the preferred operating model.

## Software Prerequisites

The planned runtime assumes:

- PowerShell 7.x
- the Az PowerShell modules needed for Azure discovery
- RSAT ActiveDirectory PowerShell module (`Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0` on Windows client / multi-session; `RSAT-AD-PowerShell` on Windows Server)
- Azure CLI when CLI-only or fallback workflows are needed
- network access to WinRM, HTTPS Redfish endpoints, and Azure public or approved private endpoints as required by the selected domains

Optional tools may be required for specific workflows later, but v1 planning assumes PowerShell plus Azure authentication tooling.

## WinRM Client Configuration

Ranger uses WinRM (PowerShell remoting) to run commands on cluster nodes. The execution machine must have the WinRM service running and **both the node IPs and the cluster VIP** added to the WinRM TrustedHosts list before `Test-WSMan` or `Invoke-Command` will succeed. The cluster VIP is required because Ranger may target the cluster name (which resolves to the VIP) in addition to individual nodes.

This is required when the execution machine is **not** domain-joined to the same domain as the cluster nodes (for example, an AVD session host or a local workstation authenticating with explicit credentials).

Run the following once from an **elevated** PowerShell session on the execution machine:

```powershell
# Start WinRM if not already running
Start-Service WinRM
Set-Service WinRM -StartupType Automatic

# Add cluster node IPs and cluster VIP to TrustedHosts (adjust IPs for the target environment)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.211.11,192.168.211.12,192.168.211.13,192.168.211.14,192.168.211.20" -Force
```

To append to existing entries rather than overwriting:

```powershell
$existing = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
$new = if ($existing) { "$existing,192.168.211.11,192.168.211.12,192.168.211.13,192.168.211.14,192.168.211.20" } else { "192.168.211.11,192.168.211.12,192.168.211.13,192.168.211.14,192.168.211.20" }
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $new -Force
```

> **Note**: TrustedHosts bypasses Kerberos mutual authentication. Only add hosts you trust. Using IP addresses instead of hostnames limits the exposure to the known network range.

The `-InstallPrerequisites` switch on `Test-AzureLocalRangerPrerequisites` does not configure WinRM or TrustedHosts — this must be done manually in an elevated session before running Ranger.

## Minimum Inputs

A useful Ranger run typically starts with:

- a target Azure Local cluster name or node list
- a cluster credential for WinRM
- Azure access for Azure-side discovery when Azure integration is in scope

Hardware discovery adds:

- BMC target list
- BMC or iDRAC credential

## Network Reachability

Different domains need different network paths.

| Path | Used for |
|---|---|
| WinRM to cluster nodes | Cluster, storage, networking, VM, identity/security, management tools, performance |
| HTTPS to BMC/Redfish endpoints | OEM hardware and management-layer discovery |
| HTTPS to Azure endpoints | Azure integration, monitoring, update, policy, backup, and Arc-related discovery |
| Optional vendor API or SSH reachability | Future direct switch or firewall interrogation |

If a domain’s network path is unavailable, that domain should be skipped or marked partial instead of blocking the entire run.

## Variant-Specific Prerequisites

### Hyperconverged

This is the baseline shape. Standard management-network, Azure, and optional BMC reachability applies.

### Switchless Storage Fabric

Storage-network switch interrogation is not relevant. Host-side networking evidence becomes more important than direct switch evidence.

### Rack-Aware

Ranger should expect rack assignments and availability-zone-style placement behavior. Operators may need to provide manual evidence if rack metadata is not discoverable from the host side.

### Local Identity with Azure Key Vault

Current Microsoft documentation describes these extra prerequisites:

- the cluster runs without Active Directory
- a consistent local administrator account exists across nodes
- static IP addressing is required
- DNS zones and host records must already be configured
- Azure Key Vault is used for backup secrets
- SSH access to Arc-enabled servers may be needed for some remote Azure-portal workflows

Windows Admin Center is not supported in this mode, and SCVMM support is limited or unsupported.

### Disconnected Operations

Disconnected environments need extra planning because the local control plane consumes additional capacity and connectivity assumptions differ from connected Azure Local.

Current Microsoft documentation indicates that disconnected operations require:

- approved disconnected-operations eligibility
- extra capacity for the local control plane
- a dedicated management cluster in the current documented disconnected model
- careful planning for PKI, identity, and local monitoring paths

### Multi-Rack Preview

Current Microsoft documentation describes multi-rack as a preview architecture with:

- one main rack for network aggregation and SAN storage
- several compute racks
- managed networking exposed through Azure APIs and ARM
- Azure ExpressRoute in the documented preview architecture

This is not a standard hyperconverged deployment and should be treated as variant-specific.

## Before You Run Ranger

Before a meaningful run, verify:

1. you are on the right workstation or jump box
2. the WinRM service is running on the execution machine and cluster node IPs are in TrustedHosts (see [WinRM Client Configuration](#winrm-client-configuration) above)
3. cluster WinRM access works (`Test-WSMan -ComputerName <node-ip> -Credential <domain-cred> -Authentication Negotiate`)
4. Azure authentication works for the intended subscription and resource group
5. BMC endpoints are reachable if hardware discovery is included
6. DNS, proxy, and firewall posture allow the selected domains to communicate
7. you understand which domains are expected to run and which should be skipped

## Next Reads

- [Operator Authentication](authentication.md)
- [Operator Configuration](configuration.md)
- [Operator Troubleshooting](troubleshooting.md)
- [How Ranger Works](../architecture/how-ranger-works.md)
