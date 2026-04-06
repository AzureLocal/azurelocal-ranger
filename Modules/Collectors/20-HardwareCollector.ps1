function Invoke-RangerHardwareCollector {
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

    if (-not $CredentialMap.bmc) {
        throw 'The hardware collector requires a BMC credential.'
    }

    $nodes = New-Object System.Collections.ArrayList
    $managementPosture = New-Object System.Collections.ArrayList
    $relationships = New-Object System.Collections.ArrayList
    $findings = New-Object System.Collections.ArrayList
    $rawEvidence = New-Object System.Collections.ArrayList

    foreach ($endpoint in @($Config.targets.bmc.endpoints)) {
        $host = $endpoint.host
        $nodeName = if ($endpoint.node) { $endpoint.node } else { $host }
        try {
            $systemUri = "https://$host/redfish/v1/Systems/System.Embedded.1"
            $system = Invoke-RangerRedfishRequest -Uri $systemUri -Credential $CredentialMap.bmc
            $bios = Invoke-RangerSafeAction -Label "Redfish BIOS inventory for $host" -DefaultValue $null -ScriptBlock { Invoke-RangerRedfishRequest -Uri "$systemUri/Bios" -Credential $CredentialMap.bmc }
            $manager = Invoke-RangerSafeAction -Label "Redfish manager inventory for $host" -DefaultValue $null -ScriptBlock { Invoke-RangerRedfishRequest -Uri "https://$host/redfish/v1/Managers/iDRAC.Embedded.1" -Credential $CredentialMap.bmc }
            $processors = @(
                Invoke-RangerSafeAction -Label "Redfish processor inventory for $host" -DefaultValue @() -ScriptBlock {
                    Invoke-RangerRedfishCollection -CollectionUri "$systemUri/Processors" -Host $host -Credential $CredentialMap.bmc
                }
            )
            $memory = @(
                Invoke-RangerSafeAction -Label "Redfish memory inventory for $host" -DefaultValue @() -ScriptBlock {
                    Invoke-RangerRedfishCollection -CollectionUri "$systemUri/Memory" -Host $host -Credential $CredentialMap.bmc
                }
            )
            $ethernet = @(
                Invoke-RangerSafeAction -Label "Redfish Ethernet inventory for $host" -DefaultValue @() -ScriptBlock {
                    Invoke-RangerRedfishCollection -CollectionUri "$systemUri/EthernetInterfaces" -Host $host -Credential $CredentialMap.bmc
                }
            )
            $storageControllers = @(
                Invoke-RangerSafeAction -Label "Redfish storage inventory for $host" -DefaultValue @() -ScriptBlock {
                    Invoke-RangerRedfishCollection -CollectionUri "$systemUri/Storage" -Host $host -Credential $CredentialMap.bmc
                }
            )
            $firmwareInventory = @(
                Invoke-RangerSafeAction -Label "Redfish firmware inventory for $host" -DefaultValue @() -ScriptBlock {
                    Invoke-RangerRedfishCollection -CollectionUri "https://$host/redfish/v1/UpdateService/FirmwareInventory" -Host $host -Credential $CredentialMap.bmc
                }
            )
            $updateService = Invoke-RangerSafeAction -Label "Redfish update service for $host" -DefaultValue $null -ScriptBlock { Invoke-RangerRedfishRequest -Uri "https://$host/redfish/v1/UpdateService" -Credential $CredentialMap.bmc }
            $dellLcService = Invoke-RangerSafeAction -Label "Dell lifecycle controller service for $host" -DefaultValue $null -ScriptBlock { Invoke-RangerRedfishRequest -Uri "https://$host/redfish/v1/Managers/iDRAC.Embedded.1/Oem/Dell/DellLCService" -Credential $CredentialMap.bmc }
            $dellAttributes = Invoke-RangerSafeAction -Label "Dell manager attributes for $host" -DefaultValue $null -ScriptBlock { Invoke-RangerRedfishRequest -Uri "https://$host/redfish/v1/Managers/iDRAC.Embedded.1/Attributes" -Credential $CredentialMap.bmc }

            $trustedModules = @($system.TrustedModules)
            $processorModels = @(Get-RangerGroupedCount -Items $processors -PropertyName 'Model')
            $memoryCapacityGiB = [math]::Round((@($memory | Where-Object { $_.CapacityMiB } | ForEach-Object { [double]$_.CapacityMiB / 1024 } | Measure-Object -Sum).Sum), 2)
            $firmwareVersions = @(Get-RangerGroupedCount -Items $firmwareInventory -PropertyName 'Version')
            $storageControllerModels = @(Get-RangerGroupedCount -Items $storageControllers -PropertyName 'Name')

            [void]$nodes.Add([ordered]@{
                node             = $nodeName
                endpoint         = $host
                manufacturer     = $system.Manufacturer
                model            = $system.Model
                serviceTag       = $system.SKU
                serialNumber     = $system.SerialNumber
                powerState       = $system.PowerState
                biosVersion      = if ($bios.Attributes.SystemBiosVersion) { $bios.Attributes.SystemBiosVersion } else { $system.BiosVersion }
                bmcFirmware      = $manager.FirmwareVersion
                cpuCount         = @($processors).Count
                memoryDeviceCount = @($memory).Count
                memoryGiB        = if ($system.MemorySummary.TotalSystemMemoryGiB) { $system.MemorySummary.TotalSystemMemoryGiB } else { $null }
                nicCount         = @($ethernet).Count
                storageControllerCount = @($storageControllers).Count
                firmwareCount    = @($firmwareInventory).Count
                processorSummary = [ordered]@{ sockets = @($processors).Count; models = $processorModels }
                memorySummary    = [ordered]@{ dimmCount = @($memory).Count; totalCapacityGiB = $memoryCapacityGiB }
                ethernetSummary  = [ordered]@{ portCount = @($ethernet).Count; byState = @(Get-RangerGroupedCount -Items $ethernet -PropertyName 'LinkStatus') }
                storageSummary   = [ordered]@{ controllerCount = @($storageControllers).Count; models = $storageControllerModels }
                firmwareSummary  = [ordered]@{ componentCount = @($firmwareInventory).Count; versions = $firmwareVersions }
                securityPosture  = [ordered]@{ trustedModuleCount = @($trustedModules).Count; secureBoot = $bios.Attributes.SecureBoot }
                trustedModules   = ConvertTo-RangerHashtable -InputObject $system.TrustedModules
                boot             = ConvertTo-RangerHashtable -InputObject $system.Boot
            })

            [void]$managementPosture.Add([ordered]@{
                node                    = $nodeName
                endpoint                = $host
                managerModel            = $manager.Model
                managerFirmwareVersion  = $manager.FirmwareVersion
                lifecycleController     = if ($manager.Name) { $manager.Name } else { 'iDRAC' }
                openManageSignals       = ConvertTo-RangerHashtable -InputObject $manager.Oem
                firmwareInventoryCount  = @($firmwareInventory).Count
                lastResetTime           = $manager.DateTime
                updateService           = [ordered]@{ serviceEnabled = $updateService.ServiceEnabled; pushUri = $updateService.HttpPushUri; multipartPushUri = $updateService.MultipartHttpPushUri }
                lifecycleControllerState = ConvertTo-RangerHashtable -InputObject $dellLcService
                supportAssistSignals    = ConvertTo-RangerHashtable -InputObject $dellAttributes
                firmwareCompliance      = [ordered]@{ complianceEvidence = if ($updateService) { 'update-service-present' } else { 'not-discovered' }; inventoryCount = @($firmwareInventory).Count }
            })

            [void]$relationships.Add((New-RangerRelationship -SourceType 'bmc-endpoint' -SourceId $host -TargetType 'cluster-node' -TargetId $nodeName -RelationshipType 'manages' -Properties ([ordered]@{ manufacturer = $system.Manufacturer; model = $system.Model })))
            [void]$rawEvidence.Add([ordered]@{
                node              = $nodeName
                system            = ConvertTo-RangerHashtable -InputObject $system
                bios              = ConvertTo-RangerHashtable -InputObject $bios
                manager           = ConvertTo-RangerHashtable -InputObject $manager
                updateService     = ConvertTo-RangerHashtable -InputObject $updateService
                lifecycleController = ConvertTo-RangerHashtable -InputObject $dellLcService
                managerAttributes = ConvertTo-RangerHashtable -InputObject $dellAttributes
                processors        = ConvertTo-RangerHashtable -InputObject $processors
                memory            = ConvertTo-RangerHashtable -InputObject $memory
                ethernet          = ConvertTo-RangerHashtable -InputObject $ethernet
                storageControllers = ConvertTo-RangerHashtable -InputObject $storageControllers
                firmwareInventory = ConvertTo-RangerHashtable -InputObject $firmwareInventory
            })
        }
        catch {
            [void]$findings.Add((New-RangerFinding -Severity warning -Title "BMC endpoint unavailable for $nodeName" -Description $_.Exception.Message -AffectedComponents @($nodeName, $host) -CurrentState 'hardware collector partial' -Recommendation 'Confirm BMC reachability, Redfish availability, and credential validity.'))
        }
    }

    if ($nodes.Count -eq 0) {
        throw 'No hardware inventory could be gathered from the configured BMC endpoints.'
    }

    $nodesArray = @($nodes)
    $managementArray = @($managementPosture)
    $securityNodesWithoutTrustedModule = @($nodesArray | Where-Object { $_.securityPosture.trustedModuleCount -eq 0 })
    if ($securityNodesWithoutTrustedModule.Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'One or more nodes do not report a trusted module through Redfish' -Description 'The hardware collector found nodes without a visible TPM or other trusted module signal in the Redfish system payload.' -AffectedComponents (@($securityNodesWithoutTrustedModule | ForEach-Object { $_.node })) -CurrentState 'trusted module metadata absent' -Recommendation 'Validate TPM posture and Redfish visibility for each affected node before relying on the hardware security inventory.'))
    }

    if (@($managementArray | Where-Object { -not $_.updateService.serviceEnabled }).Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'One or more Dell management endpoints did not advertise update-service enablement' -Description 'The OEM posture snapshot could not confirm a healthy Redfish update-service path for every endpoint.' -AffectedComponents (@($managementArray | Where-Object { -not $_.updateService.serviceEnabled } | ForEach-Object { $_.node })) -CurrentState 'firmware-service posture mixed' -Recommendation 'Review iDRAC update-service state, firmware catalog access, and lifecycle-controller posture before relying on automated firmware evidence.'))
    }

    return @{
        Status        = if ($findings.Count -gt 0) { 'partial' } else { 'success' }
        Domains       = @{
            hardware = [ordered]@{
                nodes   = $nodesArray
                summary = [ordered]@{
                    nodeCount     = $nodes.Count
                    manufacturers = @(Get-RangerGroupedCount -Items $nodesArray -PropertyName 'manufacturer')
                    models        = @(Get-RangerGroupedCount -Items $nodesArray -PropertyName 'model')
                    firmwareNodes = @($managementArray | Where-Object { $_.firmwareInventoryCount -gt 0 }).Count
                    totalMemoryGiB = [math]::Round((@($nodesArray | Where-Object { $null -ne $_.memoryGiB } | Measure-Object -Property memoryGiB -Sum).Sum), 2)
                    totalProcessors = @($nodesArray | Measure-Object -Property cpuCount -Sum).Sum
                }
                firmware = [ordered]@{ managedNodes = @($managementArray | Where-Object { $_.managerFirmwareVersion }).Count; versions = @(Get-RangerGroupedCount -Items $managementArray -PropertyName 'managerFirmwareVersion') }
                security = [ordered]@{ trustedModuleNodes = @($nodesArray | Where-Object { $_.securityPosture.trustedModuleCount -gt 0 }).Count; secureBootEnabledNodes = @($nodesArray | Where-Object { $_.securityPosture.secureBoot -in @('Enabled', 'On', $true) }).Count }
            }
            oemIntegration = [ordered]@{
                endpoints         = @($Config.targets.bmc.endpoints)
                managementPosture = $managementArray
            }
        }
        Findings      = @($findings)
        Relationships = @($relationships)
        RawEvidence   = @($rawEvidence)
    }
}