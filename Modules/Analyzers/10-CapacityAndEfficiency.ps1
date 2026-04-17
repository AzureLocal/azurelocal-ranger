#Requires -Version 7.0

<#
.SYNOPSIS
    v2.5.0 analyzer pass — capacity headroom (#128), idle / underutilized VM
    detection (#125), storage efficiency (#126), and SQL / Windows Server
    license inventory (#127). Runs after all collectors so it can reason over
    the complete manifest.
#>

function Invoke-RangerCapacityAnalysis {
    <#
    .SYNOPSIS
        v2.5.0 (#128): compute cluster capacity headroom and runway projection.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary]$Manifest,
        [double]$WarnUtilizationPct = 80,
        [double]$FailUtilizationPct = 90
    )

    $nodes = @($Manifest.domains.clusterNode.nodes)
    $vms   = @($Manifest.domains.virtualMachines.inventory)
    $volumes = @($Manifest.domains.storage.volumes)
    $pools = @($Manifest.domains.storage.pools)

    $totalLogicalCores = 0
    $totalMemoryGiB    = 0.0
    foreach ($n in $nodes) {
        if ($n.logicalProcessorCount) { $totalLogicalCores += [int]$n.logicalProcessorCount }
        if ($n.totalMemoryGiB)        { $totalMemoryGiB += [double]$n.totalMemoryGiB }
    }

    $allocatedVcpu = 0
    $allocatedMemMb = 0
    foreach ($vm in $vms) {
        if ($vm.processorCount) { $allocatedVcpu += [int]$vm.processorCount }
        if ($vm.memoryAssignedMb) { $allocatedMemMb += [long]$vm.memoryAssignedMb }
    }
    $allocatedMemGiB = [Math]::Round($allocatedMemMb / 1024.0, 1)

    # vCPU oversubscription is normal; headroom tracked against logical cores for visibility only.
    $vcpuPct = if ($totalLogicalCores -gt 0) { [Math]::Round(($allocatedVcpu / $totalLogicalCores) * 100, 1) } else { 0 }
    $memPct  = if ($totalMemoryGiB -gt 0)    { [Math]::Round(($allocatedMemGiB / $totalMemoryGiB) * 100, 1) } else { 0 }

    # Storage headroom — per-volume used/free plus pool-level allocation
    $totalVolGiB = 0.0; $freeVolGiB = 0.0
    foreach ($v in $volumes) {
        if ($v.sizeGB)      { $totalVolGiB += [double]$v.sizeGB }
        if ($v.freeSpaceGB) { $freeVolGiB  += [double]$v.freeSpaceGB }
    }
    $usedVolGiB = [Math]::Round($totalVolGiB - $freeVolGiB, 1)
    $storagePct = if ($totalVolGiB -gt 0) { [Math]::Round(($usedVolGiB / $totalVolGiB) * 100, 1) } else { 0 }

    $poolCapacityGiB = 0.0; $poolAllocatedGiB = 0.0
    foreach ($p in $pools) {
        if ($p.size)          { $poolCapacityGiB  += [double]$p.size / 1GB }
        if ($p.allocatedSize) { $poolAllocatedGiB += [double]$p.allocatedSize / 1GB }
    }
    $poolPct = if ($poolCapacityGiB -gt 0) { [Math]::Round(($poolAllocatedGiB / $poolCapacityGiB) * 100, 1) } else { 0 }

    $statusFor = {
        param($pct)
        if ($pct -ge $FailUtilizationPct) { 'Critical' }
        elseif ($pct -ge $WarnUtilizationPct) { 'Warning' }
        else { 'Healthy' }
    }

    # Runway — if growth trend is unknown (no historical data), we surface current state only;
    # a `projectedRunwayMonths` field is written as $null so consumers can fill in from trend data.
    return [ordered]@{
        summary = [ordered]@{
            nodeCount               = $nodes.Count
            vmCount                 = $vms.Count
            totalLogicalCores       = $totalLogicalCores
            allocatedVcpu           = $allocatedVcpu
            vcpuUtilizationPct      = $vcpuPct
            vcpuStatus              = & $statusFor $vcpuPct
            totalMemoryGiB          = [Math]::Round($totalMemoryGiB, 1)
            allocatedMemoryGiB      = $allocatedMemGiB
            memoryUtilizationPct    = $memPct
            memoryStatus            = & $statusFor $memPct
            totalStorageGiB         = [Math]::Round($totalVolGiB, 1)
            usedStorageGiB          = $usedVolGiB
            storageUtilizationPct   = $storagePct
            storageStatus           = & $statusFor $storagePct
            poolCapacityGiB         = [Math]::Round($poolCapacityGiB, 1)
            poolAllocatedGiB        = [Math]::Round($poolAllocatedGiB, 1)
            poolUtilizationPct      = $poolPct
            poolStatus              = & $statusFor $poolPct
            projectedRunwayMonths   = $null
            thresholds              = @{ warn = $WarnUtilizationPct; fail = $FailUtilizationPct }
        }
        perNode = @(
            foreach ($n in $nodes) {
                $nodeVms = @($vms | Where-Object { $_.hostNode -eq $n.name })
                $nodeVcpu = ($nodeVms | Measure-Object -Property processorCount -Sum).Sum
                $nodeMemMb = ($nodeVms | Measure-Object -Property memoryAssignedMb -Sum).Sum
                [ordered]@{
                    node                 = $n.name
                    logicalCores         = [int]$n.logicalProcessorCount
                    allocatedVcpu        = [int]$nodeVcpu
                    vcpuUtilizationPct   = if ($n.logicalProcessorCount) { [Math]::Round(($nodeVcpu / [double]$n.logicalProcessorCount) * 100, 1) } else { 0 }
                    memoryGiB            = [double]$n.totalMemoryGiB
                    allocatedMemoryGiB   = [Math]::Round($nodeMemMb / 1024.0, 1)
                    memoryUtilizationPct = if ($n.totalMemoryGiB) { [Math]::Round((($nodeMemMb / 1024.0) / [double]$n.totalMemoryGiB) * 100, 1) } else { 0 }
                    vmCount              = $nodeVms.Count
                }
            }
        )
    }
}

function Invoke-RangerVmUtilizationAnalysis {
    <#
    .SYNOPSIS
        v2.5.0 (#125): detect idle / underutilized VMs and produce rightsizing hints.
    .DESCRIPTION
        Consumes `vm.utilization` sidecar data when present (average/peak CPU and memory %)
        and falls back to allocation-only heuristics when utilization counters are absent.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary]$Manifest,
        [double]$IdleCpuPct = 5,
        [double]$UnderCpuPct = 20,
        [double]$UnderMemPct = 30
    )

    $vms = @($Manifest.domains.virtualMachines.inventory)
    $classified = New-Object System.Collections.ArrayList
    $idleCount = 0; $underCount = 0; $rightsizedVcpu = 0; $rightsizedMemMb = 0

    foreach ($vm in $vms) {
        $util = $vm.utilization
        $avgCpu = if ($util -and $null -ne $util.avgCpuPct) { [double]$util.avgCpuPct } else { $null }
        $peakCpu = if ($util -and $null -ne $util.peakCpuPct) { [double]$util.peakCpuPct } else { $null }
        $avgMem = if ($util -and $null -ne $util.avgMemoryPct) { [double]$util.avgMemoryPct } else { $null }
        $runState = [string]$vm.state

        $classification = 'unknown'
        $recommendation = $null
        $proposedVcpu = [int]$vm.processorCount
        $proposedMemMb = [int]$vm.memoryAssignedMb

        if ($runState -ne 'Running') {
            $classification = 'stopped'
            $recommendation = 'VM is not running — consider decommission or archive if idle > 30 days.'
        } elseif ($null -ne $avgCpu -and $null -ne $peakCpu) {
            if ($peakCpu -le $IdleCpuPct) {
                $classification = 'idle'
                $recommendation = "Idle (peak CPU ${peakCpu}%). Stop or consolidate."
                $idleCount++
            } elseif ($avgCpu -le $UnderCpuPct -and ($null -ne $avgMem -and $avgMem -le $UnderMemPct)) {
                $classification = 'underutilized'
                $proposedVcpu = [Math]::Max(1, [int][Math]::Ceiling($vm.processorCount * 0.5))
                $proposedMemMb = [int]([Math]::Ceiling(($vm.memoryAssignedMb * 0.5) / 512) * 512)
                $rightsizedVcpu += ($vm.processorCount - $proposedVcpu)
                $rightsizedMemMb += ($vm.memoryAssignedMb - $proposedMemMb)
                $recommendation = "Rightsize to $proposedVcpu vCPU / $([Math]::Round($proposedMemMb/1024,1)) GiB (avg CPU ${avgCpu}%, avg mem ${avgMem}%)."
                $underCount++
            } else {
                $classification = 'healthy'
            }
        } else {
            $classification = 'no-counters'
            $recommendation = 'No utilization counters available — enable performance collection to classify.'
        }

        [void]$classified.Add([ordered]@{
            name            = $vm.name
            hostNode        = $vm.hostNode
            state           = $runState
            processorCount  = [int]$vm.processorCount
            memoryAssignedMb = [int]$vm.memoryAssignedMb
            avgCpuPct       = $avgCpu
            peakCpuPct      = $peakCpu
            avgMemoryPct    = $avgMem
            classification  = $classification
            proposedVcpu    = $proposedVcpu
            proposedMemoryMb = $proposedMemMb
            recommendation  = $recommendation
        })
    }

    return [ordered]@{
        summary = [ordered]@{
            vmCount                       = $vms.Count
            idleCount                     = $idleCount
            underutilizedCount            = $underCount
            potentialVcpuFreed            = $rightsizedVcpu
            potentialMemoryFreedGiB       = [Math]::Round($rightsizedMemMb / 1024.0, 1)
            thresholds                    = @{ idleCpuPct = $IdleCpuPct; underCpuPct = $UnderCpuPct; underMemPct = $UnderMemPct }
        }
        classifications = @($classified)
    }
}

function Invoke-RangerStorageEfficiencyAnalysis {
    <#
    .SYNOPSIS
        v2.5.0 (#126): dedup, thin-provisioning coverage, and storage waste surface.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary]$Manifest
    )

    $volumes = @($Manifest.domains.storage.volumes)
    $records = New-Object System.Collections.ArrayList
    $dedupEnabled = 0; $dedupEligible = 0; $thinEnabled = 0; $thinEligible = 0
    $totalLogicalGiB = 0.0; $totalPhysicalGiB = 0.0; $totalSavedGiB = 0.0

    foreach ($v in $volumes) {
        $label = [string]$v.fileSystemLabel
        if ([string]::IsNullOrWhiteSpace($label) -or $label -eq 'OS') { continue }

        $eff = $v.efficiency
        $dedup = if ($eff -and $null -ne $eff.dedupEnabled) { [bool]$eff.dedupEnabled } else { $false }
        $dedupMode = if ($eff) { [string]$eff.dedupMode } else { '' }
        $thin = if ($eff -and $null -ne $eff.thinProvisioned) { [bool]$eff.thinProvisioned } else { $false }
        $savedGiB = if ($eff -and $null -ne $eff.savedGiB) { [double]$eff.savedGiB } else { 0 }
        $ratio = if ($eff -and $null -ne $eff.dedupRatio) { [double]$eff.dedupRatio } else { $null }
        $sizeGiB = [double]$v.sizeGB
        $freeGiB = [double]$v.freeSpaceGB
        $usedGiB = $sizeGiB - $freeGiB

        $dedupEligible++; $thinEligible++
        if ($dedup) { $dedupEnabled++ }
        if ($thin)  { $thinEnabled++ }
        $totalLogicalGiB += $sizeGiB
        $totalPhysicalGiB += if ($ratio -and $ratio -gt 0) { $usedGiB / $ratio } else { $usedGiB }
        $totalSavedGiB += $savedGiB

        $waste = if (-not $thin -and $freeGiB -gt ($sizeGiB * 0.5)) { 'over-provisioned' }
                 elseif (-not $dedup -and $label -match '(vmstore|backup|file)') { 'dedup-candidate' }
                 else { 'none' }

        [void]$records.Add([ordered]@{
            volume           = $label
            sizeGiB          = [Math]::Round($sizeGiB, 1)
            usedGiB          = [Math]::Round($usedGiB, 1)
            freeGiB          = [Math]::Round($freeGiB, 1)
            dedupEnabled     = $dedup
            dedupMode        = $dedupMode
            dedupRatio       = $ratio
            savedGiB         = $savedGiB
            thinProvisioned  = $thin
            wasteClass       = $waste
        })
    }

    $dedupCoverage = if ($dedupEligible -gt 0) { [Math]::Round(($dedupEnabled / $dedupEligible) * 100, 1) } else { 0 }
    $thinCoverage  = if ($thinEligible -gt 0)  { [Math]::Round(($thinEnabled / $thinEligible) * 100, 1) } else { 0 }

    return [ordered]@{
        summary = [ordered]@{
            volumeCount         = $records.Count
            dedupEnabledCount   = $dedupEnabled
            dedupCoveragePct    = $dedupCoverage
            thinEnabledCount    = $thinEnabled
            thinCoveragePct     = $thinCoverage
            totalLogicalGiB     = [Math]::Round($totalLogicalGiB, 1)
            totalPhysicalGiB    = [Math]::Round($totalPhysicalGiB, 1)
            totalSavedGiB       = [Math]::Round($totalSavedGiB, 1)
            overallRatio        = if ($totalPhysicalGiB -gt 0) { [Math]::Round($totalLogicalGiB / $totalPhysicalGiB, 2) } else { 1.0 }
        }
        volumes = @($records)
    }
}

function Invoke-RangerLicenseInventory {
    <#
    .SYNOPSIS
        v2.5.0 (#127): SQL Server + Windows Server license inventory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary]$Manifest
    )

    $vms = @($Manifest.domains.virtualMachines.inventory)
    $sqlInstances = New-Object System.Collections.ArrayList
    $wsInstances  = New-Object System.Collections.ArrayList
    $sqlCores = 0; $wsCores = 0

    foreach ($vm in $vms) {
        $guest = $vm.guestSoftware
        if (-not $guest) { continue }

        if ($guest.windowsServer) {
            $ws = $guest.windowsServer
            $cores = [int]$vm.processorCount
            $wsCores += $cores
            [void]$wsInstances.Add([ordered]@{
                vm             = $vm.name
                hostNode       = $vm.hostNode
                edition        = [string]$ws.edition
                version        = [string]$ws.version
                coreCount      = $cores
                licenseModel   = [string]$ws.licenseModel
                ahbEligible    = [bool]$ws.ahbEligible
            })
        }

        if ($guest.sqlServer) {
            foreach ($sql in @($guest.sqlServer)) {
                $cores = if ($sql.assignedCoreCount) { [int]$sql.assignedCoreCount } else { [int]$vm.processorCount }
                $sqlCores += $cores
                [void]$sqlInstances.Add([ordered]@{
                    vm             = $vm.name
                    hostNode       = $vm.hostNode
                    instanceName   = [string]$sql.instanceName
                    edition        = [string]$sql.edition
                    version        = [string]$sql.version
                    coreCount      = $cores
                    licenseModel   = [string]$sql.licenseModel
                    ahbEligible    = [bool]$sql.ahbEligible
                })
            }
        }
    }

    return [ordered]@{
        summary = [ordered]@{
            sqlInstanceCount     = $sqlInstances.Count
            sqlTotalCores        = $sqlCores
            windowsServerCount   = $wsInstances.Count
            windowsServerCores   = $wsCores
        }
        sqlServer      = @($sqlInstances)
        windowsServer  = @($wsInstances)
    }
}

function Invoke-RangerV25Analyzers {
    <#
    .SYNOPSIS
        Run all v2.5.0 analyzer passes and merge the results into the manifest.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary]$Manifest
    )

    if (-not $Manifest.domains) { $Manifest.domains = [ordered]@{} }

    $capacity = Invoke-RangerCapacityAnalysis -Manifest $Manifest
    $vmUtil   = Invoke-RangerVmUtilizationAnalysis -Manifest $Manifest
    $efficiency = Invoke-RangerStorageEfficiencyAnalysis -Manifest $Manifest
    $licenses = Invoke-RangerLicenseInventory -Manifest $Manifest

    $Manifest.domains.capacityAnalysis   = $capacity
    $Manifest.domains.vmUtilization      = $vmUtil
    $Manifest.domains.storageEfficiency  = $efficiency
    $Manifest.domains.licenseInventory   = $licenses

    return $Manifest
}
