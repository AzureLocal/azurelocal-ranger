function Invoke-RangerManagementPerformanceCollector {
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

    $nodeSnapshots = @(
        Invoke-RangerSafeAction -Label 'Management and performance snapshot' -DefaultValue @() -ScriptBlock {
            Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -ScriptBlock {
                $managementServices = @(
                    foreach ($name in @('ServerManagementGateway', 'HealthService', 'SCVMMAgent', 'MOMAgent', 'Dell*')) {
                        Get-Service -Name $name -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, Status, StartType
                    }
                )

                $cpu = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
                $memory = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
                $disks = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfDisk_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne '_Total' } | Select-Object Name, PercentFreeSpace, AvgDiskSecPerTransfer, DiskTransfersPerSec
                $network = Get-CimInstance -ClassName Win32_PerfFormattedData_Tcpip_NetworkInterface -ErrorAction SilentlyContinue | Select-Object Name, BytesTotalPersec, CurrentBandwidth
                $events = if (Get-Command -Name Get-WinEvent -ErrorAction SilentlyContinue) { Get-WinEvent -LogName System -MaxEvents 15 -ErrorAction SilentlyContinue | Select-Object TimeCreated, Id, LevelDisplayName, ProviderName } else { @() }

                [ordered]@{
                    node = $env:COMPUTERNAME
                    tools = @($managementServices)
                    compute = [ordered]@{
                        cpuUtilizationPercent = if ($cpu) { $cpu.PercentProcessorTime } else { $null }
                        availableMemoryMb     = if ($memory) { [math]::Round(($memory.FreePhysicalMemory / 1KB), 2) } else { $null }
                        totalMemoryMb         = if ($memory) { [math]::Round(($memory.TotalVisibleMemorySize / 1KB), 2) } else { $null }
                    }
                    storage = @($disks)
                    networking = @($network)
                    events = @($events)
                }
            }
        }
    )

    if ($nodeSnapshots.Count -eq 0) {
        throw 'Management and performance collector did not return any usable node data.'
    }

    $tools = @($nodeSnapshots | ForEach-Object { $_.tools } | Where-Object { $null -ne $_ })
    $compute = @($nodeSnapshots | ForEach-Object { [ordered]@{ node = $_.node; metrics = $_.compute } })
    $storage = @($nodeSnapshots | ForEach-Object { [ordered]@{ node = $_.node; metrics = $_.storage } })
    $network = @($nodeSnapshots | ForEach-Object { [ordered]@{ node = $_.node; metrics = $_.networking } })
    $outliers = @($nodeSnapshots | Where-Object { $_.compute.cpuUtilizationPercent -gt 85 })
    $events = @($nodeSnapshots | ForEach-Object { [ordered]@{ node = $_.node; values = $_.events } })
    $relationships = New-Object System.Collections.ArrayList
    foreach ($snapshot in @($nodeSnapshots)) {
        foreach ($tool in @($snapshot.tools)) {
            [void]$relationships.Add((New-RangerRelationship -SourceType 'cluster-node' -SourceId $snapshot.node -TargetType 'management-tool' -TargetId $tool.Name -RelationshipType 'managed-by' -Properties ([ordered]@{ status = $tool.Status; displayName = $tool.DisplayName })))
        }
    }
    $summary = [ordered]@{
        averageCpuUtilizationPercent = Get-RangerAverageValue -Values @($nodeSnapshots | ForEach-Object { $_.compute.cpuUtilizationPercent })
        averageAvailableMemoryMb     = Get-RangerAverageValue -Values @($nodeSnapshots | ForEach-Object { $_.compute.availableMemoryMb })
        runningManagementServices    = @($tools | Where-Object { $_.Status -eq 'Running' }).Count
        toolNames                    = @(Get-RangerGroupedCount -Items $tools -PropertyName 'Name')
        highCpuNodes                 = @($outliers).Count
        eventSeverities              = @(Get-RangerGroupedCount -Items @($nodeSnapshots | ForEach-Object { $_.events }) -PropertyName 'LevelDisplayName')
    }

    $findings = New-Object System.Collections.ArrayList
    if ($outliers.Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Compute baseline indicates high sustained CPU on one or more nodes' -Description 'The performance baseline returned total CPU values above 85 percent for at least one node.' -AffectedComponents (@($outliers | ForEach-Object { $_.node })) -CurrentState 'performance outlier' -Recommendation 'Validate whether the baseline was captured during an expected workload peak or whether capacity and placement need review.'))
    }

    if (@($tools | Where-Object { $_.Name -eq 'HealthService' -and $_.Status -ne 'Running' }).Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'HealthService is not running on one or more nodes' -Description 'Management tooling inventory found the Windows Admin Center or Azure Local health service stopped on at least one node.' -AffectedComponents (@($tools | Where-Object { $_.Name -eq 'HealthService' -and $_.Status -ne 'Running' } | ForEach-Object { $_.DisplayName })) -CurrentState 'management service stopped' -Recommendation 'Review service health, dependent agents, and management-plane readiness before using the environment for operational handoff.'))
    }

    $lowMemoryNodes = @($nodeSnapshots | Where-Object { $null -ne $_.compute.availableMemoryMb -and $_.compute.availableMemoryMb -lt 65536 })
    if ($lowMemoryNodes.Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'One or more nodes report less than 64 GB of free memory' -Description 'The performance baseline found nodes with relatively low available memory for a formal handoff snapshot.' -AffectedComponents (@($lowMemoryNodes | ForEach-Object { $_.node })) -CurrentState 'memory headroom reduced' -Recommendation 'Confirm whether the memory posture is expected for this collection window or whether workload placement and capacity should be reviewed.'))
    }

    return @{
        Status        = if ($findings.Count -gt 0) { 'partial' } else { 'success' }
        Domains       = @{
            managementTools = [ordered]@{
                tools  = ConvertTo-RangerHashtable -InputObject @($tools)
                agents = ConvertTo-RangerHashtable -InputObject @($tools | Where-Object { $_.Status -eq 'Running' })
                summary = [ordered]@{ totalServices = @($tools).Count; runningServices = @($tools | Where-Object { $_.Status -eq 'Running' }).Count; serviceNames = $summary.toolNames }
            }
            performance = [ordered]@{
                nodes      = ConvertTo-RangerHashtable -InputObject @($nodeSnapshots | ForEach-Object { $_.node })
                compute    = ConvertTo-RangerHashtable -InputObject $compute
                storage    = ConvertTo-RangerHashtable -InputObject $storage
                networking = ConvertTo-RangerHashtable -InputObject $network
                outliers   = ConvertTo-RangerHashtable -InputObject @($outliers | ForEach-Object { [ordered]@{ node = $_.node; cpuUtilizationPercent = $_.compute.cpuUtilizationPercent } })
                events     = ConvertTo-RangerHashtable -InputObject $events
                summary    = $summary
            }
        }
        Findings      = @($findings)
        Relationships = @($relationships)
        RawEvidence   = ConvertTo-RangerHashtable -InputObject $nodeSnapshots
    }
}