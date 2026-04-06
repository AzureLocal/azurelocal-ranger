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
                physicalDisks = if (Get-Command -Name Get-PhysicalDisk -ErrorAction SilentlyContinue) { Get-PhysicalDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus, MediaType, Size, SerialNumber, Usage } else { @() }
                virtualDisks = if (Get-Command -Name Get-VirtualDisk -ErrorAction SilentlyContinue) { Get-VirtualDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus, ResiliencySettingName, Size, FootprintOnPool } else { @() }
                volumes = if (Get-Command -Name Get-Volume -ErrorAction SilentlyContinue) { Get-Volume | Select-Object DriveLetter, FileSystemLabel, FileSystem, HealthStatus, SizeRemaining, Size } else { @() }
                csvs = if (Get-Command -Name Get-ClusterSharedVolume -ErrorAction SilentlyContinue) { Get-ClusterSharedVolume | Select-Object Name, State, OwnerNode } else { @() }
                qos = if (Get-Command -Name Get-StorageQosPolicy -ErrorAction SilentlyContinue) { Get-StorageQosPolicy | Select-Object Name, PolicyId, PolicyType, MinimumIops, MaximumIops } else { @() }
                sofs = if (Get-Command -Name Get-SmbShare -ErrorAction SilentlyContinue) { Get-SmbShare | Where-Object { $_.ContinuouslyAvailable } | Select-Object Name, Path, ScopeName, ContinuouslyAvailable } else { @() }
                replica = if (Get-Command -Name Get-SRGroup -ErrorAction SilentlyContinue) { Get-SRGroup | Select-Object Name, ReplicationMode, LastInSyncTime, State } else { @() }
                clusterNetworks = if (Get-Command -Name Get-ClusterNetwork -ErrorAction SilentlyContinue) { Get-ClusterNetwork | Select-Object Name, Role, Address, AddressMask, State } else { @() }
            }
        }
    }

    $networkNodes = @(
        Invoke-RangerSafeAction -Label 'Networking inventory snapshot' -DefaultValue @() -ScriptBlock {
            Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -ScriptBlock {
                $proxy = try { netsh winhttp show proxy | Out-String } catch { $null }
                [ordered]@{
                    node          = $env:COMPUTERNAME
                    adapters      = if (Get-Command -Name Get-NetAdapter -ErrorAction SilentlyContinue) { Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress } else { @() }
                    vSwitches     = if (Get-Command -Name Get-VMSwitch -ErrorAction SilentlyContinue) { Get-VMSwitch | Select-Object Name, SwitchType, NetAdapterInterfaceDescriptions, AllowManagementOS } else { @() }
                    hostVirtualNics = if (Get-Command -Name Get-VMNetworkAdapter -ErrorAction SilentlyContinue) { Get-VMNetworkAdapter -ManagementOS | Select-Object Name, SwitchName, Status, IPAddresses } else { @() }
                    intents       = if (Get-Command -Name Get-NetIntent -ErrorAction SilentlyContinue) { Get-NetIntent | Select-Object Name, ClusterName, IsStorageIntent, IsComputeIntent } else { @() }
                    dns           = if (Get-Command -Name Get-DnsClientServerAddress -ErrorAction SilentlyContinue) { Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object InterfaceAlias, ServerAddresses } else { @() }
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

    $findings = New-Object System.Collections.ArrayList
    $unhealthyDisks = @($storageSnapshot.physicalDisks | Where-Object { $_.HealthStatus -and $_.HealthStatus -ne 'Healthy' })
    if ($unhealthyDisks.Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Physical disks report a non-healthy state' -Description 'The storage collector found one or more disks that were not healthy.' -AffectedComponents (@($unhealthyDisks | ForEach-Object { $_.FriendlyName })) -CurrentState "$($unhealthyDisks.Count) unhealthy disks" -Recommendation 'Inspect failed or degraded disks and review Storage Spaces Direct health before generating an as-built handoff.'))
    }

    $publicFirewallEnabled = @($networkNodes | ForEach-Object { $_.firewall } | Where-Object { $_.Name -eq 'Public' -and $_.Enabled }).Count
    if ($publicFirewallEnabled -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'Public firewall profile is enabled on one or more nodes' -Description 'Host-side firewall posture indicates the Public profile is enabled on at least one node.' -CurrentState "$publicFirewallEnabled nodes with Public firewall enabled" -Recommendation 'Review whether the enabled profile aligns with intended host networking and management access posture.'))
    }

    return @{
        Status        = if ($findings.Count -gt 0) { 'partial' } else { 'success' }
        Domains       = @{
            storage = [ordered]@{
                pools         = ConvertTo-RangerHashtable -InputObject $storageSnapshot.pools
                physicalDisks = ConvertTo-RangerHashtable -InputObject $storageSnapshot.physicalDisks
                virtualDisks  = ConvertTo-RangerHashtable -InputObject $storageSnapshot.virtualDisks
                volumes       = ConvertTo-RangerHashtable -InputObject $storageSnapshot.volumes
                csvs          = ConvertTo-RangerHashtable -InputObject $storageSnapshot.csvs
                qos           = ConvertTo-RangerHashtable -InputObject $storageSnapshot.qos
                sofs          = ConvertTo-RangerHashtable -InputObject $storageSnapshot.sofs
                replica       = ConvertTo-RangerHashtable -InputObject $storageSnapshot.replica
            }
            networking = [ordered]@{
                nodes           = ConvertTo-RangerHashtable -InputObject $networkNodes
                clusterNetworks = ConvertTo-RangerHashtable -InputObject $storageSnapshot.clusterNetworks
                adapters        = ConvertTo-RangerHashtable -InputObject @($networkNodes | ForEach-Object { $_.adapters })
                vSwitches       = ConvertTo-RangerHashtable -InputObject @($networkNodes | ForEach-Object { $_.vSwitches })
                hostVirtualNics = ConvertTo-RangerHashtable -InputObject @($networkNodes | ForEach-Object { $_.hostVirtualNics })
                intents         = ConvertTo-RangerHashtable -InputObject @($networkNodes | ForEach-Object { $_.intents })
                dns             = ConvertTo-RangerHashtable -InputObject @($networkNodes | ForEach-Object { $_.dns })
                proxy           = ConvertTo-RangerHashtable -InputObject @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; value = $_.proxy } })
                firewall        = ConvertTo-RangerHashtable -InputObject @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; profiles = $_.firewall } })
                sdn             = ConvertTo-RangerHashtable -InputObject @($networkNodes | ForEach-Object { $_.sdn })
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