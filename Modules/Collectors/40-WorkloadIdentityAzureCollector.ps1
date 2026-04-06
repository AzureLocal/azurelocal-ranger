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

                    [ordered]@{
                        name              = $vm.Name
                        hostNode          = $env:COMPUTERNAME
                        state             = $vm.State.ToString()
                        uptime            = $vm.Uptime
                        generation        = $vm.Generation
                        processorCount    = $vm.ProcessorCount
                        memoryAssignedMb  = [math]::Round(($vm.MemoryAssigned / 1MB), 2)
                        dynamicMemory     = [bool]$vm.DynamicMemoryEnabled
                        checkpointType    = $vm.CheckpointType
                        storagePaths      = @($drives | ForEach-Object { $_.Path })
                        switchNames       = @($adapters | ForEach-Object { $_.SwitchName })
                        replicationMode   = if ($replication) { $replication.ReplicationMode } else { $null }
                    }
                }
            }
        }
    )

    $identitySnapshots = @(
        Invoke-RangerSafeAction -Label 'Identity and security snapshot' -DefaultValue @() -ScriptBlock {
            Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -ScriptBlock {
                $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
                $defender = if (Get-Command -Name Get-MpComputerStatus -ErrorAction SilentlyContinue) { Get-MpComputerStatus | Select-Object AMRunningMode, AntispywareEnabled, AntivirusEnabled, RealTimeProtectionEnabled } else { $null }
                $bitlocker = if (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue) { Get-BitLockerVolume | Select-Object MountPoint, ProtectionStatus, EncryptionMethod, VolumeStatus } else { @() }
                $localAdmins = try { Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop | Select-Object Name, ObjectClass, PrincipalSource } catch { @() }
                $certificates = Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction SilentlyContinue | Select-Object Subject, Thumbprint, NotAfter
                $deviceGuard = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
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
                    credSsp       = $credSsp
                    auditPolicy   = @($audit)
                }
            }
        }
    )

    $azureResources = @(
        Get-RangerAzureResources -Config $Config
    )

    $policyAssignments = @(
        Invoke-RangerSafeAction -Label 'Azure policy assignment snapshot' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $Config.credentials.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)

                if (-not (Get-Command -Name Get-AzPolicyAssignment -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($SubscriptionId) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) {
                    return @()
                }

                $scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup"
                Get-AzPolicyAssignment -Scope $scope -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, Scope, EnforcementMode
            }
        }
    )

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
    }

    $findings = New-Object System.Collections.ArrayList
    if (@($identitySnapshots | Where-Object { -not $_.partOfDomain }).Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($Config.credentials.cluster.passwordRef) -and -not [string]::IsNullOrWhiteSpace($Config.targets.azure.resourceGroup)) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'Local identity posture detected with Azure context configured' -Description 'At least one node appears not to be joined to a domain while Azure registration context is configured.' -CurrentState 'local-key-vault candidate' -Recommendation 'Confirm whether this is a local-identity deployment and verify Key Vault secret references and certificate posture.'))
    }

    return @{
        Status        = 'success'
        Domains       = @{
            virtualMachines = [ordered]@{
                inventory        = ConvertTo-RangerHashtable -InputObject $vmInventory
                placement        = ConvertTo-RangerHashtable -InputObject @($vmInventory | ForEach-Object { [ordered]@{ vm = $_.name; hostNode = $_.hostNode; state = $_.state } })
                workloadFamilies = @($workloadFamilies)
            }
            identitySecurity = [ordered]@{
                nodes        = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; partOfDomain = $_.partOfDomain; domain = $_.domain; credSsp = $_.credSsp } })
                certificates = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; items = $_.certificates } })
                posture      = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; defender = $_.defender; deviceGuard = $_.deviceGuard; bitlocker = $_.bitlocker } })
                localAdmins  = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; members = $_.localAdmins } })
                auditPolicy  = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; values = $_.auditPolicy } })
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