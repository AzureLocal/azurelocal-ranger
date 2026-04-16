function Invoke-RangerRetry {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [int]$RetryCount = 2,
        [int]$DelaySeconds = 1,
        [string]$Label = 'operation',
        [string]$Target,
        [string[]]$RetryOnExceptionType = @(),
        [switch]$Exponential
    )

    $attempt = 0
    do {
        try {
            return & $ScriptBlock
        }
        catch {
            $attempt++
            $exceptionType = if ($_.Exception) { $_.Exception.GetType().FullName } else { 'UnknownException' }
            $shouldRetry = $RetryOnExceptionType.Count -eq 0 -or $exceptionType -in $RetryOnExceptionType
            if (-not $shouldRetry -or $attempt -gt $RetryCount) {
                throw
            }

            $delay = if ($Exponential) { [math]::Pow(2, $attempt - 1) * $DelaySeconds } else { $DelaySeconds }
            Write-RangerLog -Level debug -Message "Retry attempt $attempt/$RetryCount for '$Label'$(if ($Target) { " on '$Target'" }) after ${exceptionType}: $($_.Exception.Message)"
            Add-RangerRetryDetail -Target $Target -Label $Label -Attempt $attempt -ExceptionType $exceptionType -Message $_.Exception.Message
            Start-Sleep -Seconds $delay
        }
    } while ($true)
}

function Get-RangerWinRmProbeCacheKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    # Issue #158: cache key is target-only — Test-WSMan probes connectivity (port + WinRM service
    # reachability), not credential authorization. Keying on credential caused one probe per
    # candidate, redundant re-probes, and misleading "preflight succeeded" log lines immediately
    # before "Access is denied" errors.
    return $ComputerName.Trim().ToLowerInvariant()
}

function Test-RangerWinRmTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [PSCredential]$Credential
    )

    if (-not $script:RangerWinRmProbeCache) {
        $script:RangerWinRmProbeCache = @{}
    }

    $cacheKey = Get-RangerWinRmProbeCacheKey -ComputerName $ComputerName
    if ($script:RangerWinRmProbeCache.ContainsKey($cacheKey)) {
        return $script:RangerWinRmProbeCache[$cacheKey]
    }

    $probeMessages = New-Object System.Collections.Generic.List[string]
    $probeOptions = @(
        [ordered]@{ transport = 'http';  port = 5985; useSsl = $false },
        [ordered]@{ transport = 'https'; port = 5986; useSsl = $true }
    )

    foreach ($probe in $probeOptions) {
        $portReachable = $true
        if (Test-RangerCommandAvailable -Name 'Test-NetConnection') {
            try {
                $connection = Test-NetConnection -ComputerName $ComputerName -Port $probe.port -WarningAction SilentlyContinue
                $portReachable = [bool]$connection.TcpTestSucceeded
            }
            catch {
                $portReachable = $false
            }

            if (-not $portReachable) {
                $probeMessages.Add("TCP $($probe.port) unreachable")
                continue
            }
        }

        if (Test-RangerCommandAvailable -Name 'Test-WSMan') {
            # Issue #158: do not pass credential to Test-WSMan — this is a connectivity probe
            # (can we reach the WinRM service?), not an authorization probe. Passing a credential
            # caused Test-WSMan to succeed with bad credentials and emit misleading log output.
            $wsmanParams = @{
                ComputerName   = $ComputerName
                Authentication = 'None'
                ErrorAction    = 'Stop'
            }

            if ($probe.useSsl) {
                $wsmanParams.UseSSL = $true
            }

            try {
                $null = Test-WSMan @wsmanParams
                $state = [ordered]@{
                    Reachable = $true
                    Transport = $probe.transport
                    Port      = $probe.port
                    Message   = "WinRM preflight succeeded over $($probe.transport.ToUpperInvariant())"
                }
                $script:RangerWinRmProbeCache[$cacheKey] = $state
                Write-RangerLog -Level debug -Message "WinRM preflight succeeded for '$ComputerName' over $($probe.transport.ToUpperInvariant())"
                return $state
            }
            catch {
                $probeMessages.Add("WSMan $($probe.transport) failed: $($_.Exception.Message)")
                continue
            }
        }

        $state = [ordered]@{
            Reachable = $true
            Transport = $probe.transport
            Port      = $probe.port
            Message   = 'WinRM preflight tooling unavailable; assuming target is reachable.'
        }
        $script:RangerWinRmProbeCache[$cacheKey] = $state
        Write-RangerLog -Level debug -Message "WinRM preflight skipped for '$ComputerName' because Test-WSMan is unavailable"
        return $state
    }

    $state = [ordered]@{
        Reachable = $false
        Transport = $null
        Port      = $null
        Message   = "WinRM preflight failed for '$ComputerName': $($probeMessages -join ' | ')"
    }
    $script:RangerWinRmProbeCache[$cacheKey] = $state
    Write-RangerLog -Level warn -Message $state.Message
    return $state
}

