<#
.SYNOPSIS
    Generates a synthetic Ranger manifest fixture using IIC (Infinite Improbability Corp)
    fictional company data for simulation testing.

.DESCRIPTION
    Modeled on the Azure Scout New-SyntheticSampleReport.ps1 pattern.
    Produces tests/maproom/Fixtures/synthetic-manifest.json without any live connections,
    Az module, or WinRM sessions.

    All company data follows the mandatory IIC canonical standard defined in:
    https://azurelocal.github.io/standards/examples

.EXAMPLE
    .\tests\maproom\scripts\New-RangerSyntheticManifest.ps1

.NOTES
    Output: tests/maproom/Fixtures/synthetic-manifest.json
    Schema: 1.1.0-draft / mode: as-built
#>
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\Fixtures\synthetic-manifest.json')
)

Set-StrictMode -Version Latest

# =============================================================================
# IIC REFERENCE DATA POOLS
# All data follows the mandatory IIC (Infinite Improbability Corp) standard.
# Domain: iic.local  |  NetBIOS: IMPROBABLE  |  Public: improbability.cloud
# =============================================================================

$iic = @{
    Company         = 'Infinite Improbability Corp'
    Abbreviation    = 'IIC'
    Domain          = 'iic.local'
    NetBIOS         = 'IMPROBABLE'
    PublicDomain    = 'improbability.cloud'
    EntraTenant     = 'improbability.onmicrosoft.com'

    # Cluster
    ClusterName     = 'azlocal-iic-01'
    NodeNames       = @('azl-iic-n01', 'azl-iic-n02', 'azl-iic-n03')
    NodeFqdns       = @('azl-iic-n01.iic.local', 'azl-iic-n02.iic.local', 'azl-iic-n03.iic.local')
    NodeIPs         = @('10.0.0.11', '10.0.0.12', '10.0.0.13')
    IdracIPs        = @('10.245.64.11', '10.245.64.12', '10.245.64.13')
    ServiceTags     = @('ABC1234', 'ABC1235', 'ABC1236')
    HardwareModel   = 'PowerEdge R760'
    HardwareMfr    = 'Dell Inc.'
    FirmwareVersion = '2.10.0.0'

    # Azure Platform
    TenantId        = '00000000-0000-0000-0000-000000000000'
    SubscriptionId  = '33333333-3333-3333-3333-333333333333'
    ResourceGroup   = 'rg-iic-compute-01'
    ArcRG           = 'rg-iic-arc-01'
    MonitorRG       = 'rg-iic-monitor-01'
    SecurityRG      = 'rg-iic-security-01'
    KeyVault        = 'kv-iic-platform'
    LogAnalytics    = 'law-iic-monitor-01'
    DCR             = 'dcr-iic-azl-01'
    DCE             = 'dce-iic-azl-01'
    ArcGateway      = 'arcgw-iic-01'
    CustomLocation  = 'cl-iic-azlocal-01'
    ResourceBridge  = 'rb-iic-azlocal-01'

    # VLANs
    VlanMgmt        = 2203
    VlanMgmtCidr    = '10.0.0.0/24'
    VlanStorage     = 2204
    VlanStorageCidr = '10.0.1.0/24'
    VlanWorkload    = 2205
    VlanWorkloadCidr = '10.0.2.0/24'
    DnsServers      = @('192.168.10.10', '192.168.10.11')
    Gateway         = '10.0.0.1'

    # CSV / Storage
    StoragePoolName = 'S2D on azlocal-iic-01'
    CsvNames        = @('csv-iic-azlocal-01-vmstore-01', 'csv-iic-azlocal-01-vmstore-02', 'csv-iic-azlocal-01-vmstore-03')

    # VMs
    AvdVmNames      = @('avd-iic-sh01', 'avd-iic-sh02', 'avd-iic-sh03')
    ArcVmNames      = @('arc-iic-vm01', 'arc-iic-vm02')

    # Accounts
    LcmAccount      = 'lcm-iic-azl-clus01'
    DomainJoin      = 'IMPROBABLE\svc.iic.deploy'
    LocalAdmin      = 'Administrator'
    OuPath          = 'OU=Clusters,OU=Servers,DC=iic,DC=local'
}

# =============================================================================
# HELPER — build a cert that expires in 60 days (triggers warning finding)
# =============================================================================
$certExpiry60Days  = (Get-Date).AddDays(60).ToString('yyyy-MM-ddTHH:mm:ssZ')
$certExpiry2Years  = (Get-Date).AddDays(730).ToString('yyyy-MM-ddTHH:mm:ssZ')
$runStart          = '2026-04-06T12:00:00Z'
$runEnd            = '2026-04-06T12:08:32Z'

# =============================================================================
# BUILD: run block
# =============================================================================
$run = [ordered]@{
    toolVersion       = '0.2.0'
    schemaVersion     = '1.1.0-draft'
    startTimeUtc      = $runStart
    endTimeUtc        = $runEnd
    mode              = 'as-built'
    runner            = 'RANGER-SYNTH'
    includeDomains    = @()
    excludeDomains    = @()
    selectedCollectors = @(
        'topology-cluster', 'hardware', 'storage-networking',
        'workload-identity-azure', 'monitoring-observability', 'management-performance'
    )
    schemaValidation  = [ordered]@{
        isValid  = $true
        errors   = @()
        warnings = @()
    }
}

# =============================================================================
# BUILD: target block
# =============================================================================
$target = [ordered]@{
    environmentLabel = 'iic-azlocal-01'
    clusterName      = $iic.ClusterName
    clusterFqdn      = "$($iic.ClusterName).$($iic.Domain)"
    resourceGroup    = $iic.ResourceGroup
    subscriptionId   = $iic.SubscriptionId
    tenantId         = $iic.TenantId
    nodeList         = $iic.NodeFqdns
}

