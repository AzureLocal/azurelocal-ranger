function Invoke-RangerCollectorExecution {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Definition,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory = $true)]
        $CredentialMap,

        [Parameter(Mandatory = $true)]
        [string]$PackageRoot,

        # Issue #30: connectivity matrix from Get-RangerConnectivityMatrix.
        # When supplied, collectors whose transport surface is unreachable are skipped
        # with status 'skipped' rather than being attempted and failing mid-run.
        [System.Collections.IDictionary]$ConnectivityMatrix
    )

    $messages = New-Object System.Collections.Generic.List[string]
    $start = (Get-Date).ToUniversalTime().ToString('o')
    $status = 'success'
    $functionName = $Definition.FunctionName
    $arguments = @{
        Config        = $Config
        CredentialMap = $CredentialMap
        Definition    = $Definition
        PackageRoot   = $PackageRoot
    }

    try {
        # Issue #30: skip collector gracefully when connectivity matrix says its
        # required transport surface is not reachable from this runner.
        if ($ConnectivityMatrix -and (Get-Command -Name 'Test-RangerCollectorConnectivitySatisfied' -ErrorAction SilentlyContinue)) {
            $satisfied = Test-RangerCollectorConnectivitySatisfied -Definition $Definition -ConnectivityMatrix $ConnectivityMatrix
            if (-not $satisfied) {
                $skipSurface = $Definition.RequiredCredential
                $skipMsg = "Collector '$($Definition.Id)' skipped — $skipSurface transport unreachable (connectivity posture: $($ConnectivityMatrix.posture))."
                $messages.Add($skipMsg)
                $end = (Get-Date).ToUniversalTime().ToString('o')
                return @{
                    CollectorId     = $Definition.Id
                    Status          = 'skipped'
                    StartTimeUtc    = $start
                    EndTimeUtc      = $end
                    TargetScope     = @($Definition.RequiredTargets)
                    CredentialScope = $Definition.RequiredCredential
                    Messages        = @($messages)
                    Domains         = @{}
                    Topology        = $null
                    Relationships   = @()
                    Findings        = @()
                    Evidence        = @()
                    RawEvidence     = $null
                }
            }
        }

        if (-not (Get-Command -Name $functionName -ErrorAction SilentlyContinue)) {
            throw "Collector function '$functionName' is not available."
        }

        $result = & $functionName @arguments
        if (-not $result) {
            $status = 'not-applicable'
            $result = @{}
        }
        elseif ($result.Status) {
            $status = $result.Status
        }

        $messages.Add("Collector '$($Definition.Id)' completed with status '$status'.")
    }
    catch {
        $status = if ($Definition.Class -eq 'optional' -and [bool]$Config.behavior.skipUnavailableOptionalDomains) { 'skipped' } else { 'failed' }
        $messages.Add($_.Exception.Message)
        $result = @{
            Domains       = @{}
            Findings      = @(
                New-RangerFinding -Severity warning -Title "Collector $($Definition.Id) did not complete" -Description $_.Exception.Message -CurrentState $status -Recommendation 'Review target reachability, credentials, and required dependencies.'
            )
            Relationships = @()
            Evidence      = @()
        }
    }

    $end = (Get-Date).ToUniversalTime().ToString('o')
    return @{
        CollectorId     = $Definition.Id
        Status          = $status
        StartTimeUtc    = $start
        EndTimeUtc      = $end
        TargetScope     = @($Definition.RequiredTargets)
        CredentialScope = $Definition.RequiredCredential
        Messages        = @(@($messages) + @($result.Messages) | Where-Object { $null -ne $_ })
        Domains         = if ($result.Domains) { $result.Domains } else { @{} }
        Topology        = $result.Topology
        Relationships   = @($result.Relationships)
        Findings        = @($result.Findings)
        Evidence        = @($result.Evidence)
        RawEvidence     = $result.RawEvidence
    }
}

function New-RangerPackageRoot {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [string]$OutputPathOverride,
        [string]$BasePath = (Get-Location).Path
    )

    $rootPath = if ($OutputPathOverride) { $OutputPathOverride } else { $Config.output.rootPath }
    $resolvedRoot = Resolve-RangerPath -Path $rootPath -BasePath $BasePath
    $packageName = '{0}-{1}-{2}' -f (Get-RangerSafeName -Value ($Config.environment.name)), (Get-RangerSafeName -Value $Config.output.mode), (Get-RangerTimestamp)
    $packageRoot = Join-Path -Path $resolvedRoot -ChildPath $packageName
    New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
    return $packageRoot
}

function Test-RangerDriftDictionaryLike {
    param(
        $Value
    )

    return $Value -is [System.Collections.IDictionary]
}

function Test-RangerDriftEnumerableLike {
    param(
        $Value
    )

    return $Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string]) -and -not ($Value -is [System.Collections.IDictionary])
}

function Get-RangerDriftItemIdentity {
    param(
        $Item
    )

    if (-not (Test-RangerDriftDictionaryLike -Value $Item)) {
        return $null
    }

    foreach ($propertyName in @('name', 'friendlyName', 'id', 'resourceId', 'uniqueId', 'node', 'path', 'driveLetter', 'interface', 'interfaceAlias', 'taskName', 'policyId', 'filePath', 'serialNumber')) {
        if ($Item.Contains($propertyName) -and -not [string]::IsNullOrWhiteSpace([string]$Item[$propertyName])) {
            return '{0}:{1}' -f $propertyName, [string]$Item[$propertyName]
        }
    }

    return $null
}

