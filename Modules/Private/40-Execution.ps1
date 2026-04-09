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

    $retryBlock = {
        $invokeParams = @{
            ComputerName = $ComputerName
            ScriptBlock  = $ScriptBlock
        }

        if ($Credential) {
            $invokeParams.Credential = $Credential
        }

        if ($ArgumentList) {
            $invokeParams.ArgumentList = $ArgumentList
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
                    Add-Content -LiteralPath $rangerLogPath -Value "[$((Get-Date).ToString('s'))][WARN] [$($ComputerName -join ',')] $warningMessage" -Encoding UTF8 -ErrorAction Stop
                }
                catch {
                }
            }
        }
        $rangerRemoteResult
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