# =============================================================================
# BUILD: topology block
# =============================================================================
$topology = [ordered]@{
    deploymentType      = 'hyperconverged'
    identityMode        = 'ad'
    controlPlaneMode    = 'connected'
    storageArchitecture = 'storage-spaces-direct'
    networkArchitecture = 'switched'
    variantMarkers      = @('connected')
}

# =============================================================================
# BUILD: collectors block
# =============================================================================
$collectors = [ordered]@{
    'topology-cluster'       = [ordered]@{ status = 'success' }
    'hardware'               = [ordered]@{ status = 'success' }
    'storage-networking'     = [ordered]@{ status = 'success' }
    'workload-identity-azure' = [ordered]@{ status = 'success' }
    'monitoring-observability' = [ordered]@{ status = 'success' }
    'management-performance' = [ordered]@{ status = 'success' }
}

# =============================================================================
# BUILD: domains.clusterNode
# =============================================================================
$nodes = @(
    [ordered]@{
        name                  = $iic.NodeNames[0]
        fqdn                  = $iic.NodeFqdns[0]
        state                 = 'Up'
        uptimeHours           = 312.5
        osCaption             = 'Microsoft Azure Stack HCI'
        osVersion             = '10.0.25398.1189'
        manufacturer          = $iic.HardwareMfr
        model                 = $iic.HardwareModel
        totalMemoryGiB        = 512
        logicalProcessorCount = 64
        partOfDomain          = $true
        domain                = $iic.Domain
        biosVersion           = '2.10.0.0'
    }
    [ordered]@{
        name                  = $iic.NodeNames[1]
        fqdn                  = $iic.NodeFqdns[1]
        state                 = 'Up'
        uptimeHours           = 311.8
        osCaption             = 'Microsoft Azure Stack HCI'
        osVersion             = '10.0.25398.1189'
        manufacturer          = $iic.HardwareMfr
        model                 = $iic.HardwareModel
        totalMemoryGiB        = 512
        logicalProcessorCount = 64
        partOfDomain          = $true
        domain                = $iic.Domain
        biosVersion           = '2.10.0.0'
    }
    [ordered]@{
        name                  = $iic.NodeNames[2]
        fqdn                  = $iic.NodeFqdns[2]
        state                 = 'Up'
        uptimeHours           = 310.2
        osCaption             = 'Microsoft Azure Stack HCI'
        osVersion             = '10.0.25398.1189'
        manufacturer          = $iic.HardwareMfr
        model                 = $iic.HardwareModel
        totalMemoryGiB        = 512
        logicalProcessorCount = 64
        partOfDomain          = $true
        domain                = $iic.Domain
        biosVersion           = '2.10.0.0'
    }
)

$csvItems = $iic.CsvNames | ForEach-Object {
    [ordered]@{ name = $_; state = 'Online'; ownerNode = $iic.NodeNames[0] }
}