function Add-RangerDriftChangeRecord {
    param(
        [Parameter(Mandatory = $true)]
        [ref]$Changes,

        [Parameter(Mandatory = $true)]
        [string]$Domain,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet('added', 'removed', 'changed')]
        [string]$ChangeType,

        $BaselineValue,
        $CurrentValue
    )

    [void]$Changes.Value.Add([ordered]@{
        domain        = $Domain
        path          = $Path
        changeType    = $ChangeType
        baselineValue = $BaselineValue
        currentValue  = $CurrentValue
    })
}

function Compare-RangerDriftValue {
    param(
        $Baseline,
        $Current,
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Domain,
        [Parameter(Mandatory = $true)]
        [ref]$Changes
    )

    if ($null -eq $Baseline -and $null -eq $Current) {
        return
    }

    if ($null -eq $Baseline) {
        Add-RangerDriftChangeRecord -Changes $Changes -Domain $Domain -Path $Path -ChangeType 'added' -BaselineValue $null -CurrentValue $Current
        return
    }

    if ($null -eq $Current) {
        Add-RangerDriftChangeRecord -Changes $Changes -Domain $Domain -Path $Path -ChangeType 'removed' -BaselineValue $Baseline -CurrentValue $null
        return
    }

    $baselineIsDictionary = Test-RangerDriftDictionaryLike -Value $Baseline
    $currentIsDictionary = Test-RangerDriftDictionaryLike -Value $Current
    $baselineIsEnumerable = Test-RangerDriftEnumerableLike -Value $Baseline
    $currentIsEnumerable = Test-RangerDriftEnumerableLike -Value $Current

    if (($baselineIsDictionary -and $currentIsEnumerable) -or ($baselineIsEnumerable -and $currentIsDictionary)) {
        if ($baselineIsDictionary -and -not $baselineIsEnumerable) {
            $normalizedBaseline = New-Object object[] 1
            $normalizedBaseline[0] = $Baseline
        }
        else {
            $normalizedBaseline = $Baseline
        }

        if ($currentIsDictionary -and -not $currentIsEnumerable) {
            $normalizedCurrent = New-Object object[] 1
            $normalizedCurrent[0] = $Current
        }
        else {
            $normalizedCurrent = $Current
        }

        Compare-RangerDriftValue -Baseline $normalizedBaseline -Current $normalizedCurrent -Path $Path -Domain $Domain -Changes $Changes
        return
    }

    if ($baselineIsDictionary -and $currentIsDictionary) {
        $keys = @($Baseline.Keys + $Current.Keys | Sort-Object -Unique)
        foreach ($key in $keys) {
            $childPath = if ([string]::IsNullOrWhiteSpace($Path)) { [string]$key } else { '{0}.{1}' -f $Path, $key }
            $baselineChild = if ($Baseline.Contains($key)) { $Baseline[$key] } else { $null }
            $currentChild = if ($Current.Contains($key)) { $Current[$key] } else { $null }
            Compare-RangerDriftValue -Baseline $baselineChild -Current $currentChild -Path $childPath -Domain $Domain -Changes $Changes
        }
        return
    }

    if ($baselineIsEnumerable -and $currentIsEnumerable) {
        $baselineItems = @($Baseline)
        $currentItems = @($Current)
        $identityProperty = $null

        if ($baselineItems.Count -gt 0 -or $currentItems.Count -gt 0) {
            $combinedItems = @($baselineItems) + @($currentItems)
            $sampleItem = @($combinedItems | Where-Object { $_ -ne $null } | Select-Object -First 1)[0]
            $sampleIdentity = Get-RangerDriftItemIdentity -Item $sampleItem
            if ($sampleIdentity) {
                $identityProperty = ($sampleIdentity -split ':', 2)[0]
            }
        }

        if ($identityProperty) {
            $baselineMap = [ordered]@{}
            foreach ($item in $baselineItems) {
                $identity = Get-RangerDriftItemIdentity -Item $item
                if ($identity) {
                    $baselineMap[$identity] = $item
                }
            }

            $currentMap = [ordered]@{}
            foreach ($item in $currentItems) {
                $identity = Get-RangerDriftItemIdentity -Item $item
                if ($identity) {
                    $currentMap[$identity] = $item
                }
            }

            $keys = @($baselineMap.Keys + $currentMap.Keys | Sort-Object -Unique)
            foreach ($key in $keys) {
                $label = $key.Substring($identityProperty.Length + 1)
                $childPath = '{0}[{1}]' -f $Path, $label
                $baselineChild = if ($baselineMap.Contains($key)) { $baselineMap[$key] } else { $null }
                $currentChild = if ($currentMap.Contains($key)) { $currentMap[$key] } else { $null }
                Compare-RangerDriftValue -Baseline $baselineChild -Current $currentChild -Path $childPath -Domain $Domain -Changes $Changes
            }
            return
        }

        $baselineJson = $baselineItems | ConvertTo-Json -Depth 100 -Compress
        $currentJson = $currentItems | ConvertTo-Json -Depth 100 -Compress
        if ($baselineJson -ne $currentJson) {
            Add-RangerDriftChangeRecord -Changes $Changes -Domain $Domain -Path $Path -ChangeType 'changed' -BaselineValue $baselineItems -CurrentValue $currentItems
        }
        return
    }

    $baselineJson = $Baseline | ConvertTo-Json -Depth 20 -Compress
    $currentJson = $Current | ConvertTo-Json -Depth 20 -Compress
    if ($baselineJson -ne $currentJson) {
        Add-RangerDriftChangeRecord -Changes $Changes -Domain $Domain -Path $Path -ChangeType 'changed' -BaselineValue $Baseline -CurrentValue $Current
    }
}