function Get-RangerExecutionHostContext {
    $computerName = $env:COMPUTERNAME
    $domain = $null
    $isDomainJoined = $null

    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $computerName = if (-not [string]::IsNullOrWhiteSpace([string]$computerSystem.Name)) { [string]$computerSystem.Name } else { $computerName }
        $domain = if (-not [string]::IsNullOrWhiteSpace([string]$computerSystem.Domain)) { [string]$computerSystem.Domain } else { $null }
        $isDomainJoined = [bool]$computerSystem.PartOfDomain
    }
    catch {
    }

    [ordered]@{
        ComputerName    = $computerName
        Domain          = $domain
        IsDomainJoined  = $isDomainJoined
    }
}

function Get-RangerRemoteCredentialCandidates {
    param(
        [PSCredential]$ClusterCredential,

        [PSCredential]$DomainCredential
    )

    $candidates = New-Object System.Collections.Generic.List[object]
    $seenUsers = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    if ($ClusterCredential) {
        [void]$seenUsers.Add([string]$ClusterCredential.UserName)
        [void]$candidates.Add([ordered]@{
            Name       = 'cluster'
            Credential = $ClusterCredential
            UserName   = [string]$ClusterCredential.UserName
        })
    }

    if ($DomainCredential -and $seenUsers.Add([string]$DomainCredential.UserName)) {
        [void]$candidates.Add([ordered]@{
            Name       = 'domain'
            Credential = $DomainCredential
            UserName   = [string]$DomainCredential.UserName
        })
    }

    if (-not $ClusterCredential -and -not $DomainCredential) {
        [void]$candidates.Add([ordered]@{
            Name       = 'current-context'
            Credential = $null
            UserName   = '<current-context>'
        })
    }

    return $candidates.ToArray()
}

function Test-RangerRemoteAuthorization {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [PSCredential]$Credential,

        [int]$RetryCount = 1,
        [int]$TimeoutSeconds = 0
    )

    $result = @(
        Invoke-RangerRemoteCommand -ComputerName @($ComputerName) -Credential $Credential -RetryCount $RetryCount -TimeoutSeconds $TimeoutSeconds -ScriptBlock {
            $identity = try { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } catch { $env:USERNAME }
            [ordered]@{
                computerName = $env:COMPUTERNAME
                identity     = $identity
            }
        }
    ) | Select-Object -First 1

    if ($null -eq $result) {
        throw "Authorization probe returned no data from '$ComputerName'."
    }

    return [ordered]@{
        Target             = $ComputerName
        CredentialUserName = if ($Credential) { [string]$Credential.UserName } else { '<current-context>' }
        RemoteComputerName = [string]$result.computerName
        RemoteIdentity     = [string]$result.identity
    }
}