$clusterNode = [ordered]@{
    cluster = [ordered]@{
        name                   = $iic.ClusterName
        id                     = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
        domain                 = $iic.Domain
        clusterFunctionalLevel = 11
        s2dEnabled             = $true
        dynamicQuorum          = $true
        registrationConfigured = $true
        productName            = 'Microsoft Azure Stack HCI'
        displayVersion         = '23H2'
        releaseId              = '2311'
        currentBuild           = '25398'
        editionId              = 'ServerAzureStackHCICor'
        installationType       = 'Server Core'
        operatingModel         = [ordered]@{
            deploymentType   = 'hyperconverged'
            identityMode     = 'ad'
            controlPlaneMode = 'connected'
        }
        registration           = [ordered]@{
            subscriptionId = $iic.SubscriptionId
            resourceGroup  = $iic.ResourceGroup
            tenantId       = $iic.TenantId
        }
        licensing              = @()
    }
    nodes         = $nodes
    quorum        = [ordered]@{
        quorumType         = 'CloudWitness'
        quorumResource     = 'Cloud Witness'
        quorumResourcePath = 'iic-witness.blob.core.windows.net'
    }
    faultDomains  = @(
        [ordered]@{ name = 'Rack-IIC-01'; faultDomainType = 'Rack'; location = 'IIC Primary DC Rack 01' }
    )
    networks      = @(
        [ordered]@{ name = 'Management';      role = 1; address = '10.0.0.0';  addressMask = '255.255.255.0'; state = 'Up'; metric = 100 }
        [ordered]@{ name = 'Storage-1';       role = 2; address = '10.0.1.0';  addressMask = '255.255.255.0'; state = 'Up'; metric = 200 }
        [ordered]@{ name = 'Storage-2';       role = 2; address = '10.0.1.128';addressMask = '255.255.255.128';state = 'Up'; metric = 200 }
        [ordered]@{ name = 'Workload';        role = 3; address = '10.0.2.0';  addressMask = '255.255.255.0'; state = 'Up'; metric = 300 }
    )
    roles         = @(
        [ordered]@{ name = 'Cluster Group';           groupType = 'ClusterGroup';       state = 'Online'; ownerNode = $iic.NodeNames[0] }
        [ordered]@{ name = 'Available Storage';        groupType = 'ClusterGroup';       state = 'Online'; ownerNode = $iic.NodeNames[1] }
        [ordered]@{ name = "$($iic.CsvNames[0])";     groupType = 'ClusterSharedVolume';state = 'Online'; ownerNode = $iic.NodeNames[0] }
        [ordered]@{ name = "$($iic.CsvNames[1])";     groupType = 'ClusterSharedVolume';state = 'Online'; ownerNode = $iic.NodeNames[1] }
        [ordered]@{ name = "$($iic.CsvNames[2])";     groupType = 'ClusterSharedVolume';state = 'Online'; ownerNode = $iic.NodeNames[2] }
    )
    csvSummary    = [ordered]@{
        count = 3
        items = @($csvItems)
    }
    updatePosture = [ordered]@{
        clusterAwareUpdating = [ordered]@{
            clusterName             = $iic.ClusterName
            maxRetriesPerNode       = 3
            requireAllNodesOnline   = $true
            startDate               = '2026-04-01T02:00:00Z'
            daysOfWeek              = 'Tuesday'
        }
        lifecycleServices = @(
            [ordered]@{ name = 'ClusSvc'; displayName = 'Cluster Service'; status = 'Running'; startType = 'Automatic' }
            [ordered]@{ name = 'CauService'; displayName = 'Cluster-Aware Updating'; status = 'Running'; startType = 'Manual' }
        )
        validationReports = @(
            [ordered]@{ name = 'Test-Cluster-2026-03-28.htm'; lastWriteTime = '2026-03-28T04:12:00Z'; length = 245760 }
        )
    }
    eventSummary  = @(
        [ordered]@{ timeCreated = '2026-04-06T08:14:32Z'; id = 1135; levelDisplayName = 'Warning'; providerName = 'Microsoft-Windows-FailoverClustering'; message = 'Cluster network Management lost quorum.' }
        [ordered]@{ timeCreated = '2026-04-06T07:02:11Z'; id = 1064; levelDisplayName = 'Information'; providerName = 'Microsoft-Windows-FailoverClustering'; message = 'Cluster network connection restored.' }
        [ordered]@{ timeCreated = '2026-04-05T22:00:05Z'; id = 1656; levelDisplayName = 'Information'; providerName = 'Microsoft-Windows-FailoverClustering'; message = 'CAU update pass completed successfully.' }
    )
    healthSummary = [ordered]@{
        totalNodes   = 3
        healthyNodes = 3
        unhealthy    = 0
    }
    nodeSummary   = [ordered]@{
        manufacturers       = @([ordered]@{ name = $iic.HardwareMfr; count = 3 })
        models              = @([ordered]@{ name = $iic.HardwareModel; count = 3 })
        totalMemoryGiB      = 1536
        totalLogicalCpu     = 192
        domainJoinedNodes   = 3
        localIdentityNodes  = 0
    }
    faultDomainSummary = [ordered]@{
        count     = 1
        byType    = @([ordered]@{ name = 'Rack'; count = 1 })
        locations = @([ordered]@{ name = 'IIC Primary DC Rack 01'; count = 1 })
    }
    networkSummary = [ordered]@{
        clusterNetworkCount = 4
        byRole              = @(
            [ordered]@{ name = '1'; count = 1 }
            [ordered]@{ name = '2'; count = 2 }
            [ordered]@{ name = '3'; count = 1 }
        )
        switched            = $true
    }
}

# =============================================================================
# BUILD: domains.hardware
# =============================================================================
$hardwareNodes = 0..2 | ForEach-Object {
    $i = $_
    [ordered]@{
        node             = $iic.NodeNames[$i]
        model            = $iic.HardwareModel
        manufacturer     = $iic.HardwareMfr
        serviceTag       = $iic.ServiceTags[$i]
        ipmiAddress      = $iic.IdracIPs[$i]
        firmwareVersion  = $iic.FirmwareVersion
        biosVersion      = $iic.FirmwareVersion
        secureBoot       = $true
        tpmPresent       = $true
        tpmVersion       = '2.0'
        totalMemoryGiB   = 512
        processorCount   = 2
        processorSockets = 2
        processorModel   = 'Intel Xeon Gold 6448Y'
        logicalCoreCount = 64
    }
}

$hardware = [ordered]@{
    nodes   = @($hardwareNodes)
    summary = [ordered]@{
        nodeCount        = 3
        manufacturers    = @([ordered]@{ name = $iic.HardwareMfr; count = 3 })
        models           = @([ordered]@{ name = $iic.HardwareModel; count = 3 })
        firmwareNodes    = 3
        totalMemoryGiB   = 1536
        totalProcessors  = 6
    }
    firmware = [ordered]@{
        managedNodes = 3
        versions     = @([ordered]@{ name = $iic.FirmwareVersion; count = 3 })
    }
    security = [ordered]@{
        trustedModuleNodes     = 3
        secureBootEnabledNodes = 3
    }
}

# =============================================================================
# BUILD: domains.storage (24 NVMe disks: 8/node, 3 CSVs, 3 virtual disks)
# =============================================================================
$physicalDisks = @(
    foreach ($nodeIdx in 0..2) {
        foreach ($diskIdx in 0..7) {
            $diskNum = ($nodeIdx * 8) + $diskIdx + 1
            [ordered]@{
                friendlyName  = "PhysicalDisk $($diskNum.ToString('000'))"
                serialNumber  = "IIC-SN-$($iic.ServiceTags[$nodeIdx])-D$($diskIdx.ToString('00'))"
                mediaType     = 'NVMe'
                size          = 1920396288000
                healthStatus  = 'Healthy'
                operationalStatus = 'OK'
                canPool       = $false
                usage         = 'Auto-Select'
                node          = $iic.NodeNames[$nodeIdx]
            }
        }
    }
)

$virtualDisks = $iic.CsvNames | ForEach-Object {
    [ordered]@{
        friendlyName      = $_
        resiliencyName    = 'Mirror'
        size              = 2147483648000
        allocatedSize     = 2000000000000
        healthStatus      = 'Healthy'
        operationalStatus = 'OK'
        numberOfColumns   = 3
        interleave        = 65536
    }
}