function New-RangerDriftReport {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$CurrentManifest,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$BaselineManifest,

        [Parameter(Mandatory = $true)]
        [string]$BaselineManifestPath
    )

    if ($BaselineManifest.run.schemaVersion -ne $CurrentManifest.run.schemaVersion) {
        return [ordered]@{
            status                = 'skipped'
            generatedAtUtc        = (Get-Date).ToUniversalTime().ToString('o')
            baselineManifestPath  = $BaselineManifestPath
            baselineSchemaVersion = $BaselineManifest.run.schemaVersion
            currentSchemaVersion  = $CurrentManifest.run.schemaVersion
            comparedDomains       = @()
            skippedReason         = "Baseline schema version '$($BaselineManifest.run.schemaVersion)' does not match current schema version '$($CurrentManifest.run.schemaVersion)'."
            summary               = [ordered]@{
                totalChanges = 0
                added        = 0
                removed      = 0
                changed      = 0
                domainCounts = @()
            }
            changes               = @()
        }
    }

    $domainsToCompare = @('clusterNode', 'hardware', 'storage', 'networking', 'virtualMachines', 'azureIntegration', 'identitySecurity')
    $changes = New-Object System.Collections.ArrayList
    foreach ($domainName in $domainsToCompare) {
        $baselineDomain = if ($BaselineManifest.domains.Contains($domainName)) { $BaselineManifest.domains[$domainName] } else { $null }
        $currentDomain = if ($CurrentManifest.domains.Contains($domainName)) { $CurrentManifest.domains[$domainName] } else { $null }
        Compare-RangerDriftValue -Baseline $baselineDomain -Current $currentDomain -Path $domainName -Domain $domainName -Changes ([ref]$changes)
    }

    $changeList = @($changes)
    $domainCounts = @(
        $changeList |
            Group-Object domain |
            Sort-Object Name |
            ForEach-Object {
                [ordered]@{
                    domain   = $_.Name
                    added    = @($_.Group | Where-Object { $_.changeType -eq 'added' }).Count
                    removed  = @($_.Group | Where-Object { $_.changeType -eq 'removed' }).Count
                    changed  = @($_.Group | Where-Object { $_.changeType -eq 'changed' }).Count
                    total    = $_.Count
                }
            }
    )

    [ordered]@{
        status                = 'generated'
        generatedAtUtc        = (Get-Date).ToUniversalTime().ToString('o')
        baselineManifestPath  = $BaselineManifestPath
        baselineSchemaVersion = $BaselineManifest.run.schemaVersion
        currentSchemaVersion  = $CurrentManifest.run.schemaVersion
        comparedDomains       = @($domainsToCompare)
        skippedReason         = $null
        summary               = [ordered]@{
            totalChanges = $changeList.Count
            added        = @($changeList | Where-Object { $_.changeType -eq 'added' }).Count
            removed      = @($changeList | Where-Object { $_.changeType -eq 'removed' }).Count
            changed      = @($changeList | Where-Object { $_.changeType -eq 'changed' }).Count
            domainCounts = $domainCounts
        }
        changes               = $changeList
    }
}

function Write-RangerJsonArtifact {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageRoot,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        $Content
    )

    $artifactPath = Join-Path -Path $PackageRoot -ChildPath $RelativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $artifactPath) -Force | Out-Null
    $Content | ConvertTo-Json -Depth 100 | Set-Content -Path $artifactPath -Encoding UTF8
    return $artifactPath
}

function New-RangerRunStatus {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Unattended,

        [string]$Status = 'success',
        [string]$ErrorMessage,
        [System.Collections.IDictionary]$Manifest,
        [string]$ManifestPath,
        [string]$LogPath,
        [string]$DriftStatus = 'not-requested'
    )

    $collectorEntries = if ($Manifest -and $Manifest.collectors) { @($Manifest.collectors.Values) } else { @() }
    [ordered]@{
        status          = $Status
        unattended      = $Unattended
        generatedAtUtc  = (Get-Date).ToUniversalTime().ToString('o')
        manifestPath    = $ManifestPath
        logPath         = $LogPath
        driftStatus     = $DriftStatus
        errorMessage    = $ErrorMessage
        collectorCounts = [ordered]@{
            total         = $collectorEntries.Count
            success       = @($collectorEntries | Where-Object { $_.status -eq 'success' }).Count
            partial       = @($collectorEntries | Where-Object { $_.status -eq 'partial' }).Count
            failed        = @($collectorEntries | Where-Object { $_.status -eq 'failed' }).Count
            skipped       = @($collectorEntries | Where-Object { $_.status -eq 'skipped' }).Count
            notApplicable = @($collectorEntries | Where-Object { $_.status -eq 'not-applicable' }).Count
        }
    }
}

