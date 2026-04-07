function Invoke-RangerStorageNetworkingCollector {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory = $true)]
        $CredentialMap,

        [Parameter(Mandatory = $true)]
        [object]$Definition,

        [Parameter(Mandatory = $true)]
        [string]$PackageRoot
    )

    $fixture = Get-RangerCollectorFixtureData -Config $Config -CollectorId $Definition.Id
    if ($fixture) {
        return ConvertTo-RangerHashtable -InputObject $fixture
    }

    $storageSnapshot = Invoke-RangerSafeAction -Label 'Storage inventory snapshot' -DefaultValue [ordered]@{} -ScriptBlock {
        Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -SingleTarget -ScriptBlock {
            [ordered]@{
                pools = if (Get-Command -Name Get-StoragePool -ErrorAction SilentlyContinue) { Get-StoragePool | Select-Object FriendlyName, HealthStatus, OperationalStatus, Size, AllocatedSize, IsPrimordial } else { @() }
                physicalDisks = if (Get-Command -Name Get-PhysicalDisk -ErrorAction SilentlyContinue) { Get-PhysicalDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus, MediaType, Size, SerialNumber, Usage, SlotNumber } else { @() }
                virtualDisks = if (Get-Command -Name Get-VirtualDisk -ErrorAction SilentlyContinue) { Get-VirtualDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus, ResiliencySettingName, Size, FootprintOnPool } else { @() }
                volumes = if (Get-Command -Name Get-Volume -ErrorAction SilentlyContinue) { Get-Volume | Select-Object DriveLetter, FileSystemLabel, FileSystem, HealthStatus, SizeRemaining, Size } else { @() }
                tiers = if (Get-Command -Name Get-StorageTier -ErrorAction SilentlyContinue) { Get-StorageTier | Select-Object FriendlyName, MediaType, ResiliencySettingName, Size, FootprintOnPool } else { @() }
                subsystems = if (Get-Command -Name Get-StorageSubSystem -ErrorAction SilentlyContinue) { Get-StorageSubSystem | Select-Object FriendlyName, Model, SerialNumber, HealthStatus } else { @() }
                resiliency = if (Get-Command -Name Get-ResiliencySetting -ErrorAction SilentlyContinue) { Get-ResiliencySetting | Select-Object Name, NumberOfDataCopiesDefault, PhysicalDiskRedundancyDefault } else { @() }
                jobs = if (Get-Command -Name Get-StorageJob -ErrorAction SilentlyContinue) { Get-StorageJob | Select-Object Name, JobState, PercentComplete, BytesProcessed } else { @() }
                csvs = if (Get-Command -Name Get-ClusterSharedVolume -ErrorAction SilentlyContinue) { Get-ClusterSharedVolume | Select-Object Name, State, OwnerNode } else { @() }
                qos = if (Get-Command -Name Get-StorageQosPolicy -ErrorAction SilentlyContinue) { Get-StorageQosPolicy | Select-Object Name, PolicyId, PolicyType, MinimumIops, MaximumIops, MaximumIoBandwidth } else { @() }
                qosFlows = if (Get-Command -Name Get-StorageQosFlow -ErrorAction SilentlyContinue) {
                    @(try { Get-StorageQosFlow -ErrorAction Stop | Select-Object Initiator, InitiatorName, PolicyId, FilePath, StorageNodeIops, Status } catch { @() })
                } else { @() }
                healthFaults = if (Get-Command -Name Get-HealthFault -ErrorAction SilentlyContinue) {
                    @(try { Get-HealthFault -ErrorAction Stop | Select-Object FaultType, FaultingObjectDescription, FaultingObjectLocation, FaultingObjectUniqueId, PerceivedSeverity, Reason, RecommendedActions, FaultTime } catch { @() })
                } else { @() }
                scrubSettings = if (Get-Command -Name Get-StorageSubSystem -ErrorAction SilentlyContinue) {
                    $subsys = Get-StorageSubSystem -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match 'S2D|Spaces' } | Select-Object -First 1
                    if ($subsys) {
                        $scrub = try { $subsys | Get-StoragePool | Get-PhysicalDisk | Get-StorageReliabilityCounter -ErrorAction Stop | Select-Object -First 1 ReadErrors, WriteErrors, Temperature } catch { $null }
                        [ordered]@{
                            scrubData = if ($scrub) { ConvertTo-Json $scrub -Compress } else { $null }
                        }
                    }
                }
                sofs = if (Get-Command -Name Get-SmbShare -ErrorAction SilentlyContinue) { Get-SmbShare | Where-Object { $_.ContinuouslyAvailable } | Select-Object Name, Path, ScopeName, ContinuouslyAvailable, FolderEnumerationMode, Description } else { @() }
                sofsDetail = if (Get-Command -Name Get-SmbShare -ErrorAction SilentlyContinue) {
                    @(Get-SmbShare -ErrorAction SilentlyContinue | Where-Object { $_.ContinuouslyAvailable } | ForEach-Object {
                        $share = $_
                        $acl = try { Get-SmbShareAccess -Name $share.Name -ErrorAction Stop | Select-Object Name, AccountName, AccessRight, AccessControlType } catch { @() }
                        $quota = if (Get-Command -Name Get-FsrmQuota -ErrorAction SilentlyContinue) {
                            try { Get-FsrmQuota -Path $share.Path -ErrorAction Stop | Select-Object Path, Size, SoftLimit, Disabled, Description } catch { $null }
                        }
                        [ordered]@{
                            name                   = $share.Name
                            path                   = $share.Path
                            scopeName              = $share.ScopeName
                            accessBasedEnumeration = ($share.FolderEnumerationMode -eq 'AccessBased')
                            access                 = @($acl)
                            quota                  = $quota
                        }
                    })
                } else { @() }
                replicaDepth = if (Get-Command -Name Get-SRGroup -ErrorAction SilentlyContinue) {
                    @(try {
                        $srPartnerships = @(try { Get-SRPartnership -ErrorAction Stop } catch { @() })
                        Get-SRGroup -ErrorAction Stop | ForEach-Object {
                            $sg = $_
                            $partnership = $srPartnerships | Where-Object { $_.SourceRGName -eq $sg.Name -or $_.DestinationRGName -eq $sg.Name } | Select-Object -First 1
                            [ordered]@{
                                name              = $sg.Name
                                replicationMode   = [string]$sg.ReplicationMode
                                replicationState  = [string]$sg.ReplicationState
                                logSizeUsedBytes  = $sg.LogSizeUsed
                                currentSyncSpeedBytesPerSecond = $sg.CurrentSynchronizationSpeed
                                lastInSyncTime    = $sg.LastInSyncTime
                                memberCount       = @($sg.Members).Count
                                partnerGroupName  = if ($partnership) { if ($partnership.SourceRGName -eq $sg.Name) { $partnership.DestinationRGName } else { $partnership.SourceRGName } } else { $null }
                                partnerComputerName = if ($partnership) { if ($partnership.SourceComputerName) { $partnership.SourceComputerName } else { $partnership.DestinationComputerName } } else { $null }
                            }
                        }
                    } catch { @() })
                } else { @() }
                replica = if (Get-Command -Name Get-SRGroup -ErrorAction SilentlyContinue) { Get-SRGroup | Select-Object Name, ReplicationMode, LastInSyncTime, State } else { @() }
                clusterNetworks = if (Get-Command -Name Get-ClusterNetwork -ErrorAction SilentlyContinue) { Get-ClusterNetwork | Select-Object Name, Role, Address, AddressMask, State } else { @() }
            }
        }
    }

    $networkNodes = @(
        Invoke-RangerSafeAction -Label 'Networking inventory snapshot' -DefaultValue @() -ScriptBlock {
            Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -ScriptBlock {
                $proxy = try { netsh winhttp show proxy | Out-String } catch { $null }
                $dcb = [ordered]@{
                    dcbxSettings  = if (Get-Command -Name Get-NetQosDcbxSetting -ErrorAction SilentlyContinue) { @(Get-NetQosDcbxSetting -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, Setting) } else { @() }
                    trafficClasses = if (Get-Command -Name Get-NetQosTrafficClass -ErrorAction SilentlyContinue) { @(Get-NetQosTrafficClass -ErrorAction SilentlyContinue | Select-Object Name, Algorithm, BandwidthPercentage, Priority) } else { @() }
                    flowControl   = if (Get-Command -Name Get-NetQosFlowControl -ErrorAction SilentlyContinue) { @(Get-NetQosFlowControl -ErrorAction SilentlyContinue | Select-Object Priority, Enabled) } else { @() }
                    policy        = if (Get-Command -Name Get-NetQosPolicy -ErrorAction SilentlyContinue) { @(Get-NetQosPolicy -ErrorAction SilentlyContinue | Select-Object Name, PriorityValue8021Action, NetDirectPortMatchCondition, IPProtocolMatchCondition) } else { @() }
                }
                $intentOverrides = if (Get-Command -Name Get-NetIntent -ErrorAction SilentlyContinue) {
                    @(Get-NetIntent -ErrorAction SilentlyContinue | ForEach-Object {
                        $intent = $_
                        [ordered]@{
                            name             = $intent.IntentName
                            adapters         = @(try { $intent.InterfaceOverride | ForEach-Object { if ($_.InterfaceDescription) { $_.InterfaceDescription } elseif ($_.InterfaceAlias) { $_.InterfaceAlias } } } catch { @() })
                            isStorageIntent  = $intent.IsStorageIntent
                            isComputeIntent  = $intent.IsComputeIntent
                            isManagementIntent = $intent.IsManagementIntent
                            storageVlans     = @(try { $intent.StorageVlans } catch { @() })
                            overrideAdapterProperty = if (Get-Command -Name Get-NetIntentAllAdapterPropertyOverrides -ErrorAction SilentlyContinue) {
                                try { Get-NetIntentAllAdapterPropertyOverrides -Name $intent.IntentName -ErrorAction Stop | Select-Object Name, AdapterName, PropertyName, PropertyValue } catch { $null }
                            }
                        }
                    })
                } else { @() }
                $lldpNeighbors = if (Get-Command -Name Get-NetAdapter -ErrorAction SilentlyContinue) {
                    @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
                        $adapterName = $_.Name
                        try {
                            # LLDP neighbor data from adapter advanced properties (read-only LLDP)
                            $lldpProp = Get-NetAdapterAdvancedProperty -Name $adapterName -RegistryKeyword '*PMNSOffload' -ErrorAction SilentlyContinue
                            # Try WMI-based LLDP where available
                            $lldpWmi = Get-CimInstance -Namespace 'root\wmi' -ClassName MSNdis_NetworkLinkDescription -Filter "InstanceName like '%$adapterName%'" -ErrorAction SilentlyContinue
                            if ($null -ne $lldpWmi) {
                                [ordered]@{ interface = $adapterName; lldpData = $lldpWmi.LinkDescription }
                            } else {
                                [ordered]@{ interface = $adapterName; lldpData = $null }
                            }
                        } catch { [ordered]@{ interface = $adapterName; lldpData = $null } }
                    } | Where-Object { $_.lldpData })
                } else { @() }
                [ordered]@{
                    node          = $env:COMPUTERNAME
                    adapters      = if (Get-Command -Name Get-NetAdapter -ErrorAction SilentlyContinue) { Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress } else { @() }
                    vSwitches     = if (Get-Command -Name Get-VMSwitch -ErrorAction SilentlyContinue) { Get-VMSwitch | Select-Object Name, SwitchType, NetAdapterInterfaceDescriptions, AllowManagementOS } else { @() }
                    hostVirtualNics = if (Get-Command -Name Get-VMNetworkAdapter -ErrorAction SilentlyContinue) { Get-VMNetworkAdapter -ManagementOS | Select-Object Name, SwitchName, Status, IPAddresses } else { @() }
                    intents       = if (Get-Command -Name Get-NetIntent -ErrorAction SilentlyContinue) { Get-NetIntent | Select-Object Name, ClusterName, IsStorageIntent, IsComputeIntent } else { @() }
                    intentOverrides = @($intentOverrides)
                    dcb           = $dcb
                    lldpNeighbors = @($lldpNeighbors)
                    dns           = if (Get-Command -Name Get-DnsClientServerAddress -ErrorAction SilentlyContinue) { Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object InterfaceAlias, ServerAddresses } else { @() }
                    ipAddresses   = if (Get-Command -Name Get-NetIPAddress -ErrorAction SilentlyContinue) { Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, IPAddress, PrefixLength, AddressState } else { @() }
                    routes        = if (Get-Command -Name Get-NetRoute -ErrorAction SilentlyContinue) { Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 50 DestinationPrefix, NextHop, InterfaceAlias, RouteMetric } else { @() }
                    vlan          = if (Get-Command -Name Get-VMNetworkAdapterVlan -ErrorAction SilentlyContinue) { Get-VMNetworkAdapterVlan -ManagementOS -ErrorAction SilentlyContinue | Select-Object VMNetworkAdapterName, OperationMode, AccessVlanId, NativeVlanId, AllowedVlanIdList } else { @() }
                    proxy         = $proxy
                    firewall      = if (Get-Command -Name Get-NetFirewallProfile -ErrorAction SilentlyContinue) { Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction } else { @() }
                    sdn           = if (Get-Command -Name Get-NetworkController -ErrorAction SilentlyContinue) { Get-NetworkController | Select-Object Name, Server } else { @() }
                }
            }
        }
    )

    if ((@($storageSnapshot.pools).Count + @($storageSnapshot.physicalDisks).Count + @($networkNodes).Count) -eq 0) {
        throw 'Storage and networking collector did not return any usable data.'
    }

    # Import optional offline device configs provided via hints
    $deviceImport = Invoke-RangerNetworkDeviceConfigImport -Config $Config

    $flattenedAdapters = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.adapters }))
    $flattenedSwitches = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.vSwitches }))
    $flattenedHostVirtualNics = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.hostVirtualNics }))
    $flattenedIntents = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.intents }))
    $flattenedDns = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.dns }))
    $flattenedIpAddresses = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.ipAddresses }))
    $flattenedRoutes = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.routes }))
    $flattenedVlan = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.vlan }))
    $flattenedFirewall = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.firewall }))
    $flattenedSdn = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.sdn }))
    $proxyByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; value = $_.proxy } })
    $dcbByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; dcb = $_.dcb } })
    $intentOverridesByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; intentOverrides = $_.intentOverrides } })
    $lldpByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; neighbors = $_.lldpNeighbors } })

    $storageSummary = [ordered]@{
        poolCount           = @($storageSnapshot.pools).Count
        physicalDiskCount   = @($storageSnapshot.physicalDisks).Count
        virtualDiskCount    = @($storageSnapshot.virtualDisks).Count
        volumeCount         = @($storageSnapshot.volumes).Count
        csvCount            = @($storageSnapshot.csvs).Count
        totalPoolCapacityGiB = [math]::Round((@($storageSnapshot.pools | Where-Object { $null -ne $_.Size } | Measure-Object -Property Size -Sum).Sum / 1GB), 2)
        allocatedPoolCapacityGiB = [math]::Round((@($storageSnapshot.pools | Where-Object { $null -ne $_.AllocatedSize } | Measure-Object -Property AllocatedSize -Sum).Sum / 1GB), 2)
        diskMediaTypes      = @(Get-RangerGroupedCount -Items $storageSnapshot.physicalDisks -PropertyName 'MediaType')
        unhealthyDisks      = @($storageSnapshot.physicalDisks | Where-Object { $_.HealthStatus -and $_.HealthStatus -ne 'Healthy' }).Count
        resiliencyModes     = @(Get-RangerGroupedCount -Items $storageSnapshot.virtualDisks -PropertyName 'ResiliencySettingName')
        tierCount           = @($storageSnapshot.tiers).Count
        storageJobCount     = @($storageSnapshot.jobs).Count
        activeHealthFaultCount = @($storageSnapshot.healthFaults).Count
        sofsShareCount      = @($storageSnapshot.sofs).Count
        replicaGroupCount   = @($storageSnapshot.replicaDepth).Count
        qosFlowCount        = @($storageSnapshot.qosFlows).Count
    }

    $networkSummary = [ordered]@{
        nodeCount         = @($networkNodes).Count
        clusterNetworkCount = @($storageSnapshot.clusterNetworks).Count
        adapterCount      = $flattenedAdapters.Count
        adapterStates     = @(Get-RangerGroupedCount -Items $flattenedAdapters -PropertyName 'Status')
        vSwitchCount      = $flattenedSwitches.Count
        intentCount       = $flattenedIntents.Count
        dnsServers        = @($flattenedDns | ForEach-Object { @($_.ServerAddresses) } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        routeCount        = $flattenedRoutes.Count
        vlanCount         = $flattenedVlan.Count
        proxyConfiguredNodes = @($proxyByNode | Where-Object { $_.value -and $_.value -notmatch 'Direct access' }).Count
        sdnControllerCount = $flattenedSdn.Count
        importedSwitchConfigCount   = @($deviceImport.switchConfig).Count
        importedFirewallConfigCount = @($deviceImport.firewallConfig).Count
        dcbConfiguredNodes = @($dcbByNode | Where-Object { $_.dcb.trafficClasses -and @($_.dcb.trafficClasses).Count -gt 0 }).Count
        lldpNeighborCount  = @($lldpByNode | ForEach-Object { @($_.neighbors).Count } | Measure-Object -Sum).Sum
    }

    $findings = New-Object System.Collections.ArrayList
    $unhealthyDisks = @($storageSnapshot.physicalDisks | Where-Object { $_.HealthStatus -and $_.HealthStatus -ne 'Healthy' })
    if ($unhealthyDisks.Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Physical disks report a non-healthy state' -Description 'The storage collector found one or more disks that were not healthy.' -AffectedComponents (@($unhealthyDisks | ForEach-Object { $_.FriendlyName })) -CurrentState "$($unhealthyDisks.Count) unhealthy disks" -Recommendation 'Inspect failed or degraded disks and review Storage Spaces Direct health before generating an as-built handoff.'))
    }

    if ($networkSummary.intentCount -eq 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'No Network ATC intents were detected' -Description 'The networking collector did not find Network ATC intent metadata in the sampled node inventory.' -CurrentState 'network intent metadata absent' -Recommendation 'Confirm whether Network ATC is intentionally unused or whether the networking inventory needs additional permissions or modules.'))
    }

    $publicFirewallEnabled = @($networkNodes | ForEach-Object { $_.firewall } | Where-Object { $_.Name -eq 'Public' -and $_.Enabled }).Count
    if ($publicFirewallEnabled -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'Public firewall profile is enabled on one or more nodes' -Description 'Host-side firewall posture indicates the Public profile is enabled on at least one node.' -CurrentState "$publicFirewallEnabled nodes with Public firewall enabled" -Recommendation 'Review whether the enabled profile aligns with intended host networking and management access posture.'))
    }

    $criticalHealthFaults = @($storageSnapshot.healthFaults | Where-Object { $_.PerceivedSeverity -in @('Fatal', 'Critical', 'Major') })
    if ($criticalHealthFaults.Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Active critical or fatal Health Service storage faults detected' -Description "The storage collector found $($criticalHealthFaults.Count) active Health Service fault(s) at Critical or higher severity." -AffectedComponents (@($criticalHealthFaults | ForEach-Object { $_.FaultingObjectDescription })) -CurrentState "$($criticalHealthFaults.Count) active critical storage faults" -Recommendation 'Review active Health Service faults in Windows Admin Center or Get-HealthFault and resolve before formal handoff.'))
    }

    $activeStorageJobs = @($storageSnapshot.jobs | Where-Object { $_.JobState -notin @('Completed', 'CompletedWithWarnings') })
    if ($activeStorageJobs.Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'Active storage jobs detected' -Description "The storage collector found $($activeStorageJobs.Count) in-progress storage job(s) such as rebuild or rebalance operations." -AffectedComponents (@($activeStorageJobs | ForEach-Object { $_.Name })) -CurrentState "$($activeStorageJobs.Count) active storage jobs" -Recommendation 'Monitor active storage jobs to completion before formal handoff. Review rebuild or rebalance progress.'))
    }

    return @{
        Status        = if ($findings.Count -gt 0) { 'partial' } else { 'success' }
        Domains       = @{
            storage = [ordered]@{
                pools         = ConvertTo-RangerHashtable -InputObject $storageSnapshot.pools
                physicalDisks = ConvertTo-RangerHashtable -InputObject $storageSnapshot.physicalDisks
                virtualDisks  = ConvertTo-RangerHashtable -InputObject $storageSnapshot.virtualDisks
                volumes       = ConvertTo-RangerHashtable -InputObject $storageSnapshot.volumes
                tiers         = ConvertTo-RangerHashtable -InputObject $storageSnapshot.tiers
                subsystems    = ConvertTo-RangerHashtable -InputObject $storageSnapshot.subsystems
                resiliency    = ConvertTo-RangerHashtable -InputObject $storageSnapshot.resiliency
                jobs          = ConvertTo-RangerHashtable -InputObject $storageSnapshot.jobs
                csvs          = ConvertTo-RangerHashtable -InputObject $storageSnapshot.csvs
                qos           = ConvertTo-RangerHashtable -InputObject $storageSnapshot.qos
                qosFlows      = ConvertTo-RangerHashtable -InputObject $storageSnapshot.qosFlows
                healthFaults  = ConvertTo-RangerHashtable -InputObject $storageSnapshot.healthFaults
                sofs          = ConvertTo-RangerHashtable -InputObject $storageSnapshot.sofs
                sofsDetail    = ConvertTo-RangerHashtable -InputObject $storageSnapshot.sofsDetail
                replica       = ConvertTo-RangerHashtable -InputObject $storageSnapshot.replica
                replicaDepth  = ConvertTo-RangerHashtable -InputObject $storageSnapshot.replicaDepth
                summary       = $storageSummary
            }
            networking = [ordered]@{
                nodes           = ConvertTo-RangerHashtable -InputObject $networkNodes
                clusterNetworks = ConvertTo-RangerHashtable -InputObject $storageSnapshot.clusterNetworks
                adapters        = ConvertTo-RangerHashtable -InputObject $flattenedAdapters
                vSwitches       = ConvertTo-RangerHashtable -InputObject $flattenedSwitches
                hostVirtualNics = ConvertTo-RangerHashtable -InputObject $flattenedHostVirtualNics
                intents         = ConvertTo-RangerHashtable -InputObject $flattenedIntents
                intentOverrides = ConvertTo-RangerHashtable -InputObject $intentOverridesByNode
                dcb             = ConvertTo-RangerHashtable -InputObject $dcbByNode
                lldpNeighbors   = ConvertTo-RangerHashtable -InputObject $lldpByNode
                dns             = ConvertTo-RangerHashtable -InputObject $flattenedDns
                ipAddresses     = ConvertTo-RangerHashtable -InputObject $flattenedIpAddresses
                routes          = ConvertTo-RangerHashtable -InputObject $flattenedRoutes
                vlan            = ConvertTo-RangerHashtable -InputObject $flattenedVlan
                proxy           = ConvertTo-RangerHashtable -InputObject $proxyByNode
                firewall        = ConvertTo-RangerHashtable -InputObject @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; profiles = $_.firewall } })
                sdn             = ConvertTo-RangerHashtable -InputObject $flattenedSdn
                switchConfig    = ConvertTo-RangerHashtable -InputObject $deviceImport.switchConfig
                firewallConfig  = ConvertTo-RangerHashtable -InputObject $deviceImport.firewallConfig
                summary         = $networkSummary
            }
        }
        Findings      = @($findings)
        Relationships = @()
        RawEvidence   = [ordered]@{
            storage = ConvertTo-RangerHashtable -InputObject $storageSnapshot
            network = ConvertTo-RangerHashtable -InputObject $networkNodes
        }
    }
}