$csvObjects = $iic.CsvNames | ForEach-Object {
    [ordered]@{
        name      = "Cluster Virtual Disk ($_)"
        state     = 'Online'
        ownerNode = $iic.NodeNames[0]
        path      = "C:\ClusterStorage\$_"
    }
}

$storage = [ordered]@{
    pools         = @(
        [ordered]@{
            friendlyName      = $iic.StoragePoolName
            healthStatus      = 'Healthy'
            operationalStatus = 'OK'
            size              = 46244158668800
            allocatedSize     = 6442450944000
            isReadOnly        = $false
            isPrimordial      = $false
        }
    )
    physicalDisks = @($physicalDisks)
    virtualDisks  = @($virtualDisks)
    volumes       = @(
        [ordered]@{ driveLetter = 'C'; fileSystemLabel = 'OS'; sizeGB = 128; freeSpaceGB = 62 }
        [ordered]@{ driveLetter = $null; fileSystemLabel = $iic.CsvNames[0]; sizeGB = 2000; freeSpaceGB = 1480 }
        [ordered]@{ driveLetter = $null; fileSystemLabel = $iic.CsvNames[1]; sizeGB = 2000; freeSpaceGB = 1620 }
        [ordered]@{ driveLetter = $null; fileSystemLabel = $iic.CsvNames[2]; sizeGB = 2000; freeSpaceGB = 1710 }
    )
    csvs          = @($csvObjects)
    qos           = @()
    sofs          = @()
    replica       = @()
    summary       = [ordered]@{
        poolCount              = 1
        physicalDiskCount      = 24
        virtualDiskCount       = 3
        volumeCount            = 4
        csvCount               = 3
        totalPoolCapacityGiB   = 43008
        allocatedPoolCapacityGiB = 6144
        diskMediaTypes         = @([ordered]@{ name = 'NVMe'; count = 24 })
        unhealthyDisks         = 0
    }
}

# =============================================================================
# BUILD: domains.networking (4 adapters/node, ATC intents, IIC VLANs)
# =============================================================================
$adapters = @(
    foreach ($nodeIdx in 0..2) {
        $node = $iic.NodeNames[$nodeIdx]
        foreach ($adapterName in @('NIC1', 'NIC2', 'NIC3', 'NIC4')) {
            [ordered]@{
                node        = $node
                name        = $adapterName
                speed       = 25000000000
                mediaType   = 'Ethernet'
                status      = 'Up'
                macAddress  = "00:50:56:IIC:$($nodeIdx):$(([array]::IndexOf(@('NIC1','NIC2','NIC3','NIC4'), $adapterName)).ToString('00'))"
                vlanId      = if ($adapterName -in @('NIC1', 'NIC2')) { $iic.VlanMgmt } elseif ($adapterName -eq 'NIC3') { $iic.VlanStorage } else { $iic.VlanWorkload }
                ipAddress   = if ($adapterName -eq 'NIC1') { $iic.NodeIPs[$nodeIdx] } else { $null }
            }
        }
    }
)

$networking = [ordered]@{
    nodes            = @($iic.NodeNames | ForEach-Object { [ordered]@{ node = $_ } })
    clusterNetworks  = @(
        [ordered]@{ name = 'Management'; address = '10.0.0.0';   subnetMask = '255.255.255.0';   role = 1; state = 'Up' }
        [ordered]@{ name = 'Storage-1';  address = '10.0.1.0';   subnetMask = '255.255.255.0';   role = 2; state = 'Up' }
        [ordered]@{ name = 'Storage-2';  address = '10.0.1.128'; subnetMask = '255.255.255.128'; role = 2; state = 'Up' }
        [ordered]@{ name = 'Workload';   address = '10.0.2.0';   subnetMask = '255.255.255.0';   role = 3; state = 'Up' }
    )
    adapters         = @($adapters)
    vSwitches        = @(
        [ordered]@{ name = 'ConvergedSwitch'; switchType = 'External'; allowManagementOS = $true; embeddedTeaming = $true }
        [ordered]@{ name = 'StorageSwitch';   switchType = 'External'; allowManagementOS = $false; embeddedTeaming = $true }
    )
    hostVirtualNics  = @(
        [ordered]@{ name = 'vManagement'; switchName = 'ConvergedSwitch'; vlanId = $iic.VlanMgmt; ipAddress = '10.0.0.11' }
    )
    intents          = @(
        [ordered]@{ name = 'ManagementCompute'; trafficType = @('Management', 'Compute'); overrideAdapterProperty = $true }
        [ordered]@{ name = 'StorageIntent';     trafficType = @('Storage');               overrideAdapterProperty = $true }
    )
    dns              = @(
        [ordered]@{ server = $iic.DnsServers[0]; reachable = $true }
        [ordered]@{ server = $iic.DnsServers[1]; reachable = $true }
    )
    proxy            = @()
    firewall         = @()
    sdn              = @()
    summary          = [ordered]@{
        nodeCount             = 3
        clusterNetworkCount   = 4
        adapterCount          = 12
        adapterStates         = @([ordered]@{ name = 'Up'; count = 12 })
        vSwitchCount          = 2
        intentCount           = 2
        dnsServers            = $iic.DnsServers
        proxyConfiguredNodes  = 0
        sdnControllerCount    = 0
    }
}

