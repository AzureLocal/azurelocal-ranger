function ConvertTo-RangerGiBValue {
    param(
        $Value
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }

    $numericValue = [double]$Value
    if ($numericValue -gt 1048576) {
        return [math]::Round($numericValue / 1GB, 2)
    }

    return [math]::Round($numericValue, 2)
}

function Get-RangerStorageResiliencyEfficiencyPercent {
    param(
        [string]$ResiliencySettingName,
        [int]$NumberOfDataCopies
    )

    if ([string]::IsNullOrWhiteSpace($ResiliencySettingName)) {
        if ($NumberOfDataCopies -gt 0) {
            return [math]::Round(100 / $NumberOfDataCopies, 1)
        }

        return 50
    }

    switch ($ResiliencySettingName.ToLowerInvariant()) {
        'mirror' {
            if ($NumberOfDataCopies -ge 3) {
                return 33.3
            }

            return 50
        }
        'parity' {
            return 60
        }
        'dualparity' {
            return 72
        }
        'simple' {
            return 100
        }
        default {
            if ($NumberOfDataCopies -gt 0) {
                return [math]::Round(100 / $NumberOfDataCopies, 1)
            }

            return 50
        }
    }
}

function Get-RangerStoragePoolAnalysis {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Pool,

        [object[]]$PhysicalDisks,
        [object[]]$VirtualDisks,
        [double]$TotalVolumeUsedGiB,
        [double]$TotalUsableAcrossPoolsGiB,
        [int]$PoolCount
    )

    $poolName = [string]$Pool['friendlyName']
    $poolPhysicalDisks = @(
        $PhysicalDisks | Where-Object {
            ($_.Contains('storagePoolFriendlyName') -and $_['storagePoolFriendlyName'] -eq $poolName) -or
            ($PoolCount -eq 1 -and [string]::IsNullOrWhiteSpace([string]$_['storagePoolFriendlyName']))
        }
    )
    $poolVirtualDisks = @(
        $VirtualDisks | Where-Object {
            ($_.Contains('storagePoolFriendlyName') -and $_['storagePoolFriendlyName'] -eq $poolName) -or
            ($PoolCount -eq 1 -and [string]::IsNullOrWhiteSpace([string]$_['storagePoolFriendlyName']))
        }
    )

    $rawCapacityGiB = [double](ConvertTo-RangerGiBValue -Value ($Pool['sizeGiB'] ?? $Pool['size'] ?? 0))
    $allocatedCapacityGiB = [double](ConvertTo-RangerGiBValue -Value ($Pool['allocatedSizeGiB'] ?? $Pool['allocatedSize'] ?? 0))
    $provisionedCapacityGiB = ConvertTo-RangerGiBValue -Value ($Pool['provisionedCapacityGiB'] ?? $Pool['provisionedCapacity'])
    if ($null -eq $provisionedCapacityGiB) {
        $provisionedCapacityGiB = [math]::Round((@($poolVirtualDisks | ForEach-Object { [double](ConvertTo-RangerGiBValue -Value $_['sizeGiB']) }) | Measure-Object -Sum).Sum, 2)
    }

    $usableCapacityGiB = [math]::Round((@($poolVirtualDisks | ForEach-Object { [double](ConvertTo-RangerGiBValue -Value $_['sizeGiB']) }) | Measure-Object -Sum).Sum, 2)
    if ($usableCapacityGiB -le 0) {
        $efficiencyPercent = Get-RangerStorageResiliencyEfficiencyPercent -ResiliencySettingName ([string]$Pool['resiliencySettingName']) -NumberOfDataCopies $(if ($Pool['numberOfDataCopies']) { [int]$Pool['numberOfDataCopies'] } else { 0 })
        $usableCapacityGiB = [math]::Round($rawCapacityGiB * $efficiencyPercent / 100, 2)
    }

    $largestDiskGiB = [double]((@($poolPhysicalDisks | ForEach-Object { [double](ConvertTo-RangerGiBValue -Value $_['sizeGiB']) }) | Measure-Object -Maximum).Maximum)
    $maintenanceReserveGiB = [math]::Round($usableCapacityGiB * 0.1, 2)
    $reserveFloorGiB = [math]::Round($usableCapacityGiB * 0.2, 2)
    $recommendedReserveGiB = [math]::Round([math]::Max([math]::Max($largestDiskGiB, $maintenanceReserveGiB), $reserveFloorGiB), 2)
    $usedUsableCapacityGiB = if ($PoolCount -le 1) {
        [math]::Round($TotalVolumeUsedGiB, 2)
    }
    elseif ($TotalUsableAcrossPoolsGiB -gt 0) {
        [math]::Round($TotalVolumeUsedGiB * ($usableCapacityGiB / $TotalUsableAcrossPoolsGiB), 2)
    }
    else {
        0
    }
    $freeUsableCapacityGiB = [math]::Round([math]::Max($usableCapacityGiB - $usedUsableCapacityGiB, 0), 2)
    $projectedSafeAllocatableCapacityGiB = [math]::Round([math]::Max($freeUsableCapacityGiB - $recommendedReserveGiB, 0), 2)
    $thinProvisioningRatio = if ($usableCapacityGiB -gt 0) { [math]::Round($provisionedCapacityGiB / $usableCapacityGiB, 2) } else { $null }
    $thinProvisionedVirtualDisks = @($poolVirtualDisks | Where-Object { $_['provisioningType'] -eq 'Thin' }).Count
    $reserveStatus = if ($freeUsableCapacityGiB -lt $recommendedReserveGiB) {
        'below-threshold'
    }
    elseif ($freeUsableCapacityGiB -lt [math]::Round($recommendedReserveGiB * 1.2, 2)) {
        'near-threshold'
    }
    else {
        'healthy'
    }
    $posture = if ($reserveStatus -eq 'below-threshold' -or ($thinProvisioningRatio -and $thinProvisioningRatio -gt 1.1)) {
        'over-provisioned'
    }
    elseif ($projectedSafeAllocatableCapacityGiB -gt [math]::Round($usableCapacityGiB * 0.35, 2)) {
        'under-provisioned'
    }
    else {
        'within safe range'
    }

    [ordered]@{
        friendlyName                         = $poolName
        healthStatus                         = [string]$Pool['healthStatus']
        operationalStatus                    = [string]$Pool['operationalStatus']
        resiliencySettingName                = [string]$Pool['resiliencySettingName']
        numberOfDataCopies                   = if ($Pool['numberOfDataCopies']) { [int]$Pool['numberOfDataCopies'] } else { $null }
        diskCount                            = $poolPhysicalDisks.Count
        diskCountByMediaType                 = @(Get-RangerGroupedCount -Items $poolPhysicalDisks -PropertyName 'mediaType')
        rawCapacityGiB                       = $rawCapacityGiB
        usableCapacityGiB                    = $usableCapacityGiB
        resiliencyOverheadGiB                = [math]::Round([math]::Max($rawCapacityGiB - $usableCapacityGiB, 0), 2)
        allocatedCapacityGiB                 = $allocatedCapacityGiB
        unallocatedCapacityGiB               = [math]::Round([math]::Max($rawCapacityGiB - $allocatedCapacityGiB, 0), 2)
        provisionedCapacityGiB               = $provisionedCapacityGiB
        usedUsableCapacityGiB                = $usedUsableCapacityGiB
        freeUsableCapacityGiB                = $freeUsableCapacityGiB
        recommendedReserveGiB                = $recommendedReserveGiB
        rebuildReserveRequirementGiB         = $largestDiskGiB
        maintenanceReserveRequirementGiB     = $maintenanceReserveGiB
        projectedSafeAllocatableCapacityGiB  = $projectedSafeAllocatableCapacityGiB
        thinProvisioningRatio                = $thinProvisioningRatio
        thinProvisionedVirtualDiskCount      = $thinProvisionedVirtualDisks
        cacheDeviceCount                     = @($poolPhysicalDisks | Where-Object { $_['usage'] -match 'Journal|Cache' }).Count
        capacityDeviceCount                  = @($poolPhysicalDisks | Where-Object { $_['usage'] -notmatch 'Journal|Cache' }).Count
        reserveStatus                        = $reserveStatus
        posture                              = $posture
        assumptions                          = 'Reserve model uses the greater of one-disk rebuild reserve, 10% maintenance reserve, and 20% free usable capacity.'
    }
}

