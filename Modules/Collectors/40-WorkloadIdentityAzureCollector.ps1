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
                    $integrationServices = if (Get-Command -Name Get-VMIntegrationService -ErrorAction SilentlyContinue) { Get-VMIntegrationService -VMName $vm.Name -ErrorAction SilentlyContinue | Select-Object Name, Enabled, PrimaryStatusDescription } else { @() }

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
                $defender = if (Get-Command -Name Get-MpComputerStatus -ErrorAction SilentlyContinue) { Get-MpComputerStatus | Select-Object AMRunningMode, AntispywareEnabled, AntivirusEnabled, RealTimeProtectionEnabled } else { $null }
                $bitlocker = if (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue) { Get-BitLockerVolume | Select-Object MountPoint, ProtectionStatus, EncryptionMethod, VolumeStatus } else { @() }
                $localAdmins = try { Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop | Select-Object Name, ObjectClass, PrincipalSource } catch { @() }
                $certificates = Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction SilentlyContinue | Select-Object Subject, Thumbprint, NotAfter
                $deviceGuard = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
                $adDomain = if (Get-Command -Name Get-ADDomain -ErrorAction SilentlyContinue) { Get-ADDomain -ErrorAction SilentlyContinue | Select-Object DNSRoot, NetBIOSName, DomainMode, DistinguishedName, ParentDomain } else { $null }
                $adForest = if (Get-Command -Name Get-ADForest -ErrorAction SilentlyContinue) { Get-ADForest -ErrorAction SilentlyContinue | Select-Object Name, ForestMode, RootDomain, Domains } else { $null }
                $appLocker = if (Get-Command -Name Get-AppLockerPolicy -ErrorAction SilentlyContinue) { try { Get-AppLockerPolicy -Effective -ErrorAction Stop | Select-Object -ExpandProperty RuleCollections | ForEach-Object { $_.CollectionType } } catch { @() } } else { @() }
                $secureBoot = try { Confirm-SecureBootUEFI -ErrorAction Stop } catch { $null }
                $credSsp = (Get-Item -Path WSMan:\localhost\Service\Auth\CredSSP -ErrorAction SilentlyContinue).Value
                $audit = try { (auditpol.exe /get /category:* 2>$null | Select-Object -First 20) } catch { @() }

                [ordered]@{
                    node          = $env:COMPUTERNAME
                    partOfDomain  = [bool]$computerSystem.PartOfDomain
                    domain        = $computerSystem.Domain
                    localAdmins   = @($localAdmins)
                    certificates  = @($certificates)
                    bitlocker     = @($bitlocker)
                    defender      = ConvertTo-RangerHashtable -InputObject $defender
                    deviceGuard   = ConvertTo-RangerHashtable -InputObject $deviceGuard
                    adDomain      = ConvertTo-RangerHashtable -InputObject $adDomain
                    adForest      = ConvertTo-RangerHashtable -InputObject $adForest
                    appLocker     = @($appLocker)
                    secureBoot    = $secureBoot
                    credSsp       = $credSsp
                    auditPolicy   = @($audit)
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
    }

    $vmSummary = [ordered]@{
        totalVms             = @($vmInventory).Count
        runningVms           = @($vmInventory | Where-Object { $_.state -eq 'Running' }).Count
        clusteredVms         = @($vmInventory | Where-Object { $_.isClustered }).Count
        totalAssignedMemoryGb = [math]::Round((@($vmInventory | Where-Object { $null -ne $_.memoryAssignedMb } | Measure-Object -Property memoryAssignedMb -Sum).Sum / 1024), 2)
        byGeneration         = @(Get-RangerGroupedCount -Items $vmInventory -PropertyName 'generation')
        byState              = @(Get-RangerGroupedCount -Items $vmInventory -PropertyName 'state')
    }

    $identitySummary = [ordered]@{
        nodeCount                = @($identitySnapshots).Count
        domainJoinedNodes        = @($identitySnapshots | Where-Object { $_.partOfDomain }).Count
        credSspEnabledNodes      = @($identitySnapshots | Where-Object { $_.credSsp -eq $true -or $_.credSsp -eq 'true' }).Count
        defenderProtectedNodes   = @($identitySnapshots | Where-Object { $_.defender.antivirusEnabled -or $_.defender.realTimeProtectionEnabled }).Count
        bitLockerProtectedNodes  = @($identitySnapshots | Where-Object { @($_.bitlocker | Where-Object { $_.ProtectionStatus -in @('On', 1, 'ProtectionOn') }).Count -gt 0 }).Count
        certificateCount         = @($identitySnapshots | ForEach-Object { @($_.certificates).Count } | Measure-Object -Sum).Sum
        certificateExpiringWithin90Days = @($identitySnapshots | ForEach-Object { @($_.certificates | Where-Object { $_.NotAfter -and ([datetime]$_.NotAfter) -lt (Get-Date).AddDays(90) }).Count } | Measure-Object -Sum).Sum
        appLockerNodes           = @($identitySnapshots | Where-Object { @($_.appLocker).Count -gt 0 }).Count
        secureBootEnabledNodes   = @($identitySnapshots | Where-Object { $_.secureBoot -eq $true }).Count
    }

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

    $findings = New-Object System.Collections.ArrayList
    if (@($identitySnapshots | Where-Object { -not $_.partOfDomain }).Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($Config.credentials.cluster.passwordRef) -and -not [string]::IsNullOrWhiteSpace($Config.targets.azure.resourceGroup)) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'Local identity posture detected with Azure context configured' -Description 'At least one node appears not to be joined to a domain while Azure registration context is configured.' -CurrentState 'local-key-vault candidate' -Recommendation 'Confirm whether this is a local-identity deployment and verify Key Vault secret references and certificate posture.'))
    }

    if (@($policyAssignments).Count -eq 0 -and @($azureResources).Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'No Azure Policy assignments were discovered at the configured resource-group scope' -Description 'The Azure integration snapshot found resources but did not return policy assignments scoped to the configured resource group.' -CurrentState 'policy assignment inventory empty' -Recommendation 'Confirm whether policy is assigned at a broader scope or whether additional reader permissions are needed for policy discovery.'))
    }

    if ($identitySummary.certificateExpiringWithin90Days -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'One or more node certificates expire within 90 days' -Description 'Identity posture data indicates at least one certificate in the local machine store is approaching expiry.' -CurrentState "$($identitySummary.certificateExpiringWithin90Days) certificates expiring within 90 days" -Recommendation 'Review certificate ownership and renew expiring node, management, and service certificates before handoff.'))
    }

    return @{
        Status        = if ($findings.Count -gt 0) { 'partial' } else { 'success' }
        Domains       = @{
            virtualMachines = [ordered]@{
                inventory        = ConvertTo-RangerHashtable -InputObject $vmInventory
                placement        = ConvertTo-RangerHashtable -InputObject @($vmInventory | ForEach-Object { [ordered]@{ vm = $_.name; hostNode = $_.hostNode; state = $_.state } })
                workloadFamilies = @($workloadFamilies)
                replication     = ConvertTo-RangerHashtable -InputObject @($vmInventory | Where-Object { $_.replicationMode } | ForEach-Object { [ordered]@{ vm = $_.name; mode = $_.replicationMode; health = $_.replicationHealth } })
                summary         = $vmSummary
            }
            identitySecurity = [ordered]@{
                nodes        = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; partOfDomain = $_.partOfDomain; domain = $_.domain; credSsp = $_.credSsp } })
                certificates = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; items = $_.certificates } })
                posture      = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; defender = $_.defender; deviceGuard = $_.deviceGuard; bitlocker = $_.bitlocker; secureBoot = $_.secureBoot; appLocker = $_.appLocker } })
                localAdmins  = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; members = $_.localAdmins } })
                auditPolicy  = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; values = $_.auditPolicy } })
                activeDirectory = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; domain = $_.adDomain; forest = $_.adForest } })
                keyVault = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; references = $keyVaultReferences } })
                summary      = $identitySummary
            }
            azureIntegration = [ordered]@{
                context   = [ordered]@{
                    subscriptionId = $Config.targets.azure.subscriptionId
                    resourceGroup  = $Config.targets.azure.resourceGroup
                    tenantId       = $Config.targets.azure.tenantId
                }
                resources = ConvertTo-RangerHashtable -InputObject $azureResources
                services  = ConvertTo-RangerHashtable -InputObject @($resourcesByType | ForEach-Object { [ordered]@{ category = $_.Name; count = $_.Count; name = $_.Name } })
                policy    = ConvertTo-RangerHashtable -InputObject $policyAssignments
                backup    = ConvertTo-RangerHashtable -InputObject @($azureResources | Where-Object { $_.ResourceType -match 'RecoveryServices|DataProtection|SiteRecovery' })
                update    = ConvertTo-RangerHashtable -InputObject @($azureResources | Where-Object { $_.ResourceType -match 'maintenance|update' })
                cost      = ConvertTo-RangerHashtable -InputObject @($azureResources | Where-Object { $_.ResourceType -match 'billing|cost' })
                resourceBridge = ConvertTo-RangerHashtable -InputObject $resourceBridge
                customLocations = ConvertTo-RangerHashtable -InputObject $customLocations
                extensions = ConvertTo-RangerHashtable -InputObject $extensions
                arcMachines = ConvertTo-RangerHashtable -InputObject $arcMachines
                siteRecovery = ConvertTo-RangerHashtable -InputObject $siteRecovery
                resourceSummary = $resourceSummary
                resourceLocations = ConvertTo-RangerHashtable -InputObject $resourceSummary.byLocation
                policySummary = [ordered]@{ assignmentCount = @($policyAssignments).Count; enforcementModes = @(Get-RangerGroupedCount -Items $policyAssignments -PropertyName 'EnforcementMode') }
                auth = [ordered]@{ method = $CredentialMap.azure.method; tenantId = $CredentialMap.azure.tenantId; subscriptionId = $CredentialMap.azure.subscriptionId; azureCliFallback = [bool]$CredentialMap.azure.useAzureCliFallback }
            }
        }
        Findings      = @($findings)
        Relationships = @($relationships)
        RawEvidence   = [ordered]@{
            virtualMachines = ConvertTo-RangerHashtable -InputObject $vmInventory
            identitySecurity = ConvertTo-RangerHashtable -InputObject $identitySnapshots
            azureResources  = ConvertTo-RangerHashtable -InputObject $azureResources
            policyAssignments = ConvertTo-RangerHashtable -InputObject $policyAssignments
        }
    }
}