# =============================================================================
# BUILD: domains.virtualMachines (3 AVD session hosts + 2 Arc VMs)
# =============================================================================
$vmInventory = @(
    # AVD session hosts
    foreach ($i in 0..2) {
        $vmName = $iic.AvdVmNames[$i]
        $hostNode = $iic.NodeNames[$i]
        [ordered]@{
            name               = $vmName
            hostNode           = $hostNode
            state              = 'Running'
            isClustered        = $true
            generation         = 2
            processorCount     = 8
            memoryAssignedMb   = 16384
            dynamicMemory      = $true
            diskCount          = 2
            networkAdapterCount = 1
            storagePaths       = @("C:\ClusterStorage\$($iic.CsvNames[$i])\VMs\$vmName\$vmName.vhdx")
            switchNames        = @('ConvergedSwitch')
            replicationMode    = $null
            replicationHealth  = $null
            workloadFamily     = 'AVD'
        }
    }
    # Arc VMs
    foreach ($i in 0..1) {
        $vmName = $iic.ArcVmNames[$i]
        $hostNode = $iic.NodeNames[$i]
        [ordered]@{
            name               = $vmName
            hostNode           = $hostNode
            state              = 'Running'
            isClustered        = $true
            generation         = 2
            processorCount     = 4
            memoryAssignedMb   = 8192
            dynamicMemory      = $false
            diskCount          = 1
            networkAdapterCount = 1
            storagePaths       = @("C:\ClusterStorage\$($iic.CsvNames[$i])\VMs\$vmName\$vmName.vhdx")
            switchNames        = @('ConvergedSwitch')
            replicationMode    = $null
            replicationHealth  = $null
            workloadFamily     = 'Arc VMs'
        }
    }
)

$vmPlacement = $vmInventory | ForEach-Object {
    [ordered]@{ vm = $_.name; hostNode = $_.hostNode; state = $_.state }
}

$virtualMachines = [ordered]@{
    inventory        = @($vmInventory)
    placement        = @($vmPlacement)
    workloadFamilies = @(
        [ordered]@{ name = 'AVD'; count = 3 }
        [ordered]@{ name = 'Arc VMs'; count = 2 }
    )
    replication      = @()
    summary          = [ordered]@{
        totalVms             = 5
        runningVms           = 5
        clusteredVms         = 5
        totalAssignedMemoryGb = 80
        byGeneration         = @([ordered]@{ name = '2'; count = 5 })
        byState              = @([ordered]@{ name = 'Running'; count = 5 })
    }
}

# =============================================================================
# BUILD: domains.identitySecurity (1 cert expiring in 60 days → warning finding)
# =============================================================================
$identityNodes = 0..2 | ForEach-Object {
    $i = $_
    [ordered]@{
        node         = $iic.NodeNames[$i]
        partOfDomain = $true
        domain       = $iic.Domain
        credSsp      = $false
    }
}

$certificates = 0..2 | ForEach-Object {
    $i = $_
    $items = if ($i -eq 0) {
        # Node 0 has a cert expiring in 60 days (triggers warning)
        @(
            [ordered]@{ subject = "CN=$($iic.NodeNames[$i]).$($iic.Domain)"; thumbprint = "AAABBB$($i)01"; notAfter = $certExpiry60Days }
            [ordered]@{ subject = "CN=$($iic.ClusterName).$($iic.Domain)";   thumbprint = "AAABBB$($i)02"; notAfter = $certExpiry2Years }
        )
    } else {
        @(
            [ordered]@{ subject = "CN=$($iic.NodeNames[$i]).$($iic.Domain)"; thumbprint = "AAABBB$($i)01"; notAfter = $certExpiry2Years }
        )
    }
    [ordered]@{ node = $iic.NodeNames[$i]; items = $items }
}

$posture = 0..2 | ForEach-Object {
    $i = $_
    [ordered]@{
        node       = $iic.NodeNames[$i]
        defender   = [ordered]@{ antivirusEnabled = $true; realTimeProtectionEnabled = $true; aMRunningMode = 'Normal' }
        deviceGuard = [ordered]@{ virtualizationBasedSecurityStatus = 2 }
        bitlocker  = @([ordered]@{ mountPoint = 'C:'; protectionStatus = 'On' })
        secureBoot = $true
        appLocker  = @()
    }
}

$localAdmins = 0..2 | ForEach-Object {
    $i = $_
    [ordered]@{
        node    = $iic.NodeNames[$i]
        members = @(
            [ordered]@{ name = "$($iic.NetBIOS)\Domain Admins"; objectClass = 'Group' }
            [ordered]@{ name = "$($iic.NetBIOS)\$($iic.LcmAccount)"; objectClass = 'User' }
        )
    }
}

$auditPolicy = 0..2 | ForEach-Object {
    [ordered]@{
        node   = $iic.NodeNames[$_]
        values = @('Logon/Logoff Success and Failure', 'Account Management Success and Failure', 'Privilege Use Success')
    }
}

$activeDirectoryPerNode = 0..2 | ForEach-Object {
    $i = $_
    [ordered]@{
        node   = $iic.NodeNames[$i]
        domain = [ordered]@{
            DNSRoot           = $iic.Domain
            NetBIOSName       = $iic.NetBIOS
            DomainMode        = 'Windows2016Domain'
            DistinguishedName = 'DC=iic,DC=local'
            ParentDomain      = $null
        }
        forest = [ordered]@{
            Name       = $iic.Domain
            ForestMode = 'Windows2016Forest'
            RootDomain = $iic.Domain
        }
    }
}

$keyVaultPerNode = 0..2 | ForEach-Object {
    [ordered]@{
        node       = $iic.NodeNames[$_]
        references = @("keyvault://$($iic.KeyVault)/local-admin-password", "keyvault://$($iic.KeyVault)/domain-join-password")
    }
}