function Update-RangerStorageDomainAnalysis {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$StorageDomain
    )

    $pools = @($StorageDomain.pools)
    $physicalDisks = @($StorageDomain.physicalDisks)
    $virtualDisks = @($StorageDomain.virtualDisks)
    $volumes = @($StorageDomain.volumes)

    foreach ($pool in $pools) {
        $pool['sizeGiB'] = ConvertTo-RangerGiBValue -Value ($pool['sizeGiB'] ?? $pool['size'])
        $pool['allocatedSizeGiB'] = ConvertTo-RangerGiBValue -Value ($pool['allocatedSizeGiB'] ?? $pool['allocatedSize'])
        $pool['provisionedCapacityGiB'] = ConvertTo-RangerGiBValue -Value ($pool['provisionedCapacityGiB'] ?? $pool['provisionedCapacity'])
    }

    foreach ($disk in $physicalDisks) {
        $disk['sizeGiB'] = ConvertTo-RangerGiBValue -Value ($disk['sizeGiB'] ?? $disk['size'])
        if (-not $disk.Contains('storagePoolFriendlyName')) {
            $disk['storagePoolFriendlyName'] = $disk['StoragePoolFriendlyName']
        }
    }

    foreach ($virtualDisk in $virtualDisks) {
        $virtualDisk['sizeGiB'] = ConvertTo-RangerGiBValue -Value ($virtualDisk['sizeGiB'] ?? $virtualDisk['size'])
        $virtualDisk['footprintOnPoolGiB'] = ConvertTo-RangerGiBValue -Value ($virtualDisk['footprintOnPoolGiB'] ?? $virtualDisk['footprintOnPool'])
        if (-not $virtualDisk.Contains('storagePoolFriendlyName')) {
            $virtualDisk['storagePoolFriendlyName'] = $virtualDisk['StoragePoolFriendlyName']
        }
    }

    foreach ($volume in $volumes) {
        $volume['sizeGiB'] = ConvertTo-RangerGiBValue -Value ($volume['sizeGiB'] ?? $volume['size'])
        $volume['sizeRemainingGiB'] = ConvertTo-RangerGiBValue -Value ($volume['sizeRemainingGiB'] ?? $volume['sizeRemaining'])
    }

    $totalVolumeUsedGiB = [math]::Round((@($volumes | ForEach-Object { [math]::Max(([double]($_['sizeGiB'] ?? 0) - [double]($_['sizeRemainingGiB'] ?? 0)), 0) }) | Measure-Object -Sum).Sum, 2)
    $totalUsableAcrossPoolsGiB = [math]::Round((@($virtualDisks | ForEach-Object { [double]($_['sizeGiB'] ?? 0) }) | Measure-Object -Sum).Sum, 2)
    $poolAnalysis = @(
        foreach ($pool in $pools) {
            Get-RangerStoragePoolAnalysis -Pool $pool -PhysicalDisks $physicalDisks -VirtualDisks $virtualDisks -TotalVolumeUsedGiB $totalVolumeUsedGiB -TotalUsableAcrossPoolsGiB $totalUsableAcrossPoolsGiB -PoolCount $pools.Count
        }
    )

    $summary = if ($StorageDomain.summary) { ConvertTo-RangerHashtable -InputObject $StorageDomain.summary } else { [ordered]@{} }
    $summary.poolCount = $pools.Count
    $summary.physicalDiskCount = $physicalDisks.Count
    $summary.virtualDiskCount = $virtualDisks.Count
    $summary.volumeCount = $volumes.Count
    $summary.csvCount = @($StorageDomain.csvs).Count
    $summary.totalRawCapacityGiB = [math]::Round((@($poolAnalysis | ForEach-Object { [double]$_['rawCapacityGiB'] }) | Measure-Object -Sum).Sum, 2)
    $summary.totalUsableCapacityGiB = [math]::Round((@($poolAnalysis | ForEach-Object { [double]$_['usableCapacityGiB'] }) | Measure-Object -Sum).Sum, 2)
    $summary.totalAllocatedCapacityGiB = [math]::Round((@($poolAnalysis | ForEach-Object { [double]$_['allocatedCapacityGiB'] }) | Measure-Object -Sum).Sum, 2)
    $summary.totalProvisionedCapacityGiB = [math]::Round((@($poolAnalysis | ForEach-Object { [double]$_['provisionedCapacityGiB'] }) | Measure-Object -Sum).Sum, 2)
    $summary.totalUsedUsableCapacityGiB = [math]::Round((@($poolAnalysis | ForEach-Object { [double]$_['usedUsableCapacityGiB'] }) | Measure-Object -Sum).Sum, 2)
    $summary.totalFreeUsableCapacityGiB = [math]::Round((@($poolAnalysis | ForEach-Object { [double]$_['freeUsableCapacityGiB'] }) | Measure-Object -Sum).Sum, 2)
    $summary.totalReserveTargetGiB = [math]::Round((@($poolAnalysis | ForEach-Object { [double]$_['recommendedReserveGiB'] }) | Measure-Object -Sum).Sum, 2)
    $summary.totalSafeAllocatableCapacityGiB = [math]::Round((@($poolAnalysis | ForEach-Object { [double]$_['projectedSafeAllocatableCapacityGiB'] }) | Measure-Object -Sum).Sum, 2)
    $summary.diskMediaTypes = @(Get-RangerGroupedCount -Items $physicalDisks -PropertyName 'mediaType')
    $summary.unhealthyDisks = @($physicalDisks | Where-Object { $_['healthStatus'] -and $_['healthStatus'] -ne 'Healthy' }).Count
    $summary.canPoolDisks = @($physicalDisks | Where-Object { $_['canPool'] }).Count
    $summary.retiredDisks = @($physicalDisks | Where-Object { [string]$_['operationalStatus'] -match 'Retiring|PredictiveFailure' }).Count
    $summary.resiliencyModes = @(Get-RangerGroupedCount -Items $virtualDisks -PropertyName 'resiliencySettingName')
    $summary.tierCount = @($StorageDomain.tiers).Count
    $summary.storageJobCount = @($StorageDomain.jobs).Count
    $summary.activeHealthFaultCount = @($StorageDomain.healthFaults).Count
    $summary.replicaGroupCount = @($StorageDomain.replicaDepth).Count
    $summary.qosFlowCount = @($StorageDomain.qosFlows).Count
    $summary.cacheEnabled = if ($StorageDomain.cacheConfig) { $StorageDomain.cacheConfig.CacheState -eq 'Enabled' } else { $null }
    $summary.dedupVolumes = @($StorageDomain.dedupStatus | Where-Object { $_.Status -ne 'Disabled' }).Count
    $summary.thinProvisioningRatio = if ($summary.totalUsableCapacityGiB -gt 0) { [math]::Round($summary.totalProvisionedCapacityGiB / $summary.totalUsableCapacityGiB, 2) } else { $null }
    $summary.poolPostureCounts = @($poolAnalysis | Group-Object posture | Sort-Object Name | ForEach-Object { [ordered]@{ name = $_.Name; count = $_.Count } })

    $StorageDomain.pools = ConvertTo-RangerHashtable -InputObject $pools
    $StorageDomain.physicalDisks = ConvertTo-RangerHashtable -InputObject $physicalDisks
    $StorageDomain.virtualDisks = ConvertTo-RangerHashtable -InputObject $virtualDisks
    $StorageDomain.volumes = ConvertTo-RangerHashtable -InputObject $volumes
    $StorageDomain.poolAnalysis = ConvertTo-RangerHashtable -InputObject $poolAnalysis
    $StorageDomain.summary = $summary
    return $StorageDomain
}

