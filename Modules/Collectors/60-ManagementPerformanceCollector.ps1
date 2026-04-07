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

                # Third-party management agent discovery
                $thirdPartyPatterns = @('VeeamAgent*', 'VeeamBackup*', 'VeeamTransport*', 'CBAComm*', 'ZertoVSS*', 'ZertoService*',
                    'dattowin*', 'DattoBackup*', 'Rubrik*', 'DatadogAgent', 'datadogagent', 'splunkd*', 'SplunkForwarder*',
                    'prometheus*', 'node_exporter*', 'SolarWinds*', 'SolarwindsOrion*', 'CcmExec', 'IntuneManagementExtension',
                    'SCOM*', 'healthservice', 'omi*', 'OMSAgentForLinux')
                $thirdPartyAgents = @(foreach ($pattern in $thirdPartyPatterns) {
                    Get-Service -Name $pattern -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, Status, StartType
                })
                # Deduplicate on Name
                $agentNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                $thirdPartyAgents = @($thirdPartyAgents | Where-Object { $agentNames.Add($_.Name) })

                # WAC/Windows Admin Center TLS certificate and extensions
                $wacCert = $null
                $wacExtensions = @()
                $wacService = Get-Service -Name 'ServerManagementGateway' -ErrorAction SilentlyContinue
                if ($wacService) {
                    $wacCert = try {
                        $wacCertThumb = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\ServerManagementExperience' -Name 'SslCertificateThumbprint' -ErrorAction Stop).SslCertificateThumbprint
                        if ($wacCertThumb) {
                            $cert = Get-ChildItem -Path "Cert:\LocalMachine\" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $wacCertThumb } | Select-Object -First 1
                            if ($cert) {
                                [ordered]@{ thumbprint = $cert.Thumbprint; subject = $cert.Subject; notAfter = $cert.NotAfter; daysUntilExpiry = [math]::Round(($cert.NotAfter - [datetime]::UtcNow).TotalDays, 1) }
                            }
                        }
                    } catch { $null }
                    $wacPort = try { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\ServerManagementExperience' -Name 'SmePort' -ErrorAction Stop).SmePort } catch { 443 }
                    $wacExtensions = @(try {
                        $extPath = Join-Path $env:ProgramFiles 'Windows Admin Center\extensions'
                        if (Test-Path $extPath) {
                            Get-ChildItem -Path $extPath -Directory -ErrorAction SilentlyContinue | Select-Object Name, @{N='LastWriteTime';E={$_.LastWriteTime}}
                        }
                    } catch { @() })
                }

                # SCVMM agent depth (version, managed host state)
                $scvmmInfo = $null
                $scvmmAgentSvc = Get-Service -Name 'SCVMMAgent' -ErrorAction SilentlyContinue
                if ($scvmmAgentSvc) {
                    $scvmmInfo = try {
                        $vmmReg = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\VirtualMachineManager\Agent' -ErrorAction Stop
                        [ordered]@{ version = $vmmReg.Version; vmmServerName = $vmmReg.VMMServerName; machineId = $vmmReg.MachineId; agentStatus = [string]$scvmmAgentSvc.Status }
                    } catch { [ordered]@{ agentStatus = [string]$scvmmAgentSvc.Status } }
                }

                # SCOM agent depth (active alerts, management group)
                $scomInfo = $null
                $momAgentSvc = Get-Service -Name 'HealthService' -ErrorAction SilentlyContinue
                if ($momAgentSvc -and $momAgentSvc.DisplayName -match 'Operations Manager|SCOM') {
                    $scomInfo = try {
                        $scomReg = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup' -ErrorAction Stop
                        [ordered]@{ version = $scomReg.ServerVersion; agentStatus = [string]$momAgentSvc.Status }
                    } catch { [ordered]@{ agentStatus = [string]$momAgentSvc.Status } }
                }

                # Performance baseline
                $cpu = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
                $memory = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
                $disks = @(Get-CimInstance -ClassName Win32_PerfFormattedData_PerfDisk_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne '_Total' } | Select-Object Name, PercentFreeSpace, AvgDiskSecPerTransfer, DiskTransfersPerSec)
                $network = @(Get-CimInstance -ClassName Win32_PerfFormattedData_Tcpip_NetworkInterface -ErrorAction SilentlyContinue | Select-Object Name, BytesTotalPersec, CurrentBandwidth)

                # RDMA Activity counters
                $rdmaCounters = @(try {
                    Get-CimInstance -ClassName Win32_PerfFormattedData_RdmaCounterSet_RDMAActivity -ErrorAction Stop |
                        Select-Object -First 10 Name, RDMAInboundBytes, RDMAOutboundBytes, RDMAInboundFrames, RDMAOutboundFrames |
                        ForEach-Object { [ordered]@{ adapter = $_.Name; inboundBytes = $_.RDMAInboundBytes; outboundBytes = $_.RDMAOutboundBytes; inboundFrames = $_.RDMAInboundFrames; outboundFrames = $_.RDMAOutboundFrames } }
                } catch {
                    # Fallback: SMB Direct counters
                    @(try {
                        Get-CimInstance -ClassName Win32_PerfFormattedData_SmbClientShares_SMBClientShares -ErrorAction Stop |
                            Select-Object -First 5 Name, BytesReceivedPersec, BytesSentPersec |
                            ForEach-Object { [ordered]@{ adapter = $_.Name; inboundBytes = $_.BytesReceivedPersec; outboundBytes = $_.BytesSentPersec; inboundFrames = $null; outboundFrames = $null } }
                    } catch { @() })
                })

                # CSV cache hit statistics
                $csvCacheStats = @(try {
                    if (Get-Command -Name Get-ClusterSharedVolume -ErrorAction SilentlyContinue) {
                        Get-ClusterSharedVolume -ErrorAction SilentlyContinue | ForEach-Object {
                            $csv = $_
                            try {
                                $state = $csv | Get-ClusterSharedVolumeState -ErrorAction Stop
                                [ordered]@{ name = $csv.Name; ownerNode = $csv.OwnerNode.Name; volumeName = $state.VolumeFriendlyName; blockMode = $state.BlockRedirectedIOReason; fileMode = $state.FileSystemRedirectedIOReason }
                            } catch {
                                [ordered]@{ name = $csv.Name; ownerNode = $csv.OwnerNode.Name }
                            }
                        }
                    }
                } catch { @() })

                # Storage reliability counters (drive latency outliers)
                $driveLatencyOutliers = @(try {
                    if (Get-Command -Name Get-StorageReliabilityCounter -ErrorAction SilentlyContinue) {
                        Get-PhysicalDisk -ErrorAction Stop | ForEach-Object {
                            $disk = $_
                            $counter = $disk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
                            if ($counter -and ($counter.ReadLatencyMax -gt 1000 -or $counter.WriteLatencyMax -gt 1000)) {
                                [ordered]@{
                                    diskFriendlyName   = $disk.FriendlyName
                                    serialNumber       = $disk.SerialNumber
                                    readLatencyMaxMs   = $counter.ReadLatencyMax
                                    writeLatencyMaxMs  = $counter.WriteLatencyMax
                                    readLatencyAvgMs   = $counter.ReadLatencyAverage
                                    writeLatencyAvgMs  = $counter.WriteLatencyAverage
                                    temperature        = $counter.Temperature
                                    wearLevel          = $counter.Wear
                                }
                            }
                        } | Where-Object { $null -ne $_ }
                    }
                } catch { @() })

                # Multi-source event log analysis
                $eventLogAnalysis = @(foreach ($logName in @(
                    'Microsoft-Windows-Health/Operational',
                    'Microsoft-Windows-StorageSpaces-Driver/Operational',
                    'Microsoft-Windows-FailoverClustering/Operational',
                    'Microsoft-Windows-SDDC-Management/Operational'
                )) {
                    try {
                        $logEvents = @(Get-WinEvent -LogName $logName -MaxEvents 500 -ErrorAction Stop)
                        $topIds = @($logEvents | Group-Object -Property Id | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object {
                            $sample = $_.Group[0].Message
                            [ordered]@{ eventId = $_.Name; count = $_.Count; level = $_.Group[0].LevelDisplayName; sample = $sample.Substring(0, [Math]::Min(200, $sample.Length)) }
                        })
                        [ordered]@{ logName = $logName; eventCount = @($logEvents).Count; topEventIds = @($topIds) }
                    } catch {
                        [ordered]@{ logName = $logName; eventCount = 0; topEventIds = @() }
                    }
                })

                # System event log (kept for backward compat)
                $events = if (Get-Command -Name Get-WinEvent -ErrorAction SilentlyContinue) {
                    @(Get-WinEvent -LogName System -MaxEvents 15 -ErrorAction SilentlyContinue | Select-Object TimeCreated, Id, LevelDisplayName, ProviderName)
                } else { @() }

                [ordered]@{
                    node              = $env:COMPUTERNAME
                    tools             = @($managementServices)
                    thirdPartyAgents  = @($thirdPartyAgents)
                    wac               = [ordered]@{ installed = $null -ne $wacService; status = if ($wacService) { [string]$wacService.Status } else { 'not-installed' }; cert = $wacCert; extensionCount = @($wacExtensions).Count; extensions = @($wacExtensions) }
                    scvmm             = $scvmmInfo
                    scom              = $scomInfo
                    compute           = [ordered]@{
                        cpuUtilizationPercent = if ($cpu) { $cpu.PercentProcessorTime } else { $null }
                        availableMemoryMb     = if ($memory) { [math]::Round(($memory.FreePhysicalMemory / 1KB), 2) } else { $null }
                        totalMemoryMb         = if ($memory) { [math]::Round(($memory.TotalVisibleMemorySize / 1KB), 2) } else { $null }
                    }
                    storage           = @($disks)
                    networking        = @($network)
                    rdmaCounters      = @($rdmaCounters)
                    csvCacheStats     = @($csvCacheStats)
                    driveLatencyOutliers = @($driveLatencyOutliers)
                    eventLogAnalysis  = @($eventLogAnalysis)
                    events            = @($events)
                }
            }
        }
    )

    if ($nodeSnapshots.Count -eq 0) {
        throw 'Management and performance collector did not return any usable node data.'
    }

    $tools = @($nodeSnapshots | ForEach-Object { $_.tools } | Where-Object { $null -ne $_ })
    $allThirdPartyAgents = @($nodeSnapshots | ForEach-Object { $sn = $_; $_.thirdPartyAgents | ForEach-Object { [ordered]@{ node = $sn.node; name = $_.Name; displayName = $_.DisplayName; status = [string]$_.Status } } })
    $compute = @($nodeSnapshots | ForEach-Object { [ordered]@{ node = $_.node; metrics = $_.compute } })
    $storage = @($nodeSnapshots | ForEach-Object { [ordered]@{ node = $_.node; metrics = $_.storage } })
    $network = @($nodeSnapshots | ForEach-Object { [ordered]@{ node = $_.node; metrics = $_.networking } })
    $allRdmaCounters = @($nodeSnapshots | ForEach-Object { $sn = $_; $_.rdmaCounters | ForEach-Object { [ordered]@{ node = $sn.node; adapter = $_.adapter; inboundBytes = $_.inboundBytes; outboundBytes = $_.outboundBytes } } })
    $allDriveLatencyOutliers = @($nodeSnapshots | ForEach-Object { $sn = $_; $_.driveLatencyOutliers | ForEach-Object { $_ + [ordered]@{ node = $sn.node } } })
    $allEventLogAnalysis = @($nodeSnapshots | ForEach-Object { $sn = $_; $_.eventLogAnalysis | ForEach-Object { $_ + [ordered]@{ node = $sn.node } } })
    $outliers = @($nodeSnapshots | Where-Object { $_.compute.cpuUtilizationPercent -gt 85 })
    $events = @($nodeSnapshots | ForEach-Object { [ordered]@{ node = $_.node; values = $_.events } })
    $wacNodes = @($nodeSnapshots | ForEach-Object { [ordered]@{ node = $_.node; wac = $_.wac } })
    $scvmmNodes = @($nodeSnapshots | Where-Object { $null -ne $_.scvmm } | ForEach-Object { [ordered]@{ node = $_.node; scvmm = $_.scvmm } })
    $scomNodes = @($nodeSnapshots | Where-Object { $null -ne $_.scom } | ForEach-Object { [ordered]@{ node = $_.node; scom = $_.scom } })

    $relationships = New-Object System.Collections.ArrayList
    foreach ($snapshot in @($nodeSnapshots)) {
        foreach ($tool in @($snapshot.tools)) {
            [void]$relationships.Add((New-RangerRelationship -SourceType 'cluster-node' -SourceId $snapshot.node -TargetType 'management-tool' -TargetId $tool.Name -RelationshipType 'managed-by' -Properties ([ordered]@{ status = $tool.Status; displayName = $tool.DisplayName })))
        }
        foreach ($agent in @($snapshot.thirdPartyAgents)) {
            [void]$relationships.Add((New-RangerRelationship -SourceType 'cluster-node' -SourceId $snapshot.node -TargetType 'third-party-agent' -TargetId $agent.Name -RelationshipType 'monitored-by' -Properties ([ordered]@{ status = $agent.Status })))
        }
    }

    $wacInstalled = @($nodeSnapshots | Where-Object { $_.wac.installed }).Count
    $wacCertExpiring = @($nodeSnapshots | Where-Object { $null -ne $_.wac.cert -and $_.wac.cert.daysUntilExpiry -lt 90 }).Count

    $summary = [ordered]@{
        averageCpuUtilizationPercent = Get-RangerAverageValue -Values @($nodeSnapshots | ForEach-Object { $_.compute.cpuUtilizationPercent })
        averageAvailableMemoryMb     = Get-RangerAverageValue -Values @($nodeSnapshots | ForEach-Object { $_.compute.availableMemoryMb })
        runningManagementServices    = @($tools | Where-Object { $_.Status -eq 'Running' }).Count
        toolNames                    = @(Get-RangerGroupedCount -Items $tools -PropertyName 'Name')
        highCpuNodes                 = @($outliers).Count
        eventSeverities              = @(Get-RangerGroupedCount -Items @($nodeSnapshots | ForEach-Object { $_.events }) -PropertyName 'LevelDisplayName')
        wacInstalledNodes            = $wacInstalled
        wacCertExpiringNodes         = $wacCertExpiring
        scvmmAgentNodes              = @($scvmmNodes).Count
        scomAgentNodes               = @($scomNodes).Count
        thirdPartyAgentTypes         = @(Get-RangerGroupedCount -Items $allThirdPartyAgents -PropertyName 'name')
        rdmaAdaptersDetected         = @($allRdmaCounters).Count
        driveLatencyOutlierCount     = @($allDriveLatencyOutliers).Count
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

    if ($wacCertExpiring -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Windows Admin Center TLS certificate is expiring within 90 days' -Description "WAC certificate inventory found $wacCertExpiring node(s) with a WAC SSL certificate expiring within 90 days." -CurrentState "$wacCertExpiring nodes with expiring WAC certificate" -Recommendation 'Renew the WAC TLS certificate before handoff to avoid browser-side security warnings for operational users.'))
    }

    if (@($allDriveLatencyOutliers).Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Drive latency outliers detected via Storage Reliability Counters' -Description "Performance baselines found $(@($allDriveLatencyOutliers).Count) physical disk(s) with maximum read or write latency above 1000 ms." -AffectedComponents (@($allDriveLatencyOutliers | ForEach-Object { "$($_.node) - $($_.diskFriendlyName)" })) -CurrentState "$(@($allDriveLatencyOutliers).Count) disks with high latency" -Recommendation 'Review drive health and predictive failure indicators. Replace any disks with sustained high latency or elevated wear levels before handoff.'))
    }

    return @{
        Status        = if ($findings.Count -gt 0) { 'partial' } else { 'success' }
        Domains       = @{
            managementTools = [ordered]@{
                tools           = ConvertTo-RangerHashtable -InputObject @($tools)
                agents          = ConvertTo-RangerHashtable -InputObject @($tools | Where-Object { $_.Status -eq 'Running' })
                thirdPartyAgents = ConvertTo-RangerHashtable -InputObject $allThirdPartyAgents
                wac             = ConvertTo-RangerHashtable -InputObject $wacNodes
                scvmm           = ConvertTo-RangerHashtable -InputObject $scvmmNodes
                scom            = ConvertTo-RangerHashtable -InputObject $scomNodes
                summary         = [ordered]@{
                    totalServices    = @($tools).Count
                    runningServices  = @($tools | Where-Object { $_.Status -eq 'Running' }).Count
                    serviceNames     = $summary.toolNames
                    wacInstalled     = $wacInstalled
                    scvmmNodes       = $summary.scvmmAgentNodes
                    scomNodes        = $summary.scomAgentNodes
                    thirdPartyTypes  = $summary.thirdPartyAgentTypes
                }
            }
            performance = [ordered]@{
                nodes                = ConvertTo-RangerHashtable -InputObject @($nodeSnapshots | ForEach-Object { $_.node })
                compute              = ConvertTo-RangerHashtable -InputObject $compute
                storage              = ConvertTo-RangerHashtable -InputObject $storage
                networking           = ConvertTo-RangerHashtable -InputObject $network
                rdmaCounters         = ConvertTo-RangerHashtable -InputObject $allRdmaCounters
                csvCacheStats        = ConvertTo-RangerHashtable -InputObject @($nodeSnapshots | ForEach-Object { $sn = $_; $_.csvCacheStats | ForEach-Object { $_ + [ordered]@{ node = $sn.node } } })
                driveLatencyOutliers = ConvertTo-RangerHashtable -InputObject $allDriveLatencyOutliers
                eventLogAnalysis     = ConvertTo-RangerHashtable -InputObject $allEventLogAnalysis
                outliers             = ConvertTo-RangerHashtable -InputObject @($outliers | ForEach-Object { [ordered]@{ node = $_.node; cpuUtilizationPercent = $_.compute.cpuUtilizationPercent } })
                events               = ConvertTo-RangerHashtable -InputObject $events
                summary              = $summary
            }
        }
        Findings      = @($findings)
        Relationships = @($relationships)
        RawEvidence   = ConvertTo-RangerHashtable -InputObject $nodeSnapshots
    }
}