function Resolve-RangerRemoteExecutionCredential {
    param(
        [string[]]$Targets,

        [PSCredential]$ClusterCredential,

        [PSCredential]$DomainCredential,

        [int]$RetryCount = 1,

        [int]$TimeoutSeconds = 0
    )

    $candidateResults = New-Object System.Collections.Generic.List[object]
    $targets = @($Targets | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $candidates = @(Get-RangerRemoteCredentialCandidates -ClusterCredential $ClusterCredential -DomainCredential $DomainCredential)

    if ($targets.Count -eq 0) {
        return [ordered]@{
            SelectedSource = 'none'
            Credential     = $null
            UserName       = $null
            Detail         = 'No remoting targets are configured.'
            Results        = @()
        }
    }

    foreach ($candidate in $candidates) {
        $authorizationResults = New-Object System.Collections.Generic.List[object]
        $failures = New-Object System.Collections.Generic.List[string]

        foreach ($target in $targets) {
            try {
                # Issue #157: use RetryCount 0 for authorization probes — "Access is denied" is not
                # transient and must not be retried; the actual collection run uses $RetryCount.
                $authorization = Test-RangerRemoteAuthorization -ComputerName $target -Credential $candidate.Credential -RetryCount 0 -TimeoutSeconds $TimeoutSeconds
                [void]$authorizationResults.Add($authorization)
            }
            catch {
                [void]$failures.Add(("{0}: {1}" -f $target, $_.Exception.Message))
            }
        }

        if ($failures.Count -eq 0) {
            return [ordered]@{
                SelectedSource = [string]$candidate.Name
                Credential     = $candidate.Credential
                UserName       = [string]$candidate.UserName
                Detail         = "Selected $($candidate.Name) remoting credential '$($candidate.UserName)' after authorization preflight succeeded on $($targets.Count) target(s)."
                Results        = $authorizationResults.ToArray()
            }
        }

        [void]$candidateResults.Add([ordered]@{
            Name     = [string]$candidate.Name
            UserName = [string]$candidate.UserName
            Failures = $failures.ToArray()
        })
    }

    $hostContext = Get-RangerExecutionHostContext
    $hostGuidance = if ($hostContext.IsDomainJoined -eq $false) {
        "Execution host '$($hostContext.ComputerName)' is not domain-joined. Prefer a qualified domain account (DOMAIN\\user or user@fqdn.domain), FQDN targets, and WinRM paths validated against actual remote command execution."
    }
    elseif ($hostContext.IsDomainJoined -eq $true) {
        "Execution host '$($hostContext.ComputerName)' is domain-joined to '$($hostContext.Domain)'. The failure is more likely the selected remoting credential or target-side authorization than runner domain membership."
    }
    else {
        "Execution host domain-join state could not be determined."
    }

    $failureSummary = @($candidateResults | ForEach-Object {
        "{0} credential '{1}' failed authorization: {2}" -f $_.Name, $_.UserName, ($_.Failures -join ' | ')
    }) -join ' '

    throw "No remoting credential could authorize on all targets. $failureSummary $hostGuidance"
}

function Invoke-RangerRemoteCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ComputerName,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [PSCredential]$Credential,
        [object[]]$ArgumentList,
        [int]$RetryCount = 1,
        [int]$TimeoutSeconds = 0
    )

    $targetStates = @($ComputerName | ForEach-Object {
        [ordered]@{
            computerName = $_
            state        = Test-RangerWinRmTarget -ComputerName $_ -Credential $Credential
        }
    })

    $reachableStates = @($targetStates | Where-Object { $_.state.Reachable })
    if ($reachableStates.Count -eq 0) {
        $messages = @($targetStates | ForEach-Object { "$($_.computerName): $($_.state.Message)" })
        throw [System.InvalidOperationException]::new("No reachable WinRM targets available. $($messages -join ' ; ')")
    }

    $unreachableTargets = @($targetStates | Where-Object { -not $_.state.Reachable } | ForEach-Object { $_.computerName })
    if ($unreachableTargets.Count -gt 0) {
        Write-RangerLog -Level warn -Message "Skipping unreachable WinRM targets: $($unreachableTargets -join ', ')"
    }

    $targetGroups = @($reachableStates | Group-Object -Property { $_.state.Transport })

    $retryBlock = {
        $results = New-Object System.Collections.Generic.List[object]

        foreach ($group in $targetGroups) {
            $groupTargets = @($group.Group | ForEach-Object { $_.computerName })
            $invokeParams = @{
                ComputerName   = $groupTargets
                ScriptBlock    = $ScriptBlock
                Authentication = 'Negotiate'
            }

            if ($Credential) {
                $invokeParams.Credential = $Credential
            }

            if ($ArgumentList) {
                $invokeParams.ArgumentList = $ArgumentList
            }

            if ($group.Name -eq 'https') {
                $invokeParams.UseSSL = $true
            }

            # Issue #113: apply per-session operation timeout when configured
            if ($TimeoutSeconds -gt 0) {
                $sessionOption = New-PSSessionOption -OperationTimeout ($TimeoutSeconds * 1000) -OpenTimeout ($TimeoutSeconds * 1000)
                $invokeParams.SessionOption = $sessionOption
            }

            $rangerRemoteWarnings = @()
            $rangerLogPath = $script:RangerLogPath
            $rangerCurrentLogLevel = if ($script:RangerLogLevel) { [string]$script:RangerLogLevel } else { 'info' }
            $rangerShouldLogWarn = $rangerCurrentLogLevel -in @('debug', 'info', 'warn')
            # Issue #159: catch at the innermost frame so the exception is re-thrown once rather
            # than propagating through Invoke-RangerRetry → Invoke-RangerRemoteCommand →
            # Test-RangerRemoteAuthorization, each recording a duplicate TerminatingError line in
            # the PowerShell transcript.
            try {
                $rangerRemoteResult = Invoke-Command @invokeParams -WarningAction SilentlyContinue -WarningVariable +rangerRemoteWarnings -ErrorAction Stop
            } catch {
                throw
            }
            foreach ($w in @($rangerRemoteWarnings)) {
                $warningMessage = if ($w -is [System.Management.Automation.WarningRecord]) { [string]$w.Message } else { [string]$w }
                if ($rangerShouldLogWarn -and -not [string]::IsNullOrWhiteSpace($warningMessage) -and $rangerLogPath) {
                    try {
                        Add-Content -LiteralPath $rangerLogPath -Value "[$((Get-Date).ToString('s'))][WARN] [$($groupTargets -join ',')] $warningMessage" -Encoding UTF8 -ErrorAction Stop
                    }
                    catch {
                    }
                }
            }

            foreach ($item in @($rangerRemoteResult)) {
                [void]$results.Add($item)
            }
        }

        return $results.ToArray()
    }.GetNewClosure()

    $transientExceptions = @(
        'System.Net.WebException',
        'System.TimeoutException',
        'System.Net.Http.HttpRequestException',
        'Microsoft.Management.Infrastructure.CimException',
        'System.Management.Automation.Remoting.PSRemotingTransportException'
    )

    Invoke-RangerRetry -RetryCount $RetryCount -DelaySeconds 1 -Exponential -ScriptBlock $retryBlock -Label 'Invoke-RangerRemoteCommand' -Target ($ComputerName -join ',') -RetryOnExceptionType $transientExceptions
}

