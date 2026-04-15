function Get-RangerCollectorPropertyValue {
    param(
        $InputObject,

        [string[]]$CandidateNames
    )

    if ($null -eq $InputObject) {
        return $null
    }

    foreach ($name in @($CandidateNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        if ($InputObject -is [System.Collections.IDictionary] -and $InputObject.Contains($name)) {
            return $InputObject[$name]
        }

        $property = $InputObject.PSObject.Properties[$name]
        if ($property) {
            return $property.Value
        }
    }

    return $null
}

function Test-RangerIpAddressString {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    $parsed = $null
    return [System.Net.IPAddress]::TryParse($Value, [ref]$parsed)
}

function Get-RangerArcNetworkProfileAddresses {
    param(
        $NetworkProfile
    )

    if ($null -eq $NetworkProfile) {
        return @()
    }

    $interfaceSets = @()
    foreach ($candidateName in @('networkInterfaces', 'NetworkInterfaces', 'networkInterface', 'NetworkInterface', 'interfaces', 'Interfaces')) {
        $candidateValue = Get-RangerCollectorPropertyValue -InputObject $NetworkProfile -CandidateNames @($candidateName)
        if ($null -ne $candidateValue) {
            $interfaceSets = @($candidateValue)
            break
        }
    }

    if (@($interfaceSets).Count -eq 0 -and $NetworkProfile -is [System.Collections.IEnumerable] -and $NetworkProfile -isnot [string]) {
        $interfaceSets = @($NetworkProfile)
    }

    $ipAddresses = New-Object System.Collections.ArrayList
    foreach ($networkInterface in @($interfaceSets)) {
        foreach ($addressProperty in @('ipAddresses', 'IPAddresses', 'ipv4Addresses', 'IPv4Addresses', 'ipv6Addresses', 'IPv6Addresses', 'addresses', 'Addresses')) {
            $rawValues = Get-RangerCollectorPropertyValue -InputObject $networkInterface -CandidateNames @($addressProperty)
            foreach ($value in @($rawValues)) {
                if ($value -is [string]) {
                    if (Test-RangerIpAddressString -Value $value) {
                        [void]$ipAddresses.Add($value)
                    }
                    continue
                }

                $candidateIp = Get-RangerCollectorPropertyValue -InputObject $value -CandidateNames @('address', 'ipAddress', 'IPAddress', 'privateIpAddress', 'privateIPAddress')
                if (Test-RangerIpAddressString -Value ([string]$candidateIp)) {
                    [void]$ipAddresses.Add([string]$candidateIp)
                }
            }
        }
    }

    return @($ipAddresses | Where-Object { Test-RangerIpAddressString -Value ([string]$_) } | Select-Object -Unique)
}

function Get-RangerVmHyperVIpAddresses {
    param(
        $VirtualMachine
    )

    $ipAddresses = New-Object System.Collections.ArrayList
    foreach ($nic in @(Get-RangerCollectorPropertyValue -InputObject $VirtualMachine -CandidateNames @('nicDetail'))) {
        foreach ($value in @(Get-RangerCollectorPropertyValue -InputObject $nic -CandidateNames @('ipAddresses', 'IPAddresses'))) {
            if (Test-RangerIpAddressString -Value ([string]$value)) {
                [void]$ipAddresses.Add([string]$value)
            }
        }
    }

    return @($ipAddresses | Select-Object -Unique)
}

function Resolve-RangerEsuOsEligibility {
    param(
        [string]$OsName,

        [string]$OsVersion
    )

    $normalizedName = if ($OsName) { $OsName.ToLowerInvariant() } else { '' }
    $normalizedVersion = if ($OsVersion) { $OsVersion.ToLowerInvariant() } else { '' }
    $detectedOs = $null
    $isEligible = $false

    if ($normalizedName -match '2012\s*r2') {
        $detectedOs = 'Windows Server 2012 R2'
        $isEligible = $true
    }
    elseif ($normalizedName -match '2012') {
        $detectedOs = 'Windows Server 2012'
        $isEligible = $true
    }
    elseif ($normalizedName -match '2016') {
        $detectedOs = 'Windows Server 2016'
        $isEligible = $true
    }
    elseif ($normalizedName -match '2019') {
        $detectedOs = 'Windows Server 2019'
        $isEligible = $true
    }
    elseif ($normalizedVersion -match '^6\.2') {
        $detectedOs = 'Windows Server 2012'
        $isEligible = $true
    }
    elseif ($normalizedVersion -match '^6\.3') {
        $detectedOs = 'Windows Server 2012 R2'
        $isEligible = $true
    }
    elseif ($normalizedVersion -match '^10\.0\.14393') {
        $detectedOs = 'Windows Server 2016'
        $isEligible = $true
    }
    elseif ($normalizedVersion -match '^10\.0\.17763') {
        $detectedOs = 'Windows Server 2019'
        $isEligible = $true
    }
    elseif ($normalizedName -match '2022' -or $normalizedVersion -match '^10\.0\.20348') {
        $detectedOs = 'Windows Server 2022'
        $isEligible = $false
    }

    [ordered]@{
        detectedOs = $detectedOs
        isEligible = $isEligible
    }
}

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

    # Issue #111: auto-detect domain context before running AD queries
    $arcResource  = Resolve-RangerClusterArcResource -Config $Config
    $domainCtx    = Resolve-RangerDomainContext -Config $Config -ArcResource $arcResource -ClusterCredential $CredentialMap.cluster
    $domainFqdn   = if ($domainCtx.FQDN) { [string]$domainCtx.FQDN } else { '' }
    $isWorkgroup  = [bool]$domainCtx.IsWorkgroup
    Write-RangerLog -Level info -Message "WorkloadIdentityCollector: domain context — FQDN='$domainFqdn', source='$($domainCtx.ResolvedBy)', workgroup=$isWorkgroup"

    $vmSnapshots = @(
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
                    $integrationServices = if (Get-Command -Name Get-VMIntegrationService -ErrorAction SilentlyContinue) { Get-VMIntegrationService -VMName $vm.Name -ErrorAction SilentlyContinue | Select-Object Name, Enabled, PrimaryStatusDescription, SecondaryStatusDescription } else { @() }
                    $checkpoints = if (Get-Command -Name Get-VMCheckpoint -ErrorAction SilentlyContinue) {
                        @(Get-VMCheckpoint -VMName $vm.Name -ErrorAction SilentlyContinue | Select-Object Name, CheckpointType, CreationTime, Id, ParentCheckpointId | ForEach-Object {
                            [ordered]@{ name = $_.Name; checkpointType = [string]$_.CheckpointType; creationTime = $_.CreationTime; id = $_.Id; parentId = $_.ParentCheckpointId }
                        })
                    } else { @() }
                    $nicsAdvanced = if (Get-Command -Name Get-VMNetworkAdapter -ErrorAction SilentlyContinue) {
                        @(Get-VMNetworkAdapter -VMName $vm.Name -ErrorAction SilentlyContinue | ForEach-Object {
                            $nic = $_
                            $sriov = if (Get-Command -Name Get-VMNetworkAdapterSRIOV -ErrorAction SilentlyContinue) { try { Get-VMNetworkAdapterSRIOV -VMNetworkAdapter $nic -ErrorAction Stop | Select-Object SriovEnabled, SRIOVWeight } catch { $null } } else { $null }
                            $rdma = if (Get-Command -Name Get-VMNetworkAdapterRdma -ErrorAction SilentlyContinue) { try { Get-VMNetworkAdapterRdma -VMNetworkAdapter $nic -ErrorAction Stop | Select-Object RdmaWeight } catch { $null } } else { $null }
                            $bw = if (Get-Command -Name Get-VMNetworkAdapterBandwidth -ErrorAction SilentlyContinue) { try { Get-VMNetworkAdapterBandwidth -VMNetworkAdapter $nic -ErrorAction Stop | Select-Object MinimumBandwidthAbsolute, MaximumBandwidth } catch { $null } } else { $null }
                            $iso = if (Get-Command -Name Get-VMNetworkAdapterIsolation -ErrorAction SilentlyContinue) { try { Get-VMNetworkAdapterIsolation -VMNetworkAdapter $nic -ErrorAction Stop | Select-Object IsolationMode, DefaultIsolationID } catch { $null } } else { $null }
                            [ordered]@{
                                name            = $nic.Name
                                switchName      = $nic.SwitchName
                                macAddress      = $nic.MacAddress
                                sriovEnabled    = if ($sriov) { $sriov.SriovEnabled } else { $null }
                                sriovWeight     = if ($sriov) { $sriov.SRIOVWeight } else { $null }
                                rdmaWeight      = if ($rdma) { $rdma.RdmaWeight } else { $null }
                                maxBandwidthMbps = if ($bw -and $bw.MaximumBandwidth) { [math]::Round($bw.MaximumBandwidth / 1MB, 0) } else { $null }
                                isolationMode   = if ($iso) { [string]$iso.IsolationMode } else { $null }
                            }
                        })
                    } else { @() }
                    # Shared VHDX detection for guest cluster heuristic
                    $hasSharedVhdx = @($drives | Where-Object { $_.SupportPersistentReservations -or $_.Path -match '\bshared\b' }).Count -gt 0

                    # Issue #62: Per-disk detail with VHD metadata
                    $diskDetail = @($drives | ForEach-Object {
                        $d = $_
                        $vhd = if ($d.Path) { try { Get-VHD -Path $d.Path -ErrorAction Stop } catch { $null } } else { $null }
                        [ordered]@{
                            controllerType     = [string]$d.ControllerType
                            controllerNumber   = $d.ControllerNumber
                            controllerLocation = $d.ControllerLocation
                            path               = $d.Path
                            vhdFormat          = if ($vhd) { [string]$vhd.VhdFormat } else { $null }
                            vhdType            = if ($vhd) { [string]$vhd.VhdType } else { $null }
                            currentSizeGiB     = if ($vhd) { [math]::Round($vhd.FileSize / 1GB, 2) } else { $null }
                            maxSizeGiB         = if ($vhd) { [math]::Round($vhd.Size / 1GB, 2) } else { $null }
                            parentPath         = if ($vhd) { $vhd.ParentPath } else { $null }
                        }
                    })
                    # Issue #62: Per-NIC detail with VLAN, security guards, spoofing
                    $nicDetail = @($adapters | ForEach-Object {
                        $nic = $_
                        $vlan = if (Get-Command -Name Get-VMNetworkAdapterVlan -ErrorAction SilentlyContinue) { try { Get-VMNetworkAdapterVlan -VMNetworkAdapter $nic -ErrorAction Stop } catch { $null } } else { $null }
                        [ordered]@{
                            name               = $nic.Name
                            switchName         = $nic.SwitchName
                            macAddress         = $nic.MacAddress
                            macAddressType     = [string]$nic.MacAddressType
                            ipAddresses        = @($nic.IPAddresses)
                            vlanId             = if ($vlan) { $vlan.AccessVlanId } else { $null }
                            dhcpGuard          = [string]$nic.DhcpGuard
                            routerGuard        = [string]$nic.RouterGuard
                            macAddressSpoofing = [string]$nic.MacAddressSpoofing
                            portMirroring      = [string]$nic.PortMirroringMode
                            deviceNaming       = $nic.DeviceNaming
                        }
                    })
                    # Issue #62: Cluster placement (preferred owners, anti-affinity, failover policy)
                    $clusterGroup = if ((Get-Command -Name Get-ClusterGroup -ErrorAction SilentlyContinue) -and $vm.IsClustered) {
                        try { Get-ClusterGroup -Name "Virtual Machine $($vm.Name)" -ErrorAction Stop } catch { $null }
                    } else { $null }
                    $vmPlacement = [ordered]@{
                        preferredOwners    = if ($clusterGroup) { @($clusterGroup.PreferredOwners) } else { @() }
                        antiAffinityGroups = if ($clusterGroup) { @($clusterGroup.AntiAffinityClassNames) } else { @() }
                        clusterRoleName    = if ($clusterGroup) { $clusterGroup.Name } else { $null }
                        clusterRoleState   = if ($clusterGroup) { [string]$clusterGroup.State } else { $null }
                        failoverThreshold  = if ($clusterGroup) { $clusterGroup.FailoverThreshold } else { $null }
                    }

                    [ordered]@{
                        name              = $vm.Name
                        hostNode          = $env:COMPUTERNAME
                        state             = $vm.State.ToString()
                        uptime            = $vm.Uptime
                        isClustered       = [bool]$vm.IsClustered
                        generation        = $vm.Generation
                        processorCount    = $vm.ProcessorCount
                        memoryAssignedMb  = [math]::Round(($vm.MemoryAssigned / 1MB), 2)
                        dynamicMemory     = [bool]$vm.DynamicMemoryEnabled
                        checkpointType    = $vm.CheckpointType
                        diskCount         = @($drives).Count
                        networkAdapterCount = @($adapters).Count
                        storagePaths      = @($drives | ForEach-Object { $_.Path })
                        switchNames       = @($adapters | ForEach-Object { $_.SwitchName })
                        replicationMode   = if ($replication) { $replication.ReplicationMode } else { $null }
                        replicationHealth = if ($replication) { $replication.Health } else { $null }
                        integrationServices = @($integrationServices)
                        integrationServiceSummary = [ordered]@{ total = @($integrationServices).Count; enabled = @($integrationServices | Where-Object { $_.Enabled }).Count }
                        checkpoints       = @($checkpoints)
                        checkpointCount   = @($checkpoints).Count
                        nicsAdvanced      = @($nicsAdvanced)
                        guestClusterCandidate = $hasSharedVhdx
                        vmId                = [string]$vm.Id
                        creationTime        = $vm.CreationTime
                        configVersion       = $vm.Version
                        notes               = $vm.Notes
                        automaticStartAction = [string]$vm.AutomaticStartAction
                        automaticStartDelay  = $vm.AutomaticStartDelay
                        automaticStopAction  = [string]$vm.AutomaticStopAction
                        memoryStartupMb     = [math]::Round($vm.MemoryStartup / 1MB, 0)
                        memoryMinimumMb     = [math]::Round($vm.MemoryMinimum / 1MB, 0)
                        memoryMaximumMb     = [math]::Round($vm.MemoryMaximum / 1MB, 0)
                        memoryDemandMb      = [math]::Round($vm.MemoryDemand / 1MB, 0)
                        diskDetail          = @($diskDetail)
                        nicDetail           = @($nicDetail)
                        placement           = $vmPlacement
                    }
                }
            }
        }
    )

    $vmInventory = @($vmSnapshots)

    $keyVaultReferences = @(
        $Config.credentials.cluster.passwordRef,
        $Config.credentials.domain.passwordRef,
        $Config.credentials.bmc.passwordRef,
        $Config.credentials.azure.clientSecretRef
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    $identitySnapshots = @(
        Invoke-RangerSafeAction -Label 'Identity and security snapshot' -DefaultValue @() -ScriptBlock {
            Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -ArgumentList @($domainFqdn, $isWorkgroup) -ScriptBlock {
                param($resolvedDomainFqdn, $resolvedIsWorkgroup)

                $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
                $defender = if (Get-Command -Name Get-MpComputerStatus -ErrorAction SilentlyContinue) { Get-MpComputerStatus | Select-Object AMRunningMode, AntispywareEnabled, AntivirusEnabled, RealTimeProtectionEnabled, IsTamperProtected, AntivirusSignatureVersion, AntivirusSignatureLastUpdated, AMProductVersion } else { $null }
                $defenderExclusions = if (Get-Command -Name Get-MpPreference -ErrorAction SilentlyContinue) {
                    try {
                        $pref = Get-MpPreference -ErrorAction Stop
                        [ordered]@{ paths = @($pref.ExclusionPath); processes = @($pref.ExclusionProcess); extensions = @($pref.ExclusionExtension) }
                    } catch { $null }
                }
                $bitlocker = if (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue) { Get-BitLockerVolume | Select-Object MountPoint, ProtectionStatus, EncryptionMethod, VolumeStatus } else { @() }
                $bitlockerProtectors = if (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue) {
                    @(Get-BitLockerVolume -ErrorAction SilentlyContinue | ForEach-Object {
                        $vol = $_
                        [ordered]@{
                            mountPoint       = $vol.MountPoint
                            protectionStatus = [string]$vol.ProtectionStatus
                            encryptionMethod = [string]$vol.EncryptionMethod
                            protectorTypes   = @($vol.KeyProtector | ForEach-Object { [string]$_.KeyProtectorType })
                            hasTpm           = [bool](@($vol.KeyProtector | Where-Object { [string]$_.KeyProtectorType -in @('Tpm', 'TpmPin', 'TpmStartupKey', 'TpmPinStartupKey') }).Count -gt 0)
                            hasRecovery      = [bool](@($vol.KeyProtector | Where-Object { [string]$_.KeyProtectorType -eq 'RecoveryPassword' }).Count -gt 0)
                            hasAdBackup      = [bool](@($vol.KeyProtector | Where-Object { [string]$_.KeyProtectorType -match 'AD' }).Count -gt 0)
                        }
                    })
                } else { @() }
                $localAdmins = try { Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop | Select-Object Name, ObjectClass, PrincipalSource } catch { @() }
                $adminUser  = Get-LocalUser -Name 'Administrator' -ErrorAction SilentlyContinue
                $guestUser  = Get-LocalUser -Name 'Guest'         -ErrorAction SilentlyContinue
                $localAdminDetail = [ordered]@{
                    members                = @($localAdmins)
                    administratorEnabled   = if ($adminUser) { [bool]$adminUser.Enabled } else { $null }
                    administratorLastLogon = if ($adminUser) { $adminUser.LastLogon }     else { $null }
                    guestEnabled           = if ($guestUser) { [bool]$guestUser.Enabled } else { $null }
                }
                $certificates = Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction SilentlyContinue | Select-Object Subject, Thumbprint, NotAfter
                $deviceGuard = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
                $wdacInfo = if ($deviceGuard) {
                    [ordered]@{
                        codeIntegrityPolicyEnforcementStatus = $deviceGuard.CodeIntegrityPolicyEnforcementStatus
                        usermodeCodeIntegrityPolicyEnforcementStatus = $deviceGuard.UsermodeCodeIntegrityPolicyEnforcementStatus
                        wdacConfigured = ($deviceGuard.CodeIntegrityPolicyEnforcementStatus -gt 0)
                        enforcementMode = switch ($deviceGuard.CodeIntegrityPolicyEnforcementStatus) { 1 { 'Audit' } 2 { 'Enforced' } default { 'None' } }
                        securityServicesRunning = @($deviceGuard.SecurityServicesRunning)
                    }
                } else { [ordered]@{ wdacConfigured = $false; enforcementMode = 'not-assessed' } }
                # Issue #111: use explicit -Server to target the cluster's DC, not the Ranger host's domain
                $adServerParam = if (-not [string]::IsNullOrWhiteSpace($resolvedDomainFqdn)) { @{ Server = $resolvedDomainFqdn } } else { @{} }
                $adDomain = if (-not $resolvedIsWorkgroup -and (Get-Command -Name Get-ADDomain -ErrorAction SilentlyContinue)) {
                    try { Get-ADDomain @adServerParam -ErrorAction Stop | Select-Object DNSRoot, NetBIOSName, DomainMode, DistinguishedName, ParentDomain } catch { $null }
                } else { $null }
                $adForest = if (-not $resolvedIsWorkgroup -and (Get-Command -Name Get-ADForest -ErrorAction SilentlyContinue)) {
                    try { Get-ADForest @adServerParam -ErrorAction Stop | Select-Object Name, ForestMode, RootDomain, Domains } catch { $null }
                } else { $null }
                $appLocker = if (Get-Command -Name Get-AppLockerPolicy -ErrorAction SilentlyContinue) { try { Get-AppLockerPolicy -Effective -ErrorAction Stop | Select-Object -ExpandProperty RuleCollections | ForEach-Object { $_.CollectionType } } catch { @() } } else { @() }
                $secureBoot = try { Confirm-SecureBootUEFI -ErrorAction Stop } catch { $null }
                $credSsp = (Get-Item -Path WSMan:\localhost\Service\Auth\CredSSP -ErrorAction SilentlyContinue).Value
                # Structured audit policy via auditpol CSV output
                $auditPolicy = try {
                    $auditRaw = (auditpol.exe /get /category:* /r 2>$null)
                    if ($auditRaw) {
                        $auditLines = $auditRaw | ConvertFrom-Csv -ErrorAction Stop
                        @($auditLines | Where-Object { $_.Subcategory } | Select-Object -First 60 | ForEach-Object {
                            [ordered]@{ category = $_.'Category/Subcategory'; subcategory = $_.Subcategory; setting = $_.'Inclusion Setting' }
                        })
                    } else { @() }
                } catch {
                    @(try { (auditpol.exe /get /category:* 2>$null | Select-Object -First 20) } catch { @() })
                }
                # Entra / Azure AD hybrid join status
                $entraJoinStatus = try {
                    $dsregOutput = (& dsregcmd.exe /status 2>$null | Out-String)
                    $hybridJoined = $dsregOutput -match 'HybridAzureADJoined\s*:\s*YES'
                    $entraJoined = $dsregOutput -match 'AzureAdJoined\s*:\s*YES'
                    $domainJoined = $dsregOutput -match 'DomainJoined\s*:\s*YES'
                    [ordered]@{
                        azureAdJoined      = $entraJoined
                        hybridAzureAdJoined = $hybridJoined
                        domainJoined       = $domainJoined
                        tenantId           = if ($dsregOutput -match 'TenantId\s*:\s*([a-f0-9-]{36})') { $Matches[1] } else { $null }
                    }
                } catch { $null }
                # AADKERB configured detection
                $aadkerbConfigured = try {
                    $null -ne (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters' -Name 'CloudKerberosTicketRetrievalEnabled' -ErrorAction Stop)
                } catch { $false }

                # Issue #64: AD object depth (CNO, AD site)
                $clusterName = if (Get-Command -Name Get-Cluster -ErrorAction SilentlyContinue) { try { (Get-Cluster -ErrorAction Stop).Name } catch { $null } } else { $null }
                $adObjects = if (-not $resolvedIsWorkgroup -and $clusterName -and (Get-Command -Name Get-ADComputer -ErrorAction SilentlyContinue)) {
                    try {
                        $cno = Get-ADComputer -Identity $clusterName @adServerParam -Properties DistinguishedName, ServicePrincipalNames, Enabled -ErrorAction Stop
                        [ordered]@{
                            cnoName              = $cno.Name
                            cnoDistinguishedName = $cno.DistinguishedName
                            cnoSpns              = @($cno.ServicePrincipalNames)
                            cnoEnabled           = [bool]$cno.Enabled
                        }
                    } catch { $null }
                } else { $null }
                $adSite = try { [System.DirectoryServices.ActiveDirectory.ActiveDirectorySite]::GetComputerSite().Name } catch { $null }
                # Issue #64: Secured-Core / DRTM / SystemGuard registry check
                $sgEnabled = try { $sgKey = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SystemGuard' -Name 'Enabled' -ErrorAction Stop; $sgKey.Enabled -eq 1 } catch { $false }
                $drtmCapable = try { $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace 'root\Microsoft\Windows\DeviceGuard' -ErrorAction Stop; @($dg.AvailableSecurityProperties) -contains 128 } catch { $false }
                $securedCoreDetail = [ordered]@{
                    systemGuardEnabled = $sgEnabled
                    drtmCapable        = $drtmCapable
                }
                # Issue #64: Syslog and WEF subscription detection
                $syslogDetail = [ordered]@{
                    wefSubscriptions = @(try {
                        Get-WinEvent -ListLog 'ForwardedEvents' -ErrorAction Stop | Select-Object LogName, LogMode, RecordCount | ForEach-Object {
                            [ordered]@{ logName = $_.LogName; mode = [string]$_.LogMode; recordCount = $_.RecordCount }
                        }
                    } catch { @() })
                    syslogAgents = @(
                        @('rsyslog', 'nxlog', 'syslog-ng', 'Microsoft-Geneva-MonitoringAgent', 'AzureMonitorAgent') | ForEach-Object {
                            $svc = Get-Service -Name $_ -ErrorAction SilentlyContinue
                            if ($svc) { [ordered]@{ name = $svc.Name; status = [string]$svc.Status; startType = [string]$svc.StartType } }
                        } | Where-Object { $_ }
                    )
                }
                # Issue #64: Drift control markers (HCI registration registry keys)
                $hciRegStatus = try { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\AzureStack\AzureStackHCI' -ErrorAction Stop).RegistrationStatus } catch { $null }
                $hciConnStatus = try { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\AzureStack\AzureStackHCI' -ErrorAction Stop).ConnectionStatus } catch { $null }
                $driftControl = [ordered]@{
                    hciRegistrationStatus = $hciRegStatus
                    hciConnectionStatus   = $hciConnStatus
                }

                # Cluster service account model (LocalSystem, gMSA, domain account)
                $clusterSvc = try { Get-CimInstance -ClassName Win32_Service -Filter "Name='ClusSvc'" -ErrorAction Stop } catch { $null }
                $clusterServiceAccountModel = if ($clusterSvc) {
                    if ($clusterSvc.StartName -match '\$$') { 'gMSA' }
                    elseif ($clusterSvc.StartName -eq 'LocalSystem') { 'LocalSystem' }
                    elseif ($clusterSvc.StartName) { 'DomainServiceAccount' }
                    else { $null }
                } else { $null }

                # Physical core count per node for billing aggregation
                $physicalCoreCount = try { (Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Measure-Object -Property NumberOfCores -Sum).Sum } catch { $null }

                # Internal certificate/secret auto-rotation state (if retrievable from HCI registry)
                $rotAutoEnabled = try {
                    $rotVal = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\AzureStack\AzureStackHCI' -Name 'CertRotationEnabled' -ErrorAction Stop).CertRotationEnabled
                    [bool]$rotVal
                } catch { $null }
                $rotLastTime = try {
                    (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\AzureStack\AzureStackHCI' -Name 'LastCertRotationTime' -ErrorAction Stop).LastCertRotationTime
                } catch { $null }
                $secretRotationState = [ordered]@{
                    autoRotationEnabled = $rotAutoEnabled
                    lastRotationTime    = $rotLastTime
                }

                [ordered]@{
                    node               = $env:COMPUTERNAME
                    partOfDomain       = [bool]$computerSystem.PartOfDomain
                    domain             = $computerSystem.Domain
                    localAdmins        = @($localAdmins)
                    localAdminDetail   = $localAdminDetail
                    certificates       = @($certificates)
                    bitlocker          = @($bitlocker)
                    bitlockerProtectors = @($bitlockerProtectors)
                    defender           = $defender
                    defenderExclusions = $defenderExclusions
                    deviceGuard        = $deviceGuard
                    wdacInfo           = $wdacInfo
                    adDomain           = $adDomain
                    adForest           = $adForest
                    appLocker          = @($appLocker)
                    secureBoot         = $secureBoot
                    credSsp            = $credSsp
                    auditPolicy        = @($auditPolicy)
                    entraJoinStatus    = $entraJoinStatus
                    aadkerbConfigured  = $aadkerbConfigured
                    adObjects          = $adObjects
                    adSite             = $adSite
                    securedCoreDetail  = $securedCoreDetail
                    syslogDetail       = $syslogDetail
                    driftControl       = $driftControl
                    clusterServiceAccountModel = $clusterServiceAccountModel
                    physicalCoreCount          = $physicalCoreCount
                    secretRotationState        = $secretRotationState
                }
            }
        }
    )

    $azureResources = @(
        Get-RangerAzureResources -Config $Config -AzureCredentialSettings $CredentialMap.azure
    )

    $policyAssignments = @(
        Invoke-RangerSafeAction -Label 'Azure policy assignment snapshot' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)

                if (-not (Get-Command -Name Get-AzPolicyAssignment -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($SubscriptionId) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) {
                    return @()
                }

                $scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup"
                Get-AzPolicyAssignment -Scope $scope -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, Scope, EnforcementMode, PolicyDefinitionId, Description
            }
        }
    )

    # ARB appliance detail (k8s version, infra config, health)
    $arbDetail = @(
        Invoke-RangerSafeAction -Label 'ARB appliance detail' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzResourceBridgeAppliance -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                Get-AzResourceBridgeAppliance -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue |
                    Select-Object Name, Status, KubernetesVersion, InfrastructureConfigProvider, DistroVersion, @{N='Identity';E={$_.Identity.Type}}
            }
        }
    )

    # AKS clusters on Arc
    $aksClusters = @(
        Invoke-RangerSafeAction -Label 'AKS Arc cluster inventory' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzAksCluster -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                $clusters = @(Get-AzAksCluster -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue)
                $aksResult = New-Object System.Collections.ArrayList
                foreach ($c in $clusters) {
                    $nodePools = @(try { Get-AzAksNodePool -ResourceGroupName $ResourceGroup -ClusterName $c.Name -ErrorAction Stop | Select-Object Name, Count, VmSize, OsType, Mode, ProvisioningState } catch { @() })
                    $aksExts = @(try { Get-AzResource -ResourceGroupName $c.NodeResourceGroup -ResourceType 'Microsoft.KubernetesConfiguration/extensions' -ErrorAction Stop | Select-Object Name, Location } catch { @() })
                    [void]$aksResult.Add([ordered]@{
                        name              = $c.Name
                        kubernetesVersion = $c.KubernetesVersion
                        provisioningState = $c.ProvisioningState
                        powerState        = if ($c.PowerState) { [string]$c.PowerState.Code } else { $null }
                        nodeResourceGroup = $c.NodeResourceGroup
                        enableRbac        = $c.EnableRBAC
                        location          = $c.Location
                        nodePoolCount     = @($nodePools).Count
                        nodePools         = @($nodePools | ForEach-Object { [ordered]@{ name = $_.Name; count = $_.Count; vmSize = $_.VmSize; osType = [string]$_.OsType; mode = [string]$_.Mode; provisioningState = $_.ProvisioningState } })
                        networkPlugin     = if ($c.NetworkProfile) { [string]$c.NetworkProfile.NetworkPlugin } else { $null }
                        networkPolicy     = if ($c.NetworkProfile) { [string]$c.NetworkProfile.NetworkPolicy } else { $null }
                        extensionCount    = @($aksExts).Count
                    })
                }
                @($aksResult)
            }
        }
    )

    # Azure Policy compliance states
    $policyComplianceStates = @(
        Invoke-RangerSafeAction -Label 'Azure Policy compliance state' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzPolicyState -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                Get-AzPolicyState -ResourceGroupName $ResourceGroup -Top 200 -ErrorAction SilentlyContinue |
                    Select-Object PolicyDefinitionName, PolicyDefinitionAction, ComplianceState, ResourceType, ResourceLocation, PolicySetDefinitionName
            }
        }
    )

    # Azure Site Recovery / ASR replicated items
    $vaults = @($azureResources | Where-Object { $_.ResourceType -match 'Microsoft.RecoveryServices/vaults' })
    $asrItems = @(
        Invoke-RangerSafeAction -Label 'ASR replicated item inventory' -DefaultValue @() -ScriptBlock {
            if ($vaults.Count -eq 0) { return @() }
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzRecoveryServicesVault -ErrorAction SilentlyContinue)) { return @() }
                $vaultList = @(Get-AzRecoveryServicesVault -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue)
                $items = New-Object System.Collections.ArrayList
                foreach ($vault in $vaultList) {
                    $ctx = Set-AzRecoveryServicesVaultContext -Vault $vault -ErrorAction SilentlyContinue
                    $replicated = @(Get-AzRecoveryServicesAsrReplicationProtectedItem -ErrorAction SilentlyContinue)
                    foreach ($item in $replicated) {
                        [void]$items.Add([ordered]@{
                            vaultName                  = $vault.Name
                            vmName                     = $item.FriendlyName
                            protectionState            = $item.ProtectionState
                            replicationHealth          = $item.ReplicationHealth
                            testFailoverState          = [string]$item.TestFailoverState
                            lastRpo                    = $item.LastSuccessfulFailoverTime
                            lastRpoCalculated          = $item.LastRpoCalculatedTime
                            lastSuccessfulTestFailover = $item.LastSuccessfulTestFailoverTime
                        })
                    }
                    # Issue #72: Recovery plans per vault
                    $plans = @(try { Get-AzRecoveryServicesAsrRecoveryPlan -ErrorAction SilentlyContinue | Select-Object Name, FriendlyName, ReplicationProvider, PrimaryFabricFriendlyName, RecoveryFabricFriendlyName } catch { @() })
                    foreach ($plan in $plans) {
                        [void]$items.Add([ordered]@{
                            vaultName         = $vault.Name
                            vmName            = $null
                            protectionState   = 'RecoveryPlan'
                            replicationHealth = $null
                            recoveryPlanName  = $plan.FriendlyName
                            replicationProvider = $plan.ReplicationProvider
                        })
                    }
                }
                @($items)
            }
        }
    )

    # Azure Backup protected items
    $backupItems = @(
        Invoke-RangerSafeAction -Label 'Azure Backup protected item inventory' -DefaultValue @() -ScriptBlock {
            if ($vaults.Count -eq 0) { return @() }
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzRecoveryServicesVault -ErrorAction SilentlyContinue)) { return @() }
                $vaultList = @(Get-AzRecoveryServicesVault -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue)
                $items = New-Object System.Collections.ArrayList
                foreach ($vault in $vaultList) {
                    $ctx = Set-AzRecoveryServicesVaultContext -Vault $vault -ErrorAction SilentlyContinue
                    $protected = @(Get-AzRecoveryServicesBackupItem -WorkloadType AzureVM -ErrorAction SilentlyContinue)
                    $protected += @(Get-AzRecoveryServicesBackupItem -WorkloadType FileFolder -ErrorAction SilentlyContinue)
                    foreach ($item in $protected) {
                        $policy = try { Get-AzRecoveryServicesBackupProtectionPolicy -Name $item.PolicyName -ErrorAction Stop } catch { $null }
                        $rpCount = try { @(Get-AzRecoveryServicesBackupRecoveryPoint -Item $item -ErrorAction Stop).Count } catch { 0 }
                        $agentType = if ($item.ContainerName -match 'MABS') { 'MABS' } elseif ($item.ContainerName -match 'DPM') { 'DPM' } elseif ($item.ContainerName -match 'MARS') { 'MARS' } else { 'AzureBackup' }
                        [void]$items.Add([ordered]@{
                            vaultName           = $vault.Name
                            name                = $item.Name
                            containerName       = $item.ContainerName
                            backupStatus        = [string]$item.Status
                            lastBackupStatus    = [string]$item.LastBackupStatus
                            lastBackupTime      = $item.LastBackupTime
                            protectionState     = [string]$item.ProtectionState
                            policyName          = if ($policy) { $policy.Name } else { $item.PolicyName }
                            recoveryPointCount  = $rpCount
                            agentType           = $agentType
                            failedInLast7Days   = ($item.LastBackupStatus -eq 'Failed') -and ($item.LastBackupTime -gt (Get-Date).AddDays(-7))
                        })
                    }
                }
                @($items)
            }
        }
    )

    $arcMachines = @($azureResources | Where-Object { $_.ResourceType -match 'hybridcompute/machines' })
    $hciRegistrations = @($azureResources | Where-Object { $_.ResourceType -match 'azurestackhci/clusters' })
    $resourceBridge = @($azureResources | Where-Object { $_.ResourceType -match 'resourcebridge' })
    $customLocations = @($azureResources | Where-Object { $_.ResourceType -match 'customlocations' })
    $extensions = @($azureResources | Where-Object { $_.ResourceType -match 'extensions' })
    $siteRecovery = @($azureResources | Where-Object { $_.ResourceType -match 'siterecovery' })

    # Issue #63: VM image gallery (marketplace + local gallery images)
    $vmImages = @(
        Invoke-RangerSafeAction -Label 'HCI VM image gallery' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if ([string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                $imgResult = New-Object System.Collections.ArrayList
                @(Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.AzureStackHCI/marketplaceGalleryImages' -ErrorAction SilentlyContinue) | ForEach-Object {
                    [void]$imgResult.Add([ordered]@{ name = $_.Name; resourceType = 'marketplaceGalleryImage'; location = $_.Location; id = $_.ResourceId })
                }
                @(Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.AzureStackHCI/galleryImages' -ErrorAction SilentlyContinue) | ForEach-Object {
                    [void]$imgResult.Add([ordered]@{ name = $_.Name; resourceType = 'galleryImage'; location = $_.Location; id = $_.ResourceId })
                }
                @($imgResult)
            }
        }
    )

    # Issue #63: ISO file discovery on CSV paths
    $isoImages = @(
        Invoke-RangerSafeAction -Label 'ISO file discovery on CSV' -DefaultValue @() -ScriptBlock {
            Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -ScriptBlock {
                try {
                    @(Get-ChildItem -Path 'C:\ClusterStorage' -Filter '*.iso' -Recurse -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 50 | ForEach-Object {
                        [ordered]@{ name = $_.Name; fullPath = $_.FullName; sizeGiB = [math]::Round($_.Length / 1GB, 2); lastWriteTime = $_.LastWriteTime }
                    })
                } catch { @() }
            }
        }
    )

    # Issue #64: Azure RBAC assignments at HCI resource group scope
    $rbacAssignments = @(
        Invoke-RangerSafeAction -Label 'Azure RBAC assignments (HCI scope)' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzRoleAssignment -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($SubscriptionId) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                $scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup"
                @(Get-AzRoleAssignment -Scope $scope -ErrorAction SilentlyContinue | Select-Object DisplayName, SignInName, RoleDefinitionName, ObjectType, Scope)
            }
        }
    )

    # Issue #64: Defender for Cloud pricing and enablement
    $defenderForCloud = @(
        Invoke-RangerSafeAction -Label 'Defender for Cloud posture' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzSecurityPricing -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($SubscriptionId)) { return @() }
                @(Get-AzSecurityPricing -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'VirtualMachines|HybridCompute|Servers' } | Select-Object Name, PricingTier, FreeTrialRemainingTime)
            }
        }
    )

    # Issue #65: Arc Connected Machine detail per node (agent version, status)
    $arcMachineDetail = @(
        Invoke-RangerSafeAction -Label 'Arc Connected Machine detail' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzConnectedMachine -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                @(Get-AzConnectedMachine -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue | ForEach-Object {
                    $machine = $_
                    $networkProfile = Get-RangerCollectorPropertyValue -InputObject $machine -CandidateNames @('NetworkProfile', 'networkProfile')
                    [ordered]@{
                        Name               = $machine.Name
                        Status             = $machine.Status
                        AgentVersion       = $machine.AgentVersion
                        OsName             = $machine.OsName
                        OsVersion          = $machine.OsVersion
                        Location           = $machine.Location
                        LastStatusChange   = $machine.LastStatusChange
                        ProvisioningState  = $machine.ProvisioningState
                        ResourceId         = if ($machine.Id) { $machine.Id } else { $machine.ResourceId }
                        NetworkProfile     = ConvertTo-RangerHashtable -InputObject $networkProfile
                        NetworkIpAddresses = @(Get-RangerArcNetworkProfileAddresses -NetworkProfile $networkProfile)
                    }
                })
            }
        }
    )

    $arcEsuProfiles = @(
        Invoke-RangerSafeAction -Label 'Arc ESU license profile' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)

                if (-not (Get-Command -Name Get-AzConnectedMachine -ErrorAction SilentlyContinue) -or
                    -not (Get-Command -Name Get-AzResource -ErrorAction SilentlyContinue) -or
                    [string]::IsNullOrWhiteSpace($ResourceGroup)) {
                    return @()
                }

                $profileResults = New-Object System.Collections.ArrayList
                foreach ($machine in @(Get-AzConnectedMachine -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue)) {
                    $machineResourceId = if ($machine.Id) { $machine.Id } else { $machine.ResourceId }
                    if ([string]::IsNullOrWhiteSpace($machineResourceId)) {
                        continue
                    }

                    $queryStatus = 'not-found'
                    $queryMessage = $null
                    $assignedLicense = $null
                    $esuEligibility = $null

                    try {
                        $licenseProfile = Get-AzResource -ResourceId "$machineResourceId/licenseProfiles/default" -ExpandProperties -ErrorAction Stop
                        $licenseProps = Get-RangerCollectorPropertyValue -InputObject $licenseProfile -CandidateNames @('Properties', 'properties')
                        $esuProfile = Get-RangerCollectorPropertyValue -InputObject $licenseProps -CandidateNames @('esuProfile', 'EsuProfile')
                        $assignedLicense = Get-RangerCollectorPropertyValue -InputObject $esuProfile -CandidateNames @('assignedLicense', 'AssignedLicense')
                        $esuEligibility = Get-RangerCollectorPropertyValue -InputObject $esuProfile -CandidateNames @('esuEligibility', 'EsuEligibility')
                        $queryStatus = 'success'
                    }
                    catch {
                        $queryStatus = 'unavailable'
                        $queryMessage = $_.Exception.Message
                    }

                    [void]$profileResults.Add([ordered]@{
                        name            = $machine.Name
                        resourceId      = $machineResourceId
                        queryStatus     = $queryStatus
                        queryMessage    = $queryMessage
                        assignedLicense = $assignedLicense
                        esuEligibility  = $esuEligibility
                    })
                }

                @($profileResults)
            }
        }
    )

    # Issue #65: Arc extension detail per machine (publisher, version, provisioning state, auto-upgrade)
    $arcExtensionsDetail = @(
        Invoke-RangerSafeAction -Label 'Arc extension detail' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzConnectedMachineExtension -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                $machineList = @(try { Get-AzConnectedMachine -ResourceGroupName $ResourceGroup -ErrorAction Stop | Select-Object Name } catch { @() })
                $extResult = New-Object System.Collections.ArrayList
                foreach ($m in $machineList) {
                    $exts = @(Get-AzConnectedMachineExtension -MachineName $m.Name -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue)
                    foreach ($e in $exts) {
                        [void]$extResult.Add([ordered]@{
                            machineName            = $m.Name
                            extensionName          = $e.Name
                            publisher              = $e.Publisher
                            extensionType          = $e.MachineExtensionType
                            typeHandlerVersion     = $e.TypeHandlerVersion
                            provisioningState      = $e.ProvisioningState
                            autoUpgradeMinorVersion = $e.AutoUpgradeMinorVersion
                        })
                    }
                }
                @($extResult)
            }
        }
    )

    # Issue #65: Resource provider registration state for Microsoft.AzureStackHCI
    $resourceProviders = @(
        Invoke-RangerSafeAction -Label 'HCI resource provider registration' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId) -ScriptBlock {
                param($SubscriptionId)
                if (-not (Get-Command -Name Get-AzResourceProvider -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($SubscriptionId)) { return @() }
                @(Get-AzResourceProvider -ProviderNamespace 'Microsoft.AzureStackHCI' -ErrorAction SilentlyContinue | Select-Object ProviderNamespace, RegistrationState, ResourceTypes | ForEach-Object {
                    [ordered]@{ namespace = $_.ProviderNamespace; registrationState = $_.RegistrationState; resourceTypeCount = @($_.ResourceTypes).Count }
                })
            }
        }
    )

    # Issue #65: HCI VM management plane resources (storageContainers, logicalNetworks, etc.)
    $vmManagementResources = @(
        Invoke-RangerSafeAction -Label 'HCI VM management plane resources' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if ([string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                $hciTypes = @(
                    'Microsoft.AzureStackHCI/storageContainers',
                    'Microsoft.AzureStackHCI/logicalNetworks',
                    'Microsoft.AzureStackHCI/galleryImages',
                    'Microsoft.AzureStackHCI/networkInterfaces',
                    'Microsoft.AzureStackHCI/virtualHardDisks',
                    'Microsoft.AzureStackHCI/networkSecurityGroups'
                )
                $vmMgmtResult = New-Object System.Collections.ArrayList
                foreach ($rt in $hciTypes) {
                    @(Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType $rt -ErrorAction SilentlyContinue) | ForEach-Object {
                        [void]$vmMgmtResult.Add([ordered]@{ name = $_.Name; resourceType = $rt; location = $_.Location })
                    }
                }
                @($vmMgmtResult)
            }
        }
    )

    # Issue #66: Arc Data Services inventory (dataControllers, sqlManagedInstances, postgresInstances)
    $arcDataServices = @(
        Invoke-RangerSafeAction -Label 'Arc Data Services inventory' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if ([string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                $dsResult = New-Object System.Collections.ArrayList
                @(Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.AzureArcData/dataControllers' -ErrorAction SilentlyContinue) | ForEach-Object { [void]$dsResult.Add([ordered]@{ name = $_.Name; resourceType = 'dataController'; location = $_.Location }) }
                @(Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.AzureArcData/sqlManagedInstances' -ErrorAction SilentlyContinue) | ForEach-Object { [void]$dsResult.Add([ordered]@{ name = $_.Name; resourceType = 'sqlManagedInstance'; location = $_.Location }) }
                @(Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.AzureArcData/postgresInstances' -ErrorAction SilentlyContinue) | ForEach-Object { [void]$dsResult.Add([ordered]@{ name = $_.Name; resourceType = 'postgresInstance'; location = $_.Location }) }
                @($dsResult)
            }
        }
    )

    # Issue #66: IoT Operations inventory
    $iotOperations = @(
        Invoke-RangerSafeAction -Label 'IoT Operations inventory' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if ([string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                $iotResult = New-Object System.Collections.ArrayList
                @(Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType 'microsoft.iotoperations/instances' -ErrorAction SilentlyContinue) | ForEach-Object { [void]$iotResult.Add([ordered]@{ name = $_.Name; resourceType = 'iotInstance'; location = $_.Location }) }
                @(Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType 'microsoft.iotoperations/brokers' -ErrorAction SilentlyContinue) | ForEach-Object { [void]$iotResult.Add([ordered]@{ name = $_.Name; resourceType = 'iotBroker'; location = $_.Location }) }
                @($iotResult)
            }
        }
    )

    # Issue #66: Cost and licensing signals (subscription type, billing model)
    $costLicensing = @(
        Invoke-RangerSafeAction -Label 'Cost and licensing snapshot' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzSubscription -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($SubscriptionId)) { return @() }
                $sub = Get-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue
                $hciCluster = if (-not [string]::IsNullOrWhiteSpace($ResourceGroup)) {
                    @(Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.AzureStackHCI/clusters' -ExpandProperties -ErrorAction SilentlyContinue) | Select-Object -First 1
                } else { $null }
                $ahbEnabled = if ($hciCluster) {
                    $propVal = try { $hciCluster.Properties.azureHybridBenefit } catch { $null }
                    if ($null -eq $propVal) { $propVal = try { $hciCluster.Properties.billingModel } catch { $null } }
                    $propVal
                } else { $null }
                $subscriptionType = try { $sub.SubscriptionType } catch { $null }
                @([ordered]@{
                    subscriptionId         = $SubscriptionId
                    subscriptionName       = if ($sub) { $sub.Name } else { $null }
                    subscriptionState      = if ($sub) { [string]$sub.State } else { $null }
                    tenantId               = if ($sub) { $sub.TenantId } else { $null }
                    subscriptionType       = $subscriptionType
                    azureHybridBenefit     = $ahbEnabled
                    hciClusterBillingModel = if ($hciCluster) { try { $hciCluster.Properties.billingModel } catch { $null } } else { $null }
                })
            }
        }
    )

    # Issue #72: Policy exemptions at resource group scope
    $policyExemptions = @(
        Invoke-RangerSafeAction -Label 'Azure Policy exemption snapshot' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzPolicyExemption -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                $scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup"
                @(Get-AzPolicyExemption -Scope $scope -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, ExemptionCategory, PolicyAssignmentId, ExpiresOn)
            }
        }
    )

    # Issue #63: Correlate Arc Connected Machines to local VM inventory by name
    $arcEsuProfileByName = @{}
    foreach ($profile in @($arcEsuProfiles)) {
        $profileName = [string](Get-RangerCollectorPropertyValue -InputObject $profile -CandidateNames @('name', 'Name'))
        if (-not [string]::IsNullOrWhiteSpace($profileName)) {
            $arcEsuProfileByName[$profileName.ToUpperInvariant()] = $profile
        }
    }

    $vmInventory = @($vmInventory | ForEach-Object {
        $vm = $_
        $arcMatch = $arcMachineDetail | Where-Object { $_.Name -eq $vm.name } | Select-Object -First 1
        if (-not $arcMatch) { $arcMatch = $arcMachines | Where-Object { $_.Name -eq $vm.name } | Select-Object -First 1 }
        $hyperVIpAddresses = @(Get-RangerVmHyperVIpAddresses -VirtualMachine $vm)
        $arcNetworkProfile = if ($arcMatch) { Get-RangerCollectorPropertyValue -InputObject $arcMatch -CandidateNames @('NetworkProfile', 'networkProfile') } else { $null }
        $arcIpAddresses = if ($arcMatch) {
            $networkIpAddresses = @(Get-RangerCollectorPropertyValue -InputObject $arcMatch -CandidateNames @('NetworkIpAddresses', 'networkIpAddresses'))
            if (@($networkIpAddresses).Count -gt 0) {
                @($networkIpAddresses | Where-Object { Test-RangerIpAddressString -Value ([string]$_) } | Select-Object -Unique)
            }
            else {
                @(Get-RangerArcNetworkProfileAddresses -NetworkProfile $arcNetworkProfile)
            }
        } else { @() }
        $effectiveIpAddresses = if (@($hyperVIpAddresses).Count -gt 0) { $hyperVIpAddresses } else { $arcIpAddresses }
        $vm['arcAgentInstalled']    = $null -ne $arcMatch
        $vm['arcAgentVersion']      = if ($arcMatch) { $arcMatch.AgentVersion } else { $null }
        $vm['arcLastHeartbeat']     = if ($arcMatch) { $arcMatch.LastStatusChange } else { $null }
        $vm['arcProvisioningState'] = if ($arcMatch) { $arcMatch.ProvisioningState } else { $null }
        $vm['arcExtensions']        = @($arcExtensionsDetail | Where-Object { $_.machineName -eq $vm.name })
        $vm['guestOsName']          = if ($arcMatch) { Get-RangerCollectorPropertyValue -InputObject $arcMatch -CandidateNames @('OsName', 'osName') } else { $null }
        $vm['guestOsVersion']       = if ($arcMatch) { Get-RangerCollectorPropertyValue -InputObject $arcMatch -CandidateNames @('OsVersion', 'osVersion') } else { $null }
        $vm['hypervIpAddresses']    = @($hyperVIpAddresses)
        $vm['arcIpAddresses']       = @($arcIpAddresses)
        $vm['effectiveIpAddresses'] = @($effectiveIpAddresses)
        $vm['primaryIpAddress']     = if (@($effectiveIpAddresses).Count -gt 0) { @($effectiveIpAddresses)[0] } else { $null }
        $vm['ipAddressSource']      = if (@($hyperVIpAddresses).Count -gt 0) { 'hyper-v-data-exchange' } elseif (@($arcIpAddresses).Count -gt 0) { 'arc-network-profile' } else { 'not-collected' }
        $vm['arcIpFallbackUsed']    = (@($hyperVIpAddresses).Count -eq 0 -and @($arcIpAddresses).Count -gt 0)
        $vm
    })

    $esuInventory = New-Object System.Collections.ArrayList
    $esuApiUnavailable = $false
    foreach ($vm in @($vmInventory)) {
        if (-not [bool]$vm.arcAgentInstalled) {
            continue
        }

        $esuEligibility = Resolve-RangerEsuOsEligibility -OsName ([string]$vm.guestOsName) -OsVersion ([string]$vm.guestOsVersion)
        $profile = if (-not [string]::IsNullOrWhiteSpace([string]$vm.name) -and $arcEsuProfileByName.ContainsKey(([string]$vm.name).ToUpperInvariant())) {
            $arcEsuProfileByName[([string]$vm.name).ToUpperInvariant()]
        } else { $null }
        $assignedLicense = Get-RangerCollectorPropertyValue -InputObject $profile -CandidateNames @('assignedLicense', 'AssignedLicense')
        $profileEligibility = Get-RangerCollectorPropertyValue -InputObject $profile -CandidateNames @('esuEligibility', 'EsuEligibility')
        $queryStatus = [string](Get-RangerCollectorPropertyValue -InputObject $profile -CandidateNames @('queryStatus', 'QueryStatus'))
        $queryMessage = [string](Get-RangerCollectorPropertyValue -InputObject $profile -CandidateNames @('queryMessage', 'QueryMessage'))

        if ($queryStatus -eq 'unavailable') {
            $esuApiUnavailable = $true
        }

        $finalEligibility = if (-not [string]::IsNullOrWhiteSpace($profileEligibility)) { $profileEligibility } elseif ($esuEligibility.isEligible) { 'Eligible' } elseif ($esuEligibility.detectedOs) { 'Ineligible' } else { 'Unknown' }
        $enrollmentStatus = if ($queryStatus -eq 'unavailable') {
            'not-collected'
        }
        elseif ($assignedLicense) {
            'enrolled'
        }
        elseif ($esuEligibility.isEligible) {
            'not-enrolled'
        }
        else {
            'ineligible'
        }

        [void]$esuInventory.Add([ordered]@{
            name                = $vm.name
            osName              = $vm.guestOsName
            osVersion           = $vm.guestOsVersion
            detectedOs          = $esuEligibility.detectedOs
            arcEnrollmentStatus = if ($vm.arcAgentInstalled) { 'enrolled' } else { 'not-enrolled' }
            esuEligibility      = $finalEligibility
            esuProfileStatus    = $enrollmentStatus
            assignedLicenseId   = $assignedLicense
            queryStatus         = if ([string]::IsNullOrWhiteSpace($queryStatus)) { 'not-found' } else { $queryStatus }
            queryMessage        = $queryMessage
        })
    }

    $resourceSummary = [ordered]@{
        totalResources  = @($azureResources).Count
        byType          = @(Get-RangerGroupedCount -Items $azureResources -PropertyName 'ResourceType')
        byLocation      = @(Get-RangerGroupedCount -Items $azureResources -PropertyName 'Location')
        azureArcMachines = $arcMachines.Count
        hciClusterRegistrations = $hciRegistrations.Count
        backupResources = @($azureResources | Where-Object { $_.ResourceType -match 'RecoveryServices|DataProtection|SiteRecovery' }).Count
        updateResources = @($azureResources | Where-Object { $_.ResourceType -match 'maintenance|update' }).Count
        resourceBridgeCount = $resourceBridge.Count
        customLocationCount = $customLocations.Count
        extensionCount      = $extensions.Count
        aksClusterCount     = @($aksClusters).Count
        arbApplianceCount   = @($arbDetail).Count
        asrProtectedItemCount = @($asrItems | Where-Object { $_.protectionState -ne 'RecoveryPlan' }).Count
        backupProtectedItemCount = @($backupItems).Count
        nonCompliantPolicies = @($policyComplianceStates | Where-Object { $_.ComplianceState -eq 'NonCompliant' }).Count
        vmImageCount        = @($vmImages).Count
        arcDataServiceCount = @($arcDataServices).Count
        iotOperationsCount  = @($iotOperations).Count
        vmManagementResourceCount = @($vmManagementResources).Count
        policyExemptionCount = @($policyExemptions).Count
    }

    $vmSummary = [ordered]@{
        totalVms              = @($vmInventory).Count
        runningVms            = @($vmInventory | Where-Object { $_.state -eq 'Running' }).Count
        clusteredVms          = @($vmInventory | Where-Object { $_.isClustered }).Count
        totalAssignedMemoryGb = [math]::Round((@($vmInventory | Where-Object { $null -ne $_.memoryAssignedMb } | Measure-Object -Property memoryAssignedMb -Sum).Sum / 1024), 2)
        byGeneration          = @(Get-RangerGroupedCount -Items $vmInventory -PropertyName 'generation')
        byState               = @(Get-RangerGroupedCount -Items $vmInventory -PropertyName 'state')
        guestClusterCandidates = @($vmInventory | Where-Object { $_.guestClusterCandidate }).Count
        vmsWithCheckpoints     = @($vmInventory | Where-Object { $_.checkpointCount -gt 0 }).Count
        totalCheckpoints       = (@($vmInventory | Measure-Object -Property checkpointCount -Sum).Sum)
        sriovEnabledNics       = @($vmInventory | ForEach-Object { @($_.nicsAdvanced | Where-Object { $_.sriovEnabled }) } | Measure-Object).Count
        vcpuOvercommitRatio    = if (@($vmInventory).Count -gt 0 -and @($config.targets.cluster.nodes).Count -gt 0) { [math]::Round((@($vmInventory | Measure-Object -Property processorCount -Sum).Sum) / 1, 2) } else { $null }
        memoryOvercommitRatio  = if (@($vmInventory).Count -gt 0) { [math]::Round((@($vmInventory | Measure-Object -Property memoryAssignedMb -Sum).Sum / 1024), 2) } else { $null }
        avgVmsPerNode          = if (@($vmInventory).Count -gt 0) { [math]::Round(@($vmInventory).Count / [math]::Max(1, @($vmInventory | ForEach-Object { $_['hostNode'] } | Select-Object -Unique).Count), 1) } else { 0 }
        highestDensityNode     = ($vmInventory | Group-Object -Property { $_['hostNode'] } | Sort-Object Count -Descending | Select-Object -First 1).Name
        arcConnectedVms        = @($vmInventory | Where-Object { $_.arcAgentInstalled -eq $true }).Count
        vmsUsingArcIpFallback  = @($vmInventory | Where-Object { $_.arcIpFallbackUsed -eq $true }).Count
    }

    $identitySummary = [ordered]@{
        nodeCount                    = @($identitySnapshots).Count
        domainJoinedNodes            = @($identitySnapshots | Where-Object { $_.partOfDomain }).Count
        hybridEntraJoinedNodes       = @($identitySnapshots | Where-Object { $_.entraJoinStatus.hybridAzureAdJoined -eq $true }).Count
        entraJoinedNodes             = @($identitySnapshots | Where-Object { $_.entraJoinStatus.azureAdJoined -eq $true }).Count
        credSspEnabledNodes          = @($identitySnapshots | Where-Object { $_.credSsp -eq $true -or $_.credSsp -eq 'true' }).Count
        defenderProtectedNodes       = @($identitySnapshots | Where-Object { $_.defender.antivirusEnabled -or $_.defender.realTimeProtectionEnabled }).Count
        tamperProtectedNodes         = @($identitySnapshots | Where-Object { $_.defender.isTamperProtected -eq $true }).Count
        defenderDefinitionAgeDays    = @($identitySnapshots | ForEach-Object { if ($_.defender.antivirusSignatureLastUpdated) { ([datetime]::UtcNow - [datetime]$_.defender.antivirusSignatureLastUpdated).TotalDays } } | Measure-Object -Maximum).Maximum
        wdacEnforcedNodes            = @($identitySnapshots | Where-Object { $_.wdacInfo.enforcementMode -eq 'Enforced' }).Count
        wdacAuditNodes               = @($identitySnapshots | Where-Object { $_.wdacInfo.enforcementMode -eq 'Audit' }).Count
        bitLockerProtectedNodes      = @($identitySnapshots | Where-Object { @($_.bitlocker | Where-Object { $_.ProtectionStatus -in @('On', 1, 'ProtectionOn') }).Count -gt 0 }).Count
        bitLockerTpmProtectedNodes   = @($identitySnapshots | Where-Object { @($_.bitlockerProtectors | Where-Object { $_.hasTpm }).Count -gt 0 }).Count
        bitLockerAdBackupNodes       = @($identitySnapshots | Where-Object { @($_.bitlockerProtectors | Where-Object { $_.hasAdBackup }).Count -gt 0 }).Count
        certificateCount             = @($identitySnapshots | ForEach-Object { @($_.certificates).Count } | Measure-Object -Sum).Sum
        certificateExpiringWithin90Days = @($identitySnapshots | ForEach-Object { @($_.certificates | Where-Object { $_.NotAfter -and ([datetime]$_.NotAfter) -lt (Get-Date).AddDays(90) }).Count } | Measure-Object -Sum).Sum
        appLockerNodes               = @($identitySnapshots | Where-Object { @($_.appLocker).Count -gt 0 }).Count
        secureBootEnabledNodes       = @($identitySnapshots | Where-Object { $_.secureBoot -eq $true }).Count
        aadkerbConfiguredNodes       = @($identitySnapshots | Where-Object { $_.aadkerbConfigured -eq $true }).Count
        securedCoreNodes             = @($identitySnapshots | Where-Object { $_.securedCoreDetail.systemGuardEnabled -eq $true }).Count
        syslogForwardingNodes        = @($identitySnapshots | Where-Object { @($_.syslogDetail.syslogAgents).Count -gt 0 -or @($_.syslogDetail.wefSubscriptions | Where-Object { $_.recordCount -gt 0 }).Count -gt 0 }).Count
        defenderForCloudEnabled      = @($defenderForCloud | Where-Object { $_.PricingTier -eq 'Standard' }).Count -gt 0
        totalPhysicalCoreCountForBilling = @($identitySnapshots | Measure-Object -Property physicalCoreCount -Sum).Sum
        clusterServiceAccountModels  = @($identitySnapshots | Select-Object -ExpandProperty clusterServiceAccountModel -ErrorAction SilentlyContinue | Where-Object { $_ } | Sort-Object -Unique)
        secretAutoRotationEnabled    = @($identitySnapshots | Where-Object { $_.secretRotationState.autoRotationEnabled -eq $true }).Count -gt 0
    }

    $findings = New-Object System.Collections.ArrayList

    # Issue #111: workgroup cluster informational finding
    if ($isWorkgroup) {
        [void]$findings.Add((New-RangerFinding -Severity informational `
            -Title 'Cluster is workgroup-joined — Active Directory collectors skipped' `
            -Description 'Resolve-RangerDomainContext determined this cluster is not domain-joined. AD domain, forest, and computer object queries have been skipped to prevent errors.' `
            -CurrentState 'workgroup — IsWorkgroup=true' `
            -Recommendation 'If the cluster should be domain-joined, verify domain membership before running Ranger again.'))
    }

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

        foreach ($switchName in @($vm.switchNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
            [void]$relationships.Add((New-RangerRelationship -SourceType 'virtual-machine' -SourceId $vm.name -TargetType 'virtual-switch' -TargetId $switchName -RelationshipType 'connected-to' -Properties ([ordered]@{ hostNode = $vm.hostNode })))
        }
    }

    if (@($identitySnapshots | Where-Object { -not $_.partOfDomain }).Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($Config.credentials.cluster.passwordRef) -and -not [string]::IsNullOrWhiteSpace($Config.targets.azure.resourceGroup)) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'Local identity posture detected with Azure context configured' -Description 'At least one node appears not to be joined to a domain while Azure registration context is configured.' -CurrentState 'local-key-vault candidate' -Recommendation 'Confirm whether this is a local-identity deployment and verify Key Vault secret references and certificate posture.'))
    }

    if (@($policyAssignments).Count -eq 0 -and @($azureResources).Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'No Azure Policy assignments were discovered at the configured resource-group scope' -Description 'The Azure integration snapshot found resources but did not return policy assignments scoped to the configured resource group.' -CurrentState 'policy assignment inventory empty' -Recommendation 'Confirm whether policy is assigned at a broader scope or whether additional reader permissions are needed for policy discovery.'))
    }

    if ($identitySummary.certificateExpiringWithin90Days -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'One or more node certificates expire within 90 days' -Description 'Identity posture data indicates at least one certificate in the local machine store is approaching expiry.' -CurrentState "$($identitySummary.certificateExpiringWithin90Days) certificates expiring within 90 days" -Recommendation 'Review certificate ownership and renew expiring node, management, and service certificates before handoff.'))
    }

    if (@($identitySnapshots | Where-Object { $_.credSsp -eq $true -or $_.credSsp -eq 'true' }).Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'CredSSP authentication is enabled on one or more nodes' -Description 'CredSSP delegates user credentials to remote hosts and widens the attack surface for credential theft.' -CurrentState "$(@($identitySnapshots | Where-Object { $_.credSsp -eq $true -or $_.credSsp -eq 'true' }).Count) nodes with CredSSP enabled" -Recommendation 'Disable CredSSP on production nodes. Use Kerberos constrained delegation or certificate authentication instead.'))
    }

    if ($identitySummary.wdacEnforcedNodes -eq 0 -and @($identitySnapshots).Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'WDAC policy is not in enforced mode on any node' -Description 'No node reported a Windows Defender Application Control policy in enforcement mode. Audit mode or no policy was detected.' -CurrentState 'WDAC enforcement mode: None or Audit on all nodes' -Recommendation 'Review WDAC policy deployment. Consider enforced mode for production workloads.'))
    }

    if (@($policyComplianceStates | Where-Object { $_.ComplianceState -eq 'NonCompliant' }).Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Azure Policy non-compliant resources detected' -Description "Policy compliance assessment returned non-compliant resources in the scoped resource group." -CurrentState "$($identitySnapshots.Count) non-compliant policy states found" -Recommendation 'Review non-compliant policy assignments and resolve policy drift before handoff.'))
    }

    foreach ($esuItem in @($esuInventory)) {
        if ($esuItem.esuProfileStatus -eq 'not-enrolled') {
            [void]$findings.Add((New-RangerFinding -Severity warning -Title "Eligible VM is not enrolled in Arc ESU: $($esuItem.name)" -Description 'This Arc-connected VM is running an ESU-eligible Windows Server release, but Ranger did not find an assigned ESU license profile.' -CurrentState "$($esuItem.detectedOs) detected; Arc connected; ESU status = not-enrolled" -Recommendation 'Review the Arc machine license profile and enroll the VM in the free ESU benefit where appropriate.'))
        }
        elseif ($esuItem.esuProfileStatus -eq 'enrolled') {
            [void]$findings.Add((New-RangerFinding -Severity informational -Title "Eligible VM is enrolled in Arc ESU: $($esuItem.name)" -Description 'This Arc-connected VM is running an ESU-eligible Windows Server release and an assigned ESU license profile was detected.' -CurrentState "$($esuItem.detectedOs) detected; Arc connected; ESU status = enrolled" -Recommendation 'Retain this ESU enrollment as part of cost and patch lifecycle reviews.'))
        }
    }

    if ($esuApiUnavailable) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'Arc ESU license profile data could not be collected for one or more machines' -Description 'Ranger attempted to query the Arc machine license profile endpoint, but one or more requests failed. ESU enrollment data is therefore incomplete.' -CurrentState 'ESU profile query status = unavailable for at least one Arc machine' -Recommendation 'Verify Microsoft.HybridCompute license profile API access and reader permissions, then rerun Ranger to complete the ESU assessment.'))
    }

    return @{
        Status        = 'success'
        Domains       = @{
            virtualMachines = [ordered]@{
                inventory        = ConvertTo-RangerHashtable -InputObject $vmInventory
                placement        = ConvertTo-RangerHashtable -InputObject @($vmInventory | ForEach-Object { [ordered]@{ vm = $_.name; hostNode = $_.hostNode; state = $_.state } })
                workloadFamilies = @($workloadFamilies)
                replication      = ConvertTo-RangerHashtable -InputObject @($vmInventory | Where-Object { $_.replicationMode } | ForEach-Object { [ordered]@{ vm = $_.name; mode = $_.replicationMode; health = $_.replicationHealth } })
                checkpoints      = ConvertTo-RangerHashtable -InputObject @($vmInventory | Where-Object { $_.checkpointCount -gt 0 } | ForEach-Object { [ordered]@{ vm = $_.name; count = $_.checkpointCount; snapshots = $_.checkpoints } })
                guestClusters    = ConvertTo-RangerHashtable -InputObject @($vmInventory | Where-Object { $_.guestClusterCandidate } | ForEach-Object { [ordered]@{ vm = $_.name; hostNode = $_.hostNode } })
                vmImages         = ConvertTo-RangerHashtable -InputObject $vmImages
                isoImages        = ConvertTo-RangerHashtable -InputObject $isoImages
                arcCorrelation   = ConvertTo-RangerHashtable -InputObject @($vmInventory | ForEach-Object { [ordered]@{ vm = $_.name; arcAgentInstalled = $_.arcAgentInstalled; arcAgentVersion = $_.arcAgentVersion; arcProvisioningState = $_.arcProvisioningState; guestOsName = $_.guestOsName; guestOsVersion = $_.guestOsVersion; ipAddressSource = $_.ipAddressSource; primaryIpAddress = $_.primaryIpAddress; effectiveIpAddresses = @($_.effectiveIpAddresses) } })
                summary          = $vmSummary
            }
            identitySecurity = [ordered]@{
                nodes           = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; partOfDomain = $_.partOfDomain; domain = $_.domain; credSsp = $_.credSsp } })
                certificates    = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; items = $_.certificates } })
                posture         = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; defender = $_.defender; defenderExclusions = $_.defenderExclusions; wdacInfo = $_.wdacInfo; bitlocker = $_.bitlocker; bitlockerProtectors = $_.bitlockerProtectors; secureBoot = $_.secureBoot; appLocker = $_.appLocker; securedCoreDetail = $_.securedCoreDetail } })
                localAdmins     = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; members = $_.localAdmins; detail = $_.localAdminDetail } })
                auditPolicy     = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; values = $_.auditPolicy } })
                activeDirectory = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; domain = $_.adDomain; forest = $_.adForest; adObjects = $_.adObjects; adSite = $_.adSite } })
                entraJoin       = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; status = $_.entraJoinStatus; aadkerbConfigured = $_.aadkerbConfigured } })
                keyVault        = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; references = $keyVaultReferences } })
                syslog          = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; detail = $_.syslogDetail } })
                driftControl    = ConvertTo-RangerHashtable -InputObject @($identitySnapshots | ForEach-Object { [ordered]@{ node = $_.node; detail = $_.driftControl } })
                rbacAssignments = ConvertTo-RangerHashtable -InputObject $rbacAssignments
                defenderForCloud = ConvertTo-RangerHashtable -InputObject $defenderForCloud
                summary         = $identitySummary
            }
            azureIntegration = [ordered]@{
                context   = [ordered]@{
                    subscriptionId = $Config.targets.azure.subscriptionId
                    resourceGroup  = $Config.targets.azure.resourceGroup
                    tenantId       = $Config.targets.azure.tenantId
                }
                resources           = ConvertTo-RangerHashtable -InputObject $azureResources
                services            = ConvertTo-RangerHashtable -InputObject @($resourcesByType | ForEach-Object { [ordered]@{ category = $_.Name; count = $_.Count; name = $_.Name } })
                policy              = ConvertTo-RangerHashtable -InputObject $policyAssignments
                policyCompliance    = ConvertTo-RangerHashtable -InputObject $policyComplianceStates
                policyExemptions    = ConvertTo-RangerHashtable -InputObject $policyExemptions
                backup              = ConvertTo-RangerHashtable -InputObject $backupItems
                backupLegacy        = ConvertTo-RangerHashtable -InputObject @($azureResources | Where-Object { $_.ResourceType -match 'RecoveryServices|DataProtection|SiteRecovery' })
                siteRecovery        = ConvertTo-RangerHashtable -InputObject $asrItems
                update              = ConvertTo-RangerHashtable -InputObject @($azureResources | Where-Object { $_.ResourceType -match 'maintenance|update' })
                cost                = ConvertTo-RangerHashtable -InputObject @($azureResources | Where-Object { $_.ResourceType -match 'billing|cost' })
                costLicensing       = ConvertTo-RangerHashtable -InputObject $costLicensing
                resourceBridge      = ConvertTo-RangerHashtable -InputObject $resourceBridge
                arbDetail           = ConvertTo-RangerHashtable -InputObject $arbDetail
                aksClusters         = ConvertTo-RangerHashtable -InputObject $aksClusters
                customLocations     = ConvertTo-RangerHashtable -InputObject $customLocations
                extensions          = ConvertTo-RangerHashtable -InputObject $extensions
                arcMachines         = ConvertTo-RangerHashtable -InputObject $arcMachines
                arcMachineDetail    = ConvertTo-RangerHashtable -InputObject $arcMachineDetail
                arcExtensionsDetail = ConvertTo-RangerHashtable -InputObject $arcExtensionsDetail
                resourceProviders   = ConvertTo-RangerHashtable -InputObject $resourceProviders
                vmManagementResources = ConvertTo-RangerHashtable -InputObject $vmManagementResources
                arcDataServices     = ConvertTo-RangerHashtable -InputObject $arcDataServices
                iotOperations       = ConvertTo-RangerHashtable -InputObject $iotOperations
                costAnalysis        = [ordered]@{
                    esuInventory = ConvertTo-RangerHashtable -InputObject $esuInventory
                    summary      = [ordered]@{
                        eligibleVmCount    = @($esuInventory | Where-Object { $_.esuEligibility -eq 'Eligible' }).Count
                        enrolledVmCount    = @($esuInventory | Where-Object { $_.esuProfileStatus -eq 'enrolled' }).Count
                        notEnrolledVmCount = @($esuInventory | Where-Object { $_.esuProfileStatus -eq 'not-enrolled' }).Count
                        ineligibleVmCount  = @($esuInventory | Where-Object { $_.esuProfileStatus -eq 'ineligible' }).Count
                    }
                }
                resourceSummary     = $resourceSummary
                resourceLocations   = ConvertTo-RangerHashtable -InputObject $resourceSummary.byLocation
                policySummary       = [ordered]@{
                    assignmentCount   = @($policyAssignments).Count
                    enforcementModes  = @(Get-RangerGroupedCount -Items $policyAssignments -PropertyName 'EnforcementMode')
                    nonCompliantCount = @($policyComplianceStates | Where-Object { $_.ComplianceState -eq 'NonCompliant' }).Count
                    complianceByType  = @(Get-RangerGroupedCount -Items ($policyComplianceStates | Where-Object { $_.ComplianceState -eq 'NonCompliant' }) -PropertyName 'ResourceType')
                    exemptionCount    = @($policyExemptions).Count
                }
                auth = [ordered]@{ method = $CredentialMap.azure.method; tenantId = $CredentialMap.azure.tenantId; subscriptionId = $CredentialMap.azure.subscriptionId; azureCliFallback = [bool]$CredentialMap.azure.useAzureCliFallback }
            }
        }
        Findings      = @($findings)
        Relationships = @($relationships)
        RawEvidence   = [ordered]@{
            domainContext     = [ordered]@{ fqdn = $domainCtx.FQDN; netBios = $domainCtx.NetBIOS; resolvedBy = $domainCtx.ResolvedBy; isWorkgroup = $domainCtx.IsWorkgroup; confidence = $domainCtx.Confidence }
            virtualMachines   = ConvertTo-RangerHashtable -InputObject $vmInventory
            identitySecurity  = ConvertTo-RangerHashtable -InputObject $identitySnapshots
            azureResources    = ConvertTo-RangerHashtable -InputObject $azureResources
            policyAssignments = ConvertTo-RangerHashtable -InputObject $policyAssignments
            policyCompliance  = ConvertTo-RangerHashtable -InputObject $policyComplianceStates
            asrItems          = ConvertTo-RangerHashtable -InputObject $asrItems
            backupItems       = ConvertTo-RangerHashtable -InputObject $backupItems
            aksClusters       = ConvertTo-RangerHashtable -InputObject $aksClusters
            arbDetail         = ConvertTo-RangerHashtable -InputObject $arbDetail
            arcMachineDetail  = ConvertTo-RangerHashtable -InputObject $arcMachineDetail
            arcDataServices   = ConvertTo-RangerHashtable -InputObject $arcDataServices
            iotOperations     = ConvertTo-RangerHashtable -InputObject $iotOperations
        }
    }
}
