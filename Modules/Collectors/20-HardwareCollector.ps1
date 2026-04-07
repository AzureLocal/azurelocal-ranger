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

            # Per-DIMM granularity from Redfish memory collection
            $memoryDimms = @(
                Invoke-RangerSafeAction -Label "Redfish DIMM detail for $host" -DefaultValue @() -ScriptBlock {
                    @($memory | ForEach-Object {
                        $dimm = $_
                        [ordered]@{
                            id               = $dimm.'@odata.id'
                            manufacturer     = $dimm.Manufacturer
                            partNumber       = $dimm.PartNumber
                            serialNumber     = $dimm.SerialNumber
                            capacityMiB      = $dimm.CapacityMiB
                            capacityGiB      = if ($dimm.CapacityMiB) { [math]::Round($dimm.CapacityMiB / 1024.0, 2) } else { $null }
                            operatingSpeedMhz = $dimm.OperatingSpeedMhz
                            memoryType       = $dimm.MemoryType
                            memoryDeviceType = $dimm.MemoryDeviceType
                            bankLocator      = $dimm.BankLocator
                            slotLocator      = $dimm.DeviceLocator
                            configuredVoltageMv = $dimm.VoltageMV
                            status           = if ($dimm.Status) { [ordered]@{ state = $dimm.Status.State; health = $dimm.Status.Health } } else { $null }
                        }
                    })
                }
            )

            # GPU / Accelerators via Redfish PCIeDevices (and OS-side via WinRM if available)
            $gpuDevices = @(
                Invoke-RangerSafeAction -Label "GPU/accelerator inventory for $host" -DefaultValue @() -ScriptBlock {
                    $pcieCollection = Invoke-RangerSafeAction -Label "Redfish PCIe devices for $host" -DefaultValue $null -ScriptBlock {
                        Invoke-RangerRedfishRequest -Uri "https://$host/redfish/v1/Systems/System.Embedded.1/PCIeDevices" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
                    }
                    if ($pcieCollection -and $pcieCollection.Members) {
                        @($pcieCollection.Members | ForEach-Object {
                            $pcieUri = $_.'@odata.id'
                            $pcieDev = Invoke-RangerSafeAction -Label "PCIe device detail $pcieUri" -DefaultValue $null -ScriptBlock {
                                Invoke-RangerRedfishRequest -Uri "https://$host$pcieUri" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
                            }
                            if ($pcieDev -and $pcieDev.Name -match 'GPU|Accelerat|NVIDIA|AMD|Radeon') {
                                [ordered]@{
                                    name       = $pcieDev.Name
                                    model      = $pcieDev.Model
                                    deviceType = $pcieDev.DeviceType
                                    slotId     = if ($pcieDev.PCIeInterface) { $pcieDev.PCIeInterface.MaxLanes } else { $null }
                                    status     = if ($pcieDev.Status) { $pcieDev.Status.Health } else { $null }
                                }
                            }
                        } | Where-Object { $_ })
                    } else { @() }
                }
            )

            # BMC SSL certificate detail
            $bmcCert = Invoke-RangerSafeAction -Label "BMC SSL certificate for $host" -DefaultValue $null -ScriptBlock {
                $certCollection = Invoke-RangerRedfishRequest -Uri "https://$host/redfish/v1/Managers/iDRAC.Embedded.1/NetworkProtocol/HTTPS/Certificates" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
                if ($certCollection -and $certCollection.Members -and @($certCollection.Members).Count -gt 0) {
                    $certUri = $certCollection.Members[0].'@odata.id'
                    $certDetail = Invoke-RangerRedfishRequest -Uri "https://$host$certUri" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
                    if ($certDetail) {
                        $expiryDate = if ($certDetail.ValidNotAfter) { [datetime]::ParseExact($certDetail.ValidNotAfter, 'yyyy-MM-ddTHH:mm:ssZ', $null, [System.Globalization.DateTimeStyles]::AssumeUniversal) } else { $null }
                        [ordered]@{
                            subject        = $certDetail.Subject
                            issuer         = $certDetail.Issuer
                            validFrom      = $certDetail.ValidNotBefore
                            validUntil     = $certDetail.ValidNotAfter
                            daysUntilExpiry = if ($expiryDate) { [math]::Round(($expiryDate - (Get-Date)).TotalDays, 0) } else { $null }
                            thumbprint     = $certDetail.Fingerprint
                        }
                    }
                }
            }

            # Physical disk enumeration with slot/location depth
            $physicalDisksDetail = @(
                Invoke-RangerSafeAction -Label "Physical disk detail for $host" -DefaultValue @() -ScriptBlock {
                    @($storageControllers | ForEach-Object {
                        $ctrlUri = $_.'@odata.id'
                        if ($ctrlUri) {
                            $driveLinks = Invoke-RangerSafeAction -Label "Drive links for $ctrlUri" -DefaultValue $null -ScriptBlock {
                                Invoke-RangerRedfishRequest -Uri "https://$host$ctrlUri" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
                            }
                            if ($driveLinks -and $driveLinks.Drives) {
                                @($driveLinks.Drives | ForEach-Object {
                                    $driveUri = $_.'@odata.id'
                                    $driveDetail = Invoke-RangerSafeAction -Label "Drive $driveUri" -DefaultValue $null -ScriptBlock {
                                        Invoke-RangerRedfishRequest -Uri "https://$host$driveUri" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
                                    }
                                    if ($driveDetail) {
                                        [ordered]@{
                                            name            = $driveDetail.Name
                                            model           = $driveDetail.Model
                                            manufacturer    = $driveDetail.Manufacturer
                                            mediaType       = $driveDetail.MediaType
                                            protocol        = $driveDetail.Protocol
                                            capacityBytes   = $driveDetail.CapacityBytes
                                            capacityGiB     = if ($driveDetail.CapacityBytes) { [math]::Round($driveDetail.CapacityBytes / 1GB, 2) } else { $null }
                                            revision        = $driveDetail.Revision
                                            serialNumber    = $driveDetail.SerialNumber
                                            partNumber      = $driveDetail.PartNumber
                                            slot            = if ($driveDetail.PhysicalLocation) { $driveDetail.PhysicalLocation.PartLocation } else { $driveDetail.Location }
                                            locationIndicatorActive = $driveDetail.LocationIndicatorActive
                                            powerState      = $driveDetail.PowerState
                                            statusHealth    = if ($driveDetail.Status) { $driveDetail.Status.Health } else { $null }
                                            statusState     = if ($driveDetail.Status) { $driveDetail.Status.State } else { $null }
                                            predictedLifeLeftPercent = $driveDetail.PredictedLifeLeftPercent
                                            hotspareType    = $driveDetail.HotspareType
                                        }
                                    }
                                } | Where-Object { $_ })
                            } else { @() }
                        } else { @() }
                    })
                }
            )

            # VBS sub-components (OS-level — requires WinRM on the node)
            $vbsPosture = Invoke-RangerSafeAction -Label "VBS sub-component posture for $nodeName" -DefaultValue $null -ScriptBlock {
                Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -NodeName $nodeName -ScriptBlock {
                    $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
                    if ($dg) {
                        [ordered]@{
                            virtualBasedSecurityStatus    = $dg.VirtualizationBasedSecurityStatus
                            securityServicesRunning       = @($dg.SecurityServicesRunning)
                            securityServicesConfigured    = @($dg.SecurityServicesConfigured)
                            codeIntegrityPolicyEnforcementStatus = $dg.CodeIntegrityPolicyEnforcementStatus
                            usermodeCodeIntegrityPolicyEnforcementStatus = $dg.UsermodeCodeIntegrityPolicyEnforcementStatus
                            # 4 = HVCI, 6 = Credential Guard, 128 = DRTM indicator
                            hvciEnabled           = (@($dg.SecurityServicesRunning) -contains 4) -or (@($dg.SecurityServicesRunning) -contains 2)
                            credentialGuardEnabled = (@($dg.SecurityServicesRunning) -contains 1)
                            securedCoreDrtm        = (@($dg.SecurityServicesConfigured) -contains 128)
                        }
                    }
                }
            }

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
                memoryDimms      = @($memoryDimms)
                ethernetSummary  = [ordered]@{ portCount = @($ethernet).Count; byState = @(Get-RangerGroupedCount -Items $ethernet -PropertyName 'LinkStatus') }
                storageSummary   = [ordered]@{ controllerCount = @($storageControllers).Count; models = $storageControllerModels }
                physicalDisksDetail = @($physicalDisksDetail)
                firmwareSummary  = [ordered]@{ componentCount = @($firmwareInventory).Count; versions = $firmwareVersions }
                gpuDevices       = @($gpuDevices)
                gpuCount         = @($gpuDevices).Count
                vbsPosture       = $vbsPosture
                bmcCert          = $bmcCert
                securityPosture  = [ordered]@{
                    trustedModuleCount    = @($trustedModules).Count
                    secureBoot            = $bios.Attributes.SecureBoot
                    hvciEnabled           = if ($vbsPosture) { $vbsPosture.hvciEnabled } else { $null }
                    credentialGuardEnabled = if ($vbsPosture) { $vbsPosture.credentialGuardEnabled } else { $null }
                    bmcCertExpiryDays     = if ($bmcCert) { $bmcCert.daysUntilExpiry } else { $null }
                }
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
                bmcCert                 = $bmcCert
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
                memoryDimms       = ConvertTo-RangerHashtable -InputObject $memoryDimms
                ethernet          = ConvertTo-RangerHashtable -InputObject $ethernet
                storageControllers = ConvertTo-RangerHashtable -InputObject $storageControllers
                physicalDisksDetail = ConvertTo-RangerHashtable -InputObject $physicalDisksDetail
                firmwareInventory = ConvertTo-RangerHashtable -InputObject $firmwareInventory
                gpuDevices        = ConvertTo-RangerHashtable -InputObject $gpuDevices
                vbsPosture        = ConvertTo-RangerHashtable -InputObject $vbsPosture
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

    $nodesWithExpiringBmcCert = @($nodesArray | Where-Object { $null -ne $_.bmcCert.daysUntilExpiry -and $_.bmcCert.daysUntilExpiry -lt 90 })
    if ($nodesWithExpiringBmcCert.Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'BMC SSL certificate expiring within 90 days on one or more nodes' -Description 'The iDRAC certificate inventory found certificates approaching expiry.' -AffectedComponents (@($nodesWithExpiringBmcCert | ForEach-Object { $_.node })) -CurrentState "$($nodesWithExpiringBmcCert.Count) nodes with expiring BMC cert" -Recommendation 'Renew the iDRAC HTTPS certificate before it expires to prevent management plane disruption.'))
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
                    gpuNodes      = @($nodesArray | Where-Object { $_.gpuCount -gt 0 }).Count
                    totalGpuCount = @($nodesArray | Measure-Object -Property gpuCount -Sum).Sum
                }
                firmware = [ordered]@{ managedNodes = @($managementArray | Where-Object { $_.managerFirmwareVersion }).Count; versions = @(Get-RangerGroupedCount -Items $managementArray -PropertyName 'managerFirmwareVersion') }
                security = [ordered]@{
                    trustedModuleNodes     = @($nodesArray | Where-Object { $_.securityPosture.trustedModuleCount -gt 0 }).Count
                    secureBootEnabledNodes = @($nodesArray | Where-Object { $_.securityPosture.secureBoot -in @('Enabled', 'On', $true) }).Count
                    hvciEnabledNodes       = @($nodesArray | Where-Object { $_.securityPosture.hvciEnabled -eq $true }).Count
                    credGuardEnabledNodes  = @($nodesArray | Where-Object { $_.securityPosture.credentialGuardEnabled -eq $true }).Count
                    bmcCertExpiringNodes   = @($nodesArray | Where-Object { $null -ne $_.securityPosture.bmcCertExpiryDays -and $_.securityPosture.bmcCertExpiryDays -lt 90 }).Count
                }
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