$identitySecurity = [ordered]@{
    nodes           = @($identityNodes)
    certificates    = @($certificates)
    posture         = @($posture)
    localAdmins     = @($localAdmins)
    auditPolicy     = @($auditPolicy)
    activeDirectory = @($activeDirectoryPerNode)
    keyVault        = @($keyVaultPerNode)
    summary         = [ordered]@{
        nodeCount                       = 3
        domainJoinedNodes               = 3
        credSspEnabledNodes             = 0
        defenderProtectedNodes          = 3
        bitLockerProtectedNodes         = 3
        certificateCount                = 4
        certificateExpiringWithin90Days = 1
        appLockerNodes                  = 0
        secureBootEnabledNodes          = 3
    }
}

# =============================================================================
# BUILD: domains.azureIntegration
# =============================================================================
$arcMachineResources = $iic.NodeNames | ForEach-Object {
    [ordered]@{
        name              = $_
        resourceType      = 'Microsoft.HybridCompute/machines'
        resourceGroupName = $iic.ArcRG
        location          = 'eastus'
    }
}

$azureResources = @(
    [ordered]@{ name = $iic.ClusterName;          resourceType = 'Microsoft.AzureStackHCI/clusters';               resourceGroupName = $iic.ResourceGroup; location = 'eastus' }
    [ordered]@{ name = 'avd-iic-hostpool-01';     resourceType = 'Microsoft.DesktopVirtualization/hostPools';      resourceGroupName = $iic.ResourceGroup; location = 'eastus' }
    [ordered]@{ name = $iic.ResourceBridge;       resourceType = 'Microsoft.ResourceConnector/appliances';          resourceGroupName = $iic.ArcRG;         location = 'eastus' }
    [ordered]@{ name = $iic.CustomLocation;       resourceType = 'Microsoft.ExtendedLocation/customLocations';      resourceGroupName = $iic.ArcRG;         location = 'eastus' }
    [ordered]@{ name = 'rsv-iic-azlocal-01';      resourceType = 'Microsoft.RecoveryServices/vaults';              resourceGroupName = $iic.ResourceGroup; location = 'eastus' }
    [ordered]@{ name = 'aum-iic-azlocal-01';      resourceType = 'Microsoft.Maintenance/configurationAssignments'; resourceGroupName = $iic.ResourceGroup; location = 'eastus' }
    [ordered]@{ name = $iic.LogAnalytics;         resourceType = 'Microsoft.OperationalInsights/workspaces';        resourceGroupName = $iic.MonitorRG;     location = 'eastus' }
) + $arcMachineResources

$azureIntegration = [ordered]@{
    context         = [ordered]@{
        subscriptionId = $iic.SubscriptionId
        resourceGroup  = $iic.ResourceGroup
        tenantId       = $iic.TenantId
    }
    resources       = @($azureResources)
    services        = @(
        [ordered]@{ category = 'Microsoft.AzureStackHCI/clusters';              count = 1; name = 'Microsoft.AzureStackHCI/clusters' }
        [ordered]@{ category = 'Microsoft.DesktopVirtualization/hostPools';     count = 1; name = 'Microsoft.DesktopVirtualization/hostPools' }
        [ordered]@{ category = 'Microsoft.HybridCompute/machines';              count = 3; name = 'Microsoft.HybridCompute/machines' }
        [ordered]@{ category = 'Microsoft.ResourceConnector/appliances';         count = 1; name = 'Microsoft.ResourceConnector/appliances' }
        [ordered]@{ category = 'Microsoft.ExtendedLocation/customLocations';     count = 1; name = 'Microsoft.ExtendedLocation/customLocations' }
        [ordered]@{ category = 'Microsoft.RecoveryServices/vaults';             count = 1; name = 'Microsoft.RecoveryServices/vaults' }
        [ordered]@{ category = 'Microsoft.OperationalInsights/workspaces';       count = 1; name = 'Microsoft.OperationalInsights/workspaces' }
    )
    policy          = @(
        [ordered]@{ name = 'iic-tagging-policy'; displayName = 'IIC: Enforce resource tags'; scope = "/subscriptions/$($iic.SubscriptionId)/resourceGroups/$($iic.ResourceGroup)"; enforcementMode = 'Default' }
        [ordered]@{ name = 'iic-audit-policy';   displayName = 'IIC: Audit security controls'; scope = "/subscriptions/$($iic.SubscriptionId)/resourceGroups/$($iic.ResourceGroup)"; enforcementMode = 'Default' }
    )
    backup          = @(
        [ordered]@{ name = 'rsv-iic-azlocal-01'; resourceType = 'Microsoft.RecoveryServices/vaults' }
    )
    update          = @(
        [ordered]@{ name = 'aum-iic-azlocal-01'; resourceType = 'Microsoft.Maintenance/configurationAssignments' }
    )
    cost            = @()
    resourceBridge  = @(
        [ordered]@{ name = $iic.ResourceBridge; resourceType = 'Microsoft.ResourceConnector/appliances'; resourceGroupName = $iic.ArcRG; location = 'eastus' }
    )
    customLocations = @(
        [ordered]@{ name = $iic.CustomLocation; resourceType = 'Microsoft.ExtendedLocation/customLocations'; resourceGroupName = $iic.ArcRG; location = 'eastus' }
    )
    extensions      = @(
        [ordered]@{ name = 'AzureMonitorWindowsAgent'; resourceType = 'Microsoft.AzureStackHCI/clusters/extensions' }
        [ordered]@{ name = 'AzureEdgeTelemetryAndDiagnostics'; resourceType = 'Microsoft.AzureStackHCI/clusters/extensions' }
    )
    arcMachines     = @($arcMachineResources)
    siteRecovery    = @()
    resourceSummary = [ordered]@{
        totalResources          = @($azureResources).Count
        byType                  = @(
            [ordered]@{ name = 'Microsoft.AzureStackHCI/clusters';              count = 1 }
            [ordered]@{ name = 'Microsoft.DesktopVirtualization/hostPools';     count = 1 }
            [ordered]@{ name = 'Microsoft.HybridCompute/machines';              count = 3 }
            [ordered]@{ name = 'Microsoft.ResourceConnector/appliances';         count = 1 }
            [ordered]@{ name = 'Microsoft.ExtendedLocation/customLocations';     count = 1 }
            [ordered]@{ name = 'Microsoft.RecoveryServices/vaults';             count = 1 }
            [ordered]@{ name = 'Microsoft.OperationalInsights/workspaces';       count = 1 }
        )
        byLocation              = @([ordered]@{ name = 'eastus'; count = @($azureResources).Count })
        azureArcMachines        = 3
        hciClusterRegistrations = 1
        backupResources         = 1
        updateResources         = 1
        resourceBridgeCount     = 1
        customLocationCount     = 1
        extensionCount          = 2
    }
    resourceLocations = @([ordered]@{ name = 'eastus'; count = @($azureResources).Count })
    policySummary   = [ordered]@{
        assignmentCount  = 2
        enforcementModes = @([ordered]@{ name = 'Default'; count = 2 })
    }
    auth            = [ordered]@{
        method          = 'service-principal'
        tenantId        = $iic.TenantId
        subscriptionId  = $iic.SubscriptionId
        azureCliFallback = $false
    }
}