function New-RangerStorageAnalysisFindings {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$StorageDomain
    )

    $findings = New-Object System.Collections.ArrayList
    foreach ($poolAnalysis in @($StorageDomain.poolAnalysis)) {
        if ($poolAnalysis.reserveStatus -eq 'below-threshold') {
            [void]$findings.Add((New-RangerFinding -Severity warning -Title "Storage reserve is below the recommended threshold for pool '$($poolAnalysis.friendlyName)'" -Description 'The pool does not currently retain the recommended amount of free usable capacity for rebuild and maintenance safety.' -CurrentState "free usable $($poolAnalysis.freeUsableCapacityGiB) GiB; reserve target $($poolAnalysis.recommendedReserveGiB) GiB" -Recommendation 'Reduce allocation pressure, expand the pool, or reclaim capacity before additional workload placement.'))
        }
        elseif ($poolAnalysis.reserveStatus -eq 'near-threshold') {
            [void]$findings.Add((New-RangerFinding -Severity informational -Title "Storage reserve is near the threshold for pool '$($poolAnalysis.friendlyName)'" -Description 'The pool is operating close to its recommended reserve target.' -CurrentState "free usable $($poolAnalysis.freeUsableCapacityGiB) GiB; reserve target $($poolAnalysis.recommendedReserveGiB) GiB" -Recommendation 'Plan capacity expansion or cleanup before the next maintenance cycle or failure event.'))
        }

        if ($poolAnalysis.thinProvisionedVirtualDiskCount -gt 0 -and $poolAnalysis.thinProvisioningRatio -gt 1) {
            [void]$findings.Add((New-RangerFinding -Severity warning -Title "Thin provisioning exceeds current usable capacity for pool '$($poolAnalysis.friendlyName)'" -Description 'Thin-provisioned virtual disks currently expose more provisioned capacity than the pool can safely back with usable capacity.' -CurrentState "thin provisioning ratio $($poolAnalysis.thinProvisioningRatio)x" -Recommendation 'Review virtual disk growth controls and keep additional free reserve before consuming more capacity.'))
        }

        if ($poolAnalysis.posture -eq 'over-provisioned' -and $poolAnalysis.reserveStatus -ne 'below-threshold') {
            [void]$findings.Add((New-RangerFinding -Severity warning -Title "Storage pool '$($poolAnalysis.friendlyName)' is operating in an over-provisioned posture" -Description 'Pool allocation and provisioned capacity reduce the remaining safe allocatable headroom.' -CurrentState "provisioned $($poolAnalysis.provisionedCapacityGiB) GiB; safe allocatable $($poolAnalysis.projectedSafeAllocatableCapacityGiB) GiB" -Recommendation 'Rebalance growth expectations against usable capacity and reserve targets before additional workload placement.'))
        }
    }

    return @($findings)
}

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
        $fixtureResult = ConvertTo-RangerHashtable -InputObject $fixture
        if ($fixtureResult.Contains('Domains') -and $fixtureResult.Domains.Contains('storage')) {
            $fixtureResult.Domains.storage = Update-RangerStorageDomainAnalysis -StorageDomain (ConvertTo-RangerHashtable -InputObject $fixtureResult.Domains.storage)
            $fixtureStorageFindings = @(New-RangerStorageAnalysisFindings -StorageDomain $fixtureResult.Domains.storage)
            if (-not $fixtureResult.Contains('Findings')) {
                $fixtureResult['Findings'] = @()
            }

            if ($fixtureStorageFindings.Count -gt 0) {
                $fixtureResult.Findings = @($fixtureResult.Findings) + $fixtureStorageFindings
            }
        }

        return $fixtureResult
    }

    $storageSnapshot = Invoke-RangerSafeAction -Label 'Storage inventory snapshot' -DefaultValue ([ordered]@{}) -ScriptBlock {
        Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -SingleTarget -ScriptBlock {
            $rangerDiagnostics = New-Object System.Collections.Generic.List[string]
            [ordered]@{
                # Issue #58: Expanded pool, physical disk, virtual disk, volume collections
                pools = if (Get-Command -Name Get-StoragePool -ErrorAction SilentlyContinue) {
                    @(Get-StoragePool | Where-Object { -not $_.IsPrimordial } | ForEach-Object {
                        $p = $_
                        # Derive dominant resiliency from virtual disks in this pool.
                        # Get-VirtualDisk piped from pool is the supported S2D query pattern.
                        $poolVds = @(try { $p | Get-VirtualDisk -ErrorAction SilentlyContinue } catch { @() })
                        $domResiliency = if ($poolVds.Count -gt 0) {
                            $poolVds | Group-Object ResiliencySettingName | Sort-Object Count -Descending | Select-Object -First 1 -ExpandProperty Name
                        } else { $null }
                        $domCopies = if ($poolVds.Count -gt 0) {
                            [int]($poolVds | Group-Object NumberOfDataCopies | Sort-Object Count -Descending | Select-Object -First 1 -ExpandProperty Name)
                        } else { $null }
                        [ordered]@{
                            friendlyName                = $p.FriendlyName
                            healthStatus                = [string]$p.HealthStatus
                            operationalStatus           = [string]$p.OperationalStatus
                            sizeGiB                     = [math]::Round($p.Size / 1GB, 2)
                            allocatedSizeGiB            = [math]::Round($p.AllocatedSize / 1GB, 2)
                            provisionedCapacityGiB      = if ($p.ProvisionedCapacity -gt 0) { [math]::Round($p.ProvisionedCapacity / 1GB, 2) } else { $null }
                            faultDomainAwarenessDefault = [string]$p.FaultDomainAwarenessDefault
                            retiredPhysicalDiskCount    = $p.RetiredPhysicalDiskCount
                            readCacheSize               = $p.ReadCacheSize
                            isTiered                    = $p.IsTiered
                            isPrimordial                = $p.IsPrimordial
                            resiliencySettingName       = $domResiliency
                            numberOfDataCopies          = $domCopies
                        }
                    })
                } else { @() }
                physicalDisks = if (Get-Command -Name Get-PhysicalDisk -ErrorAction SilentlyContinue) {
                    @(Get-PhysicalDisk | ForEach-Object {
                        $d = $_
                        [ordered]@{
                            friendlyName       = $d.FriendlyName
                            healthStatus       = [string]$d.HealthStatus
                            operationalStatus  = [string]$d.OperationalStatus
                            mediaType          = [string]$d.MediaType
                            sizeGiB            = [math]::Round($d.Size / 1GB, 2)
                            serialNumber       = $d.SerialNumber
                            usage              = [string]$d.Usage
                            slotNumber         = $d.SlotNumber
                            canPool            = $d.CanPool
                            cannotPoolReason   = $d.CannotPoolReason
                            storagePoolFriendlyName = $d.StoragePoolFriendlyName
                            busType            = [string]$d.BusType
                            manufacturer       = $d.Manufacturer
                            model              = $d.Model
                        }
                    })
                } else { @() }
                physicalDiskReliability = if (Get-Command -Name Get-StorageReliabilityCounter -ErrorAction SilentlyContinue) {
                    @(try { Get-PhysicalDisk -ErrorAction SilentlyContinue | Get-StorageReliabilityCounter -ErrorAction Stop | Select-Object DeviceId, Wear, Temperature, ReadErrors, WriteErrors, PowerOnHours, ReadLatencyMax, WriteLatencyMax } catch { @() })
                } else { @() }
                virtualDisks = if (Get-Command -Name Get-VirtualDisk -ErrorAction SilentlyContinue) {
                    @(Get-VirtualDisk -ErrorAction SilentlyContinue | ForEach-Object {
                        $vd = $_
                        [ordered]@{
                            friendlyName       = $vd.FriendlyName
                            healthStatus       = [string]$vd.HealthStatus
                            operationalStatus  = [string]$vd.OperationalStatus
                            resiliencySettingName = $vd.ResiliencySettingName
                            sizeGiB            = [math]::Round($vd.Size / 1GB, 2)
                            footprintOnPoolGiB = [math]::Round($vd.FootprintOnPool / 1GB, 2)
                            numberOfDataCopies = $vd.NumberOfDataCopies
                            numberOfColumns    = $vd.NumberOfColumns
                            interleave         = $vd.Interleave
                            isEnclosureAware   = $vd.IsEnclosureAware
                            provisioningType   = [string]$vd.ProvisioningType
                            writeCacheSize     = $vd.WriteCacheSize
                            storagePoolFriendlyName = $vd.StoragePoolFriendlyName
                            uniqueId           = $vd.UniqueId
                        }
                    })
                } else { @() }
                volumes = if (Get-Command -Name Get-Volume -ErrorAction SilentlyContinue) {
                    @(Get-Volume -ErrorAction SilentlyContinue | ForEach-Object {
                        $v = $_
                        [ordered]@{
                            driveLetter        = $v.DriveLetter
                            fileSystemLabel    = $v.FileSystemLabel
                            fileSystem         = $v.FileSystem
                            fileSystemType     = [string]$v.FileSystemType
                            healthStatus       = [string]$v.HealthStatus
                            sizeGiB            = [math]::Round($v.Size / 1GB, 2)
                            sizeRemainingGiB   = [math]::Round($v.SizeRemaining / 1GB, 2)
                            dedupMode          = [string]$v.DedupMode
                            driveType          = [string]$v.DriveType
                            path               = $v.Path
                        }
                    })
                } else { @() }
                dedupStatus = if (Get-Command -Name Get-DedupStatus -ErrorAction SilentlyContinue) {
                    @(try { Get-DedupStatus -ErrorAction Stop | Select-Object Volume, SavingsRate, SavedSpace, OptimizedFilesCount, LastOptimizationTime, Status } catch { @() })
                } else { @() }
                cacheConfig = if (Get-Command -Name Get-ClusterS2D -ErrorAction SilentlyContinue) {
                    $cacheWarnings = @()
                    try {
                        $cacheConfig = Get-ClusterS2D -ErrorAction Stop -WarningAction SilentlyContinue -WarningVariable +cacheWarnings | Select-Object CacheState, CacheBehavior, CacheModeSSD, CacheModeHDD, CachePageSizeKBytes, CacheMetadataReserveBytes, AutoConfig
                        foreach ($cacheWarning in @($cacheWarnings)) {
                            [void]$rangerDiagnostics.Add("Get-ClusterS2D: $([string]$(if ($cacheWarning -is [System.Management.Automation.WarningRecord]) { $cacheWarning.Message } else { $cacheWarning }))")
                        }
                        $cacheConfig
                    } catch {
                        [void]$rangerDiagnostics.Add("Get-ClusterS2D: $($_.Exception.Message)")
                        $null
                    }
                } else { $null }
                scrubSchedule = if (Get-Command -Name Get-ScheduledTask -ErrorAction SilentlyContinue) {
                    @(try { Get-ScheduledTask -TaskPath '\Microsoft\Windows\Data Integrity Scan\' -ErrorAction SilentlyContinue | Select-Object TaskName, TaskPath, State, Description } catch { @() })
                } else { @() }
                tiers = if (Get-Command -Name Get-StorageTier -ErrorAction SilentlyContinue) { @(try { Get-StorageTier -ErrorAction Stop | Select-Object FriendlyName, MediaType, ResiliencySettingName, Size, FootprintOnPool } catch { @() }) } else { @() }
                subsystems = if (Get-Command -Name Get-StorageSubSystem -ErrorAction SilentlyContinue) { @(try { Get-StorageSubSystem -ErrorAction Stop | Select-Object FriendlyName, Model, SerialNumber, HealthStatus } catch { @() }) } else { @() }
                resiliency = if (Get-Command -Name Get-ResiliencySetting -ErrorAction SilentlyContinue) { @(try { Get-ResiliencySetting -ErrorAction Stop | Select-Object Name, NumberOfDataCopiesDefault, PhysicalDiskRedundancyDefault } catch { @() }) } else { @() }
                jobs = if (Get-Command -Name Get-StorageJob -ErrorAction SilentlyContinue) { @(try { Get-StorageJob -ErrorAction Stop | Select-Object Name, JobState, PercentComplete, BytesProcessed } catch { @() }) } else { @() }
                csvs = if (Get-Command -Name Get-ClusterSharedVolume -ErrorAction SilentlyContinue) { @(try { Get-ClusterSharedVolume -ErrorAction Stop | Select-Object Name, State, OwnerNode } catch { @() }) } else { @() }
                qos = if (Get-Command -Name Get-StorageQosPolicy -ErrorAction SilentlyContinue) { @(try { Get-StorageQosPolicy -ErrorAction Stop | Select-Object Name, PolicyId, PolicyType, MinimumIops, MaximumIops, MaximumIoBandwidth } catch { @() }) } else { @() }
                qosFlows = if (Get-Command -Name Get-StorageQosFlow -ErrorAction SilentlyContinue) {
                    @(try { Get-StorageQosFlow -ErrorAction Stop | Select-Object Initiator, InitiatorName, PolicyId, FilePath, StorageNodeIops, Status } catch { @() })
                } else { @() }
                healthFaults = if (Get-Command -Name Get-HealthFault -ErrorAction SilentlyContinue) {
                    @(try { Get-HealthFault -ErrorAction Stop | Select-Object FaultType, FaultingObjectDescription, FaultingObjectLocation, FaultingObjectUniqueId, PerceivedSeverity, Reason, RecommendedActions, FaultTime } catch { @() })
                } else { @() }
                scrubSettings = if (Get-Command -Name Get-StorageSubSystem -ErrorAction SilentlyContinue) {
                    try {
                        $subsys = Get-StorageSubSystem -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match 'S2D|Spaces' } | Select-Object -First 1
                        if ($subsys) {
                            $scrub = try { $subsys | Get-StoragePool -ErrorAction Stop | Get-PhysicalDisk -ErrorAction Stop | Get-StorageReliabilityCounter -ErrorAction Stop | Select-Object -First 1 DeviceId, ReadErrors, WriteErrors, Temperature, Wear, PowerOnHours } catch { $null }
                            [ordered]@{
                                deviceId     = if ($scrub) { $scrub.DeviceId } else { $null }
                                readErrors   = if ($scrub) { $scrub.ReadErrors } else { $null }
                                writeErrors  = if ($scrub) { $scrub.WriteErrors } else { $null }
                                temperature  = if ($scrub) { $scrub.Temperature } else { $null }
                                wear         = if ($scrub) { $scrub.Wear } else { $null }
                                powerOnHours = if ($scrub) { $scrub.PowerOnHours } else { $null }
                            }
                        } else { $null }
                    } catch { $null }
                } else { $null }
                replicaDepth = if (Get-Command -Name Get-SRGroup -ErrorAction SilentlyContinue) {
                    @(try {
                        $srPartnerships = @(try { Get-SRPartnership -ErrorAction Stop } catch { @() })
                        Get-SRGroup -ErrorAction Stop | ForEach-Object {
                            $sg = $_
                            $partnership = $srPartnerships | Where-Object { $_.SourceRGName -eq $sg.Name -or $_.DestinationRGName -eq $sg.Name } | Select-Object -First 1
                            [ordered]@{
                                name              = $sg.Name
                                replicationMode   = [string]$sg.ReplicationMode
                                replicationState  = [string]$sg.ReplicationState
                                logSizeUsedBytes  = $sg.LogSizeUsed
                                currentSyncSpeedBytesPerSecond = $sg.CurrentSynchronizationSpeed
                                lastInSyncTime    = $sg.LastInSyncTime
                                memberCount       = @($sg.Members).Count
                                partnerGroupName  = if ($partnership) { if ($partnership.SourceRGName -eq $sg.Name) { $partnership.DestinationRGName } else { $partnership.SourceRGName } } else { $null }
                                partnerComputerName = if ($partnership) { if ($partnership.SourceComputerName) { $partnership.SourceComputerName } else { $partnership.DestinationComputerName } } else { $null }
                            }
                        }
                    } catch { @() })
                } else { @() }
                replica = if (Get-Command -Name Get-SRGroup -ErrorAction SilentlyContinue) { @(try { Get-SRGroup -ErrorAction Stop | Select-Object Name, ReplicationMode, LastInSyncTime, State } catch { @() }) } else { @() }
                clusterNetworks = if (Get-Command -Name Get-ClusterNetwork -ErrorAction SilentlyContinue) { @(try { Get-ClusterNetwork -ErrorAction Stop | Select-Object Name, Role, Address, AddressMask, State } catch { @() }) } else { @() }
                rangerDiagnostics = @($rangerDiagnostics)
            }
        }
    }

    $networkNodes = @(
        Invoke-RangerSafeAction -Label 'Networking inventory snapshot' -DefaultValue @() -ScriptBlock {
            Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -ScriptBlock {
                $rangerDiagnostics = New-Object System.Collections.Generic.List[string]
                # Issue #59: Expand proxy to structured fields early so it can be used below
                $proxyRaw = try { netsh winhttp show proxy | Out-String } catch { $null }
                $proxyEnvHttp = [System.Environment]::GetEnvironmentVariable('HTTP_PROXY')
                $proxyEnvHttps = [System.Environment]::GetEnvironmentVariable('HTTPS_PROXY')
                $proxyEnvNoProxy = [System.Environment]::GetEnvironmentVariable('NO_PROXY')
                $proxyServer = if ($proxyRaw -match 'Proxy Server\(s\)\s*:\s*(.+)') { $Matches[1].Trim() } else { $null }
                $proxyBypassRaw = if ($proxyRaw -match 'Bypass List\s*:\s*(.+)') { $Matches[1].Trim() } else { $null }
                $proxyDirect = $proxyRaw -match 'Direct access'
                $proxyDetail = [ordered]@{
                    winhttp          = $proxyServer
                    winhttp_bypass   = $proxyBypassRaw
                    isDirect         = $proxyDirect
                    envHttpProxy     = $proxyEnvHttp
                    envHttpsProxy    = $proxyEnvHttps
                    envNoProxy       = $proxyEnvNoProxy
                    proxyConfigured  = -not $proxyDirect -or -not [string]::IsNullOrWhiteSpace($proxyEnvHttps)
                    rawWinhttp       = $proxyRaw
                }
                $dcb = [ordered]@{
                    dcbxSettings  = if (Get-Command -Name Get-NetQosDcbxSetting -ErrorAction SilentlyContinue) { @(Get-NetQosDcbxSetting -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, Setting) } else { @() }
                    trafficClasses = if (Get-Command -Name Get-NetQosTrafficClass -ErrorAction SilentlyContinue) { @(Get-NetQosTrafficClass -ErrorAction SilentlyContinue | Select-Object Name, Algorithm, BandwidthPercentage, Priority) } else { @() }
                    flowControl   = if (Get-Command -Name Get-NetQosFlowControl -ErrorAction SilentlyContinue) { @(Get-NetQosFlowControl -ErrorAction SilentlyContinue | Select-Object Priority, Enabled) } else { @() }
                    policy        = if (Get-Command -Name Get-NetQosPolicy -ErrorAction SilentlyContinue) { @(Get-NetQosPolicy -ErrorAction SilentlyContinue | Select-Object Name, PriorityValue8021Action, NetDirectPortMatchCondition, IPProtocolMatchCondition) } else { @() }
                }
                $intentOverrides = if (Get-Command -Name Get-NetIntent -ErrorAction SilentlyContinue) {
                    @(Get-NetIntent -ErrorAction SilentlyContinue | ForEach-Object {
                        $intent = $_
                        [ordered]@{
                            name             = $intent.IntentName
                            adapters         = @(try { $intent.InterfaceOverride | ForEach-Object { if ($_.InterfaceDescription) { $_.InterfaceDescription } elseif ($_.InterfaceAlias) { $_.InterfaceAlias } } } catch { @() })
                            isStorageIntent  = $intent.IsStorageIntent
                            isComputeIntent  = $intent.IsComputeIntent
                            isManagementIntent = $intent.IsManagementIntent
                            storageVlans     = @(try { $intent.StorageVlans } catch { @() })
                            overrideAdapterProperty = if (Get-Command -Name Get-NetIntentAllAdapterPropertyOverrides -ErrorAction SilentlyContinue) {
                                try { Get-NetIntentAllAdapterPropertyOverrides -Name $intent.IntentName -ErrorAction Stop | Select-Object Name, AdapterName, PropertyName, PropertyValue } catch { $null }
                            }
                        }
                    })
                } else { @() }
                # Issue #313 — LLDP passive reporting: always collect neighbor data
                # using Get-NetLldpNeighbor (available on Azure Local / Windows Server
                # 2019+). Falls back to empty list gracefully when LLDP cmdlets are
                # absent. No switch credentials required — data comes from the node OS.
                $lldpNeighbors = @(
                    try {
                        if (Get-Command -Name Get-NetLldpNeighbor -ErrorAction SilentlyContinue) {
                            @(Get-NetLldpNeighbor -ErrorAction SilentlyContinue | ForEach-Object {
                                [ordered]@{
                                    interface        = $_.LocalPort
                                    neighborSystem   = $_.SystemName
                                    neighborPort     = $_.PortId
                                    neighborPortDesc = $_.PortDescription
                                    neighborMgmtAddr = $_.ManagementAddress
                                    neighborMac      = $_.ChassisId
                                    ttl              = $_.TimeToLive
                                }
                            })
                        } elseif (Get-Command -Name Get-NetAdapter -ErrorAction SilentlyContinue) {
                            # Fallback: read LLDP via WMI on older OS versions
                            @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
                                $adapterName = $_.Name
                                $lldpWmi = Get-CimInstance -Namespace 'root\wmi' -ClassName MSNdis_NetworkLinkDescription -Filter "InstanceName like '%$adapterName%'" -ErrorAction SilentlyContinue
                                if ($lldpWmi) { [ordered]@{ interface = $adapterName; neighborSystem = $null; lldpData = $lldpWmi.LinkDescription } }
                            } | Where-Object { $_ })
                        }
                    } catch { @() }
                )
                # Issue #59: SMB configuration depth and Live Migration settings
                $smbConfig = [ordered]@{
                    serverConfig    = if (Get-Command -Name Get-SmbServerConfiguration -ErrorAction SilentlyContinue) {
                        try { Get-SmbServerConfiguration -ErrorAction Stop | Select-Object EnableSMBQUIC, RequireSecuritySignature, EncryptData, AutoDisconnectTimeout, EnableMultiChannel } catch { $null }
                    } else { $null }
                    multichannelEnabled = if (Get-Command -Name Get-SmbMultichannelConfiguration -ErrorAction SilentlyContinue) {
                        try { (Get-SmbMultichannelConfiguration -ErrorAction Stop).EnableMultiChannel } catch { $null }
                    } else { $null }
                    smbDirectEnabled = if (Get-Command -Name Get-SmbDirectConfiguration -ErrorAction SilentlyContinue) {
                        try { (Get-SmbDirectConfiguration -ErrorAction Stop).Enabled } catch { $null }
                    } else { $null }
                    activeConnections = if (Get-Command -Name Get-SmbMultichannelConnection -ErrorAction SilentlyContinue) {
                        try { @(Get-SmbMultichannelConnection -ErrorAction Stop | Select-Object ServerName, ClientInterface, ServerInterface, Protocol, Selected, ConstrainedBy) } catch { @() }
                    } else { @() }
                }
                $liveMigration = if (Get-Command -Name Get-VMHost -ErrorAction SilentlyContinue) {
                    try {
                        $vmh = Get-VMHost -ErrorAction Stop
                        $smbBwLimit = if (Get-Command -Name Get-SmbBandwidthLimit -ErrorAction SilentlyContinue) { try { @(Get-SmbBandwidthLimit -ErrorAction Stop) } catch { @() } } else { @() }
                        [ordered]@{
                            liveMigrationEnabled = $vmh.VirtualMachineMigrationEnabled
                            maxMigrations        = $vmh.MaximumVirtualMachineMigrations
                            maxStorageMigrations = $vmh.MaximumStorageMigrations
                            performanceOption    = [string]$vmh.VirtualMachineMigrationPerformanceOption
                            useAnyNetworkForMigration = $vmh.UseAnyNetworkForMigration
                            liveMigrationNetworks = @(if (Get-Command -Name Get-VMHostSupportedVersion -ErrorAction SilentlyContinue) { @() } else { @() })
                            smbBandwidthLimits   = @($smbBwLimit)
                        }
                    } catch { $null }
                } else { $null }
                # Issue #61: DNS depth with conditional forwarders
                $dnsForwarders = if (Get-Command -Name Get-DnsServerForwarder -ErrorAction SilentlyContinue) {
                    try { @(Get-DnsServerForwarder -ErrorAction Stop | Select-Object IPAddress, UseRootHint, Timeout, EnableReordering) } catch { @() }
                } else { @() }
                $dnsZones = if (Get-Command -Name Get-DnsServerZone -ErrorAction SilentlyContinue) {
                    try { @(Get-DnsServerZone -ErrorAction Stop | Where-Object { $_.ZoneType -eq 'Forwarder' } | Select-Object ZoneName, ZoneType, MasterServers, ZoneFile) } catch { @() }
                } else { @() }
                # Issue #61: Firewall rule audit for Azure Local required ports
                $requiredFirewallRules = @(
                    @{ Name = 'WinRM-HTTP';   Port = 5985;  Protocol = 'TCP'; Description = 'WinRM HTTP' }
                    @{ Name = 'WinRM-HTTPS';  Port = 5986;  Protocol = 'TCP'; Description = 'WinRM HTTPS' }
                    @{ Name = 'SMB';          Port = 445;   Protocol = 'TCP'; Description = 'SMB file sharing' }
                    @{ Name = 'Cluster';      Port = 3343;  Protocol = 'TCP'; Description = 'Cluster heartbeat' }
                    @{ Name = 'HyperV-RPC';   Port = 2179;  Protocol = 'TCP'; Description = 'Hyper-V VM Connect' }
                    @{ Name = 'HyperV-LIVE';  Port = 6600;  Protocol = 'TCP'; Description = 'Hyper-V Live Migration' }
                    @{ Name = 'RPC-EP';       Port = 135;   Protocol = 'TCP'; Description = 'RPC Endpoint Mapper' }
                    @{ Name = 'NTP';          Port = 123;   Protocol = 'UDP'; Description = 'Network Time Protocol' }
                    @{ Name = 'Arc-HTTPS';    Port = 443;   Protocol = 'TCP'; Description = 'Arc agent and Azure services' }
                )
                $firewallRuleAudit = if (Get-Command -Name Get-NetFirewallRule -ErrorAction SilentlyContinue) {
                    @($requiredFirewallRules | ForEach-Object {
                        $req = $_
                        $matchingRules = @(try {
                            Get-NetFirewallRule -Enabled True -Direction Inbound -ErrorAction SilentlyContinue | ForEach-Object {
                                $r = $_
                                $portFilter = try { $r | Get-NetFirewallPortFilter -ErrorAction Stop } catch { $null }
                                if ($portFilter -and ($portFilter.LocalPort -eq $req.Port -or $portFilter.LocalPort -eq 'Any') -and ($portFilter.Protocol -eq $req.Protocol -or $portFilter.Protocol -eq 'Any')) { $r }
                            }
                        } catch { @() })
                        [ordered]@{
                            requiredPort    = $req.Port
                            protocol        = $req.Protocol
                            description     = $req.Description
                            rulesFound      = @($matchingRules).Count
                            ruleNames       = @($matchingRules | Select-Object -First 3 | ForEach-Object { $_.Name })
                            satisfied       = @($matchingRules).Count -gt 0
                        }
                    })
                } else { @() }
                $inboxDriverAdapters = if (Get-Command -Name Get-NetAdapter -ErrorAction SilentlyContinue) {
                    @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.DriverProvider -eq 'Microsoft' -and $_.Status -eq 'Up' } | Select-Object Name, InterfaceDescription, DriverProvider, DriverVersion)
                } else { @() }
                [ordered]@{
                    node          = $env:COMPUTERNAME
                    # Issue #59: Expanded adapters with driver info
                    adapters      = if (Get-Command -Name Get-NetAdapter -ErrorAction SilentlyContinue) {
                        @(Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
                            $a = $_
                            $advProps = @{}
                            try { Get-NetAdapterAdvancedProperty -Name $a.Name -ErrorAction SilentlyContinue | ForEach-Object { $advProps[$_.RegistryKeyword] = $_.RegistryValue } } catch {}
                            [ordered]@{
                                name                 = $a.Name
                                interfaceDescription = $a.InterfaceDescription
                                status               = [string]$a.Status
                                linkSpeed            = $a.LinkSpeed
                                macAddress           = $a.MacAddress
                                mtuSize              = $a.MtuSize
                                mediaType            = [string]$a.MediaType
                                driverProvider       = $a.DriverProvider
                                driverFileName       = $a.DriverFileName
                                driverVersion        = $a.DriverVersionString
                                driverDate           = $a.DriverDate
                                vlanId               = $a.VlanID
                                isInboxDriver        = $a.DriverProvider -eq 'Microsoft'
                                rdmaCapable          = if ($advProps.ContainsKey('*NetworkDirect')) { $advProps['*NetworkDirect'] -ne '0' } else { $null }
                                sriovCapable         = if ($advProps.ContainsKey('*SRIOV')) { $advProps['*SRIOV'] -ne '0' } else { $null }
                            }
                        })
                    } else { @() }
                    # Issue #59: Expanded vSwitch detail with SET, SR-IOV, bandwidth, extensions
                    vSwitches     = if (Get-Command -Name Get-VMSwitch -ErrorAction SilentlyContinue) {
                        @(Get-VMSwitch -ErrorAction SilentlyContinue | ForEach-Object {
                            $sw = $_
                            $exts = @(try { $sw | Get-VMSwitchExtension -ErrorAction Stop | Select-Object Name, Vendor, Enabled, Running } catch { @() })
                            [ordered]@{
                                name                     = $sw.Name
                                switchType               = [string]$sw.SwitchType
                                allowManagementOS        = $sw.AllowManagementOS
                                netAdapterNames          = @($sw.NetAdapterInterfaceDescriptions)
                                bandwidthReservationMode = [string]$sw.BandwidthReservationMode
                                iovEnabled               = $sw.IovEnabled
                                iovQueuePairCount        = $sw.IovQueuePairCount
                                embeddedTeamingEnabled   = $sw.EmbeddedTeamingEnabled
                                extensions               = @($exts)
                            }
                        })
                    } else { @() }
                    # Issue #59: Expanded host vNIC with RDMA, IP, VLAN
                    hostVirtualNics = if (Get-Command -Name Get-VMNetworkAdapter -ErrorAction SilentlyContinue) {
                        try {
                            @(Get-VMNetworkAdapter -ManagementOS -ErrorAction SilentlyContinue | ForEach-Object {
                                $vnic = $_
                                $rdmaAdapter = if (Get-Command -Name Get-NetAdapterRdma -ErrorAction SilentlyContinue) { try { Get-NetAdapterRdma -Name $vnic.Name -ErrorAction Stop } catch { $null } } else { $null }
                                # Guard: use Get-NetIPInterface to pre-check before Get-NetIPConfiguration.
                                # PA host vNICs (PAhostVNic2 etc.) lack MSFT_NetIPInterface entries.
                                # Get-NetIPInterface -ErrorAction SilentlyContinue suppresses stream-2 output,
                                # preventing Invoke-Command -ErrorAction Stop from promoting it to terminating.
                                $ipConf = if (Get-NetIPInterface -InterfaceAlias $vnic.Name -ErrorAction SilentlyContinue) {
                                    try { Get-NetIPConfiguration -InterfaceAlias $vnic.Name -ErrorAction SilentlyContinue | Select-Object -First 1 } catch { $null }
                                } else { $null }
                                $vlan = try { Get-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName $vnic.Name -ErrorAction Stop | Select-Object -First 1 } catch { $null }
                                [ordered]@{
                                    name            = $vnic.Name
                                    switchName      = $vnic.SwitchName
                                    status          = [string]$vnic.Status
                                    ipAddresses     = @($vnic.IPAddresses)
                                    ipAddress       = if ($ipConf) { $ipConf.IPv4Address.IPAddress } else { $null }
                                    prefixLength    = if ($ipConf) { $ipConf.IPv4Address.PrefixLength } else { $null }
                                    vlanId          = if ($vlan) { $vlan.AccessVlanId } else { $null }
                                    rdmaEnabled     = if ($rdmaAdapter) { $rdmaAdapter.Enabled } else { $null }
                                    rdmaOperational = if ($rdmaAdapter) { $rdmaAdapter.OperationalState -eq 'Active' } else { $null }
                                    isManagementNic = $vnic.IsManagementOS
                                }
                            })
                        }
                        catch {
                            [void]$rangerDiagnostics.Add("Host vNIC discovery: $($_.Exception.Message)")
                            @()
                        }
                    } else { @() }
                    smbConfig     = $smbConfig
                    liveMigration = $liveMigration
                    intents       = if (Get-Command -Name Get-NetIntent -ErrorAction SilentlyContinue) { Get-NetIntent | Select-Object Name, ClusterName, IsStorageIntent, IsComputeIntent } else { @() }
                    intentOverrides = @($intentOverrides)
                    dcb           = $dcb
                    lldpNeighbors = @($lldpNeighbors)
                    dns           = if (Get-Command -Name Get-DnsClientServerAddress -ErrorAction SilentlyContinue) { Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object InterfaceAlias, ServerAddresses } else { @() }
                    dnsForwarders = @($dnsForwarders)
                    dnsConditionalForwarders = @($dnsZones)
                    ipAddresses   = if (Get-Command -Name Get-NetIPAddress -ErrorAction SilentlyContinue) { Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, IPAddress, PrefixLength, AddressState } else { @() }
                    routes        = if (Get-Command -Name Get-NetRoute -ErrorAction SilentlyContinue) { Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 50 DestinationPrefix, NextHop, InterfaceAlias, RouteMetric } else { @() }
                    vlan          = if (Get-Command -Name Get-VMNetworkAdapterVlan -ErrorAction SilentlyContinue) { Get-VMNetworkAdapterVlan -ManagementOS -ErrorAction SilentlyContinue | Select-Object VMNetworkAdapterName, OperationMode, AccessVlanId, NativeVlanId, AllowedVlanIdList } else { @() }
                    proxy         = $proxyDetail
                    proxyRaw      = $proxyRaw
                    firewall      = if (Get-Command -Name Get-NetFirewallProfile -ErrorAction SilentlyContinue) { Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction } else { @() }
                    firewallRuleAudit = @($firewallRuleAudit)
                    inboxDriverAdapters = @($inboxDriverAdapters)
                    rangerDiagnostics = @($rangerDiagnostics)
                    # Issue #60: Full SDN discovery
                    sdn           = if (Get-Command -Name Get-NetworkController -ErrorAction SilentlyContinue) {
                        $ncObj = try { Get-NetworkController -ErrorAction Stop } catch { $null }
                        if ($ncObj) {
                            $ncNodes = @(try { Get-NetworkControllerNode -ErrorAction Stop | Select-Object Name, Server, Status, Fault } catch { @() })
                            $slbMuxes = @(try { Get-NetworkControllerLoadBalancerMux -ErrorAction Stop | Select-Object ResourceId, Status } catch { @() })
                            $rasGateways = @(try { Get-NetworkControllerGateway -ErrorAction Stop | Select-Object ResourceId, GatewayPool, State } catch { @() })
                            $vnets = @(try { Get-NetworkControllerVirtualNetwork -ErrorAction Stop | ForEach-Object { [ordered]@{ resourceId = $_.ResourceId; subnetCount = @($_.Properties.Subnets).Count } } } catch { @() })
                            $nsgs = @(try { Get-NetworkControllerAccessControlList -ErrorAction Stop | ForEach-Object { [ordered]@{ resourceId = $_.ResourceId; ruleCount = @($_.Properties.AclRules).Count } } } catch { @() })
                            $lbs = @(try { Get-NetworkControllerLoadBalancer -ErrorAction Stop | ForEach-Object { [ordered]@{ resourceId = $_.ResourceId; frontendCount = @($_.Properties.FrontendIPConfigurations).Count } } } catch { @() })
                            $logicalNets = @(try { Get-NetworkControllerLogicalNetwork -ErrorAction Stop | Select-Object ResourceId } catch { @() })
                            [ordered]@{
                                deployed            = $true
                                restApiEndpoint     = $ncObj.RestApiEndpoint
                                nodeCount           = @($ncNodes).Count
                                nodes               = @($ncNodes)
                                slbMuxCount         = @($slbMuxes).Count
                                rasGatewayCount     = @($rasGateways).Count
                                virtualNetworkCount = @($vnets).Count
                                nsgCount            = @($nsgs).Count
                                loadBalancerCount   = @($lbs).Count
                                logicalNetworkCount = @($logicalNets).Count
                                slbMuxes            = @($slbMuxes)
                                rasGateways         = @($rasGateways)
                                virtualNetworks     = @($vnets)
                                nsgs                = @($nsgs)
                                loadBalancers       = @($lbs)
                                logicalNetworks     = @($logicalNets)
                            }
                        } else { [ordered]@{ deployed = $false } }
                    } else { [ordered]@{ deployed = $false } }
                }
            }
        }
    )

    if ((@($storageSnapshot.pools).Count + @($storageSnapshot.physicalDisks).Count + @($networkNodes).Count) -eq 0) {
        throw 'Storage and networking collector did not return any usable data.'
    }

    foreach ($diagnostic in @($storageSnapshot.rangerDiagnostics)) {
        if (-not [string]::IsNullOrWhiteSpace($diagnostic)) {
            Write-RangerLog -Level warn -Message $diagnostic
        }
    }
    if ($storageSnapshot -is [System.Collections.IDictionary] -and $storageSnapshot.Contains('rangerDiagnostics')) {
        $storageSnapshot.Remove('rangerDiagnostics') | Out-Null
    }

    foreach ($networkNode in @($networkNodes)) {
        foreach ($diagnostic in @($networkNode.rangerDiagnostics)) {
            if (-not [string]::IsNullOrWhiteSpace($diagnostic)) {
                $nodeName = if ($networkNode.node) { $networkNode.node } else { 'unknown-node' }
                Write-RangerLog -Level warn -Message "[$nodeName] $diagnostic"
            }
        }
        if ($networkNode -is [System.Collections.IDictionary] -and $networkNode.Contains('rangerDiagnostics')) {
            $networkNode.Remove('rangerDiagnostics') | Out-Null
        }
    }

    # Import optional offline device configs provided via hints
    $deviceImport = Invoke-RangerNetworkDeviceConfigImport -Config $Config

    $flattenedAdapters = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.adapters }))
    $flattenedSwitches = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.vSwitches }))
    $flattenedHostVirtualNics = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.hostVirtualNics }))
    $flattenedIntents = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.intents }))
    $flattenedDns = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.dns }))
    $flattenedIpAddresses = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.ipAddresses }))
    $flattenedRoutes = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.routes }))
    $flattenedVlan = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.vlan }))
    $flattenedFirewall = @(Get-RangerFlattenedCollection -Items @($networkNodes | ForEach-Object { $_.firewall }))
    $sdnByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; sdn = $_.sdn } })
    $proxyByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; proxy = $_.proxy; proxyRaw = $_.proxyRaw } })
    $dcbByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; dcb = $_.dcb } })
    $intentOverridesByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; intentOverrides = $_.intentOverrides } })
    $lldpByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; neighbors = $_.lldpNeighbors } })
    $firewallAuditByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; audit = $_.firewallRuleAudit; inboxDriverAdapters = $_.inboxDriverAdapters } })
    $smbByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; smbConfig = $_.smbConfig; liveMigration = $_.liveMigration } })
    $dnsForwardersByNode = @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; forwarders = $_.dnsForwarders; conditionalForwarders = $_.dnsConditionalForwarders } })

    $storageDomain = Update-RangerStorageDomainAnalysis -StorageDomain ([ordered]@{
        pools                 = ConvertTo-RangerHashtable -InputObject $storageSnapshot.pools
        physicalDisks         = ConvertTo-RangerHashtable -InputObject $storageSnapshot.physicalDisks
        physicalDiskReliability = ConvertTo-RangerHashtable -InputObject $storageSnapshot.physicalDiskReliability
        virtualDisks          = ConvertTo-RangerHashtable -InputObject $storageSnapshot.virtualDisks
        volumes               = ConvertTo-RangerHashtable -InputObject $storageSnapshot.volumes
        dedupStatus           = ConvertTo-RangerHashtable -InputObject $storageSnapshot.dedupStatus
        cacheConfig           = ConvertTo-RangerHashtable -InputObject $storageSnapshot.cacheConfig
        scrubSchedule         = ConvertTo-RangerHashtable -InputObject $storageSnapshot.scrubSchedule
        tiers                 = ConvertTo-RangerHashtable -InputObject $storageSnapshot.tiers
        subsystems            = ConvertTo-RangerHashtable -InputObject $storageSnapshot.subsystems
        resiliency            = ConvertTo-RangerHashtable -InputObject $storageSnapshot.resiliency
        jobs                  = ConvertTo-RangerHashtable -InputObject $storageSnapshot.jobs
        csvs                  = ConvertTo-RangerHashtable -InputObject $storageSnapshot.csvs
        qos                   = ConvertTo-RangerHashtable -InputObject $storageSnapshot.qos
        qosFlows              = ConvertTo-RangerHashtable -InputObject $storageSnapshot.qosFlows
        healthFaults          = ConvertTo-RangerHashtable -InputObject $storageSnapshot.healthFaults
        replica               = ConvertTo-RangerHashtable -InputObject $storageSnapshot.replica
        replicaDepth          = ConvertTo-RangerHashtable -InputObject $storageSnapshot.replicaDepth
        summary               = [ordered]@{}
    })
    $storageSummary = $storageDomain.summary

    $networkSummary = [ordered]@{
        nodeCount         = @($networkNodes).Count
        clusterNetworkCount = @($storageSnapshot.clusterNetworks).Count
        adapterCount      = $flattenedAdapters.Count
        adapterStates     = @(Get-RangerGroupedCount -Items $flattenedAdapters -PropertyName 'status')
        vSwitchCount      = $flattenedSwitches.Count
        intentCount       = $flattenedIntents.Count
        dnsServers        = @($flattenedDns | ForEach-Object { @($_.ServerAddresses) } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        routeCount        = $flattenedRoutes.Count
        vlanCount         = $flattenedVlan.Count
        proxyConfiguredNodes = @($proxyByNode | Where-Object { $_.proxy -and $_.proxy.proxyConfigured }).Count
        sdnDeployed       = @($sdnByNode | Where-Object { $_.sdn.deployed }).Count -gt 0
        importedSwitchConfigCount   = @($deviceImport.switchConfig).Count
        importedFirewallConfigCount = @($deviceImport.firewallConfig).Count
        dcbConfiguredNodes = @($dcbByNode | Where-Object { $_.dcb.trafficClasses -and @($_.dcb.trafficClasses).Count -gt 0 }).Count
        lldpNeighborCount  = @($lldpByNode | ForEach-Object { @($_.neighbors).Count } | Measure-Object -Sum).Sum
        inboxDriverAdapterCount = @($networkNodes | ForEach-Object { @($_.inboxDriverAdapters).Count } | Measure-Object -Sum).Sum
        firewallRulesAudited = @($networkNodes | Select-Object -First 1 | ForEach-Object { @($_.firewallRuleAudit).Count }).Sum
        firewallRequiredPortsSatisfied = @($networkNodes | Select-Object -First 1 | ForEach-Object { @($_.firewallRuleAudit | Where-Object { $_.satisfied }).Count }).Sum
    }

    $findings = New-Object System.Collections.ArrayList
    $unhealthyDisks = @($storageSnapshot.physicalDisks | Where-Object { $_.HealthStatus -and $_.HealthStatus -ne 'Healthy' })
    if ($unhealthyDisks.Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Physical disks report a non-healthy state' -Description 'The storage collector found one or more disks that were not healthy.' -AffectedComponents (@($unhealthyDisks | ForEach-Object { $_.FriendlyName })) -CurrentState "$($unhealthyDisks.Count) unhealthy disks" -Recommendation 'Inspect failed or degraded disks and review Storage Spaces Direct health before generating an as-built handoff.'))
    }

    if ($networkSummary.intentCount -eq 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'No Network ATC intents were detected' -Description 'The networking collector did not find Network ATC intent metadata in the sampled node inventory.' -CurrentState 'network intent metadata absent' -Recommendation 'Confirm whether Network ATC is intentionally unused or whether the networking inventory needs additional permissions or modules.'))
    }

    $publicFirewallEnabled = @($networkNodes | ForEach-Object { $_.firewall } | Where-Object { $_.Name -eq 'Public' -and $_.Enabled }).Count
    if ($publicFirewallEnabled -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'Public firewall profile is enabled on one or more nodes' -Description 'Host-side firewall posture indicates the Public profile is enabled on at least one node.' -CurrentState "$publicFirewallEnabled nodes with Public firewall enabled" -Recommendation 'Review whether the enabled profile aligns with intended host networking and management access posture.'))
    }

    $criticalHealthFaults = @($storageSnapshot.healthFaults | Where-Object { $_.PerceivedSeverity -in @('Fatal', 'Critical', 'Major') })
    if ($criticalHealthFaults.Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Active critical or fatal Health Service storage faults detected' -Description "The storage collector found $($criticalHealthFaults.Count) active Health Service fault(s) at Critical or higher severity." -AffectedComponents (@($criticalHealthFaults | ForEach-Object { $_.FaultingObjectDescription })) -CurrentState "$($criticalHealthFaults.Count) active critical storage faults" -Recommendation 'Review active Health Service faults in Windows Admin Center or Get-HealthFault and resolve before formal handoff.'))
    }

    $activeStorageJobs = @($storageSnapshot.jobs | Where-Object { $_.JobState -notin @('Completed', 'CompletedWithWarnings') })
    if ($activeStorageJobs.Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'Active storage jobs detected' -Description "The storage collector found $($activeStorageJobs.Count) in-progress storage job(s) such as rebuild or rebalance operations." -AffectedComponents (@($activeStorageJobs | ForEach-Object { $_.Name })) -CurrentState "$($activeStorageJobs.Count) active storage jobs" -Recommendation 'Monitor active storage jobs to completion before formal handoff. Review rebuild or rebalance progress.'))
    }

    $allInboxAdapters = @($networkNodes | ForEach-Object { @($_.inboxDriverAdapters) })
    if ($allInboxAdapters.Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Adapters using inbox (Microsoft) drivers detected' -Description "$($allInboxAdapters.Count) network adapter(s) are using inbox Microsoft drivers, which are not supported/qualified for Azure Local production workloads." -AffectedComponents (@($allInboxAdapters | ForEach-Object { $_.Name })) -CurrentState 'Inbox driver on production-facing NIC' -Recommendation 'Install vendor-supplied NIC drivers from the OEM or Windows Server Catalog. Inbox drivers are unsupported for Storage and compute traffic on Azure Local.'))
    }

    $retiredDisks = @($storageSnapshot.physicalDisks | Where-Object { $_.operationalStatus -match 'Retiring|PredictiveFailure' })
    if ($retiredDisks.Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Physical disks flagged for retirement' -Description "$($retiredDisks.Count) disk(s) have an operational status indicating predictive failure or retirement." -AffectedComponents (@($retiredDisks | ForEach-Object { $_.friendlyName })) -CurrentState "$($retiredDisks.Count) disks in Retiring/PredictiveFailure state" -Recommendation 'Replace disks flagged for retirement before formal handoff to prevent data loss.'))
    }

    foreach ($storageFinding in @(New-RangerStorageAnalysisFindings -StorageDomain $storageDomain)) {
        [void]$findings.Add($storageFinding)
    }

    return @{
        Status        = 'success'
        Domains       = @{
            storage = $storageDomain
            networking = [ordered]@{
                nodes                = ConvertTo-RangerHashtable -InputObject $networkNodes
                clusterNetworks      = ConvertTo-RangerHashtable -InputObject $storageSnapshot.clusterNetworks
                adapters             = ConvertTo-RangerHashtable -InputObject $flattenedAdapters
                vSwitches            = ConvertTo-RangerHashtable -InputObject $flattenedSwitches
                hostVirtualNics      = ConvertTo-RangerHashtable -InputObject $flattenedHostVirtualNics
                intents              = ConvertTo-RangerHashtable -InputObject $flattenedIntents
                intentOverrides      = ConvertTo-RangerHashtable -InputObject $intentOverridesByNode
                dcb                  = ConvertTo-RangerHashtable -InputObject $dcbByNode
                lldpNeighbors        = ConvertTo-RangerHashtable -InputObject $lldpByNode
                dns                  = ConvertTo-RangerHashtable -InputObject $flattenedDns
                dnsForwarders        = ConvertTo-RangerHashtable -InputObject $dnsForwardersByNode
                ipAddresses          = ConvertTo-RangerHashtable -InputObject $flattenedIpAddresses
                routes               = ConvertTo-RangerHashtable -InputObject $flattenedRoutes
                vlan                 = ConvertTo-RangerHashtable -InputObject $flattenedVlan
                proxy                = ConvertTo-RangerHashtable -InputObject $proxyByNode
                firewall             = ConvertTo-RangerHashtable -InputObject @($networkNodes | ForEach-Object { [ordered]@{ node = $_.node; profiles = $_.firewall } })
                firewallRuleAudit    = ConvertTo-RangerHashtable -InputObject $firewallAuditByNode
                sdn                  = ConvertTo-RangerHashtable -InputObject $sdnByNode
                smbConfig            = ConvertTo-RangerHashtable -InputObject $smbByNode
                switchConfig         = ConvertTo-RangerHashtable -InputObject $deviceImport.switchConfig
                firewallConfig       = ConvertTo-RangerHashtable -InputObject $deviceImport.firewallConfig
                summary              = $networkSummary
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
