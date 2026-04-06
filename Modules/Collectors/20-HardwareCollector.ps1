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
            })

            [void]$relationships.Add((New-RangerRelationship -SourceType 'bmc-endpoint' -SourceId $host -TargetType 'cluster-node' -TargetId $nodeName -RelationshipType 'manages' -Properties ([ordered]@{ manufacturer = $system.Manufacturer; model = $system.Model })))
            [void]$rawEvidence.Add([ordered]@{
                node              = $nodeName
                system            = ConvertTo-RangerHashtable -InputObject $system
                bios              = ConvertTo-RangerHashtable -InputObject $bios
                manager           = ConvertTo-RangerHashtable -InputObject $manager
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

    return @{
        Status        = if ($findings.Count -gt 0) { 'partial' } else { 'success' }
        Domains       = @{
            hardware = [ordered]@{
                nodes   = @($nodes)
                summary = [ordered]@{
                    nodeCount     = $nodes.Count
                    manufacturers = @($nodes | Group-Object -Property manufacturer | ForEach-Object { [ordered]@{ name = $_.Name; count = $_.Count } })
                    firmwareNodes = @($managementPosture | Where-Object { $_.firmwareInventoryCount -gt 0 }).Count
                }
            }
            oemIntegration = [ordered]@{
                endpoints         = @($Config.targets.bmc.endpoints)
                managementPosture = @($managementPosture)
            }
        }
        Findings      = @($findings)
        Relationships = @($relationships)
        RawEvidence   = @($rawEvidence)
    }
}