# =============================================================================
# BUILD: domains.monitoring (AMA on 3 nodes, DCR, DCE, LAW, 2 alerts)
# =============================================================================
$amaAgents = $iic.NodeNames | ForEach-Object {
    [ordered]@{ name = 'AzureMonitorWindowsAgent'; node = $_; status = 'Running'; version = '1.22.2.0' }
}

$healthPerNode = $iic.NodeNames | ForEach-Object {
    [ordered]@{ node = $_; healthServiceRunning = $true; reportCount = 12 }
}

$monitoring = [ordered]@{
    telemetry     = @(
        [ordered]@{ name = 'AzureEdgeTelemetryAndDiagnostics'; status = 'Succeeded'; version = '1.0.6' }
    )
    ama           = @($amaAgents)
    dcr           = @(
        [ordered]@{
            name          = $iic.DCR
            resourceGroup = $iic.MonitorRG
            location      = 'eastus'
            dataFlows     = @('Windows Event Log', 'Performance Counters')
        }
    )
    dce           = @(
        [ordered]@{
            name          = $iic.DCE
            resourceGroup = $iic.MonitorRG
            location      = 'eastus'
            endpoint      = "https://$($iic.DCE).eastus-1.ingest.monitor.azure.com"
        }
    )
    insights      = @(
        [ordered]@{
            name          = $iic.LogAnalytics
            resourceGroup = $iic.MonitorRG
            location      = 'eastus'
            workspaceId   = "/subscriptions/55555555-5555-5555-5555-555555555555/resourceGroups/$($iic.MonitorRG)/providers/Microsoft.OperationalInsights/workspaces/$($iic.LogAnalytics)"
            retentionDays = 90
        }
    )
    alerts        = @(
        [ordered]@{ name = 'alert-iic-azl-critical-cpu';      severity = 0; state = 'Enabled'; condition = 'CPU > 85%' }
        [ordered]@{ name = 'alert-iic-azl-storage-capacity';  severity = 1; state = 'Enabled'; condition = 'Used capacity > 80%' }
    )
    health        = @($healthPerNode)
    updateManager = @(
        [ordered]@{ name = 'aum-iic-azlocal-01'; resourceType = 'Microsoft.Maintenance/configurationAssignments' }
    )
    summary       = [ordered]@{
        telemetryCount            = 1
        amaCount                  = 3
        dcrCount                  = 1
        dceCount                  = 1
        alertCount                = 2
        updateManagerCount        = 1
        healthServiceRunningNodes = 3
    }
}

# =============================================================================
# BUILD: domains.managementTools
# =============================================================================
$mgmtToolServices = @(
    'ServerManagementGateway', 'HealthService', 'WinRM', 'MicrosoftMonitoringAgent'
) | ForEach-Object {
    [ordered]@{ name = $_; status = 'Running' }
}

$mgmtAgents = $iic.NodeNames | ForEach-Object {
    [ordered]@{ name = 'HealthService'; node = $_; status = 'Running' }
}

$managementTools = [ordered]@{
    tools   = @($mgmtToolServices)
    agents  = @($mgmtAgents)
    summary = [ordered]@{
        totalServices   = @($mgmtToolServices).Count
        runningServices = @($mgmtToolServices).Count
        serviceNames    = @($mgmtToolServices | ForEach-Object { [ordered]@{ name = $_.name; count = 1 } })
    }
}

# =============================================================================
# BUILD: domains.performance
# =============================================================================
$perfCompute = 0..2 | ForEach-Object {
    $i = $_
    $cpu = @(35, 42, 38)[$i]
    [ordered]@{ node = $iic.NodeNames[$i]; metrics = [ordered]@{ cpuUtilizationPercent = $cpu; availableMemoryMb = 180224 } }
}

$performance = [ordered]@{
    nodes      = $iic.NodeNames
    compute    = @($perfCompute)
    storage    = @($iic.NodeNames | ForEach-Object { [ordered]@{ node = $_; metrics = @() } })
    networking = @($iic.NodeNames | ForEach-Object { [ordered]@{ node = $_; metrics = @() } })
    outliers   = @()
    events     = @($iic.NodeNames | ForEach-Object { [ordered]@{ node = $_; values = @() } })
    summary    = [ordered]@{
        averageCpuUtilizationPercent = 38.3
        averageAvailableMemoryMb     = 180224
        runningManagementServices    = @($mgmtToolServices).Count
        toolNames                    = @($mgmtToolServices | ForEach-Object { [ordered]@{ name = $_.name; count = 1 } })
        highCpuNodes                 = 0
        eventSeverities              = @()
    }
}