function Invoke-RangerDiscoveryRuntime {
    param(
        [string]$ConfigPath,
        $ConfigObject,
        [string]$OutputPath,
        [hashtable]$CredentialOverrides,
        [string[]]$IncludeDomains,
        [string[]]$ExcludeDomains,
        [switch]$NoRender,
        [hashtable]$StructuralOverrides,
        [switch]$AllowInteractiveInput,
        [switch]$Unattended,
        [string]$BaselineManifestPath
    )

    $config = Import-RangerConfiguration -ConfigPath $ConfigPath -ConfigObject $ConfigObject
    $config = Set-RangerStructuralOverrides -Config $config -StructuralOverrides $StructuralOverrides

    if ($IncludeDomains) {
        $config.domains.include = @($IncludeDomains)
    }

    if ($ExcludeDomains) {
        $config.domains.exclude = @($ExcludeDomains)
    }

    if ($Unattended) {
        $config.behavior.promptForMissingCredentials = $false
    }

    # v1.6.0 (#196/#197): auto-discover missing resourceGroup and cluster FQDN
    # from Azure Arc before any prompting or validation, headless or interactive.
    Invoke-RangerAzureAutoDiscovery -Config $config | Out-Null

    if ($AllowInteractiveInput) {
        $config = Invoke-RangerInteractiveInput -Config $config
    }

    $script:RangerLogLevel = Resolve-RangerLogLevel -Level $(if ($config.behavior.logLevel) { $config.behavior.logLevel } else { 'info' })
    $script:RangerBehaviorRetryCount = if ($config.behavior.retryCount -gt 0) { [int]$config.behavior.retryCount } else { 0 }
    $validation = Test-RangerConfiguration -Config $config -PassThru
    if (-not $validation.IsValid) {
        throw ($validation.Errors -join [Environment]::NewLine)
    }

    # v1.6.0 (#206): initialise the skipped-resources tracker for this run.
    Reset-RangerSkippedResources

    # v1.6.0 (#212): pre-run permission audit. Runs by default; skip when
    # behavior.skipPreCheck is true (set by -SkipPreCheck parameter or config)
    # or when the selected collectors are operating in fixture mode (no live
    # Azure / cluster calls will occur so an ARM permission audit is moot).
    $skipPreCheck = [bool]($config.behavior.skipPreCheck)
    $fixtureMap = $null
    try { $fixtureMap = $config.domains.hints.fixtures } catch { }
    $isFixtureMode = $false
    try {
        $selected = Resolve-RangerSelectedCollectors -Config $config
        if ($fixtureMap -is [System.Collections.IDictionary] -and @($selected).Count -gt 0) {
            $isFixtureMode = @($selected | Where-Object { -not $fixtureMap.Contains($_.Id) -or [string]::IsNullOrWhiteSpace([string]$fixtureMap[$_.Id]) }).Count -eq 0
        }
    } catch { }

    if ($skipPreCheck) {
        Write-RangerLog -Level debug -Message 'Pre-check skipped (-SkipPreCheck or behavior.skipPreCheck=true).'
    }
    elseif ($isFixtureMode) {
        Write-RangerLog -Level debug -Message 'Pre-check skipped — all selected collectors are running in fixture mode.'
    }
    else {
        try {
            $audit = Invoke-RangerPermissionAudit -Config $config
            Format-RangerPermissionAuditConsole -Result $audit
            switch ($audit.OverallReadiness) {
                'Insufficient' {
                    throw "Pre-run permission audit failed (Insufficient). Re-run with -SkipPreCheck to bypass, or address the remediation steps above."
                }
                'Partial' {
                    Write-RangerLog -Level warn -Message "Pre-run permission audit returned Partial — some collectors may fail. $(@($audit.Recommendations) -join '; ')"
                }
                default {
                    Write-RangerLog -Level info -Message 'Pre-check passed.'
                }
            }
        }
        catch {
            if ($_.Exception.Message -like 'Pre-run permission audit failed*') { throw }
            Write-RangerLog -Level warn -Message "Pre-run permission audit threw — $($_.Exception.Message). Continuing; set -SkipPreCheck to suppress."
        }
    }

    $selectedCollectors = Resolve-RangerSelectedCollectors -Config $config
    $credentialMap = Resolve-RangerCredentialMap -Config $config -Overrides $CredentialOverrides
    $basePath = if ($ConfigPath) { Split-Path -Parent (Resolve-RangerPath -Path $ConfigPath) } else { (Get-Location).Path }
    $resolvedBaselineManifestPath = if (-not [string]::IsNullOrWhiteSpace($BaselineManifestPath)) { Resolve-RangerPath -Path $BaselineManifestPath -BasePath $basePath } else { $null }
    $packageRoot = New-RangerPackageRoot -Config $config -OutputPathOverride $OutputPath -BasePath $basePath
    $script:RangerLogPath = $null
    $script:RangerRetryDetails = New-Object System.Collections.ArrayList
    $script:RangerWinRmProbeCache = @{}
    $logPath = Initialize-RangerFileLog -PackageRoot $packageRoot
    $transcriptPath = Join-Path -Path $packageRoot -ChildPath 'ranger.transcript.log'
    $manifest = $null
    $manifestPath = $null
    $manifestValidation = $null
    $driftReport = $null
    $runStatusPath = $null
    $script:_rangerPrevVerbosePreference = $VerbosePreference
    $script:_rangerPrevDebugPreference = $DebugPreference
    $script:_rangerPrevInformationPreference = $InformationPreference
    $script:_rangerPrevProgressPreference = $ProgressPreference

    # Issue #163: never set $DebugPreference = 'Continue' — MSAL 4.x and the Az SDK emit
    # thousands of internal debug lines via Write-Debug, inflating ranger.log from ~2 KB to
    # 512 KB+ and burying actionable output. Ranger uses Write-RangerLog for all structured
    # logging; $DebugPreference is left at its caller-set value in all log levels.
    switch ($script:RangerLogLevel) {
        'debug' {
            $VerbosePreference     = 'Continue'
            $InformationPreference = 'Continue'
            $ProgressPreference    = 'Continue'
        }
        default {
            $VerbosePreference     = 'SilentlyContinue'
            $InformationPreference = 'SilentlyContinue'
            $ProgressPreference    = 'SilentlyContinue'
        }
    }
    $DebugPreference = 'SilentlyContinue'

    # Install a global Write-Warning proxy so warnings from ANY module (Az, WinRM, S2D, etc.) are
    # captured in the run log for the duration of this run, then restored in the finally block.
    $script:_rangerPrevWriteWarning = Get-Item function:\global:Write-Warning -ErrorAction SilentlyContinue
    function global:Write-Warning {
        param([AllowNull()][object]$Message)

        $messageText = ConvertTo-RangerLogMessage -InputObject $Message
        $currentLevel = Resolve-RangerLogLevel -Level $(if ($script:RangerLogLevel) { $script:RangerLogLevel } else { 'info' })
        if ((Get-RangerLogLevelRank -Level 'warn') -ge (Get-RangerLogLevelRank -Level $currentLevel) -and -not [string]::IsNullOrWhiteSpace($messageText) -and $script:RangerLogPath) {
            try {
                Add-Content -LiteralPath $script:RangerLogPath -Value "[$((Get-Date).ToString('s'))][WARN] $messageText" -Encoding UTF8 -ErrorAction Stop
            }
            catch {
            }
        }

        Microsoft.PowerShell.Utility\Write-Warning -Message $messageText
    }

    try {
        try {
            Start-Transcript -Path $transcriptPath -Force -ErrorAction Stop | Out-Null
        }
        catch {
            Write-RangerLog -Level warn -Message "Transcript start failed: $($_.Exception.Message)"
        }

        Write-RangerLog -Level info -Message "AzureLocalRanger run started — package: $(Split-Path -Leaf $packageRoot)"
        $manifest = New-RangerManifest -Config $config -SelectedCollectors $selectedCollectors
        $manifest.run.unattended = [bool]$Unattended
        $manifest.run.baselineManifestPath = $resolvedBaselineManifestPath
        $manifest.run.retryDetails = @()
        $manifestPath = Join-Path -Path $packageRoot -ChildPath 'manifest\audit-manifest.json'
        $evidenceRoot = Join-Path -Path $packageRoot -ChildPath 'evidence'

        # Issue #139 — WinRM preflight: probe all cluster targets before any collector runs.
        # Fails the run immediately when any configured target is unreachable.
        $preflightTargets = [System.Collections.Generic.List[string]]::new()
        if (-not [string]::IsNullOrWhiteSpace([string]$config.targets.cluster.fqdn) -and -not (Test-RangerPlaceholderValue -Value $config.targets.cluster.fqdn -FieldName 'targets.cluster.fqdn')) {
            $preflightTargets.Add([string]$config.targets.cluster.fqdn)
        }
        foreach ($node in @($config.targets.cluster.nodes)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$node) -and -not (Test-RangerPlaceholderValue -Value $node -FieldName 'targets.cluster.node') -and $node -notin $preflightTargets) {
                $preflightTargets.Add([string]$node)
            }
        }

        if ($preflightTargets.Count -gt 0) {
            $retryCount = if ($config.behavior -and $config.behavior.retryCount -gt 0) { [int]$config.behavior.retryCount } else { 1 }
            $timeoutSec = if ($config.behavior -and $config.behavior.timeoutSeconds -gt 0) { [int]$config.behavior.timeoutSeconds } else { 0 }
            Write-RangerLog -Level info -Message "WinRM preflight probing $($preflightTargets.Count) target(s): $($preflightTargets -join ', ')"
            $remoteExecution = Resolve-RangerRemoteExecutionCredential -Targets $preflightTargets -ClusterCredential $credentialMap.cluster -DomainCredential $credentialMap.domain -RetryCount $retryCount -TimeoutSeconds $timeoutSec
            $manifest.run.remoteExecution = [ordered]@{
                selectedSource = $remoteExecution.SelectedSource
                userName       = $remoteExecution.UserName
                detail         = $remoteExecution.Detail
                targets        = @($preflightTargets)
                results        = @($remoteExecution.Results)
            }
            if ($remoteExecution.Credential -or $remoteExecution.SelectedSource -eq 'current-context') {
                $credentialMap.cluster = $remoteExecution.Credential
            }
            Write-RangerLog -Level info -Message $remoteExecution.Detail
            foreach ($rr in @($remoteExecution.Results)) {
                Write-RangerLog -Level info -Message "Remote authorization preflight: '$($rr.Target)' reached '$($rr.RemoteComputerName)' as '$($rr.RemoteIdentity)' via $($remoteExecution.SelectedSource) credential '$($remoteExecution.UserName)'"
            }
        }

        # Issue #30 — Build connectivity matrix after WinRM preflight so we know which
        # transport surfaces are reachable before any collector attempts a connection.
        # The matrix is stored in the manifest for observability and passed to each
        # collector execution so unreachable transports produce 'skipped' not 'failed'.
        $connectivityMatrix = $null
        if (Get-Command -Name 'Get-RangerConnectivityMatrix' -ErrorAction SilentlyContinue) {
            $ctxTimeout = if ($config.behavior -and $config.behavior.timeoutSeconds -gt 0) { [int]$config.behavior.timeoutSeconds } else { 10 }
            Write-RangerLog -Level info -Message "Connectivity matrix probe starting (timeout: $ctxTimeout s)"
            $connectivityMatrix = Get-RangerConnectivityMatrix -Config $config -TimeoutSeconds $ctxTimeout
            $manifest.run.connectivity = [ordered]@{
                posture      = $connectivityMatrix.posture
                probeTimeUtc = $connectivityMatrix.probeTimeUtc
                cluster      = $connectivityMatrix.cluster
                azure        = $connectivityMatrix.azure
                bmc          = $connectivityMatrix.bmc
                arc          = $connectivityMatrix.arc
            }
            Write-RangerLog -Level info -Message "Connectivity posture: $($connectivityMatrix.posture) — cluster=$($connectivityMatrix.cluster.reachable), azure=$($connectivityMatrix.azure.reachable), bmc=$($connectivityMatrix.bmc.reachable)"

            # Issue #26: probe Arc Run Command availability and update matrix.arc.available
            # so downstream code (and the manifest) can reflect the actual transport posture.
            if (Get-Command -Name 'Test-RangerArcTransportAvailable' -ErrorAction SilentlyContinue) {
                $arcAvailable = Test-RangerArcTransportAvailable -Config $config
                $connectivityMatrix.arc.available = $arcAvailable
                $manifest.run.connectivity.arc = [ordered]@{ available = $arcAvailable }
                Write-RangerLog -Level info -Message "Arc Run Command transport available: $arcAvailable"
            }

            # Surface a finding for any unreachable transport that has configured targets
            if (-not $connectivityMatrix.azure.reachable -and $connectivityMatrix.azure.enabled) {
                if (Get-Command -Name 'New-RangerConnectivityFinding' -ErrorAction SilentlyContinue) {
                    $manifest.findings += @(New-RangerConnectivityFinding -Surface 'azure' -Detail 'management.azure.com:443 unreachable')
                }
            }
            if (-not $connectivityMatrix.bmc.reachable -and @($connectivityMatrix.bmc.endpoints).Count -gt 0) {
                if (Get-Command -Name 'New-RangerConnectivityFinding' -ErrorAction SilentlyContinue) {
                    $bmcDetail = ($connectivityMatrix.bmc.endpoints | ForEach-Object { "$($_.host): unreachable" }) -join '; '
                    $manifest.findings += @(New-RangerConnectivityFinding -Surface 'bmc' -Detail $bmcDetail)
                }
            }
        }

        # Issue #76 / #170: initialise Spectre.Console progress display — degrades gracefully
        # when PwshSpectreConsole is absent, in CI, or in Unattended / non-interactive mode.
        # Default to $true when the config key is absent so operators get progress display
        # without needing to add showProgress: true to every config file.
        $progressCtx = $null
        $showProgress = if ($config.output -is [System.Collections.IDictionary] -and $config.output.Contains('showProgress')) {
            [bool]$config.output['showProgress']
        } else {
            $true
        }
        if ($showProgress -and -not $Unattended -and (Get-Command -Name 'New-RangerProgressContext' -ErrorAction SilentlyContinue)) {
            $progressCtx = New-RangerProgressContext -Collectors $selectedCollectors
        }

        foreach ($collector in $selectedCollectors) {
            Write-RangerLog -Level info -Message "Collector '$($collector.Id)' starting"
            if ($progressCtx -and (Get-Command -Name 'Update-RangerProgressCollectorStart' -ErrorAction SilentlyContinue)) {
                Update-RangerProgressCollectorStart -Context $progressCtx -CollectorId $collector.Id
            }
            $collectorResult = Invoke-RangerCollectorExecution -Definition $collector -Config $config -CredentialMap $credentialMap -PackageRoot $packageRoot -ConnectivityMatrix $connectivityMatrix
            Write-RangerLog -Level info -Message "Collector '$($collector.Id)' completed with status '$($collectorResult.Status)'"
            if ($progressCtx -and (Get-Command -Name 'Update-RangerProgressCollectorDone' -ErrorAction SilentlyContinue)) {
                Update-RangerProgressCollectorDone -Context $progressCtx -CollectorId $collector.Id -Status $collectorResult.Status
            }
            Add-RangerCollectorToManifest -Manifest ([ref]$manifest) -CollectorResult $collectorResult -EvidenceRoot $evidenceRoot -KeepRawEvidence ([bool]$config.output.keepRawEvidence)
        }

        if ($progressCtx -and (Get-Command -Name 'Complete-RangerProgressDisplay' -ErrorAction SilentlyContinue)) {
            Complete-RangerProgressDisplay -Context $progressCtx
        }

        $manifest.run.retryDetails = @($script:RangerRetryDetails)

        # v1.6.0 (#206): surface skipped subscriptions / resources in the manifest.
        $skipped = @(Get-RangerSkippedResources)
        $manifest.run.skippedResources = $skipped
        if ($skipped.Count -gt 0) {
            $summary = @($skipped | Group-Object -Property category | ForEach-Object { "{0}: {1}" -f $_.Name, $_.Count }) -join ', '
            $manifest.findings += @(
                New-RangerFinding -Severity warning -Title 'Partial discovery — some Azure resources were skipped' -Description 'One or more ARM queries failed and were skipped so the run could continue.' -CurrentState "Skipped $($skipped.Count) ($summary)" -Recommendation 'Review manifest.run.skippedResources for per-item reasons and verify RBAC / network reachability.'
            )
            if ([bool]$config.behavior.failOnPartialDiscovery) {
                throw "behavior.failOnPartialDiscovery=true — aborting because $($skipped.Count) resource(s) were skipped during collection ($summary)."
            }
        }

        # v2.0.0: post-collection analysis — VM distribution (#223), agent version
        # grouping (#224), AHB cost/licensing (#222). Helpers are idempotent and
        # respect values already present in the manifest (e.g. fixture-provided).
        if (Get-Command -Name 'Invoke-RangerManifestPostAnalysis' -ErrorAction SilentlyContinue) {
            try { Invoke-RangerManifestPostAnalysis -Manifest $manifest }
            catch { Write-RangerLog -Level warn -Message "Post-analysis warning: $($_.Exception.Message)" }
        }

        # v2.0.0 (#230): empty-data safeguard — if collection returned no nodes,
        # reporting would render empty tables with no actionable error.
        $nodeCount = @($manifest.domains.clusterNode.nodes).Count
        if ($nodeCount -eq 0) {
            $clusterTarget = [string]$config.targets.cluster.fqdn
            throw "Ranger: collection completed but returned no node data. Verify WinRM connectivity to '$clusterTarget' and that the credentials have read access to root/MSCluster."
        }

        $manifestValidation = Test-RangerManifestSchema -Manifest $manifest -SelectedCollectors $selectedCollectors
        $manifest.run.schemaValidation = [ordered]@{
            isValid  = $manifestValidation.IsValid
            errors   = @($manifestValidation.Errors)
            warnings = @($manifestValidation.Warnings)
        }

        if ($manifestValidation.Warnings.Count -gt 0) {
            $manifest.findings += @(
                New-RangerFinding -Severity informational -Title 'Manifest schema warnings were recorded' -Description 'The generated manifest passed core validation but recorded schema warnings that should be reviewed before handoff.' -CurrentState ($manifestValidation.Warnings -join '; ') -Recommendation 'Review duplicate artifact paths or incomplete metadata before packaging the deliverable.'
            )
        }

        if (-not $manifestValidation.IsValid) {
            $manifest.findings += @(
                New-RangerFinding -Severity warning -Title 'Manifest schema validation failed' -Description 'The generated manifest did not satisfy the minimum schema contract for Ranger outputs.' -CurrentState ($manifestValidation.Errors -join '; ') -Recommendation 'Correct the collector payload or manifest contract before treating this package as a handoff-ready deliverable.'
            )
        }

        if ($resolvedBaselineManifestPath) {
            if (-not (Test-Path -Path $resolvedBaselineManifestPath)) {
                throw "Baseline manifest file not found: $resolvedBaselineManifestPath"
            }

            $baselineManifest = Get-Content -Path $resolvedBaselineManifestPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
            $driftReport = New-RangerDriftReport -CurrentManifest $manifest -BaselineManifest (ConvertTo-RangerHashtable -InputObject $baselineManifest) -BaselineManifestPath $resolvedBaselineManifestPath
            $manifest.run.drift = [ordered]@{
                status        = $driftReport.status
                summary       = $driftReport.summary
                skippedReason = $driftReport.skippedReason
            }

            $driftArtifactPath = Write-RangerJsonArtifact -PackageRoot $packageRoot -RelativePath 'manifest\drift-report.json' -Content $driftReport
            $manifest.artifacts += @(
                New-RangerArtifactRecord -Type 'drift-report' -RelativePath ([System.IO.Path]::GetRelativePath($packageRoot, $driftArtifactPath)) -Status $(if ($driftReport.status -eq 'generated') { 'generated' } else { 'skipped' }) -Audience 'all' -Reason $driftReport.skippedReason
            )

            if ($driftReport.status -eq 'generated') {
                foreach ($change in @($driftReport.changes)) {
                    $manifest.findings += @(
                        New-RangerFinding -Severity informational -Title "Detected manifest drift: $($change.changeType)" -Description "Detected a $($change.changeType) change at $($change.path)." -CurrentState $(if ($null -ne $change.baselineValue -and $null -ne $change.currentValue) { "baseline=$($change.baselineValue | ConvertTo-Json -Depth 5 -Compress); current=$($change.currentValue | ConvertTo-Json -Depth 5 -Compress)" } elseif ($null -ne $change.currentValue) { "current=$($change.currentValue | ConvertTo-Json -Depth 5 -Compress)" } else { "baseline=$($change.baselineValue | ConvertTo-Json -Depth 5 -Compress)" }) -Recommendation 'Review whether this environment drift was expected and update the baseline manifest after the change is approved.'
                    )
                }
            }
            else {
                $manifest.findings += @(
                    New-RangerFinding -Severity informational -Title 'Baseline comparison was skipped' -Description 'Ranger received a baseline manifest path but did not generate a drift comparison.' -CurrentState $driftReport.skippedReason -Recommendation 'Confirm the baseline manifest schema version matches the current run before relying on drift analysis.'
                )
            }
        }

        Save-RangerManifest -Manifest $manifest -Path $manifestPath
        $manifest.artifacts += @(New-RangerArtifactRecord -Type 'manifest-json' -RelativePath ([System.IO.Path]::GetRelativePath($packageRoot, $manifestPath)) -Status generated -Audience 'all')

        if (-not $manifestValidation.IsValid -and [bool]$config.behavior.failOnSchemaViolation) {
            Save-RangerManifest -Manifest $manifest -Path $manifestPath
            throw ($manifestValidation.Errors -join [Environment]::NewLine)
        }

        if (-not $NoRender -and [bool]$config.behavior.continueToRendering) {
            $renderResult = Invoke-RangerOutputGeneration -Manifest $manifest -PackageRoot $packageRoot -Formats @($config.output.formats) -Mode $config.output.mode
            if ($renderResult.Artifacts) {
                $manifest.artifacts += @($renderResult.Artifacts)
            }
            Save-RangerManifest -Manifest $manifest -Path $manifestPath
        }

        $packageIndexPath = New-RangerPackageIndex -Manifest $manifest -ManifestPath $manifestPath -PackageRoot $packageRoot
        $manifest.artifacts += @(New-RangerArtifactRecord -Type 'package-index' -RelativePath ([System.IO.Path]::GetRelativePath($packageRoot, $packageIndexPath)) -Status generated -Audience 'all')

        if ($logPath -and (Test-Path -LiteralPath $logPath)) {
            Write-RangerLog -Level info -Message "Run complete — package: $(Split-Path -Leaf $packageRoot)"
            $manifest.artifacts += @(New-RangerArtifactRecord -Type 'run-log' -RelativePath ([System.IO.Path]::GetRelativePath($packageRoot, $logPath)) -Status generated -Audience 'all')
        }

        $runStatus = New-RangerRunStatus -Unattended ([bool]$Unattended) -Status 'success' -Manifest $manifest -ManifestPath $manifestPath -LogPath $logPath -DriftStatus $(if ($driftReport) { $driftReport.status } else { 'not-requested' })
        $runStatusPath = Write-RangerJsonArtifact -PackageRoot $packageRoot -RelativePath 'run-status.json' -Content $runStatus
        $manifest.artifacts += @(New-RangerArtifactRecord -Type 'run-status' -RelativePath ([System.IO.Path]::GetRelativePath($packageRoot, $runStatusPath)) -Status generated -Audience 'all')

        Save-RangerManifest -Manifest $manifest -Path $manifestPath

        if ($Unattended -and @($manifest.collectors.Values | Where-Object { $_.status -eq 'failed' }).Count -gt 0) {
            throw 'Unattended run completed with one or more failed collectors. See run-status.json and ranger.log for details.'
        }

        [ordered]@{
            Config       = $config
            Manifest     = $manifest
            ManifestPath = $manifestPath
            PackageRoot  = $packageRoot
            LogPath      = $logPath
            Validation   = $validation
            ManifestSchema = $manifestValidation
        }
    }
    catch {
        if ($packageRoot) {
            $failureDriftStatus = if ($driftReport) { $driftReport.status } else { 'not-requested' }
            $failureRunStatus = New-RangerRunStatus -Unattended ([bool]$Unattended) -Status 'failed' -ErrorMessage $_.Exception.Message -Manifest $manifest -ManifestPath $manifestPath -LogPath $logPath -DriftStatus $failureDriftStatus
            $runStatusPath = Write-RangerJsonArtifact -PackageRoot $packageRoot -RelativePath 'run-status.json' -Content $failureRunStatus

            if ($manifest) {
                if (-not @($manifest.artifacts | Where-Object { $_.type -eq 'run-status' -and $_.relativePath -eq ([System.IO.Path]::GetRelativePath($packageRoot, $runStatusPath)) }).Count) {
                    $manifest.artifacts += @(New-RangerArtifactRecord -Type 'run-status' -RelativePath ([System.IO.Path]::GetRelativePath($packageRoot, $runStatusPath)) -Status generated -Audience 'all')
                }

                if ($manifestPath) {
                    Save-RangerManifest -Manifest $manifest -Path $manifestPath
                }
            }
        }

        throw
    }
    finally {
        try {
            Stop-Transcript | Out-Null
        }
        catch {
        }

        if ($logPath -and (Test-Path -LiteralPath $logPath) -and (Test-Path -LiteralPath $transcriptPath)) {
            try {
                Add-Content -LiteralPath $logPath -Value @('', '# Host transcript', '') -Encoding UTF8 -ErrorAction Stop
                Get-Content -LiteralPath $transcriptPath -ErrorAction Stop | Add-Content -LiteralPath $logPath -Encoding UTF8 -ErrorAction Stop
            }
            catch {
            }
        }

        # Restore whatever Write-Warning existed before the run (usually the built-in)
        if ($script:_rangerPrevWriteWarning) {
            Set-Item function:\global:Write-Warning -Value $script:_rangerPrevWriteWarning.ScriptBlock
        } else {
            Remove-Item function:\global:Write-Warning -ErrorAction SilentlyContinue
        }
        $VerbosePreference = $script:_rangerPrevVerbosePreference
        $DebugPreference = $script:_rangerPrevDebugPreference
        $InformationPreference = $script:_rangerPrevInformationPreference
        $ProgressPreference = $script:_rangerPrevProgressPreference
        $script:RangerLogPath = $null
        $script:RangerRetryDetails = $null
        $script:RangerWinRmProbeCache = $null
        $script:RangerBehaviorRetryCount = $null
    }
}
