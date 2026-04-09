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
        [string]$ComputerName,

        [PSCredential]$Credential
    )

    $userName = if ($Credential -and $Credential.UserName) { [string]$Credential.UserName } else { '<default>' }
    return '{0}|{1}' -f $ComputerName.Trim().ToLowerInvariant(), $userName.Trim().ToLowerInvariant()
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

    $cacheKey = Get-RangerWinRmProbeCacheKey -ComputerName $ComputerName -Credential $Credential
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
            $wsmanParams = @{
                ComputerName   = $ComputerName
                Authentication = 'Negotiate'
                ErrorAction    = 'Stop'
            }

            if ($Credential) {
                $wsmanParams.Credential = $Credential
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
            $rangerRemoteResult = Invoke-Command @invokeParams -WarningAction SilentlyContinue -WarningVariable +rangerRemoteWarnings -ErrorAction Stop
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