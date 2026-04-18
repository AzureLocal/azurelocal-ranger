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
    # Issue #173: track Redfish endpoints that returned errors so the collector
    # can report 'partial' rather than 'success' when data was unavailable.
    $redfishEndpointErrors = New-Object System.Collections.ArrayList

    $usableEndpoints = @(
        foreach ($endpoint in @($Config.targets.bmc.endpoints)) {
            if ($null -eq $endpoint) {
                continue
            }

            $bmcHost = if ($endpoint -is [System.Collections.IDictionary]) { $endpoint['host'] } else { $endpoint.host }
            if ([string]::IsNullOrWhiteSpace([string]$bmcHost)) {
                continue
            }

            [ordered]@{
                host = [string]$bmcHost
                node = if ($endpoint -is [System.Collections.IDictionary]) { $endpoint['node'] } else { $endpoint.node }
            }
        }
    )

    if ($usableEndpoints.Count -eq 0) {
        throw 'No usable BMC endpoints with a host value are configured.'
    }

    foreach ($endpoint in $usableEndpoints) {
        $bmcHost = $endpoint.host
        $nodeName = if ($endpoint.node) { $endpoint.node } else { $bmcHost }
        $remoteNodeTarget = @(
            @($Config.targets.cluster.nodes) |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace([string]$_) -and (
                        [string]$_ -ieq [string]$nodeName -or
                        (($_ -split '\.')[0] -ieq [string]$nodeName)
                    )
                } |
                Select-Object -First 1
        )[0]

        if ([string]::IsNullOrWhiteSpace([string]$remoteNodeTarget)) {
            $remoteNodeTarget = $nodeName
        }

        # When no matching cluster node was found, $remoteNodeTarget equals the BMC IP.
        # iDRAC / BMC IPs run Redfish only — attempting WinRM against them always fails.
        # Skip all WinRM-based sub-collectors (VBS posture, DDA, OMI) for this endpoint.
        $hasWinRmTarget = $remoteNodeTarget -ne $bmcHost
        try {
            $systemUri = "https://$bmcHost/redfish/v1/Systems/System.Embedded.1"
            $system = Invoke-RangerRedfishRequest -Uri $systemUri -Credential $CredentialMap.bmc
            $bios = Invoke-RangerSafeAction -Label "Redfish BIOS inventory for $bmcHost" -DefaultValue $null -ScriptBlock { Invoke-RangerRedfishRequest -Uri "$systemUri/Bios" -Credential $CredentialMap.bmc }
            $manager = Invoke-RangerSafeAction -Label "Redfish manager inventory for $bmcHost" -DefaultValue $null -ScriptBlock { Invoke-RangerRedfishRequest -Uri "https://$bmcHost/redfish/v1/Managers/iDRAC.Embedded.1" -Credential $CredentialMap.bmc }
            $processors = @(
                Invoke-RangerSafeAction -Label "Redfish processor inventory for $bmcHost" -DefaultValue @() -ScriptBlock {
                    Invoke-RangerRedfishCollection -CollectionUri "$systemUri/Processors" -Host $bmcHost -Credential $CredentialMap.bmc
                }
            )
            $memory = @(
                Invoke-RangerSafeAction -Label "Redfish memory inventory for $bmcHost" -DefaultValue @() -ScriptBlock {
                    Invoke-RangerRedfishCollection -CollectionUri "$systemUri/Memory" -Host $bmcHost -Credential $CredentialMap.bmc
                }
            )
            $ethernet = @(
                Invoke-RangerSafeAction -Label "Redfish Ethernet inventory for $bmcHost" -DefaultValue @() -ScriptBlock {
                    Invoke-RangerRedfishCollection -CollectionUri "$systemUri/EthernetInterfaces" -Host $bmcHost -Credential $CredentialMap.bmc
                }
            )
            $storageControllers = @(
                Invoke-RangerSafeAction -Label "Redfish storage inventory for $bmcHost" -DefaultValue @() -ScriptBlock {
                    Invoke-RangerRedfishCollection -CollectionUri "$systemUri/Storage" -Host $bmcHost -Credential $CredentialMap.bmc
                }
            )
            $firmwareInventory = @(
                Invoke-RangerSafeAction -Label "Redfish firmware inventory for $bmcHost" -DefaultValue @() -ScriptBlock {
                    Invoke-RangerRedfishCollection -CollectionUri "https://$bmcHost/redfish/v1/UpdateService/FirmwareInventory" -Host $bmcHost -Credential $CredentialMap.bmc
                }
            )
            $updateService = Invoke-RangerSafeAction -Label "Redfish update service for $bmcHost" -DefaultValue $null -ScriptBlock { Invoke-RangerRedfishRequest -Uri "https://$bmcHost/redfish/v1/UpdateService" -Credential $CredentialMap.bmc }
            $dellLcService = Invoke-RangerSafeAction -Label "Dell lifecycle controller service for $bmcHost" -DefaultValue $null -ScriptBlock { Invoke-RangerRedfishRequest -Uri "https://$bmcHost/redfish/v1/Managers/iDRAC.Embedded.1/Oem/Dell/DellLCService" -Credential $CredentialMap.bmc }
            $dellAttributes = Invoke-RangerSafeAction -Label "Dell manager attributes for $bmcHost" -DefaultValue $null -ScriptBlock { Invoke-RangerRedfishRequest -Uri "https://$bmcHost/redfish/v1/Managers/iDRAC.Embedded.1/Attributes" -Credential $CredentialMap.bmc }

            # Issue #57: Power supplies and thermal/fans from Redfish
            $powerSupplies = @(
                Invoke-RangerSafeAction -Label "Power supply inventory for $bmcHost" -DefaultValue @() -ScriptBlock {
                    $powerPayload = Invoke-RangerRedfishRequest -Uri "https://$bmcHost/redfish/v1/Chassis/System.Embedded.1/Power" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
                    if ($powerPayload -and $powerPayload.PowerSupplies) {
                        @($powerPayload.PowerSupplies | ForEach-Object {
                            [ordered]@{
                                name                 = $_.Name
                                manufacturer         = $_.Manufacturer
                                model                = $_.Model
                                serialNumber         = $_.SerialNumber
                                partNumber           = $_.PartNumber
                                powerCapacityWatts   = $_.PowerCapacityWatts
                                lastPowerOutputWatts = $_.LastPowerOutputWatts
                                statusHealth         = if ($_.Status) { $_.Status.Health } else { $null }
                                statusState          = if ($_.Status) { $_.Status.State } else { $null }
                            }
                        })
                    } else { @() }
                }
            )
            $thermalPayload = Invoke-RangerSafeAction -Label "Thermal inventory for $bmcHost" -DefaultValue $null -ScriptBlock { Invoke-RangerRedfishRequest -Uri "https://$bmcHost/redfish/v1/Chassis/System.Embedded.1/Thermal" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue }
            $fans = if ($thermalPayload -and $thermalPayload.Fans) {
                @($thermalPayload.Fans | ForEach-Object {
                    [ordered]@{
                        name         = $_.Name
                        reading      = $_.Reading
                        readingUnits = $_.ReadingUnits
                        minReadingRange = $_.MinReadingRange
                        statusHealth = if ($_.Status) { $_.Status.Health } else { $null }
                        statusState  = if ($_.Status) { $_.Status.State } else { $null }
                    }
                })
            } else { @() }
            $temperatures = if ($thermalPayload -and $thermalPayload.Temperatures) {
                @($thermalPayload.Temperatures | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) } | Select-Object -First 20 | ForEach-Object {
                    [ordered]@{
                        name                     = $_.Name
                        readingCelsius           = $_.ReadingCelsius
                        upperThresholdCritical   = $_.UpperThresholdCritical
                        upperThresholdNonCritical = $_.UpperThresholdNonCritical
                        statusHealth             = if ($_.Status) { $_.Status.Health } else { $null }
                        statusState              = if ($_.Status) { $_.Status.State } else { $null }
                    }
                })
            } else { @() }

            # Issue #57: NIC detail from Redfish NetworkAdapters endpoint
            $networkAdaptersDetail = @(
                Invoke-RangerSafeAction -Label "Redfish NetworkAdapters for $bmcHost" -DefaultValue @() -ScriptBlock {
                    $naCollection = Invoke-RangerRedfishRequest -Uri "$systemUri/NetworkAdapters" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
                    if ($naCollection -and $naCollection.Members) {
                        @($naCollection.Members | ForEach-Object {
                            $naUri = $_.'@odata.id'
                            $na = Invoke-RangerSafeAction -Label "NetworkAdapter $naUri" -DefaultValue $null -ScriptBlock {
                                Invoke-RangerRedfishRequest -Uri "https://$bmcHost$naUri" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
                            }
                            if ($na) {
                                [ordered]@{
                                    id              = $na.Id
                                    name            = $na.Name
                                    manufacturer    = $na.Manufacturer
                                    model           = $na.Model
                                    partNumber      = $na.PartNumber
                                    serialNumber    = $na.SerialNumber
                                    driverVersion   = if ($na.Controllers) { @($na.Controllers)[0].FirmwarePackageVersion } else { $null }
                                    firmwareVersion = if ($na.Controllers) { @($na.Controllers)[0].ControllerCapabilities.DataCenterBridging } else { $null }
                                    networkPorts    = @(if ($na.NetworkPorts) {
                                        Invoke-RangerSafeAction -Label "NetworkPorts for $naUri" -DefaultValue @() -ScriptBlock {
                                            $portsUri = "https://$bmcHost$naUri/NetworkPorts"
                                            $ports = Invoke-RangerRedfishRequest -Uri $portsUri -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
                                            if ($ports -and $ports.Members) {
                                                @($ports.Members | ForEach-Object {
                                                    $p = Invoke-RangerSafeAction -Label "Port $_.'@odata.id'" -DefaultValue $null -ScriptBlock {
                                                        Invoke-RangerRedfishRequest -Uri "https://$bmcHost$($_.'@odata.id')" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
                                                    }
                                                    if ($p) { [ordered]@{ id = $p.Id; linkStatus = $p.LinkStatus; currentLinkSpeedMbps = $p.CurrentLinkSpeedMbps; macAddress = $p.AssociatedNetworkAddresses; supportedLinkCapabilities = @($p.SupportedLinkCapabilities) } }
                                                } | Where-Object { $_ })
                                            } else { @() }
                                        }
                                    } else { @() })
                                    statusHealth = if ($na.Status) { $na.Status.Health } else { $null }
                                }
                            }
                        } | Where-Object { $_ })
                    } else { @() }
                }
            )

            # Per-DIMM granularity from Redfish memory collection
            $memoryDimms = @(
                Invoke-RangerSafeAction -Label "Redfish DIMM detail for $bmcHost" -DefaultValue @() -ScriptBlock {
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
                Invoke-RangerSafeAction -Label "GPU/accelerator inventory for $bmcHost" -DefaultValue @() -ScriptBlock {
                    $pcieCollection = try {
                        Invoke-RangerRedfishRequest -Uri "https://$bmcHost/redfish/v1/Systems/System.Embedded.1/PCIeDevices" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
                    }
                    catch {
                        if ($_.Exception.Message -match '404' -or ($_.Exception -is [Microsoft.PowerShell.Commands.HttpResponseException] -and [int]$_.Exception.Response.StatusCode -eq 404)) {
                            # Issue #173: record the missing endpoint so the collector reports partial
                            [void]$redfishEndpointErrors.Add([ordered]@{ host = $bmcHost; endpoint = 'PCIeDevices'; statusCode = 404; message = $_.Exception.Message })
                            $null
                        }
                        else {
                            throw
                        }
                    }
                    if ($pcieCollection -and $pcieCollection.Members) {
                        @($pcieCollection.Members | ForEach-Object {
                            $pcieUri = $_.'@odata.id'
                            $pcieDev = Invoke-RangerSafeAction -Label "PCIe device detail $pcieUri" -DefaultValue $null -ScriptBlock {
                                Invoke-RangerRedfishRequest -Uri "https://$bmcHost$pcieUri" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
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
            $bmcCert = Invoke-RangerSafeAction -Label "BMC SSL certificate for $bmcHost" -DefaultValue $null -ScriptBlock {
                $certCollection = Invoke-RangerRedfishRequest -Uri "https://$bmcHost/redfish/v1/Managers/iDRAC.Embedded.1/NetworkProtocol/HTTPS/Certificates" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
                if ($certCollection -and $certCollection.Members -and @($certCollection.Members).Count -gt 0) {
                    $certUri = $certCollection.Members[0].'@odata.id'
                    $certDetail = Invoke-RangerRedfishRequest -Uri "https://$bmcHost$certUri" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
                    if ($certDetail) {
                        $expiryDate = $null
                        if ($certDetail.ValidNotAfter) {
                            $parsedExpiry = [datetimeoffset]::MinValue
                            if ([datetimeoffset]::TryParse([string]$certDetail.ValidNotAfter, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$parsedExpiry)) {
                                $expiryDate = $parsedExpiry.UtcDateTime
                            }
                        }
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
                Invoke-RangerSafeAction -Label "Physical disk detail for $bmcHost" -DefaultValue @() -ScriptBlock {
                    @($storageControllers | ForEach-Object {
                        $ctrlUri = $_.'@odata.id'
                        if ($ctrlUri) {
                            $driveLinks = Invoke-RangerSafeAction -Label "Drive links for $ctrlUri" -DefaultValue $null -ScriptBlock {
                                Invoke-RangerRedfishRequest -Uri "https://$bmcHost$ctrlUri" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
                            }
                            if ($driveLinks -and $driveLinks.Drives) {
                                @($driveLinks.Drives | ForEach-Object {
                                    $driveUri = $_.'@odata.id'
                                    $driveDetail = Invoke-RangerSafeAction -Label "Drive $driveUri" -DefaultValue $null -ScriptBlock {
                                        Invoke-RangerRedfishRequest -Uri "https://$bmcHost$driveUri" -Credential $CredentialMap.bmc -ErrorAction SilentlyContinue
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

            # VBS sub-components (OS-level — requires WinRM on the cluster node, not the BMC IP).
            # Skip when no matching cluster node was resolved; probing the iDRAC IP via WinRM always fails.
            $vbsPosture = if (-not $hasWinRmTarget) {
                Write-RangerLog -Level debug -Message "VBS sub-component posture for $nodeName skipped — no cluster node FQDN matched; '$remoteNodeTarget' is the BMC IP, not a WinRM target."
                $null
            } else {
            Invoke-RangerSafeAction -Label "VBS sub-component posture for $nodeName" -DefaultValue $null -ScriptBlock {
                Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -NodeName $remoteNodeTarget -ScriptBlock {
                    $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
                    # Issue #57: DDA and GPU-P capability
                    $partitionableGpu = @(try { Get-VMHostPartitionableGpu -ErrorAction Stop } catch { try { Get-VMPartitionableGpu -ErrorAction Stop } catch { @() } })
                    # Issue #70: OpenManage Integration for Microsoft Azure Local
                    $omiService = @(Get-Service -Name 'DELL_*', 'OpenManage*', 'OMHCI*' -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, Status, StartType)
                    $omiReg = try { Get-ItemProperty -Path 'HKLM:\SOFTWARE\Dell\OpenManage' -ErrorAction Stop } catch {
                        try { Get-ItemProperty -Path 'HKLM:\SOFTWARE\Dell\SEA\OMHCI' -ErrorAction Stop } catch { $null }
                    }
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
                            gpuPCapable            = @($partitionableGpu).Count -gt 0
                            gpuPartitionableCount  = @($partitionableGpu).Count
                            openManageService      = @($omiService | ForEach-Object { [ordered]@{ name = $_.Name; status = [string]$_.Status } })
                            openManageInstalled    = @($omiService).Count -gt 0
                            openManageVersion      = if ($omiReg) { $omiReg.Version } else { $null }
                        }
                    }
                }
            }
            } # end $hasWinRmTarget guard

            # Issue #57: TPM detail extraction from system.TrustedModules
            $tpmDetail = if (@($system.TrustedModules).Count -gt 0) {
                $tpm = @($system.TrustedModules)[0]
                [ordered]@{
                    present         = $true
                    firmwareVersion = $tpm.FirmwareVersion
                    interfaceType   = $tpm.InterfaceType
                    statusHealth    = if ($tpm.Status) { $tpm.Status.Health } else { $null }
                    statusState     = if ($tpm.Status) { $tpm.Status.State } else { $null }
                }
            } else { [ordered]@{ present = $false } }

            # Issue #57: BIOS depth extraction
            $biosDetail = [ordered]@{
                version     = if ($bios.Attributes.SystemBiosVersion) { $bios.Attributes.SystemBiosVersion } else { $system.BiosVersion }
                vendor      = $bios.Attributes.SystemBiosVendor
                releaseDate = $bios.Attributes.SystemBiosReleaseDate
                bootMode    = if ($bios.Attributes.BootMode) { $bios.Attributes.BootMode } else { if ($system.Boot.BootSourceOverrideTarget) { 'UEFI' } else { $null } }
                secureBoot  = $bios.Attributes.SecureBoot
                uefiEnabled = $bios.Attributes.UefiBootSettings -eq 'Enabled' -or $bios.Attributes.BootMode -eq 'Uefi'
            }

            # Issue #70: Structured Dell OEM data
            $idracLicenseLevel = Invoke-RangerSafeAction -Label "iDRAC license level for $bmcHost" -DefaultValue $null -ScriptBlock {
                if ($dellAttributes -and $dellAttributes.Attributes) {
                    $attrs = $dellAttributes.Attributes
                    # Try common Dell attribute paths for license level
                    $lic = $attrs.'iDRAC.Embedded.1.LicensingSummary'
                    if (-not $lic) { $lic = $attrs.'LicenseSKU' }
                    if (-not $lic) { $lic = $attrs.'Info.1.License' }
                    $lic
                }
            }
            $lcVersion = Invoke-RangerSafeAction -Label "Lifecycle Controller version for $bmcHost" -DefaultValue $null -ScriptBlock {
                if ($dellLcService) {
                    $v = $dellLcService.LCVersion
                    if (-not $v) { $v = $dellLcService.Version }
                    if (-not $v -and $manager) { $manager.FirmwareVersion }
                    else { $v }
                }
            }
            $supportAssistDetail = Invoke-RangerSafeAction -Label "SupportAssist data for $bmcHost" -DefaultValue $null -ScriptBlock {
                if ($dellAttributes -and $dellAttributes.Attributes) {
                    $attrs = $dellAttributes.Attributes
                    [ordered]@{
                        enabled                 = [string]$attrs.'SupportAssist.1.Enable' -eq 'Enabled'
                        proSupportEntitlementDate = $attrs.'SupportAssist.1.ProPackageRenewalDate'
                        lastCollectionTime      = $attrs.'SupportAssist.1.CollectionTimeStamp'
                        contactEmail            = $attrs.'SupportAssist.1.ContactEmail'
                    }
                }
            }
            $firmwareComplianceDetail = @($firmwareInventory | ForEach-Object {
                $fw = $_
                [ordered]@{
                    name          = $fw.Name
                    id            = $fw.'@odata.id'
                    version       = $fw.Version
                    updateable    = $fw.Updateable
                    softwareType  = $fw.SoftwareType
                    releaseDate   = $fw.ReleaseDate
                    statusHealth  = if ($fw.Status) { $fw.Status.Health } else { $null }
                }
            })

            $trustedModules = @($system.TrustedModules)
            $processorModels = @(Get-RangerGroupedCount -Items $processors -PropertyName 'Model')
            $processorTotalCores = try { ($processors | Where-Object { $_.TotalCores } | Measure-Object -Property TotalCores -Sum).Sum } catch { $null }
            $processorLogicalThreads = try { ($processors | Where-Object { $_.TotalThreads } | Measure-Object -Property TotalThreads -Sum).Sum } catch { $null }
            $memoryCapacityGiB = [math]::Round((@($memory | Where-Object { $_.CapacityMiB } | ForEach-Object { [double]$_.CapacityMiB / 1024 } | Measure-Object -Sum).Sum), 2)
            $firmwareVersions = @(Get-RangerGroupedCount -Items $firmwareInventory -PropertyName 'Version')
            $storageControllerModels = @(Get-RangerGroupedCount -Items $storageControllers -PropertyName 'Name')

            [void]$nodes.Add([ordered]@{
                node             = $nodeName
                endpoint         = $bmcHost
                manufacturer     = $system.Manufacturer
                model            = $system.Model
                serviceTag       = $system.SKU
                serialNumber     = $system.SerialNumber
                powerState       = $system.PowerState
                biosVersion      = if ($bios.Attributes.SystemBiosVersion) { $bios.Attributes.SystemBiosVersion } else { $system.BiosVersion }
                biosDetail       = $biosDetail
                bmcFirmware      = $manager.FirmwareVersion
                cpuCount         = @($processors).Count
                memoryDeviceCount = @($memory).Count
                memoryGiB        = if ($system.MemorySummary.TotalSystemMemoryGiB) { $system.MemorySummary.TotalSystemMemoryGiB } else { $null }
                nicCount         = @($ethernet).Count
                storageControllerCount = @($storageControllers).Count
                firmwareCount    = @($firmwareInventory).Count
                processorSummary = [ordered]@{
                    sockets            = @($processors).Count
                    totalPhysicalCores = $processorTotalCores
                    logicalProcessors  = $processorLogicalThreads
                    models             = $processorModels
                }
                memorySummary    = [ordered]@{ dimmCount = @($memory).Count; totalCapacityGiB = $memoryCapacityGiB }
                memoryDimms      = @($memoryDimms)
                ethernetSummary  = [ordered]@{ portCount = @($ethernet).Count; byState = @(Get-RangerGroupedCount -Items $ethernet -PropertyName 'LinkStatus') }
                networkAdaptersDetail = @($networkAdaptersDetail)
                storageSummary   = [ordered]@{ controllerCount = @($storageControllers).Count; models = $storageControllerModels }
                physicalDisksDetail = @($physicalDisksDetail)
                firmwareSummary  = [ordered]@{ componentCount = @($firmwareInventory).Count; versions = $firmwareVersions }
                firmwareComplianceDetail = @($firmwareComplianceDetail)
                gpuDevices       = @($gpuDevices)
                gpuCount         = @($gpuDevices).Count
                powerSupplies    = @($powerSupplies)
                powerSupplyCount = @($powerSupplies).Count
                fans             = @($fans)
                fanCount         = @($fans).Count
                temperatures     = @($temperatures)
                tpmDetail        = $tpmDetail
                vbsPosture       = $vbsPosture
                bmcCert          = $bmcCert
                idracLicenseLevel = $idracLicenseLevel
                lcVersion        = $lcVersion
                supportAssist    = $supportAssistDetail
                securityPosture  = [ordered]@{
                    trustedModuleCount    = @($trustedModules).Count
                    secureBoot            = $bios.Attributes.SecureBoot
                    hvciEnabled           = if ($vbsPosture) { $vbsPosture.hvciEnabled } else { $null }
                    credentialGuardEnabled = if ($vbsPosture) { $vbsPosture.credentialGuardEnabled } else { $null }
                    bmcCertExpiryDays     = if ($bmcCert) { $bmcCert.daysUntilExpiry } else { $null }
                    tpmPresent            = $tpmDetail.present
                    tpmVersion            = $tpmDetail.interfaceType
                    gpuPCapable           = if ($vbsPosture) { $vbsPosture.gpuPCapable } else { $null }
                    openManageInstalled   = if ($vbsPosture) { $vbsPosture.openManageInstalled } else { $null }
                }
                trustedModules   = ConvertTo-RangerHashtable -InputObject $system.TrustedModules
                boot             = ConvertTo-RangerHashtable -InputObject $system.Boot
            })

            [void]$managementPosture.Add([ordered]@{
                node                    = $nodeName
                endpoint                = $bmcHost
                managerModel            = $manager.Model
                managerFirmwareVersion  = $manager.FirmwareVersion
                lifecycleController     = if ($manager.Name) { $manager.Name } else { 'iDRAC' }
                lifecycleControllerVersion = $lcVersion
                idracLicenseLevel       = $idracLicenseLevel
                openManageSignals       = ConvertTo-RangerHashtable -InputObject $manager.Oem
                openManageInstalled     = if ($vbsPosture) { $vbsPosture.openManageInstalled } else { $null }
                openManageVersion       = if ($vbsPosture) { $vbsPosture.openManageVersion } else { $null }
                firmwareInventoryCount  = @($firmwareInventory).Count
                firmwareComplianceDetail = @($firmwareComplianceDetail)
                lastResetTime           = $manager.DateTime
                updateService           = [ordered]@{ serviceEnabled = $updateService.ServiceEnabled; pushUri = $updateService.HttpPushUri; multipartPushUri = $updateService.MultipartHttpPushUri }
                lifecycleControllerState = ConvertTo-RangerHashtable -InputObject $dellLcService
                supportAssist           = $supportAssistDetail
                bmcCert                 = $bmcCert
            })

            [void]$relationships.Add((New-RangerRelationship -SourceType 'bmc-endpoint' -SourceId $bmcHost -TargetType 'cluster-node' -TargetId $nodeName -RelationshipType 'manages' -Properties ([ordered]@{ manufacturer = $system.Manufacturer; model = $system.Model })))
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
            [void]$findings.Add((New-RangerFinding -Severity warning -Title "BMC endpoint unavailable for $nodeName" -Description $_.Exception.Message -AffectedComponents @($nodeName, $bmcHost) -CurrentState 'hardware collector partial' -Recommendation 'Confirm BMC reachability, Redfish availability, and credential validity.'))
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

    # Issue #173: surface Redfish endpoint errors as a finding so the collector
    # correctly reports 'partial' and the operator knows which data is missing.
    if ($redfishEndpointErrors.Count -gt 0) {
        $affectedHosts = @($redfishEndpointErrors | ForEach-Object { $_.host } | Select-Object -Unique)
        $endpointList  = ($redfishEndpointErrors | ForEach-Object { "$($_.host)/$($_.endpoint) (HTTP $($_.statusCode))" }) -join '; '
        [void]$findings.Add((New-RangerFinding -Severity warning `
            -Title 'One or more Redfish endpoints returned errors — hardware data incomplete' `
            -Description "The following Redfish endpoints returned error responses and their data is absent from this run: $endpointList" `
            -AffectedComponents $affectedHosts `
            -CurrentState 'hardware collector partial' `
            -Recommendation 'Verify iDRAC firmware version supports the requested endpoint. PCIeDevices requires iDRAC 9 firmware 4.x or later.'))
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
