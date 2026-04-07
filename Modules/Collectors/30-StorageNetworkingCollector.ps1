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
                # Issue #58: Expanded pool, physical disk, virtual disk, volume collections
                pools = if (Get-Command -Name Get-StoragePool -ErrorAction SilentlyContinue) {
                    @(Get-StoragePool | Where-Object { -not $_.IsPrimordial } | ForEach-Object {
                        $p = $_
                        [ordered]@{
                            friendlyName                = $p.FriendlyName
                            healthStatus                = [string]$p.HealthStatus
                            operationalStatus           = [string]$p.OperationalStatus
                            sizeGiB                     = [math]::Round($p.Size / 1GB, 2)
                            allocatedSizeGiB            = [math]::Round($p.AllocatedSize / 1GB, 2)
                            provisionedCapacityGiB      = if ($p.ProvisionedCapacity -gt 0) { [math]::Round($p.ProvisionedCapacity / 1GB, 2) } else { $null }
                            faultDomainAwarenessDefault = [string]$p.FaultDomainAwarenessDefault
                            retiredPhysicalDiskCount    = $p.RetiredPhysicalDiskCount
                            readCacheSize               = $p.ReadCacheSize
                            isTiered                    = $p.IsTiered
                            isPrimordial                = $p.IsPrimordial
                        }
                    })
                } else { @() }
                physicalDisks = if (Get-Command -Name Get-PhysicalDisk -ErrorAction SilentlyContinue) {
                    @(Get-PhysicalDisk | ForEach-Object {
                        $d = $_
                        [ordered]@{
                            friendlyName       = $d.FriendlyName
                            healthStatus       = [string]$d.HealthStatus
                            operationalStatus  = [string]$d.OperationalStatus
                            mediaType          = [string]$d.MediaType
                            sizeGiB            = [math]::Round($d.Size / 1GB, 2)
                            serialNumber       = $d.SerialNumber
                            usage              = [string]$d.Usage
                            slotNumber         = $d.SlotNumber
                            canPool            = $d.CanPool
                            cannotPoolReason   = $d.CannotPoolReason
                            busType            = [string]$d.BusType
                            manufacturer       = $d.Manufacturer
                            model              = $d.Model
                        }
                    })
                } else { @() }
                physicalDiskReliability = if (Get-Command -Name Get-StorageReliabilityCounter -ErrorAction SilentlyContinue) {
                    @(try { Get-PhysicalDisk -ErrorAction SilentlyContinue | Get-StorageReliabilityCounter -ErrorAction Stop | Select-Object DeviceId, Wear, Temperature, ReadErrors, WriteErrors, PowerOnHours, ReadLatencyMax, WriteLatencyMax } catch { @() })
                } else { @() }
                virtualDisks = if (Get-Command -Name Get-VirtualDisk -ErrorAction SilentlyContinue) {
                    @(Get-VirtualDisk -ErrorAction SilentlyContinue | ForEach-Object {
                        $vd = $_
                        [ordered]@{
                            friendlyName       = $vd.FriendlyName
                            healthStatus       = [string]$vd.HealthStatus
                            operationalStatus  = [string]$vd.OperationalStatus
                            resiliencySettingName = $vd.ResiliencySettingName
                            sizeGiB            = [math]::Round($vd.Size / 1GB, 2)
                            footprintOnPoolGiB = [math]::Round($vd.FootprintOnPool / 1GB, 2)
                            numberOfDataCopies = $vd.NumberOfDataCopies
                            numberOfColumns    = $vd.NumberOfColumns
                            interleave         = $vd.Interleave
                            isEnclosureAware   = $vd.IsEnclosureAware
                            provisioningType   = [string]$vd.ProvisioningType
                            writeCacheSize     = $vd.WriteCacheSize
                            uniqueId           = $vd.UniqueId
                        }
                    })
                } else { @() }
                volumes = if (Get-Command -Name Get-Volume -ErrorAction SilentlyContinue) {
                    @(Get-Volume -ErrorAction SilentlyContinue | ForEach-Object {
                        $v = $_
                        [ordered]@{
                            driveLetter        = $v.DriveLetter
                            fileSystemLabel    = $v.FileSystemLabel
                            fileSystem         = $v.FileSystem
                            fileSystemType     = [string]$v.FileSystemType
                            healthStatus       = [string]$v.HealthStatus
                            sizeGiB            = [math]::Round($v.Size / 1GB, 2)
                            sizeRemainingGiB   = [math]::Round($v.SizeRemaining / 1GB, 2)
                            dedupMode          = [string]$v.DedupMode
                            driveType          = [string]$v.DriveType
                            path               = $v.Path
                        }
                    })
                } else { @() }
                dedupStatus = if (Get-Command -Name Get-DedupStatus -ErrorAction SilentlyContinue) {
                    @(try { Get-DedupStatus -ErrorAction Stop | Select-Object Volume, SavingsRate, SavedSpace, OptimizedFilesCount, LastOptimizationTime, Status } catch { @() })
                } else { @() }
                cacheConfig = if (Get-Command -Name Get-ClusterS2D -ErrorAction SilentlyContinue) {
                    try { Get-ClusterS2D -ErrorAction Stop | Select-Object CacheState, CacheBehavior, CacheModeSSD, CacheModeHDD, CachePageSizeKBytes, CacheMetadataReserveBytes, AutoConfig } catch { $null }
                } else { $null }
                scrubSchedule = if (Get-Command -Name Get-ScheduledTask -ErrorAction SilentlyContinue) {
                    @(try { Get-ScheduledTask -TaskPath '\Microsoft\Windows\Data Integrity Scan\' -ErrorAction SilentlyContinue | Select-Object TaskName, TaskPath, State, Description } catch { @() })
                } else { @() }
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
                # Issue #59: Expand proxy to structured fields early so it can be used below
                $proxyRaw = try { netsh winhttp show proxy | Out-String } catch { $null }
                $proxyEnvHttp = [System.Environment]::GetEnvironmentVariable('HTTP_PROXY')
                $proxyEnvHttps = [System.Environment]::GetEnvironmentVariable('HTTPS_PROXY')
                $proxyEnvNoProxy = [System.Environment]::GetEnvironmentVariable('NO_PROXY')
                $proxyServer = if ($proxyRaw -match 'Proxy Server\(s\)\s*:\s*(.+)') { $Matches[1].Trim() } else { $null }
                $proxyBypassRaw = if ($proxyRaw -match 'Bypass List\s*:\s*(.+)') { $Matches[1].Trim() } else { $null }
                $proxyDirect = $proxyRaw -match 'Direct access'
                $proxyDetail = [ordered]@{
                    winhttp          = $proxyServer
                    winhttp_bypass   = $proxyBypassRaw
                    isDirect         = $proxyDirect
                    envHttpProxy     = $proxyEnvHttp
                    envHttpsProxy    = $proxyEnvHttps
                    envNoProxy       = $proxyEnvNoProxy
                    proxyConfigured  = -not $proxyDirect -or -not [string]::IsNullOrWhiteSpace($proxyEnvHttps)
                    rawWinhttp       = $proxyRaw
                }
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
                # Issue #59: SMB configuration depth and Live Migration settings
                $smbConfig = [ordered]@{
                    serverConfig    = if (Get-Command -Name Get-SmbServerConfiguration -ErrorAction SilentlyContinue) {
                        try { Get-SmbServerConfiguration -ErrorAction Stop | Select-Object EnableSMBQUIC, RequireSecuritySignature, EncryptData, AutoDisconnectTimeout, EnableMultiChannel } catch { $null }
                    } else { $null }
                    multichannelEnabled = if (Get-Command -Name Get-SmbMultichannelConfiguration -ErrorAction SilentlyContinue) {
                        try { (Get-SmbMultichannelConfiguration -ErrorAction Stop).EnableMultiChannel } catch { $null }
                    } else { $null }
                    smbDirectEnabled = if (Get-Command -Name Get-SmbDirectConfiguration -ErrorAction SilentlyContinue) {
                        try { (Get-SmbDirectConfiguration -ErrorAction Stop).Enabled } catch { $null }
                    } else { $null }
                    activeConnections = if (Get-Command -Name Get-SmbMultichannelConnection -ErrorAction SilentlyContinue) {
                        try { @(Get-SmbMultichannelConnection -ErrorAction Stop | Select-Object ServerName, ClientInterface, ServerInterface, Protocol, Selected, ConstrainedBy) } catch { @() }
                    } else { @() }
                }
                $liveMigration = if (Get-Command -Name Get-VMHost -ErrorAction SilentlyContinue) {
                    try {
                        $vmh = Get-VMHost -ErrorAction Stop
                        $smbBwLimit = if (Get-Command -Name Get-SmbBandwidthLimit -ErrorAction SilentlyContinue) { try { @(Get-SmbBandwidthLimit -ErrorAction Stop) } catch { @() } } else { @() }
                        [ordered]@{
                            liveMigrationEnabled = $vmh.VirtualMachineMigrationEnabled
                            maxMigrations        = $vmh.MaximumVirtualMachineMigrations
                            maxStorageMigrations = $vmh.MaximumStorageMigrations
                            performanceOption    = [string]$vmh.VirtualMachineMigrationPerformanceOption
                            useAnyNetworkForMigration = $vmh.UseAnyNetworkForMigration
                            liveMigrationNetworks = @(if (Get-Command -Name Get-VMHostSupportedVersion -ErrorAction SilentlyContinue) { @() } else { @() })
                            smbBandwidthLimits   = @($smbBwLimit)
                        }
                    } catch { $null }
                } else { $null }
                # Issue #61: DNS depth with conditional forwarders
                $dnsForwarders = if (Get-Command -Name Get-DnsServerForwarder -ErrorAction SilentlyContinue) {
                    try { @(Get-DnsServerForwarder -ErrorAction Stop | Select-Object IPAddress, UseRootHint, Timeout, EnableReordering) } catch { @() }
                } else { @() }
                $dnsZones = if (Get-Command -Name Get-DnsServerZone -ErrorAction SilentlyContinue) {
                    try { @(Get-DnsServerZone -ErrorAction Stop | Where-Object { $_.ZoneType -eq 'Forwarder' } | Select-Object ZoneName, ZoneType, MasterServers, ZoneFile) } catch { @() }
                } else { @() }
                # Issue #61: Firewall rule audit for Azure Local required ports
                $requiredFirewallRules = @(
                    @{ Name = 'WinRM-HTTP';   Port = 5985;  Protocol = 'TCP'; Description = 'WinRM HTTP' }
                    @{ Name = 'WinRM-HTTPS';  Port = 5986;  Protocol = 'TCP'; Description = 'WinRM HTTPS' }
                    @{ Name = 'SMB';          Port = 445;   Protocol = 'TCP'; Description = 'SMB file sharing' }
                    @{ Name = 'Cluster';      Port = 3343;  Protocol = 'TCP'; Description = 'Cluster heartbeat' }
                    @{ Name = 'HyperV-RPC';   Port = 2179;  Protocol = 'TCP'; Description = 'Hyper-V VM Connect' }
                    @{ Name = 'HyperV-LIVE';  Port = 6600;  Protocol = 'TCP'; Description = 'Hyper-V Live Migration' }
                    @{ Name = 'RPC-EP';       Port = 135;   Protocol = 'TCP'; Description = 'RPC Endpoint Mapper' }
                    @{ Name = 'NTP';          Port = 123;   Protocol = 'UDP'; Description = 'Network Time Protocol' }
                    @{ Name = 'Arc-HTTPS';    Port = 443;   Protocol = 'TCP'; Description = 'Arc agent and Azure services' }
                )
                $firewallRuleAudit = if (Get-Command -Name Get-NetFirewallRule -ErrorAction SilentlyContinue) {
                    @($requiredFirewallRules | ForEach-Object {
                        $req = $_
                        $matchingRules = @(try {
                            Get-NetFirewallRule -Enabled True -Direction Inbound -ErrorAction SilentlyContinue | ForEach-Object {
                                $r = $_
                                $portFilter = try { $r | Get-NetFirewallPortFilter -ErrorAction Stop } catch { $null }
                                if ($portFilter -and ($portFilter.LocalPort -eq $req.Port -or $portFilter.LocalPort -eq 'Any') -and ($portFilter.Protocol -eq $req.Protocol -or $portFilter.Protocol -eq 'Any')) { $r }
                            }
                        } catch { @() })
                        [ordered]@{
                            requiredPort    = $req.Port
                            protocol        = $req.Protocol
                            description     = $req.Description
                            rulesFound      = @($matchingRules).Count
                            ruleNames       = @($matchingRules | Select-Object -First 3 | ForEach-Object { $_.Name })
                            satisfied       = @($matchingRules).Count -gt 0
                        }
                    })
                } else { @() }
                $inboxDriverAdapters = if (Get-Command -Name Get-NetAdapter -ErrorAction SilentlyContinue) {
                    @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.DriverProvider -eq 'Microsoft' -and $_.Status -eq 'Up' } | Select-Object Name, InterfaceDescription, DriverProvider, DriverVersion)
                } else { @() }
                [ordered]@{
                    node          = $env:COMPUTERNAME
                    # Issue #59: Expanded adapters with driver info
                    adapters      = if (Get-Command -Name Get-NetAdapter -ErrorAction SilentlyContinue) {
                        @(Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
                            $a = $_
                            $advProps = @{}
                            try { Get-NetAdapterAdvancedProperty -Name $a.Name -ErrorAction SilentlyContinue | ForEach-Object { $advProps[$_.RegistryKeyword] = $_.RegistryValue } } catch {}
                            [ordered]@{
                                name                 = $a.Name
                                interfaceDescription = $a.InterfaceDescription
                                status               = [string]$a.Status
                                linkSpeed            = $a.LinkSpeed
                                macAddress           = $a.MacAddress
                                mtuSize              = $a.MtuSize
                                mediaType            = [string]$a.MediaType
                                driverProvider       = $a.DriverProvider
                                driverFileName       = $a.DriverFileName
                                driverVersion        = $a.DriverVersionString
                                driverDate           = $a.DriverDate
                                vlanId               = $a.VlanID
                                isInboxDriver        = $a.DriverProvider -eq 'Microsoft'
                                rdmaCapable          = if ($advProps.ContainsKey('*NetworkDirect')) { $advProps['*NetworkDirect'] -ne '0' } else { $null }
                                sriovCapable         = if ($advProps.ContainsKey('*SRIOV')) { $advProps['*SRIOV'] -ne '0' } else { $null }
                            }
                        })
                    } else { @() }
                    # Issue #59: Expanded vSwitch detail with SET, SR-IOV, bandwidth, extensions
                    vSwitches     = if (Get-Command -Name Get-VMSwitch -ErrorAction SilentlyContinue) {
                        @(Get-VMSwitch -ErrorAction SilentlyContinue | ForEach-Object {
                            $sw = $_
                            $exts = @(try { $sw | Get-VMSwitchExtension -ErrorAction Stop | Select-Object Name, Vendor, Enabled, Running } catch { @() })
                            [ordered]@{
                                name                     = $sw.Name
                                switchType               = [string]$sw.SwitchType
                                allowManagementOS        = $sw.AllowManagementOS
                                netAdapterNames          = @($sw.NetAdapterInterfaceDescriptions)
                                bandwidthReservationMode = [string]$sw.BandwidthReservationMode
                                iovEnabled               = $sw.IovEnabled
                                iovQueuePairCount        = $sw.IovQueuePairCount
                                embeddedTeamingEnabled   = $sw.EmbeddedTeamingEnabled
                                extensions               = @($exts)
                            }
                        })
                    } else { @() }
                    # Issue #59: Expanded host vNIC with RDMA, IP, VLAN
                    hostVirtualNics = if (Get-Command -Name Get-VMNetworkAdapter -ErrorAction SilentlyContinue) {
                        @(Get-VMNetworkAdapter -ManagementOS -ErrorAction SilentlyContinue | ForEach-Object {
                            $vnic = $_
                            $rdmaAdapter = if (Get-Command -Name Get-NetAdapterRdma -ErrorAction SilentlyContinue) { try { Get-NetAdapterRdma -Name $vnic.Name -ErrorAction Stop } catch { $null } } else { $null }
                            $ipConf = try { Get-NetIPConfiguration -InterfaceAlias $vnic.Name -ErrorAction Stop | Select-Object -First 1 } catch { $null }
                            $vlan = try { Get-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName $vnic.Name -ErrorAction Stop | Select-Object -First 1 } catch { $null }
                            [ordered]@{
                                name            = $vnic.Name
                                switchName      = $vnic.SwitchName
                                status          = [string]$vnic.Status
                                ipAddresses     = @($vnic.IPAddresses)
                                ipAddress       = if ($ipConf) { $ipConf.IPv4Address.IPAddress } else { $null }
                                prefixLength    = if ($ipConf) { $ipConf.IPv4Address.PrefixLength } else { $null }
                                vlanId          = if ($vlan) { $vlan.AccessVlanId } else { $null }
                                rdmaEnabled     = if ($rdmaAdapter) { $rdmaAdapter.Enabled } else { $null }
                                rdmaOperational = if ($rdmaAdapter) { $rdmaAdapter.OperationalState -eq 'Active' } else { $null }
                                isManagementNic = $vnic.IsManagementOS
                            }
                        })
                    } else { @() }
                    smbConfig     = $smbConfig
                    liveMigration = $liveMigration
                    intents       = if (Get-Command -Name Get-NetIntent -ErrorAction SilentlyContinue) { Get-NetIntent | Select-Object Name, ClusterName, IsStorageIntent, IsComputeIntent } else { @() }
                    intentOverrides = @($intentOverrides)
                    dcb           = $dcb
                    lldpNeighbors = @($lldpNeighbors)
                    dns           = if (Get-Command -Name Get-DnsClientServerAddress -ErrorAction SilentlyContinue) { Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object InterfaceAlias, ServerAddresses } else { @() }
                    dnsForwarders = @($dnsForwarders)
                    dnsConditionalForwarders = @($dnsZones)
                    ipAddresses   = if (Get-Command -Name Get-NetIPAddress -ErrorAction SilentlyContinue) { Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, IPAddress, PrefixLength, AddressState } else { @() }
                    routes        = if (Get-Command -Name Get-NetRoute -ErrorAction SilentlyContinue) { Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 50 DestinationPrefix, NextHop, InterfaceAlias, RouteMetric } else { @() }
                    vlan          = if (Get-Command -Name Get-VMNetworkAdapterVlan -ErrorAction SilentlyContinue) { Get-VMNetworkAdapterVlan -ManagementOS -ErrorAction SilentlyContinue | Select-Object VMNetworkAdapterName, OperationMode, AccessVlanId, NativeVlanId, AllowedVlanIdList } else { @() }
                    proxy         = $proxyDetail
                    proxyRaw      = $proxyRaw
                    firewall      = if (Get-Command -Name Get-NetFirewallProfile -ErrorAction SilentlyContinue) { Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction } else { @() }
                    firewallRuleAudit = @($firewallRuleAudit)
                    inboxDriverAdapters = @($inboxDriverAdapters)
                    # Issue #60: Full SDN discovery
                    sdn           = if (Get-Command -Name Get-NetworkController -ErrorAction SilentlyContinue) {
                        $ncObj = try { Get-NetworkController -ErrorAction Stop } catch { $null }
                        if ($ncObj) {
                            $ncNodes = @(try { Get-NetworkControllerNode -ErrorAction Stop | Select-Object Name, Server, Status, Fault } catch { @() })
                            $slbMuxes = @(try { Get-NetworkControllerLoadBalancerMux -ErrorAction Stop | Select-Object ResourceId, Status } catch { @() })
                            $rasGateways = @(try { Get-NetworkControllerGateway -ErrorAction Stop | Select-Object ResourceId, GatewayPool, State } catch { @() })
                            $vnets = @(try { Get-NetworkControllerVirtualNetwork -ErrorAction Stop | ForEach-Object { [ordered]@{ resourceId = $_.ResourceId; subnetCount = @($_.Properties.Subnets).Count } } } catch { @() })
                            $nsgs = @(try { Get-NetworkControllerAccessControlList -ErrorAction Stop | ForEach-Object { [ordered]@{ resourceId = $_.ResourceId; ruleCount = @($_.Properties.AclRules).Count } } } catch { @() })
                            $lbs = @(try { Get-NetworkControllerLoadBalancer -ErrorAction Stop | ForEach-Object { [ordered]@{ resourceId = $_.ResourceId; frontendCount = @($_.Properties.FrontendIPConfigurations).Count } } } catch { @() })
                            $logicalNets = @(try { Get-NetworkControllerLogicalNetwork -ErrorAction Stop | Select-Object ResourceId } catch { @() })
                            [ordered]@{
                                deployed            = $true
                                restApiEndpoint     = $ncObj.RestApiEndpoint
                                nodeCount           = @($ncNodes).Count
                                nodes               = @($ncNodes)
                                slbMuxCount         = @($slbMuxes).Count
                                rasGatewayCount     = @($rasGateways).Count
                                virtualNetworkCount = @($vnets).Count
                                nsgCount            = @($nsgs).Count
                                loadBalancerCount   = @($lbs).Count
                                logicalNetworkCount = @($logicalNets).Count
                                slbMuxes            = @($slbMuxes)
                                rasGateways         = @($rasGateways)
                                virtualNetworks     = @($vnets)
                                nsgs                = @($nsgs)
                                loadBalancers       = @($lbs)
                                logicalNetworks     = @($logicalNets)
                            }
                        } else { [ordered]@{ deployed = $false } }
                    } else { [ordered]@{ deployed = $false } }
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
    $sdnByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; sdn = $_.sdn } })
    $proxyByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; proxy = $_.proxy; proxyRaw = $_.proxyRaw } })
    $dcbByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; dcb = $_.dcb } })
    $intentOverridesByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; intentOverrides = $_.intentOverrides } })
    $lldpByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; neighbors = $_.lldpNeighbors } })
    $firewallAuditByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; audit = $_.firewallRuleAudit; inboxDriverAdapters = $_.inboxDriverAdapters } })
    $smbByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; smbConfig = $_.smbConfig; liveMigration = $_.liveMigration } })
    $dnsForwardersByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; forwarders = $_.dnsForwarders; conditionalForwarders = $_.dnsConditionalForwarders } })

    $storageSummary = [ordered]@{
        poolCount           = @($storageSnapshot.pools).Count
        physicalDiskCount   = @($storageSnapshot.physicalDisks).Count
        virtualDiskCount    = @($storageSnapshot.virtualDisks).Count
        volumeCount         = @($storageSnapshot.volumes).Count
        csvCount            = @($storageSnapshot.csvs).Count
        totalPoolCapacityGiB = [math]::Round((@($storageSnapshot.pools | Where-Object { $null -ne $_.sizeGiB } | Measure-Object -Property sizeGiB -Sum).Sum), 2)
        allocatedPoolCapacityGiB = [math]::Round((@($storageSnapshot.pools | Where-Object { $null -ne $_.allocatedSizeGiB } | Measure-Object -Property allocatedSizeGiB -Sum).Sum), 2)
        diskMediaTypes      = @(Get-RangerGroupedCount -Items $storageSnapshot.physicalDisks -PropertyName 'mediaType')
        unhealthyDisks      = @($storageSnapshot.physicalDisks | Where-Object { $_.healthStatus -and $_.healthStatus -ne 'Healthy' }).Count
        canPoolDisks        = @($storageSnapshot.physicalDisks | Where-Object { $_.canPool }).Count
        retiredDisks        = @($storageSnapshot.physicalDisks | Where-Object { $_.operationalStatus -match 'Retiring|PredictiveFailure' }).Count
        resiliencyModes     = @(Get-RangerGroupedCount -Items $storageSnapshot.virtualDisks -PropertyName 'resiliencySettingName')
        tierCount           = @($storageSnapshot.tiers).Count
        storageJobCount     = @($storageSnapshot.jobs).Count
        activeHealthFaultCount = @($storageSnapshot.healthFaults).Count
        sofsShareCount      = @($storageSnapshot.sofs).Count
        replicaGroupCount   = @($storageSnapshot.replicaDepth).Count
        qosFlowCount        = @($storageSnapshot.qosFlows).Count
        cacheEnabled        = if ($storageSnapshot.cacheConfig) { $storageSnapshot.cacheConfig.CacheState -eq 'Enabled' } else { $null }
        dedupVolumes        = @($storageSnapshot.dedupStatus | Where-Object { $_.Status -ne 'Disabled' }).Count
    }

    $networkSummary = [ordered]@{
        nodeCount         = @($networkNodes).Count
        clusterNetworkCount = @($storageSnapshot.clusterNetworks).Count
        adapterCount      = $flattenedAdapters.Count
        adapterStates     = @(Get-RangerGroupedCount -Items $flattenedAdapters -PropertyName 'status')
        vSwitchCount      = $flattenedSwitches.Count
        intentCount       = $flattenedIntents.Count
        dnsServers        = @($flattenedDns | ForEach-Object { @($_.ServerAddresses) } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        routeCount        = $flattenedRoutes.Count
        vlanCount         = $flattenedVlan.Count
        proxyConfiguredNodes = @($proxyByNode | Where-Object { $_.proxy -and $_.proxy.proxyConfigured }).Count
        sdnDeployed       = @($sdnByNode | Where-Object { $_.sdn.deployed }).Count -gt 0
        importedSwitchConfigCount   = @($deviceImport.switchConfig).Count
        importedFirewallConfigCount = @($deviceImport.firewallConfig).Count
        dcbConfiguredNodes = @($dcbByNode | Where-Object { $_.dcb.trafficClasses -and @($_.dcb.trafficClasses).Count -gt 0 }).Count
        lldpNeighborCount  = @($lldpByNode | ForEach-Object { @($_.neighbors).Count } | Measure-Object -Sum).Sum
        inboxDriverAdapterCount = @($networkNodes | ForEach-Object { @($_.inboxDriverAdapters).Count } | Measure-Object -Sum).Sum
        firewallRulesAudited = @($networkNodes | Select-Object -First 1 | ForEach-Object { @($_.firewallRuleAudit).Count }).Sum
        firewallRequiredPortsSatisfied = @($networkNodes | Select-Object -First 1 | ForEach-Object { @($_.firewallRuleAudit | Where-Object { $_.satisfied }).Count }).Sum
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

    $allInboxAdapters = @($networkNodes | ForEach-Object { @($_.inboxDriverAdapters) })
    if ($allInboxAdapters.Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Adapters using inbox (Microsoft) drivers detected' -Description "$($allInboxAdapters.Count) network adapter(s) are using inbox Microsoft drivers, which are not supported/qualified for Azure Local production workloads." -AffectedComponents (@($allInboxAdapters | ForEach-Object { $_.Name })) -CurrentState 'Inbox driver on production-facing NIC' -Recommendation 'Install vendor-supplied NIC drivers from the OEM or Windows Server Catalog. Inbox drivers are unsupported for Storage and compute traffic on Azure Local.'))
    }

    $retiredDisks = @($storageSnapshot.physicalDisks | Where-Object { $_.operationalStatus -match 'Retiring|PredictiveFailure' })
    if ($retiredDisks.Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Physical disks flagged for retirement' -Description "$($retiredDisks.Count) disk(s) have an operational status indicating predictive failure or retirement." -AffectedComponents (@($retiredDisks | ForEach-Object { $_.friendlyName })) -CurrentState "$($retiredDisks.Count) disks in Retiring/PredictiveFailure state" -Recommendation 'Replace disks flagged for retirement before formal handoff to prevent data loss.'))
    }

    return @{
        Status        = if ($findings.Count -gt 0) { 'partial' } else { 'success' }
        Domains       = @{
            storage = [ordered]@{
                pools              = ConvertTo-RangerHashtable -InputObject $storageSnapshot.pools
                physicalDisks      = ConvertTo-RangerHashtable -InputObject $storageSnapshot.physicalDisks
                physicalDiskReliability = ConvertTo-RangerHashtable -InputObject $storageSnapshot.physicalDiskReliability
                virtualDisks       = ConvertTo-RangerHashtable -InputObject $storageSnapshot.virtualDisks
                volumes            = ConvertTo-RangerHashtable -InputObject $storageSnapshot.volumes
                dedupStatus        = ConvertTo-RangerHashtable -InputObject $storageSnapshot.dedupStatus
                cacheConfig        = ConvertTo-RangerHashtable -InputObject $storageSnapshot.cacheConfig
                scrubSchedule      = ConvertTo-RangerHashtable -InputObject $storageSnapshot.scrubSchedule
                tiers              = ConvertTo-RangerHashtable -InputObject $storageSnapshot.tiers
                subsystems         = ConvertTo-RangerHashtable -InputObject $storageSnapshot.subsystems
                resiliency         = ConvertTo-RangerHashtable -InputObject $storageSnapshot.resiliency
                jobs               = ConvertTo-RangerHashtable -InputObject $storageSnapshot.jobs
                csvs               = ConvertTo-RangerHashtable -InputObject $storageSnapshot.csvs
                qos                = ConvertTo-RangerHashtable -InputObject $storageSnapshot.qos
                qosFlows           = ConvertTo-RangerHashtable -InputObject $storageSnapshot.qosFlows
                healthFaults       = ConvertTo-RangerHashtable -InputObject $storageSnapshot.healthFaults
                sofs               = ConvertTo-RangerHashtable -InputObject $storageSnapshot.sofs
                sofsDetail         = ConvertTo-RangerHashtable -InputObject $storageSnapshot.sofsDetail
                replica            = ConvertTo-RangerHashtable -InputObject $storageSnapshot.replica
                replicaDepth       = ConvertTo-RangerHashtable -InputObject $storageSnapshot.replicaDepth
                summary            = $storageSummary
            }
            networking = [ordered]@{
                nodes                = ConvertTo-RangerHashtable -InputObject $networkNodes
                clusterNetworks      = ConvertTo-RangerHashtable -InputObject $storageSnapshot.clusterNetworks
                adapters             = ConvertTo-RangerHashtable -InputObject $flattenedAdapters
                vSwitches            = ConvertTo-RangerHashtable -InputObject $flattenedSwitches
                hostVirtualNics      = ConvertTo-RangerHashtable -InputObject $flattenedHostVirtualNics
                intents              = ConvertTo-RangerHashtable -InputObject $flattenedIntents
                intentOverrides      = ConvertTo-RangerHashtable -InputObject $intentOverridesByNode
                dcb                  = ConvertTo-RangerHashtable -InputObject $dcbByNode
                lldpNeighbors        = ConvertTo-RangerHashtable -InputObject $lldpByNode
                dns                  = ConvertTo-RangerHashtable -InputObject $flattenedDns
                dnsForwarders        = ConvertTo-RangerHashtable -InputObject $dnsForwardersByNode
                ipAddresses          = ConvertTo-RangerHashtable -InputObject $flattenedIpAddresses
                routes               = ConvertTo-RangerHashtable -InputObject $flattenedRoutes
                vlan                 = ConvertTo-RangerHashtable -InputObject $flattenedVlan
                proxy                = ConvertTo-RangerHashtable -InputObject $proxyByNode
                firewall             = ConvertTo-RangerHashtable -InputObject @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; profiles = $_.firewall } })
                firewallRuleAudit    = ConvertTo-RangerHashtable -InputObject $firewallAuditByNode
                sdn                  = ConvertTo-RangerHashtable -InputObject $sdnByNode
                smbConfig            = ConvertTo-RangerHashtable -InputObject $smbByNode
                switchConfig         = ConvertTo-RangerHashtable -InputObject $deviceImport.switchConfig
                firewallConfig       = ConvertTo-RangerHashtable -InputObject $deviceImport.firewallConfig
                summary              = $networkSummary
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