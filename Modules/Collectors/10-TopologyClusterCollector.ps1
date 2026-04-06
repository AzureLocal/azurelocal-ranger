function Invoke-RangerTopologyClusterCollector {
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

    $clusterSnapshot = Invoke-RangerSafeAction -Label 'Cluster foundation snapshot' -DefaultValue $null -ScriptBlock {
        Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -SingleTarget -ScriptBlock {
            $cluster = if (Get-Command -Name Get-Cluster -ErrorAction SilentlyContinue) {
                Get-Cluster | Select-Object Name, Id, Domain, ClusterFunctionalLevel, S2DEnabled, CrossSubnetDelay, CrossSiteDelay, DynamicQuorum
            }

            $quorum = if (Get-Command -Name Get-ClusterQuorum -ErrorAction SilentlyContinue) {
                $value = Get-ClusterQuorum
                [ordered]@{
                    quorumType         = $value.QuorumType
                    quorumResource     = $value.QuorumResource
                    quorumResourcePath = $value.QuorumResourcePath
                }
            }

            $faultDomains = if (Get-Command -Name Get-ClusterFaultDomain -ErrorAction SilentlyContinue) {
                Get-ClusterFaultDomain | Select-Object Name, FaultDomainType, Location
            }
            else {
                @()
            }

            $networks = if (Get-Command -Name Get-ClusterNetwork -ErrorAction SilentlyContinue) {
                Get-ClusterNetwork | Select-Object Name, Role, Address, AddressMask, State, Metric, AutoMetric
            }
            else {
                @()
            }

            $csvs = if (Get-Command -Name Get-ClusterSharedVolume -ErrorAction SilentlyContinue) {
                Get-ClusterSharedVolume | Select-Object Name, State, OwnerNode
            }
            else {
                @()
            }

            $cau = if (Get-Command -Name Get-CauClusterRole -ErrorAction SilentlyContinue) {
                Get-CauClusterRole | Select-Object ClusterName, MaxRetriesPerNode, RequireAllNodesOnline, StartDate, DaysOfWeek
            }

            $events = if (Get-Command -Name Get-WinEvent -ErrorAction SilentlyContinue) {
                Get-WinEvent -LogName 'Microsoft-Windows-FailoverClustering/Operational' -MaxEvents 20 -ErrorAction SilentlyContinue |
                    Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message
            }
            else {
                @()
            }

            [ordered]@{
                cluster      = $cluster
                quorum       = $quorum
                faultDomains = @($faultDomains)
                networks     = @($networks)
                csvs         = @($csvs)
                cau          = $cau
                events       = @($events)
            }
        }
    }

    $nodeSnapshots = @(
        Invoke-RangerSafeAction -Label 'Cluster node inventory' -DefaultValue @() -ScriptBlock {
            Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -ScriptBlock {
                $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
                $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
                $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
                $clusterNodeState = if (Get-Command -Name Get-ClusterNode -ErrorAction SilentlyContinue) {
                    (Get-ClusterNode -Name $env:COMPUTERNAME -ErrorAction SilentlyContinue).State
                }

                [ordered]@{
                    name           = $env:COMPUTERNAME
                    fqdn           = if ($computerSystem.DNSHostName -and $computerSystem.Domain) { "{0}.{1}" -f $computerSystem.DNSHostName, $computerSystem.Domain } else { $computerSystem.DNSHostName }
                    state          = if ($clusterNodeState) { [string]$clusterNodeState } else { 'Up' }
                    uptimeHours    = if ($operatingSystem.LastBootUpTime) { [math]::Round(((Get-Date) - $operatingSystem.LastBootUpTime).TotalHours, 2) } else { $null }
                    osCaption      = $operatingSystem.Caption
                    osVersion      = $operatingSystem.Version
                    lastBootUpTime = $operatingSystem.LastBootUpTime
                    manufacturer   = $computerSystem.Manufacturer
                    model          = $computerSystem.Model
                    partOfDomain   = [bool]$computerSystem.PartOfDomain
                    domain         = $computerSystem.Domain
                    biosVersion    = if ($bios) { @($bios.SMBIOSBIOSVersion) -join ', ' } else { $null }
                }
            }
        }
    )

    if (-not $clusterSnapshot -and $nodeSnapshots.Count -eq 0) {
        throw 'Cluster topology collector could not gather any usable data.'
    }

    $deploymentType = if (-not [string]::IsNullOrWhiteSpace((Get-RangerHintValue -Config $Config -Name 'deploymentType'))) { [string](Get-RangerHintValue -Config $Config -Name 'deploymentType') } elseif ($clusterSnapshot.networks.Count -le 1) { 'switchless' } else { 'hyperconverged' }
    $identityMode = if (-not [string]::IsNullOrWhiteSpace((Get-RangerHintValue -Config $Config -Name 'identityMode'))) { [string](Get-RangerHintValue -Config $Config -Name 'identityMode') } elseif (@($nodeSnapshots | Where-Object { -not $_.partOfDomain }).Count -gt 0) { 'local-key-vault' } else { 'ad' }
    $controlPlaneMode = if (-not [string]::IsNullOrWhiteSpace((Get-RangerHintValue -Config $Config -Name 'controlPlaneMode'))) { [string](Get-RangerHintValue -Config $Config -Name 'controlPlaneMode') } elseif ([string]::IsNullOrWhiteSpace($Config.targets.azure.subscriptionId)) { 'disconnected' } else { 'connected' }
    $storageArchitecture = if ($clusterSnapshot.cluster.S2DEnabled) { 'storage-spaces-direct' } else { 'shared-storage' }
    $networkArchitecture = if ($clusterSnapshot.networks.Count -le 1) { 'switchless' } else { 'switched' }
    $variantMarkers = @()
    if ($deploymentType -eq 'switchless') { $variantMarkers += 'switchless' }
    if ($identityMode -eq 'local-key-vault') { $variantMarkers += 'local-identity' }
    if ($controlPlaneMode -eq 'disconnected') { $variantMarkers += 'disconnected' }

    $healthSummary = [ordered]@{
        totalNodes   = @($nodeSnapshots).Count
        healthyNodes = @($nodeSnapshots | Where-Object { $_.state -eq 'Up' }).Count
        unhealthy    = @($nodeSnapshots | Where-Object { $_.state -ne 'Up' }).Count
    }

    $findings = New-Object System.Collections.ArrayList
    if ($healthSummary.unhealthy -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'One or more cluster nodes are not up' -Description 'The cluster foundation collector detected nodes that were not in the Up state.' -AffectedComponents (@($nodeSnapshots | Where-Object { $_.state -ne 'Up' } | ForEach-Object { $_.name })) -CurrentState "$($healthSummary.unhealthy) nodes not up" -Recommendation 'Review cluster membership, maintenance state, and failover clustering health.'))
    }

    if ($controlPlaneMode -eq 'disconnected') {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'Azure connectivity context is disconnected or undefined' -Description 'The cluster target does not currently advertise an Azure subscription context in the Ranger configuration.' -CurrentState $controlPlaneMode -Recommendation 'Confirm whether this deployment should operate disconnected or if Azure registration metadata is missing from the config.'))
    }

    return @{
        Status        = if ($healthSummary.unhealthy -gt 0) { 'partial' } else { 'success' }
        Topology      = [ordered]@{
            deploymentType     = $deploymentType
            identityMode       = $identityMode
            controlPlaneMode   = $controlPlaneMode
            storageArchitecture = $storageArchitecture
            networkArchitecture = $networkArchitecture
            variantMarkers     = @($variantMarkers)
        }
        Domains       = @{
            clusterNode = [ordered]@{
                cluster       = [ordered]@{
                    name                  = $clusterSnapshot.cluster.Name
                    id                    = $clusterSnapshot.cluster.Id
                    domain                = $clusterSnapshot.cluster.Domain
                    clusterFunctionalLevel = $clusterSnapshot.cluster.ClusterFunctionalLevel
                    s2dEnabled            = $clusterSnapshot.cluster.S2DEnabled
                    dynamicQuorum         = $clusterSnapshot.cluster.DynamicQuorum
                    registrationConfigured = -not [string]::IsNullOrWhiteSpace($Config.targets.azure.subscriptionId)
                }
                nodes         = @($nodeSnapshots)
                quorum        = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.quorum
                faultDomains  = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.faultDomains
                networks      = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.networks
                csvSummary    = [ordered]@{ count = @($clusterSnapshot.csvs).Count; items = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.csvs }
                updatePosture = [ordered]@{ clusterAwareUpdating = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.cau }
                eventSummary  = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.events
                healthSummary = $healthSummary
            }
        }
        Findings      = @($findings)
        Relationships = @()
        RawEvidence   = [ordered]@{
            cluster = ConvertTo-RangerHashtable -InputObject $clusterSnapshot
            nodes   = ConvertTo-RangerHashtable -InputObject $nodeSnapshots
        }
    }
}