function Invoke-RangerRetry {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [int]$RetryCount = 2,
        [int]$DelaySeconds = 1
    )

    $attempt = 0
    do {
        try {
            return & $ScriptBlock
        }
        catch {
            $attempt++
            if ($attempt -gt $RetryCount) {
                throw
            }

            Start-Sleep -Seconds $DelaySeconds
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
        [int]$RetryCount = 1
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

        Invoke-Command @invokeParams
    }.GetNewClosure()

    Invoke-RangerRetry -RetryCount $RetryCount -ScriptBlock $retryBlock
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