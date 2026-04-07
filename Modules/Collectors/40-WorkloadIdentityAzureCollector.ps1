function Invoke-RangerWorkloadIdentityAzureCollector {
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

    $vmInventory = @(
        Invoke-RangerSafeAction -Label 'VM inventory snapshot' -DefaultValue @() -ScriptBlock {
            Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -ScriptBlock {
                if (-not (Get-Command -Name Get-VM -ErrorAction SilentlyContinue)) {
                    return @()
                }

                Get-VM | ForEach-Object {
                    $vm = $_
                    $drives = if (Get-Command -Name Get-VMHardDiskDrive -ErrorAction SilentlyContinue) { Get-VMHardDiskDrive -VMName $vm.Name -ErrorAction SilentlyContinue } else { @() }
                    $adapters = if (Get-Command -Name Get-VMNetworkAdapter -ErrorAction SilentlyContinue) { Get-VMNetworkAdapter -VMName $vm.Name -ErrorAction SilentlyContinue } else { @() }
                    $replication = if (Get-Command -Name Get-VMReplication -ErrorAction SilentlyContinue) { Get-VMReplication -VMName $vm.Name -ErrorAction SilentlyContinue } else { $null }
                    $integrationServices = if (Get-Command -Name Get-VMIntegrationService -ErrorAction SilentlyContinue) { Get-VMIntegrationService -VMName $vm.Name -ErrorAction SilentlyContinue | Select-Object Name, Enabled, PrimaryStatusDescription, SecondaryStatusDescription } else { @() }
                    $checkpoints = if (Get-Command -Name Get-VMCheckpoint -ErrorAction SilentlyContinue) {
                        @(Get-VMCheckpoint -VMName $vm.Name -ErrorAction SilentlyContinue | Select-Object Name, CheckpointType, CreationTime, Id, ParentCheckpointId | ForEach-Object {
                            [ordered]@{ name = $_.Name; checkpointType = [string]$_.CheckpointType; creationTime = $_.CreationTime; id = $_.Id; parentId = $_.ParentCheckpointId }
                        })
                    } else { @() }
                    $nicsAdvanced = if (Get-Command -Name Get-VMNetworkAdapter -ErrorAction SilentlyContinue) {
                        @(Get-VMNetworkAdapter -VMName $vm.Name -ErrorAction SilentlyContinue | ForEach-Object {
                            $nic = $_
                            $sriov = if (Get-Command -Name Get-VMNetworkAdapterSRIOV -ErrorAction SilentlyContinue) { try { Get-VMNetworkAdapterSRIOV -VMNetworkAdapter $nic -ErrorAction Stop | Select-Object SriovEnabled, SRIOVWeight } catch { $null } } else { $null }
                            $rdma = if (Get-Command -Name Get-VMNetworkAdapterRdma -ErrorAction SilentlyContinue) { try { Get-VMNetworkAdapterRdma -VMNetworkAdapter $nic -ErrorAction Stop | Select-Object RdmaWeight } catch { $null } } else { $null }
                            $bw = if (Get-Command -Name Get-VMNetworkAdapterBandwidth -ErrorAction SilentlyContinue) { try { Get-VMNetworkAdapterBandwidth -VMNetworkAdapter $nic -ErrorAction Stop | Select-Object MinimumBandwidthAbsolute, MaximumBandwidth } catch { $null } } else { $null }
                            $iso = if (Get-Command -Name Get-VMNetworkAdapterIsolation -ErrorAction SilentlyContinue) { try { Get-VMNetworkAdapterIsolation -VMNetworkAdapter $nic -ErrorAction Stop | Select-Object IsolationMode, DefaultIsolationID } catch { $null } } else { $null }
                            [ordered]@{
                                name            = $nic.Name
                                switchName      = $nic.SwitchName
                                macAddress      = $nic.MacAddress
                                sriovEnabled    = if ($sriov) { $sriov.SriovEnabled } else { $null }
                                sriovWeight     = if ($sriov) { $sriov.SRIOVWeight } else { $null }
                                rdmaWeight      = if ($rdma) { $rdma.RdmaWeight } else { $null }
                                maxBandwidthMbps = if ($bw -and $bw.MaximumBandwidth) { [math]::Round($bw.MaximumBandwidth / 1MB, 0) } else { $null }
                                isolationMode   = if ($iso) { [string]$iso.IsolationMode } else { $null }
                            }
                        })
                    } else { @() }
                    # Shared VHDX detection for guest cluster heuristic
                    $hasSharedVhdx = @($drives | Where-Object { $_.SupportPersistentReservations -or $_.Path -match '\bshared\b' }).Count -gt 0

                    [ordered]@{
                        name              = $vm.Name
                        hostNode          = $env:COMPUTERNAME
                        state             = $vm.State.ToString()
                        uptime            = $vm.Uptime
                        isClustered       = [bool]$vm.IsClustered
                        generation        = $vm.Generation
                        processorCount    = $vm.ProcessorCount
                        memoryAssignedMb  = [math]::Round(($vm.MemoryAssigned / 1MB), 2)
                        dynamicMemory     = [bool]$vm.DynamicMemoryEnabled
                        checkpointType    = $vm.CheckpointType
                        diskCount         = @($drives).Count
                        networkAdapterCount = @($adapters).Count
                        storagePaths      = @($drives | ForEach-Object { $_.Path })
                        switchNames       = @($adapters | ForEach-Object { $_.SwitchName })
                        replicationMode   = if ($replication) { $replication.ReplicationMode } else { $null }
                        replicationHealth = if ($replication) { $replication.Health } else { $null }
                        integrationServices = @($integrationServices)
                        integrationServiceSummary = [ordered]@{ total = @($integrationServices).Count; enabled = @($integrationServices | Where-Object { $_.Enabled }).Count }
                        checkpoints       = @($checkpoints)
                        checkpointCount   = @($checkpoints).Count
                        nicsAdvanced      = @($nicsAdvanced)
                        guestClusterCandidate = $hasSharedVhdx
                    }
                }
            }
        }
    )

    $keyVaultReferences = @(
        $Config.credentials.cluster.passwordRef,
        $Config.credentials.domain.passwordRef,
        $Config.credentials.bmc.passwordRef,
        $Config.credentials.azure.clientSecretRef
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    $identitySnapshots = @(
        Invoke-RangerSafeAction -Label 'Identity and security snapshot' -DefaultValue @() -ScriptBlock {
            Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -ScriptBlock {
                $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
                $defender = if (Get-Command -Name Get-MpComputerStatus -ErrorAction SilentlyContinue) { Get-MpComputerStatus | Select-Object AMRunningMode, AntispywareEnabled, AntivirusEnabled, RealTimeProtectionEnabled, IsTamperProtected, AntivirusSignatureVersion, AntivirusSignatureLastUpdated, AMProductVersion } else { $null }
                $defenderExclusions = if (Get-Command -Name Get-MpPreference -ErrorAction SilentlyContinue) {
                    try {
                        $pref = Get-MpPreference -ErrorAction Stop
                        [ordered]@{ paths = @($pref.ExclusionPath); processes = @($pref.ExclusionProcess); extensions = @($pref.ExclusionExtension) }
                    } catch { $null }
                }
                $bitlocker = if (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue) { Get-BitLockerVolume | Select-Object MountPoint, ProtectionStatus, EncryptionMethod, VolumeStatus } else { @() }
                $bitlockerProtectors = if (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue) {
                    @(Get-BitLockerVolume -ErrorAction SilentlyContinue | ForEach-Object {
                        $vol = $_
                        [ordered]@{
                            mountPoint       = $vol.MountPoint
                            protectionStatus = [string]$vol.ProtectionStatus
                            encryptionMethod = [string]$vol.EncryptionMethod
                            protectorTypes   = @($vol.KeyProtector | ForEach-Object { [string]$_.KeyProtectorType })
                            hasTpm           = [bool](@($vol.KeyProtector | Where-Object { [string]$_.KeyProtectorType -in @('Tpm', 'TpmPin', 'TpmStartupKey', 'TpmPinStartupKey') }).Count -gt 0)
                            hasRecovery      = [bool](@($vol.KeyProtector | Where-Object { [string]$_.KeyProtectorType -eq 'RecoveryPassword' }).Count -gt 0)
                            hasAdBackup      = [bool](@($vol.KeyProtector | Where-Object { [string]$_.KeyProtectorType -match 'AD' }).Count -gt 0)
                        }
                    })
                } else { @() }
                $localAdmins = try { Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop | Select-Object Name, ObjectClass, PrincipalSource } catch { @() }
                $adminUser  = Get-LocalUser -Name 'Administrator' -ErrorAction SilentlyContinue
                $guestUser  = Get-LocalUser -Name 'Guest'         -ErrorAction SilentlyContinue
                $localAdminDetail = [ordered]@{
                    members                = @($localAdmins)
                    administratorEnabled   = if ($adminUser) { [bool]$adminUser.Enabled } else { $null }
                    administratorLastLogon = if ($adminUser) { $adminUser.LastLogon }     else { $null }
                    guestEnabled           = if ($guestUser) { [bool]$guestUser.Enabled } else { $null }
                }
                $certificates = Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction SilentlyContinue | Select-Object Subject, Thumbprint, NotAfter
                $deviceGuard = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
                $wdacInfo = if ($deviceGuard) {
                    [ordered]@{
                        codeIntegrityPolicyEnforcementStatus = $deviceGuard.CodeIntegrityPolicyEnforcementStatus
                        usermodeCodeIntegrityPolicyEnforcementStatus = $deviceGuard.UsermodeCodeIntegrityPolicyEnforcementStatus
                        wdacConfigured = ($deviceGuard.CodeIntegrityPolicyEnforcementStatus -gt 0)
                        enforcementMode = switch ($deviceGuard.CodeIntegrityPolicyEnforcementStatus) { 1 { 'Audit' } 2 { 'Enforced' } default { 'None' } }
                        securityServicesRunning = @($deviceGuard.SecurityServicesRunning)
                    }
                } else { [ordered]@{ wdacConfigured = $false; enforcementMode = 'not-assessed' } }
                $adDomain = if (Get-Command -Name Get-ADDomain -ErrorAction SilentlyContinue) { Get-ADDomain -ErrorAction SilentlyContinue | Select-Object DNSRoot, NetBIOSName, DomainMode, DistinguishedName, ParentDomain } else { $null }
                $adForest = if (Get-Command -Name Get-ADForest -ErrorAction SilentlyContinue) { Get-ADForest -ErrorAction SilentlyContinue | Select-Object Name, ForestMode, RootDomain, Domains } else { $null }
                $appLocker = if (Get-Command -Name Get-AppLockerPolicy -ErrorAction SilentlyContinue) { try { Get-AppLockerPolicy -Effective -ErrorAction Stop | Select-Object -ExpandProperty RuleCollections | ForEach-Object { $_.CollectionType } } catch { @() } } else { @() }
                $secureBoot = try { Confirm-SecureBootUEFI -ErrorAction Stop } catch { $null }
                $credSsp = (Get-Item -Path WSMan:\localhost\Service\Auth\CredSSP -ErrorAction SilentlyContinue).Value
                # Structured audit policy via auditpol CSV output
                $auditPolicy = try {
                    $auditRaw = (auditpol.exe /get /category:* /r 2>$null)
                    if ($auditRaw) {
                        $auditLines = $auditRaw | ConvertFrom-Csv -ErrorAction Stop
                        @($auditLines | Where-Object { $_.Subcategory } | Select-Object -First 60 | ForEach-Object {
                            [ordered]@{ category = $_.'Category/Subcategory'; subcategory = $_.Subcategory; setting = $_.'Inclusion Setting' }
                        })
                    } else { @() }
                } catch {
                    @(try { (auditpol.exe /get /category:* 2>$null | Select-Object -First 20) } catch { @() })
                }
                # Entra / Azure AD hybrid join status
                $entraJoinStatus = try {
                    $dsregOutput = (& dsregcmd.exe /status 2>$null | Out-String)
                    $hybridJoined = $dsregOutput -match 'HybridAzureADJoined\s*:\s*YES'
                    $entraJoined = $dsregOutput -match 'AzureAdJoined\s*:\s*YES'
                    $domainJoined = $dsregOutput -match 'DomainJoined\s*:\s*YES'
                    [ordered]@{
                        azureAdJoined      = $entraJoined
                        hybridAzureAdJoined = $hybridJoined
                        domainJoined       = $domainJoined
                        tenantId           = if ($dsregOutput -match 'TenantId\s*:\s*([a-f0-9-]{36})') { $Matches[1] } else { $null }
                    }
                } catch { $null }
                # AADKERB configured detection
                $aadkerbConfigured = try {
                    $null -ne (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters' -Name 'CloudKerberosTicketRetrievalEnabled' -ErrorAction Stop)
                } catch { $false }

                [ordered]@{
                    node               = $env:COMPUTERNAME
                    partOfDomain       = [bool]$computerSystem.PartOfDomain
                    domain             = $computerSystem.Domain
                    localAdmins        = @($localAdmins)
                    localAdminDetail   = $localAdminDetail
                    certificates       = @($certificates)
                    bitlocker          = @($bitlocker)
                    bitlockerProtectors = @($bitlockerProtectors)
                    defender           = ConvertTo-RangerHashtable -InputObject $defender
                    defenderExclusions = $defenderExclusions
                    deviceGuard        = ConvertTo-RangerHashtable -InputObject $deviceGuard
                    wdacInfo           = $wdacInfo
                    adDomain           = ConvertTo-RangerHashtable -InputObject $adDomain
                    adForest           = ConvertTo-RangerHashtable -InputObject $adForest
                    appLocker          = @($appLocker)
                    secureBoot         = $secureBoot
                    credSsp            = $credSsp
                    auditPolicy        = @($auditPolicy)
                    entraJoinStatus    = $entraJoinStatus
                    aadkerbConfigured  = $aadkerbConfigured
                }
            }
        }
    )

    $azureResources = @(
        Get-RangerAzureResources -Config $Config -AzureCredentialSettings $CredentialMap.azure
    )

    $policyAssignments = @(
        Invoke-RangerSafeAction -Label 'Azure policy assignment snapshot' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)

                if (-not (Get-Command -Name Get-AzPolicyAssignment -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($SubscriptionId) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) {
                    return @()
                }

                $scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup"
                Get-AzPolicyAssignment -Scope $scope -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, Scope, EnforcementMode
            }
        }
    )

    # ARB appliance detail (k8s version, infra config, health)
    $arbDetail = @(
        Invoke-RangerSafeAction -Label 'ARB appliance detail' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzResourceBridgeAppliance -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                Get-AzResourceBridgeAppliance -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue |
                    Select-Object Name, Status, KubernetesVersion, InfrastructureConfigProvider, DistroVersion, @{N='Identity';E={$_.Identity.Type}}
            }
        }
    )

    # AKS clusters on Arc
    $aksClusters = @(
        Invoke-RangerSafeAction -Label 'AKS Arc cluster inventory' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzAksCluster -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                Get-AzAksCluster -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue |
                    Select-Object Name, KubernetesVersion, ProvisioningState, PowerState, NodeResourceGroup, EnableRBAC, Location
            }
        }
    )

    # AVD host pools
    $avdHostPools = @(
        Invoke-RangerSafeAction -Label 'AVD host pool inventory' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzWvdHostPool -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                $pools = @(Get-AzWvdHostPool -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue)
                $pools | Select-Object Name, HostPoolType, LoadBalancerType, ValidationEnvironment, MaxSessionLimit, PreferredAppGroupType, Status
            }
        }
    )

    # Azure Policy compliance states
    $policyComplianceStates = @(
        Invoke-RangerSafeAction -Label 'Azure Policy compliance state' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzPolicyState -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                Get-AzPolicyState -ResourceGroupName $ResourceGroup -Top 200 -ErrorAction SilentlyContinue |
                    Select-Object PolicyDefinitionName, PolicyDefinitionAction, ComplianceState, ResourceType, ResourceLocation, PolicySetDefinitionName
            }
        }
    )

    # Azure Site Recovery / ASR replicated items
    $vaults = @($azureResources | Where-Object { $_.ResourceType -match 'Microsoft.RecoveryServices/vaults' })
    $asrItems = @(
        Invoke-RangerSafeAction -Label 'ASR replicated item inventory' -DefaultValue @() -ScriptBlock {
            if ($vaults.Count -eq 0) { return @() }
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzRecoveryServicesVault -ErrorAction SilentlyContinue)) { return @() }
                $vaultList = @(Get-AzRecoveryServicesVault -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue)
                $items = New-Object System.Collections.ArrayList
                foreach ($vault in $vaultList) {
                    $ctx = Set-AzRecoveryServicesVaultContext -Vault $vault -ErrorAction SilentlyContinue
                    $replicated = @(Get-AzRecoveryServicesAsrReplicationProtectedItem -ErrorAction SilentlyContinue)
                    foreach ($item in $replicated) {
                        [void]$items.Add([ordered]@{
                            vaultName        = $vault.Name
                            vmName           = $item.FriendlyName
                            protectionState  = $item.ProtectionState
                            replicationHealth = $item.ReplicationHealth
                            testFailoverState = $item.TestFailoverState
                            lastRpo          = $item.LastSuccessfulFailoverTime
                        })
                    }
                }
                @($items)
            }
        }
    )

    # Azure Backup protected items
    $backupItems = @(
        Invoke-RangerSafeAction -Label 'Azure Backup protected item inventory' -DefaultValue @() -ScriptBlock {
            if ($vaults.Count -eq 0) { return @() }
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzRecoveryServicesVault -ErrorAction SilentlyContinue)) { return @() }
                $vaultList = @(Get-AzRecoveryServicesVault -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue)
                $items = New-Object System.Collections.ArrayList
                foreach ($vault in $vaultList) {
                    $ctx = Set-AzRecoveryServicesVaultContext -Vault $vault -ErrorAction SilentlyContinue
                    $protected = @(Get-AzRecoveryServicesBackupItem -WorkloadType AzureVM -ErrorAction SilentlyContinue)
                    $protected += @(Get-AzRecoveryServicesBackupItem -WorkloadType FileFolder -ErrorAction SilentlyContinue)
                    foreach ($item in $protected) {
                        [void]$items.Add([ordered]@{
                            vaultName       = $vault.Name
                            name            = $item.Name
                            containerName   = $item.ContainerName
                            backupStatus    = [string]$item.Status
                            lastBackupStatus = [string]$item.LastBackupStatus
                            lastBackupTime  = $item.LastBackupTime
                            protectionState = [string]$item.ProtectionState
                        })
                    }
                }
                @($items)
            }
        }
    )

    $arcMachines = @($azureResources | Where-Object { $_.ResourceType -match 'hybridcompute/machines' })
    $hciRegistrations = @($azureResources | Where-Object { $_.ResourceType -match 'azurestackhci/clusters' })
    $resourceBridge = @($azureResources | Where-Object { $_.ResourceType -match 'resourcebridge' })
    $customLocations = @($azureResources | Where-Object { $_.ResourceType -match 'customlocations' })
    $extensions = @($azureResources | Where-Object { $_.ResourceType -match 'extensions' })
    $siteRecovery = @($azureResources | Where-Object { $_.ResourceType -match 'siterecovery' })
    $resourceSummary = [ordered]@{
        totalResources  = @($azureResources).Count
        byType          = @(Get-RangerGroupedCount -Items $azureResources -PropertyName 'ResourceType')
        byLocation      = @(Get-RangerGroupedCount -Items $azureResources -PropertyName 'Location')
        azureArcMachines = $arcMachines.Count
        hciClusterRegistrations = $hciRegistrations.Count
        backupResources = @($azureResources | Where-Object { $_.ResourceType -match 'RecoveryServices|DataProtection|SiteRecovery' }).Count
        updateResources = @($azureResources | Where-Object { $_.ResourceType -match 'maintenance|update' }).Count
        resourceBridgeCount = $resourceBridge.Count
        customLocationCount = $customLocations.Count
        extensionCount      = $extensions.Count
        aksClusterCount     = @($aksClusters).Count
        avdHostPoolCount    = @($avdHostPools).Count
        arbApplianceCount   = @($arbDetail).Count
        asrProtectedItemCount = @($asrItems).Count
        backupProtectedItemCount = @($backupItems).Count
        nonCompliantPolicies = @($policyComplianceStates | Where-Object { $_.ComplianceState -eq 'NonCompliant' }).Count
    }

    $vmSummary = [ordered]@{
        totalVms              = @($vmInventory).Count
        runningVms            = @($vmInventory | Where-Object { $_.state -eq 'Running' }).Count
        clusteredVms          = @($vmInventory | Where-Object { $_.isClustered }).Count
        totalAssignedMemoryGb = [math]::Round((@($vmInventory | Where-Object { $null -ne $_.memoryAssignedMb } | Measure-Object -Property memoryAssignedMb -Sum).Sum / 1024), 2)
        byGeneration          = @(Get-RangerGroupedCount -Items $vmInventory -PropertyName 'generation')
        byState               = @(Get-RangerGroupedCount -Items $vmInventory -PropertyName 'state')
        guestClusterCandidates = @($vmInventory | Where-Object { $_.guestClusterCandidate }).Count
        vmsWithCheckpoints     = @($vmInventory | Where-Object { $_.checkpointCount -gt 0 }).Count
        totalCheckpoints       = (@($vmInventory | Measure-Object -Property checkpointCount -Sum).Sum)
        sriovEnabledNics       = @($vmInventory | ForEach-Object { @($_.nicsAdvanced | Where-Object { $_.sriovEnabled }) } | Measure-Object).Count
    }

    $identitySummary = [ordered]@{
        nodeCount                    = @($identitySnapshots).Count
        domainJoinedNodes            = @($identitySnapshots | Where-Object { $_.partOfDomain }).Count
        hybridEntraJoinedNodes       = @($identitySnapshots | Where-Object { $_.entraJoinStatus.hybridAzureAdJoined -eq $true }).Count
        entraJoinedNodes             = @($identitySnapshots | Where-Object { $_.entraJoinStatus.azureAdJoined -eq $true }).Count
        credSspEnabledNodes          = @($identitySnapshots | Where-Object { $_.credSsp -eq $true -or $_.credSsp -eq 'true' }).Count
        defenderProtectedNodes       = @($identitySnapshots | Where-Object { $_.defender.antivirusEnabled -or $_.defender.realTimeProtectionEnabled }).Count
        tamperProtectedNodes         = @($identitySnapshots | Where-Object { $_.defender.isTamperProtected -eq $true }).Count
        defenderDefinitionAgeDays    = @($identitySnapshots | ForEach-Object { if ($_.defender.antivirusSignatureLastUpdated) { ([datetime]::UtcNow - [datetime]$_.defender.antivirusSignatureLastUpdated).TotalDays } } | Measure-Object -Maximum).Maximum
        wdacEnforcedNodes            = @($identitySnapshots | Where-Object { $_.wdacInfo.enforcementMode -eq 'Enforced' }).Count
        wdacAuditNodes               = @($identitySnapshots | Where-Object { $_.wdacInfo.enforcementMode -eq 'Audit' }).Count
        bitLockerProtectedNodes      = @($identitySnapshots | Where-Object { @($_.bitlocker | Where-Object { $_.ProtectionStatus -in @('On', 1, 'ProtectionOn') }).Count -gt 0 }).Count
        bitLockerTpmProtectedNodes   = @($identitySnapshots | Where-Object { @($_.bitlockerProtectors | Where-Object { $_.hasTpm }).Count -gt 0 }).Count
        bitLockerAdBackupNodes       = @($identitySnapshots | Where-Object { @($_.bitlockerProtectors | Where-Object { $_.hasAdBackup }).Count -gt 0 }).Count
        certificateCount             = @($identitySnapshots | ForEach-Object { @($_.certificates).Count } | Measure-Object -Sum).Sum
        certificateExpiringWithin90Days = @($identitySnapshots | ForEach-Object { @($_.certificates | Where-Object { $_.NotAfter -and ([datetime]$_.NotAfter) -lt (Get-Date).AddDays(90) }).Count } | Measure-Object -Sum).Sum
        appLockerNodes               = @($identitySnapshots | Where-Object { @($_.appLocker).Count -gt 0 }).Count
        secureBootEnabledNodes       = @($identitySnapshots | Where-Object { $_.secureBoot -eq $true }).Count
        aadkerbConfiguredNodes       = @($identitySnapshots | Where-Object { $_.aadkerbConfigured -eq $true }).Count
    }

    $findings = New-Object System.Collections.ArrayList
    $workloadFamilies = New-Object System.Collections.ArrayList
    $resourcesByType = @($azureResources | Group-Object -Property ResourceType)
    $workloadDetections = @(
        [ordered]@{ Name = 'AKS'; Match = (@($azureResources | Where-Object { $_.ResourceType -match 'kubernetes|containerservice' }).Count -gt 0) }
        [ordered]@{ Name = 'AVD'; Match = (@($azureResources | Where-Object { $_.ResourceType -match 'desktopvirtualization' }).Count -gt 0) }
        [ordered]@{ Name = 'Arc VMs'; Match = (@($azureResources | Where-Object { $_.ResourceType -match 'hybridcompute/machines' }).Count -gt 0) }
        [ordered]@{ Name = 'Arc Data Services'; Match = (@($azureResources | Where-Object { $_.ResourceType -match 'azurearcdata|sql' }).Count -gt 0) }
        [ordered]@{ Name = 'IoT Operations'; Match = (@($azureResources | Where-Object { $_.ResourceType -match 'iot' }).Count -gt 0) }
        [ordered]@{ Name = 'Microsoft 365 Local'; Match = (@($azureResources | Where-Object { $_.Name -match 'm365|microsoft365' }).Count -gt 0) }
    )

    foreach ($detection in $workloadDetections) {
        if ($detection.Match) {
            [void]$workloadFamilies.Add([ordered]@{ name = $detection.Name; count = 1 })
        }
    }

    $relationships = New-Object System.Collections.ArrayList
    foreach ($vm in $vmInventory) {
        if ($vm.hostNode) {
            [void]$relationships.Add((New-RangerRelationship -SourceType 'cluster-node' -SourceId $vm.hostNode -TargetType 'virtual-machine' -TargetId $vm.name -RelationshipType 'hosts' -Properties ([ordered]@{ state = $vm.state })))
        }

        foreach ($switchName in @($vm.switchNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
            [void]$relationships.Add((New-RangerRelationship -SourceType 'virtual-machine' -SourceId $vm.name -TargetType 'virtual-switch' -TargetId $switchName -RelationshipType 'connected-to' -Properties ([ordered]@{ hostNode = $vm.hostNode })))
        }
    }

    if (@($identitySnapshots | Where-Object { -not $_.partOfDomain }).Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($Config.credentials.cluster.passwordRef) -and -not [string]::IsNullOrWhiteSpace($Config.targets.azure.resourceGroup)) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'Local identity posture detected with Azure context configured' -Description 'At least one node appears not to be joined to a domain while Azure registration context is configured.' -CurrentState 'local-key-vault candidate' -Recommendation 'Confirm whether this is a local-identity deployment and verify Key Vault secret references and certificate posture.'))
    }

    if (@($policyAssignments).Count -eq 0 -and @($azureResources).Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'No Azure Policy assignments were discovered at the configured resource-group scope' -Description 'The Azure integration snapshot found resources but did not return policy assignments scoped to the configured resource group.' -CurrentState 'policy assignment inventory empty' -Recommendation 'Confirm whether policy is assigned at a broader scope or whether additional reader permissions are needed for policy discovery.'))
    }

    if ($identitySummary.certificateExpiringWithin90Days -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'One or more node certificates expire within 90 days' -Description 'Identity posture data indicates at least one certificate in the local machine store is approaching expiry.' -CurrentState "$($identitySummary.certificateExpiringWithin90Days) certificates expiring within 90 days" -Recommendation 'Review certificate ownership and renew expiring node, management, and service certificates before handoff.'))
    }

    if (@($identitySnapshots | Where-Object { $_.credSsp -eq $true -or $_.credSsp -eq 'true' }).Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'CredSSP authentication is enabled on one or more nodes' -Description 'CredSSP delegates user credentials to remote hosts and widens the attack surface for credential theft.' -CurrentState "$(@($identitySnapshots | Where-Object { $_.credSsp -eq $true -or $_.credSsp -eq 'true' }).Count) nodes with CredSSP enabled" -Recommendation 'Disable CredSSP on production nodes. Use Kerberos constrained delegation or certificate authentication instead.'))
    }

    if ($identitySummary.wdacEnforcedNodes -eq 0 -and @($identitySnapshots).Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'WDAC policy is not in enforced mode on any node' -Description 'No node reported a Windows Defender Application Control policy in enforcement mode. Audit mode or no policy was detected.' -CurrentState 'WDAC enforcement mode: None or Audit on all nodes' -Recommendation 'Review WDAC policy deployment. Consider enforced mode for production workloads.'))
    }

    if (@($policyComplianceStates | Where-Object { $_.ComplianceState -eq 'NonCompliant' }).Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Azure Policy non-compliant resources detected' -Description "Policy compliance assessment returned non-compliant resources in the scoped resource group." -CurrentState "$($identitySnapshots.Count) non-compliant policy states found" -Recommendation 'Review non-compliant policy assignments and resolve policy drift before handoff.'))
    }

    return @{
        Status        = if ($findings.Count -gt 0) { 'partial' } else { 'success' }
        Domains       = @{
            virtualMachines = [ordered]@{
                inventory        = ConvertTo-RangerHashtable -InputObject $vmInventory
                placement        = ConvertTo-RangerHashtable -InputObject @($vmInventory | ForEach-Object { [ordered]@{ vm = $_.name; hostNode = $_.hostNode; state = $_.state } })
                workloadFamilies = @($workloadFamilies)
                replication      = ConvertTo-RangerHashtable -InputObject @($vmInventory | Where-Object { $_.replicationMode } | ForEach-Object { [ordered]@{ vm = $_.name; mode = $_.replicationMode; health = $_.replicationHealth } })
                checkpoints      = ConvertTo-RangerHashtable -InputObject @($vmInventory | Where-Object { $_.checkpointCount -gt 0 } | ForEach-Object { [ordered]@{ vm = $_.name; count = $_.checkpointCount; snapshots = $_.checkpoints } })
                guestClusters    = ConvertTo-RangerHashtable -InputObject @($vmInventory | Where-Object { $_.guestClusterCandidate } | ForEach-Object { [ordered]@{ vm = $_.name; hostNode = $_.hostNode } })
                summary          = $vmSummary
            }
            identitySecurity = [ordered]@{
                nodes           = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; partOfDomain = $_.partOfDomain; domain = $_.domain; credSsp = $_.credSsp } })
                certificates    = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; items = $_.certificates } })
                posture         = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; defender = $_.defender; defenderExclusions = $_.defenderExclusions; wdacInfo = $_.wdacInfo; bitlocker = $_.bitlocker; bitlockerProtectors = $_.bitlockerProtectors; secureBoot = $_.secureBoot; appLocker = $_.appLocker } })
                localAdmins     = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; members = $_.localAdmins; detail = $_.localAdminDetail } })
                auditPolicy     = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; values = $_.auditPolicy } })
                activeDirectory = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; domain = $_.adDomain; forest = $_.adForest } })
                entraJoin       = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; status = $_.entraJoinStatus; aadkerbConfigured = $_.aadkerbConfigured } })
                keyVault        = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; references = $keyVaultReferences } })
                summary         = $identitySummary
            }
            azureIntegration = [ordered]@{
                context   = [ordered]@{
                    subscriptionId = $Config.targets.azure.subscriptionId
                    resourceGroup  = $Config.targets.azure.resourceGroup
                    tenantId       = $Config.targets.azure.tenantId
                }
                resources        = ConvertTo-RangerHashtable -InputObject $azureResources
                services         = ConvertTo-RangerHashtable -InputObject @($resourcesByType | ForEach-Object { [ordered]@{ category = $_.Name; count = $_.Count; name = $_.Name } })
                policy           = ConvertTo-RangerHashtable -InputObject $policyAssignments
                policyCompliance = ConvertTo-RangerHashtable -InputObject $policyComplianceStates
                backup           = ConvertTo-RangerHashtable -InputObject $backupItems
                backupLegacy     = ConvertTo-RangerHashtable -InputObject @($azureResources | Where-Object { $_.ResourceType -match 'RecoveryServices|DataProtection|SiteRecovery' })
                siteRecovery     = ConvertTo-RangerHashtable -InputObject $asrItems
                update           = ConvertTo-RangerHashtable -InputObject @($azureResources | Where-Object { $_.ResourceType -match 'maintenance|update' })
                cost             = ConvertTo-RangerHashtable -InputObject @($azureResources | Where-Object { $_.ResourceType -match 'billing|cost' })
                resourceBridge   = ConvertTo-RangerHashtable -InputObject $resourceBridge
                arbDetail        = ConvertTo-RangerHashtable -InputObject $arbDetail
                aksClusters      = ConvertTo-RangerHashtable -InputObject $aksClusters
                avdHostPools     = ConvertTo-RangerHashtable -InputObject $avdHostPools
                customLocations  = ConvertTo-RangerHashtable -InputObject $customLocations
                extensions       = ConvertTo-RangerHashtable -InputObject $extensions
                arcMachines      = ConvertTo-RangerHashtable -InputObject $arcMachines
                resourceSummary  = $resourceSummary
                resourceLocations = ConvertTo-RangerHashtable -InputObject $resourceSummary.byLocation
                policySummary    = [ordered]@{
                    assignmentCount   = @($policyAssignments).Count
                    enforcementModes  = @(Get-RangerGroupedCount -Items $policyAssignments -PropertyName 'EnforcementMode')
                    nonCompliantCount = @($policyComplianceStates | Where-Object { $_.ComplianceState -eq 'NonCompliant' }).Count
                    complianceByType  = @(Get-RangerGroupedCount -Items ($policyComplianceStates | Where-Object { $_.ComplianceState -eq 'NonCompliant' }) -PropertyName 'ResourceType')
                }
                auth = [ordered]@{ method = $CredentialMap.azure.method; tenantId = $CredentialMap.azure.tenantId; subscriptionId = $CredentialMap.azure.subscriptionId; azureCliFallback = [bool]$CredentialMap.azure.useAzureCliFallback }
            }
        }
        Findings      = @($findings)
        Relationships = @($relationships)
        RawEvidence   = [ordered]@{
            virtualMachines   = ConvertTo-RangerHashtable -InputObject $vmInventory
            identitySecurity  = ConvertTo-RangerHashtable -InputObject $identitySnapshots
            azureResources    = ConvertTo-RangerHashtable -InputObject $azureResources
            policyAssignments = ConvertTo-RangerHashtable -InputObject $policyAssignments
            policyCompliance  = ConvertTo-RangerHashtable -InputObject $policyComplianceStates
            asrItems          = ConvertTo-RangerHashtable -InputObject $asrItems
            backupItems       = ConvertTo-RangerHashtable -InputObject $backupItems
            aksClusters       = ConvertTo-RangerHashtable -InputObject $aksClusters
            avdHostPools      = ConvertTo-RangerHashtable -InputObject $avdHostPools
            arbDetail         = ConvertTo-RangerHashtable -InputObject $arbDetail
        }
    }
}