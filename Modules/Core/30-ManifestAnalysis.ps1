function Invoke-RangerVmDistributionAnalysis {
    <#
    .SYNOPSIS
        v2.0.0 (#223): compute VM distribution balance across cluster nodes.
    .DESCRIPTION
        After Arc VM inventory is collected, count VMs per node, compute the
        coefficient of variation, and flag as unbalanced if CV > 0.3 or any
        node has > 2× the average.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $nodes = @($Manifest.domains.clusterNode.nodes | Where-Object { $_ -and $_.name })
    $vms   = @($Manifest.domains.virtualMachines.inventory | Where-Object { $_ -and $_.hostNode })

    if ($nodes.Count -eq 0) {
        return [ordered]@{
            balanced = $true
            cv       = 0.0
            status   = 'pass'
            perNode  = @()
            message  = 'No nodes to analyse.'
        }
    }

    $perNode = @($nodes | ForEach-Object {
        $n = $_.name
        [ordered]@{
            node    = $n
            vmCount = @($vms | Where-Object { [string]$_.hostNode -eq $n }).Count
        }
    })

    $counts = @($perNode | ForEach-Object { [double]$_.vmCount })
    $mean   = if ($counts.Count -gt 0) { [double](($counts | Measure-Object -Average).Average) } else { 0.0 }

    if ($mean -eq 0 -or $counts.Count -le 1) {
        return [ordered]@{
            balanced = $true
            cv       = 0.0
            status   = 'pass'
            mean     = $mean
            perNode  = $perNode
            message  = if ($mean -eq 0) { 'Zero VMs — balanced by definition.' } else { 'Single-node cluster — balanced by definition.' }
        }
    }

    $variance = [double](($counts | ForEach-Object { ($_ - $mean) * ($_ - $mean) } | Measure-Object -Average).Average)
    $stdDev   = [math]::Sqrt($variance)
    $cv       = $stdDev / $mean
    $maxCount = [double](($counts | Measure-Object -Maximum).Maximum)
    $overload = $maxCount -gt (2.0 * $mean)

    $status = if ($cv -gt 0.3 -or $overload) { 'fail' }
              elseif ($cv -ge 0.2)           { 'warning' }
              else                            { 'pass' }

    $maxNode = @($perNode | Sort-Object { [int]$_.vmCount } -Descending | Select-Object -First 1)[0]

    [ordered]@{
        balanced = ($status -ne 'fail')
        cv       = [math]::Round($cv, 3)
        status   = $status
        mean     = [math]::Round($mean, 2)
        maxCount = [int]$maxCount
        overloadedNode = if ($overload -and $maxNode) { [string]$maxNode.node } else { $null }
        perNode  = $perNode
        message  = switch ($status) {
            'fail'    { "Imbalanced (CV=$([math]::Round($cv, 3))). $(if ($overload -and $maxNode) { "$($maxNode.node) is overloaded." } else { '' })" }
            'warning' { "Slightly imbalanced (CV=$([math]::Round($cv, 3)))." }
            default   { 'VMs distributed evenly across nodes.' }
        }
    }
}

function Invoke-RangerAgentVersionAnalysis {
    <#
    .SYNOPSIS
        v2.0.0 (#224): group cluster nodes by Arc agent version and OS version.
    .DESCRIPTION
        Returns agentVersionGroups, osVersionGroups, and an agentVersionDrift
        summary (uniqueVersions, latestVersion, maxBehind, status).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $nodes = @($Manifest.domains.clusterNode.nodes | Where-Object { $_ -and $_.name })

    $agentGroups = @($nodes | Group-Object -Property { [string]$_.arcAgentVersion } | ForEach-Object {
        [ordered]@{
            version   = if ([string]::IsNullOrWhiteSpace($_.Name)) { 'unknown' } else { $_.Name }
            nodeCount = $_.Count
            nodeNames = @($_.Group | ForEach-Object { $_.name })
        }
    })

    $osGroups = @($nodes | Group-Object -Property { [string]($_.osSku ?? $_.osCaption) } | ForEach-Object {
        $first = @($_.Group)[0]
        [ordered]@{
            osSku     = if ([string]::IsNullOrWhiteSpace($_.Name)) { 'unknown' } else { $_.Name }
            version   = [string]$first.osVersion
            nodeCount = $_.Count
            nodeNames = @($_.Group | ForEach-Object { $_.name })
        }
    })

    # Determine "latest" by natural sort-descending of version strings (good enough
    # for dotted semver + build-number formats used by Arc agent).
    $versions = @($agentGroups | Where-Object { $_.version -ne 'unknown' } | ForEach-Object { $_.version } | Sort-Object -Descending)
    $latest   = if ($versions.Count -gt 0) { [string]$versions[0] } else { $null }

    # maxBehind = index in descending list of the oldest version in use.
    $maxBehind = 0
    foreach ($g in $agentGroups) {
        if ($g.version -eq 'unknown' -or -not $latest) { continue }
        $idx = [Array]::IndexOf($versions, [string]$g.version)
        if ($idx -gt $maxBehind) { $maxBehind = $idx }
    }

    $uniqueVersions = @($agentGroups | Where-Object { $_.version -ne 'unknown' }).Count
    $status = if ($uniqueVersions -le 1) { 'pass' }
              elseif ($maxBehind -eq 1)  { 'warning' }
              else                        { 'fail' }

    [ordered]@{
        agentVersionGroups = $agentGroups
        osVersionGroups    = $osGroups
        drift              = [ordered]@{
            uniqueVersions = $uniqueVersions
            latestVersion  = $latest
            maxBehind      = $maxBehind
            status         = $status
        }
    }
}

function Invoke-RangerCostLicensingAnalysis {
    <#
    .SYNOPSIS
        v2.0.0 (#222): compute Azure Hybrid Benefit adoption and cost/savings.
    .DESCRIPTION
        AHB for Azure Local is a cluster-level property. Reads
        softwareAssuranceProperties.softwareAssuranceStatus, multiplies physical
        cores against the public $10/core/month rate, and computes potential
        savings if AHB is not enabled. Does not override an existing costLicensing
        object already populated by a collector or fixture — merges summary fields
        in-place so the pricing reference date is always current.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $existing = $null
    try { $existing = $Manifest.domains.azureIntegration.costLicensing } catch { }
    if ($existing -and $existing.summary -and $null -ne $existing.summary.totalPhysicalCores) {
        # Collector/fixture already populated — ensure pricing date is set.
        if (-not $existing.pricingReference) {
            $existing['pricingReference'] = [ordered]@{
                asOfDate = (Get-Date).ToString('yyyy-MM-dd')
                url      = 'https://azure.microsoft.com/en-us/pricing/details/azure-local/'
            }
        } elseif (-not $existing.pricingReference.asOfDate) {
            $existing.pricingReference.asOfDate = (Get-Date).ToString('yyyy-MM-dd')
        }
        return $existing
    }

    # Derive from cluster + hardware domains.
    $cluster  = $Manifest.domains.clusterNode.cluster
    $hardware = @($Manifest.domains.hardware.nodes)
    $costPerCore = 10.00

    $ahbEnabled = $false
    try {
        $saStatus = [string]$cluster.softwareAssuranceProperties.softwareAssuranceStatus
        $ahbEnabled = $saStatus -match '^(Enabled|enabled|True|1)$'
    } catch { }

    $totalCores = 0
    $perNode = New-Object System.Collections.ArrayList
    foreach ($h in $hardware) {
        $cores = 0
        foreach ($prop in @('physicalCoreCount','physicalCores','logicalCoreCount','processorCount')) {
            if ($null -ne $h.$prop) { $cores = [int]$h.$prop; break }
        }
        $totalCores += $cores
        [void]$perNode.Add([ordered]@{
            node             = [string]$h.node
            physicalCores    = $cores
            ahbEnabled       = $ahbEnabled
            monthlyCostUsd   = [double]($cores * $costPerCore)
            monthlySavingUsd = if ($ahbEnabled) { [double]($cores * $costPerCore) } else { 0.0 }
        })
    }

    $coresWithAhb    = if ($ahbEnabled) { $totalCores } else { 0 }
    $coresWithoutAhb = $totalCores - $coresWithAhb
    $currentCost     = [double]($totalCores * $costPerCore)
    $savings         = [double]($coresWithoutAhb * $costPerCore)
    $adoption        = if ($totalCores -gt 0) { [double][math]::Round(($coresWithAhb / $totalCores) * 100, 1) } else { 0.0 }

    [ordered]@{
        subscriptionName = [string]$Manifest.domains.azureIntegration.context.subscriptionId
        cluster          = [string]$cluster.name
        ahbStatus        = if ($ahbEnabled) { 'Enabled' } else { 'Disabled' }
        perNode          = @($perNode)
        summary          = [ordered]@{
            totalPhysicalCores         = $totalCores
            coresWithAhb               = $coresWithAhb
            coresWithoutAhb            = $coresWithoutAhb
            costPerCoreUsd             = $costPerCore
            currentMonthlyCostUsd      = $currentCost
            potentialMonthlySavingsUsd = $savings
            ahbAdoptionPct             = $adoption
            currency                   = 'USD'
        }
        pricingReference = [ordered]@{
            asOfDate = (Get-Date).ToString('yyyy-MM-dd')
            url      = 'https://azure.microsoft.com/en-us/pricing/details/azure-local/'
        }
    }
}

function Invoke-RangerManifestPostAnalysis {
    <#
    .SYNOPSIS
        v2.0.0: run all post-collection manifest analysis helpers in place.
    .DESCRIPTION
        After all collectors have populated the manifest, compute derived
        analyses (VM distribution balance #223, agent version drift #224, AHB
        cost/savings #222) and merge them into the appropriate domains.
        Idempotent — if a fixture already provided the values, they are kept.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    # #223 — VM distribution
    try {
        $vmSummary = $Manifest.domains.virtualMachines.summary
        if ($vmSummary -and $null -eq $vmSummary.vmDistributionBalanced) {
            $vmDist = Invoke-RangerVmDistributionAnalysis -Manifest $Manifest
            $vmSummary.vmDistribution          = @($vmDist.perNode)
            $vmSummary.vmDistributionBalanced  = [bool]$vmDist.balanced
            $vmSummary.vmDistributionCv        = [double]$vmDist.cv
            $vmSummary.vmDistributionStatus    = [string]$vmDist.status
        }
    } catch {
        Write-Warning "VM distribution analysis failed: $($_.Exception.Message)"
    }

    # #224 — agent version grouping
    try {
        $nodeSummary = $Manifest.domains.clusterNode.nodeSummary
        if ($nodeSummary -and $null -eq $nodeSummary.arcAgentVersionGroups) {
            $agentAnalysis = Invoke-RangerAgentVersionAnalysis -Manifest $Manifest
            $nodeSummary.arcAgentVersionGroups = @($agentAnalysis.agentVersionGroups)
            $nodeSummary.osVersionGroups       = @($agentAnalysis.osVersionGroups)
            $nodeSummary.agentVersionDrift     = $agentAnalysis.drift
        }
    } catch {
        Write-Warning "Agent version analysis failed: $($_.Exception.Message)"
    }

    # #222 — AHB cost/licensing
    try {
        if (-not $Manifest.domains.azureIntegration.costLicensing -or `
            -not $Manifest.domains.azureIntegration.costLicensing.summary -or `
            $null -eq $Manifest.domains.azureIntegration.costLicensing.summary.totalPhysicalCores) {
            $cost = Invoke-RangerCostLicensingAnalysis -Manifest $Manifest
            $Manifest.domains.azureIntegration.costLicensing = $cost
        } else {
            # Ensure pricing reference date is current.
            Invoke-RangerCostLicensingAnalysis -Manifest $Manifest | Out-Null
        }
    } catch {
        Write-Warning "Cost licensing analysis failed: $($_.Exception.Message)"
    }
}