# =============================================================================
# BUILD: domains.oemIntegration
# =============================================================================
$oemEndpoints = 0..2 | ForEach-Object {
    $i = $_
    [ordered]@{
        host  = "idrac-$($iic.NodeNames[$i]).$($iic.Domain)"
        node  = $iic.NodeNames[$i]
        ip    = $iic.IdracIPs[$i]
        port  = 443
        reachable = $true
    }
}

$oemPosture = 0..2 | ForEach-Object {
    $i = $_
    [ordered]@{
        node            = $iic.NodeNames[$i]
        managerModel    = 'iDRAC9'
        firmwareVersion = '7.10.30.00'
        serviceTag      = $iic.ServiceTags[$i]
    }
}

$oemIntegration = [ordered]@{
    endpoints         = @($oemEndpoints)
    managementPosture = @($oemPosture)
}

# =============================================================================
# BUILD: findings (2 warnings + 2 informationals)
# =============================================================================
$findings = @(
    [ordered]@{
        severity            = 'warning'
        title               = 'One or more node certificates expire within 90 days'
        description         = "Identity posture data indicates certificate on $($iic.NodeNames[0]) expires within 90 days."
        affectedComponents  = @($iic.NodeNames[0])
        currentState        = '1 certificate expiring within 90 days'
        recommendation      = 'Review certificate ownership and renew expiring node certificates before handoff.'
    }
    [ordered]@{
        severity            = 'warning'
        title               = 'iDRAC firmware below recommended baseline on all nodes'
        description         = 'OEM integration data shows iDRAC firmware at 7.10.30.00. The recommended baseline is 7.20 or later.'
        affectedComponents  = $iic.NodeNames
        currentState        = 'iDRAC firmware 7.10.30.00'
        recommendation      = 'Update iDRAC firmware via Dell OME or Lifecycle Controller during next maintenance window.'
    }
    [ordered]@{
        severity            = 'informational'
        title               = 'Azure Policy assignments discovered at resource group scope'
        description         = '2 policy assignments are enforcing tagging and security control auditing.'
        affectedComponents  = @($iic.ResourceGroup)
        currentState        = '2 policy assignments active'
        recommendation      = 'Verify policy scope extends to arc resource group and monitor for compliance drift.'
    }
    [ordered]@{
        severity            = 'informational'
        title               = 'Cluster event history includes a transient network quorum warning'
        description         = 'A Management network quorum warning event was recorded on 2026-04-06. Cluster recovered automatically.'
        affectedComponents  = @($iic.ClusterName)
        currentState        = 'single event logged; cluster healthy'
        recommendation      = 'Review switch port configuration to confirm management NICs are on dedicated VLANs and bonded correctly.'
    }
)

# =============================================================================
# BUILD: relationships
# =============================================================================
$relationships = @(
    foreach ($vm in $vmInventory) {
        [ordered]@{
            source           = [ordered]@{ type = 'cluster-node'; id = $vm.hostNode }
            target           = [ordered]@{ type = 'virtual-machine'; id = $vm.name }
            relationshipType = 'hosts'
            properties       = [ordered]@{ state = $vm.state; workloadFamily = $vm.workloadFamily }
        }
    }
    foreach ($nodeIdx in 0..2) {
        [ordered]@{
            source           = [ordered]@{ type = 'cluster-node'; id = $iic.NodeNames[$nodeIdx] }
            target           = [ordered]@{ type = 'arc-machine'; id = $iic.NodeNames[$nodeIdx] }
            relationshipType = 'registered-as'
            properties       = [ordered]@{ resourceGroup = $iic.ArcRG }
        }
    }
    [ordered]@{
        source           = [ordered]@{ type = 'cluster'; id = $iic.ClusterName }
        target           = [ordered]@{ type = 'log-analytics-workspace'; id = $iic.LogAnalytics }
        relationshipType = 'monitored-by'
        properties       = [ordered]@{ dcrName = $iic.DCR }
    }
)

# =============================================================================
# ASSEMBLE MANIFEST
# =============================================================================
$manifest = [ordered]@{
    run           = $run
    target        = $target
    topology      = $topology
    collectors    = $collectors
    domains       = [ordered]@{
        clusterNode      = $clusterNode
        hardware         = $hardware
        storage          = $storage
        networking       = $networking
        virtualMachines  = $virtualMachines
        identitySecurity = $identitySecurity
        azureIntegration = $azureIntegration
        monitoring       = $monitoring
        managementTools  = $managementTools
        performance      = $performance
        oemIntegration   = $oemIntegration
    }
    relationships = @($relationships)
    findings      = @($findings)
    artifacts     = @()
    evidence      = @()
}

# =============================================================================
# WRITE
# =============================================================================
$outputDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$manifest | ConvertTo-Json -Depth 20 | Set-Content -Path $OutputPath -Encoding UTF8 -Force

Write-Host "[OK] Synthetic IIC manifest written to: $OutputPath" -ForegroundColor Green
Write-Host "     Nodes:    $($iic.NodeNames -join ', ')" -ForegroundColor Cyan
Write-Host "     Cluster:  $($iic.ClusterName)" -ForegroundColor Cyan
Write-Host "     Domain:   $($iic.Domain)" -ForegroundColor Cyan
Write-Host "     Mode:     as-built" -ForegroundColor Cyan
Write-Host "     Findings: $(@($findings | Where-Object { $_.severity -eq 'warning' }).Count) warnings, $(@($findings | Where-Object { $_.severity -eq 'informational' }).Count) informationals" -ForegroundColor Cyan