function Invoke-RangerRedfishRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential,

        [string]$Method = 'Get'
    )

    Invoke-RangerRetry -RetryCount 1 -ScriptBlock {
        Invoke-RestMethod -Uri $Uri -Method $Method -Credential $Credential -SkipCertificateCheck -ContentType 'application/json' -ErrorAction Stop
    }
}

function Invoke-RangerRedfishCollection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionUri,

        [Parameter(Mandatory = $true)]
        [string]$Host,

        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential
    )

    $results = @()
    $collection = Invoke-RangerRedfishRequest -Uri $CollectionUri -Credential $Credential
    foreach ($member in @($collection.Members)) {
        $path = $member.'@odata.id'
        if (-not $path) {
            continue
        }

        $uri = if ($path -match '^https?://') { $path } else { "https://$Host$path" }
        try {
            $results += Invoke-RangerRedfishRequest -Uri $uri -Credential $Credential
        }
        catch {
            Write-RangerLog -Level warn -Message "Redfish member retrieval failed for '$uri': $($_.Exception.Message)"
        }
    }

    return @($results)
}

function Connect-RangerAzureContext {
    param(
        $AzureCredentialSettings
    )

    $settings = if ($AzureCredentialSettings) { ConvertTo-RangerHashtable -InputObject $AzureCredentialSettings } else { [ordered]@{ method = 'existing-context' } }
    $method = if ($settings.method) { [string]$settings.method } else { 'existing-context' }

    if (-not (Test-RangerCommandAvailable -Name 'Get-AzContext')) {
        return $false
    }

    $context = Get-AzContext -ErrorAction SilentlyContinue
    if ($context) {
        if ($settings.subscriptionId -and $context.Subscription -and $context.Subscription.Id -ne $settings.subscriptionId -and (Test-RangerCommandAvailable -Name 'Set-AzContext')) {
            try {
                Set-AzContext -SubscriptionId $settings.subscriptionId -ErrorAction Stop | Out-Null
            }
            catch {
                Write-RangerLog -Level warn -Message "Failed to switch Az context to subscription '$($settings.subscriptionId)': $($_.Exception.Message)"
            }
        }

        return $true
    }

    switch ($method) {
        'managed-identity' {
            $connectParams = @{ Identity = $true; ErrorAction = 'Stop' }
            if ($settings.clientId) {
                $connectParams.AccountId = $settings.clientId
            }
            if ($settings.subscriptionId) {
                $connectParams.Subscription = $settings.subscriptionId
            }

            Connect-AzAccount @connectParams | Out-Null
            return $true
        }
        'device-code' {
            $connectParams = @{ UseDeviceAuthentication = $true; ErrorAction = 'Stop' }
            if ($settings.tenantId) {
                $connectParams.Tenant = $settings.tenantId
            }
            if ($settings.subscriptionId) {
                $connectParams.Subscription = $settings.subscriptionId
            }

            Connect-AzAccount @connectParams | Out-Null
            return $true
        }
        'service-principal' {
            if (-not $settings.clientSecretSecureString) {
                throw 'Azure service-principal authentication requires a resolved client secret.'
            }

            $credential = [PSCredential]::new([string]$settings.clientId, $settings.clientSecretSecureString)
            $connectParams = @{
                ServicePrincipal = $true
                Tenant           = $settings.tenantId
                Credential       = $credential
                ErrorAction      = 'Stop'
            }
            if ($settings.subscriptionId) {
                $connectParams.Subscription = $settings.subscriptionId
            }

            Connect-AzAccount @connectParams | Out-Null
            return $true
        }
        default {
            return $false
        }
    }
}

function Invoke-RangerAzureQuery {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [object[]]$ArgumentList,
        $AzureCredentialSettings
    )

    if (-not (Connect-RangerAzureContext -AzureCredentialSettings $AzureCredentialSettings)) {
        return $null
    }

    & $ScriptBlock @ArgumentList
}

function Test-RangerAzureCliAuthenticated {
    if (-not (Test-RangerCommandAvailable -Name 'az')) {
        return $false
    }

    & az account show --output json 2>$null | Out-Null
    return $LASTEXITCODE -eq 0
}

function Get-RangerFixtureData {
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $resolvedPath = Resolve-RangerPath -Path $Path
    if (-not (Test-Path -Path $resolvedPath)) {
        throw "Fixture file not found: $resolvedPath"
    }

    return Get-Content -Path $resolvedPath -Raw | ConvertFrom-Json -Depth 100
}
