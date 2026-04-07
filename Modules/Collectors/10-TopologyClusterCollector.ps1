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

            $groups = if (Get-Command -Name Get-ClusterGroup -ErrorAction SilentlyContinue) {
                Get-ClusterGroup | Select-Object Name, GroupType, State, OwnerNode
            }
            else {
                @()
            }

            $cau = if (Get-Command -Name Get-CauClusterRole -ErrorAction SilentlyContinue) {
                Get-CauClusterRole | Select-Object ClusterName, MaxRetriesPerNode, MaxFailedNodes, RequireAllNodesOnline, StartDate, DaysOfWeek, EnableFirewallRules, RebootMode, SelfUpdating, CauPluginName, CauPluginArguments
            }

            $cauRunHistory = if (Get-Command -Name Get-CauReport -ErrorAction SilentlyContinue) {
                @(try { Get-CauReport -ErrorAction Stop | Sort-Object -Property RunDate -Descending | Select-Object -First 5 Status, LastNodeCompleted, NodeResults, RunDate, Description } catch { @() })
            } else { @() }

            $solutionUpdateEnv = if (Get-Command -Name Get-SolutionUpdateEnvironment -ErrorAction SilentlyContinue) {
                try { Get-SolutionUpdateEnvironment -ErrorAction Stop | Select-Object State, Version, SbeVersion, HardwareModel, LastCheckedForUpdates, LastUpdated, LifecycleUri } catch { $null }
            } else { $null }

            $solutionUpdateHistory = if (Get-Command -Name Get-SolutionUpdateRun -ErrorAction SilentlyContinue) {
                @(try { Get-SolutionUpdateRun -ErrorAction Stop | Sort-Object -Property StartTimeUtc -Descending | Select-Object -First 5 RunId, State, StartTimeUtc, LastUpdatedTimeUtc, Version, Description } catch { @() })
            } elseif (Get-Command -Name Get-SolutionUpdate -ErrorAction SilentlyContinue) {
                @(try { Get-SolutionUpdate -ErrorAction Stop | Where-Object { $_.State -notin @('ReadyToInstall', 'Staged', 'NotApplicable') } | Select-Object -First 5 Version, State, Description, PreparedTime, InstalledTime } catch { @() })
            } else { @() }

            $pendingSolutionUpdates = if (Get-Command -Name Get-SolutionUpdate -ErrorAction SilentlyContinue) {
                @(try { Get-SolutionUpdate -ErrorAction Stop | Where-Object { $_.State -in @('ReadyToInstall', 'Staged') } | Select-Object -First 10 Version, State, Description, PackagePath } catch { @() })
            } else { @() }

            $arcRegistration = if (Get-Command -Name Get-AzureLocalRegistration -ErrorAction SilentlyContinue) {
                try { Get-AzureLocalRegistration -ErrorAction Stop | Select-Object RegistrationStatus, AzureSubscriptionId, AzureResourceName, AzureResourceGroupName, AzureTenantId, HybridSKU, BillingModel, RegistrationDate } catch { $null }
            } elseif (Get-Command -Name Get-AzStackHciRegistration -ErrorAction SilentlyContinue) {
                try { Get-AzStackHciRegistration -ErrorAction Stop | Select-Object RegistrationStatus, AzureSubscriptionId, AzureResourceName, AzureResourceGroupName, AzureTenantId } catch { $null }
            } else { $null }

            $events = if (Get-Command -Name Get-WinEvent -ErrorAction SilentlyContinue) {
                Get-WinEvent -LogName 'Microsoft-Windows-FailoverClustering/Operational' -MaxEvents 20 -ErrorAction SilentlyContinue |
                    Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message
            }
            else {
                @()
            }

            $clusterCreationEvent = if (Get-Command -Name Get-WinEvent -ErrorAction SilentlyContinue) {
                Get-WinEvent -LogName 'Microsoft-Windows-FailoverClustering/Operational' -MaxEvents 1 -Oldest -ErrorAction SilentlyContinue |
                    Select-Object -First 1 TimeCreated
            }

            $release = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
            $licensing = Get-CimInstance -ClassName SoftwareLicensingProduct -ErrorAction SilentlyContinue |
                Where-Object { $_.PartialProductKey -and $_.Name -match 'Windows' } |
                Select-Object -First 5 Name, Description, LicenseStatus, GracePeriodRemaining
            $validationReports = Get-ChildItem -Path (Join-Path $env:SystemRoot 'Cluster\Reports') -Filter '*Test*.htm*' -ErrorAction SilentlyContinue |
                Sort-Object -Property LastWriteTime -Descending |
                Select-Object -First 5 Name, FullName, LastWriteTime, Length
            $lifecycleServices = @(
                foreach ($serviceName in @('CauService', '*Lifecycle*', '*LCM*', 'MocGateway', 'WacsService')) {
                    Get-Service -Name $serviceName -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, Status, StartType
                }
            )

            [ordered]@{
                cluster      = $cluster
                quorum       = $quorum
                faultDomains = @($faultDomains)
                networks     = @($networks)
                csvs         = @($csvs)
                groups       = @($groups)
                cau          = $cau
                cauRunHistory = @($cauRunHistory)
                solutionUpdateEnv = $solutionUpdateEnv
                solutionUpdateHistory = @($solutionUpdateHistory)
                pendingSolutionUpdates = @($pendingSolutionUpdates)
                arcRegistration = $arcRegistration
                events       = @($events)
                clusterCreationEvent = $clusterCreationEvent
                release      = $release
                licensing    = @($licensing)
                validationReports = @($validationReports)
                lifecycleServices = @($lifecycleServices)
            }
        }
    }

    $nodeSnapshots = @(
        Invoke-RangerSafeAction -Label 'Cluster node inventory' -DefaultValue @() -ScriptBlock {
            Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -ScriptBlock {
                $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
                $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
                $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
                $processors = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue
                $clusterNodeState = if (Get-Command -Name Get-ClusterNode -ErrorAction SilentlyContinue) {
                    (Get-ClusterNode -Name $env:COMPUTERNAME -ErrorAction SilentlyContinue).State
                }

                $nodePendingUpdates = if (Get-Command -Name Get-SolutionUpdate -ErrorAction SilentlyContinue) {
                    @(try { Get-SolutionUpdate -ErrorAction Stop | Where-Object { $_.State -in @('ReadyToInstall', 'Staged') } | Select-Object -First 10 Version, State, Description } catch { @() })
                } else {
                    @(try {
                        $wuSession = New-Object -ComObject Microsoft.Update.Session -ErrorAction Stop
                        $wuSearcher = $wuSession.CreateUpdateSearcher()
                        $wuResult = $wuSearcher.Search('IsInstalled=0')
                        @($wuResult.Updates | Select-Object -First 20 | ForEach-Object {
                            [ordered]@{ title = $_.Title; kbArticleIds = @($_.KBArticleIDs); classification = @($_.Categories | ForEach-Object { $_.Name }) -join ',' }
                        })
                    } catch { @() })
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
                    totalMemoryGiB = if ($computerSystem.TotalPhysicalMemory) { ConvertTo-RangerGiB -Value $computerSystem.TotalPhysicalMemory } else { $null }
                    logicalProcessorCount = @($processors | ForEach-Object { $_.NumberOfLogicalProcessors } | Measure-Object -Sum).Sum
                    partOfDomain   = [bool]$computerSystem.PartOfDomain
                    domain         = $computerSystem.Domain
                    biosVersion    = if ($bios) { @($bios.SMBIOSBIOSVersion) -join ', ' } else { $null }
                    pendingUpdates = @($nodePendingUpdates)
                    pendingUpdateCount = @($nodePendingUpdates).Count
                }
            }
        }
    )

    if (-not $clusterSnapshot -and $nodeSnapshots.Count -eq 0) {
        throw 'Cluster topology collector could not gather any usable data.'
    }

    if (-not $clusterSnapshot) {
        $clusterSnapshot = [ordered]@{
            cluster      = [ordered]@{}
            quorum       = [ordered]@{}
            faultDomains = @()
            networks     = @()
            csvs         = @()
            groups       = @()
            cau          = $null
            events       = @()
            release      = [ordered]@{}
            licensing    = @()
            validationReports = @()
            lifecycleServices = @()
        }
    }

    $deploymentType = if (-not [string]::IsNullOrWhiteSpace((Get-RangerHintValue -Config $Config -Name 'deploymentType'))) { [string](Get-RangerHintValue -Config $Config -Name 'deploymentType') } elseif (@($clusterSnapshot.networks).Count -le 1) { 'switchless' } else { 'hyperconverged' }
    $identityMode = if (-not [string]::IsNullOrWhiteSpace((Get-RangerHintValue -Config $Config -Name 'identityMode'))) { [string](Get-RangerHintValue -Config $Config -Name 'identityMode') } elseif (@($nodeSnapshots | Where-Object { -not $_.partOfDomain }).Count -gt 0) { 'local-key-vault' } else { 'ad' }
    $controlPlaneMode = if (-not [string]::IsNullOrWhiteSpace((Get-RangerHintValue -Config $Config -Name 'controlPlaneMode'))) { [string](Get-RangerHintValue -Config $Config -Name 'controlPlaneMode') } elseif ([string]::IsNullOrWhiteSpace($Config.targets.azure.subscriptionId)) { 'disconnected' } else { 'connected' }
    $storageArchitecture = if ($clusterSnapshot.cluster.S2DEnabled) { 'storage-spaces-direct' } else { 'shared-storage' }
    $networkArchitecture = if (@($clusterSnapshot.networks).Count -le 1) { 'switchless' } else { 'switched' }
    $variantMarkers = @()
    if ($deploymentType -eq 'switchless') { $variantMarkers += 'switchless' }
    if ($identityMode -eq 'local-key-vault') { $variantMarkers += 'local-identity' }
    if ($controlPlaneMode -eq 'disconnected') { $variantMarkers += 'disconnected' }

    $healthSummary = [ordered]@{
        totalNodes   = @($nodeSnapshots).Count
        healthyNodes = @($nodeSnapshots | Where-Object { $_.state -eq 'Up' }).Count
        unhealthy    = @($nodeSnapshots | Where-Object { $_.state -ne 'Up' }).Count
    }

    $nodeSummary = [ordered]@{
        manufacturers       = @(Get-RangerGroupedCount -Items $nodeSnapshots -PropertyName 'manufacturer')
        models              = @(Get-RangerGroupedCount -Items $nodeSnapshots -PropertyName 'model')
        totalMemoryGiB      = [math]::Round((@($nodeSnapshots | Where-Object { $null -ne $_.totalMemoryGiB } | Measure-Object -Property totalMemoryGiB -Sum).Sum), 2)
        totalLogicalCpu     = @($nodeSnapshots | Where-Object { $null -ne $_.logicalProcessorCount } | Measure-Object -Property logicalProcessorCount -Sum).Sum
        domainJoinedNodes   = @($nodeSnapshots | Where-Object { $_.partOfDomain }).Count
        localIdentityNodes  = @($nodeSnapshots | Where-Object { -not $_.partOfDomain }).Count
    }

    $faultDomainSummary = [ordered]@{
        count     = @($clusterSnapshot.faultDomains).Count
        byType    = @(Get-RangerGroupedCount -Items $clusterSnapshot.faultDomains -PropertyName 'FaultDomainType')
        locations = @(Get-RangerGroupedCount -Items $clusterSnapshot.faultDomains -PropertyName 'Location')
    }

    $networkSummary = [ordered]@{
        clusterNetworkCount = @($clusterSnapshot.networks).Count
        byRole              = @(Get-RangerGroupedCount -Items $clusterSnapshot.networks -PropertyName 'Role')
        switched            = @($clusterSnapshot.networks).Count -gt 1
    }

    $findings = New-Object System.Collections.ArrayList
    if ($healthSummary.unhealthy -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'One or more cluster nodes are not up' -Description 'The cluster foundation collector detected nodes that were not in the Up state.' -AffectedComponents (@($nodeSnapshots | Where-Object { $_.state -ne 'Up' } | ForEach-Object { $_.name })) -CurrentState "$($healthSummary.unhealthy) nodes not up" -Recommendation 'Review cluster membership, maintenance state, and failover clustering health.'))
    }

    if (@($clusterSnapshot.faultDomains).Count -eq 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'No cluster fault domains were discovered' -Description 'Ranger did not find rack or site-oriented fault domain metadata in the cluster snapshot.' -CurrentState 'fault-domain metadata absent' -Recommendation 'Confirm whether fault domains are intentionally not modeled or whether additional cluster foundation metadata should be configured.'))
    }

    if (-not $clusterSnapshot.cau) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'Cluster-Aware Updating role was not detected' -Description 'The collector did not find a Cluster-Aware Updating role in the sampled cluster state.' -CurrentState 'cau not detected' -Recommendation 'Confirm whether Cluster-Aware Updating is intentionally unmanaged or whether update orchestration data needs to be collected another way.'))
    }

    if (@($clusterSnapshot.validationReports).Count -eq 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'No recent cluster validation reports were discovered' -Description 'The collector did not find recent Test-Cluster style report artifacts in the cluster reports folder.' -CurrentState 'validation history not discovered' -Recommendation 'If validation reports exist elsewhere, record that evidence path; otherwise consider capturing a fresh validation run for formal handoff material.'))
    }

    if ($controlPlaneMode -eq 'disconnected') {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'Azure connectivity context is disconnected or undefined' -Description 'The cluster target does not currently advertise an Azure subscription context in the Ranger configuration.' -CurrentState $controlPlaneMode -Recommendation 'Confirm whether this deployment should operate disconnected or if Azure registration metadata is missing from the config.'))
    }

    if (@($clusterSnapshot.pendingSolutionUpdates).Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Pending solution updates detected on the cluster' -Description "The collector found $(@($clusterSnapshot.pendingSolutionUpdates).Count) solution update(s) in ReadyToInstall or Staged state." -AffectedComponents @($clusterSnapshot.cluster.Name) -CurrentState "$(@($clusterSnapshot.pendingSolutionUpdates).Count) pending updates" -Recommendation 'Review pending solution updates and schedule an appropriate maintenance window to apply them.'))
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
                    productName           = $clusterSnapshot.release.ProductName
                    displayVersion        = $clusterSnapshot.release.DisplayVersion
                    releaseId             = $clusterSnapshot.release.ReleaseId
                    currentBuild          = $clusterSnapshot.release.CurrentBuild
                    editionId             = $clusterSnapshot.release.EditionID
                    installationType      = $clusterSnapshot.release.InstallationType
                    operatingModel        = [ordered]@{ deploymentType = $deploymentType; identityMode = $identityMode; controlPlaneMode = $controlPlaneMode }
                    registration          = [ordered]@{ subscriptionId = $Config.targets.azure.subscriptionId; resourceGroup = $Config.targets.azure.resourceGroup; tenantId = $Config.targets.azure.tenantId }
                    licensing             = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.licensing
                }
                nodes         = @($nodeSnapshots)
                quorum        = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.quorum
                faultDomains  = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.faultDomains
                networks      = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.networks
                roles         = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.groups
                csvSummary    = [ordered]@{ count = @($clusterSnapshot.csvs).Count; items = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.csvs }
                updatePosture = [ordered]@{
                    clusterAwareUpdating   = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.cau
                    cauRunHistory          = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.cauRunHistory
                    solutionUpdateEnv      = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.solutionUpdateEnv
                    solutionUpdateHistory  = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.solutionUpdateHistory
                    pendingSolutionUpdates = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.pendingSolutionUpdates
                    lifecycleServices      = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.lifecycleServices
                    validationReports      = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.validationReports
                    pendingSolutionUpdateCount = @($clusterSnapshot.pendingSolutionUpdates).Count
                }
                registration  = [ordered]@{
                    subscriptionId        = $Config.targets.azure.subscriptionId
                    resourceGroup         = $Config.targets.azure.resourceGroup
                    tenantId              = $Config.targets.azure.tenantId
                    arcRegistrationDetail = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.arcRegistration
                    clusterCreationHint   = if ($clusterSnapshot.clusterCreationEvent) { $clusterSnapshot.clusterCreationEvent.TimeCreated.ToString('o') } else { $null }
                }
                eventSummary  = ConvertTo-RangerHashtable -InputObject $clusterSnapshot.events
                healthSummary = $healthSummary
                nodeSummary   = $nodeSummary
                faultDomainSummary = $faultDomainSummary
                networkSummary = $networkSummary
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