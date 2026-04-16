function Test-RangerKeyVaultUri {
    param(
        [AllowNull()]
        $Value
    )

    $Value -is [string] -and $Value.StartsWith('keyvault://')
}

function ConvertFrom-RangerKeyVaultUri {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )

    if (-not (Test-RangerKeyVaultUri -Value $Uri)) {
        throw "Invalid Key Vault URI: $Uri"
    }

    $parts = $Uri.Substring(11).Split('/')
    if ($parts.Count -lt 2) {
        throw "Invalid Key Vault URI format: $Uri"
    }

    [ordered]@{
        VaultName  = $parts[0]
        SecretName = $parts[1]
        Version    = if ($parts.Count -gt 2) { $parts[2] } else { $null }
    }
}

function ConvertTo-RangerSecureString {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    $secureValue = [System.Security.SecureString]::new()
    foreach ($character in $Value.ToCharArray()) {
        $secureValue.AppendChar($character)
    }
    $secureValue.MakeReadOnly()
    return $secureValue
}

function Get-RangerSecretFromUri {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [switch]$AsPlainText
    )

    $parsed = ConvertFrom-RangerKeyVaultUri -Uri $Uri
    $providerFailures = [System.Collections.Generic.List[string]]::new()

    if (Test-RangerCommandAvailable -Name 'Get-AzKeyVaultSecret') {
        try {
            $secretParams = @{
                VaultName   = $parsed.VaultName
                Name        = $parsed.SecretName
                ErrorAction = 'Stop'
            }

            if ($parsed.Version) {
                $secretParams.Version = $parsed.Version
            }

            $secret = Get-AzKeyVaultSecret @secretParams
            if ($AsPlainText) {
                return ConvertTo-RangerPlainText -Value $secret.SecretValue
            }

            return $secret.SecretValue
        }
        catch {
            [void]$providerFailures.Add("Az.KeyVault failed: $($_.Exception.Message)")
        }
    }

    if (Test-RangerCommandAvailable -Name 'az') {
        try {
            $arguments = @('keyvault', 'secret', 'show', '--vault-name', $parsed.VaultName, '--name', $parsed.SecretName, '--query', 'value', '-o', 'tsv')
            if ($parsed.Version) {
                $arguments += @('--version', $parsed.Version)
            }

            $value = & az @arguments
            if ($LASTEXITCODE -ne 0) {
                throw "Azure CLI exited with code $LASTEXITCODE."
            }

            if ($AsPlainText) {
                return $value
            }

            return (ConvertTo-RangerSecureString -Value $value)
        }
        catch {
            [void]$providerFailures.Add("Azure CLI failed: $($_.Exception.Message)")
        }
    }

    if ($providerFailures.Count -gt 0) {
        $joined = $providerFailures -join ' '
        $dnsPatterns = @('getaddrinfo failed', 'No such host is known', 'could not be resolved', 'name or service not known')
        $isDnsFailure = $false
        foreach ($pattern in $dnsPatterns) {
            if ($joined -match [regex]::Escape($pattern)) { $isDnsFailure = $true; break }
        }

        if ($isDnsFailure) {
            $kvHost = "$($parsed.VaultName).vault.azure.net"
            $message = @(
                "Key Vault hostname '$kvHost' could not be resolved.",
                "Likely causes: (1) VPN or private endpoint network not connected, (2) Key Vault name '$($parsed.VaultName)' is incorrect in your config, (3) DNS resolver cannot reach the private zone.",
                "Action: verify the Key Vault name, confirm you are on the required network, or enable 'behavior.promptForMissingCredentials' in your config to be prompted interactively when KV is unreachable.",
                "Provider detail: $joined"
            ) -join ' '
            $ex = [System.Management.Automation.RuntimeException]::new($message)
            $ex.Data['RangerKeyVaultDnsFailure'] = $true
            $ex.Data['RangerKeyVaultHost'] = $kvHost
            $ex.Data['RangerKeyVaultUri'] = $Uri
            throw $ex
        }

        throw "Could not resolve Key Vault secret '$Uri'. $joined"
    }

    throw 'Neither Az.KeyVault nor the Azure CLI is available for Key Vault secret resolution.'
}

function Resolve-RangerPasswordValue {
    param(
        $CredentialBlock
    )

    if (-not $CredentialBlock) {
        return $null
    }

    if ($CredentialBlock.passwordSecureString -is [securestring]) {
        return $CredentialBlock.passwordSecureString
    }

    if ($CredentialBlock.password) {
        return (ConvertTo-RangerSecureString -Value ([string]$CredentialBlock.password))
    }

    if ($CredentialBlock.passwordRef) {
        return Get-RangerSecretFromUri -Uri $CredentialBlock.passwordRef
    }

    return $null
}

function Resolve-RangerCredentialDefinition {
    param(
        [string]$Name,
        $CredentialBlock,
        [PSCredential]$OverrideCredential,
        [bool]$AllowPrompt = $true
    )

    if ($OverrideCredential) {
        return $OverrideCredential
    }

    if ($CredentialBlock -is [PSCredential]) {
        return $CredentialBlock
    }

    if ($CredentialBlock -and $CredentialBlock.username) {
        try {
            $password = Resolve-RangerPasswordValue -CredentialBlock $CredentialBlock
            if ($password) {
                return [PSCredential]::new([string]$CredentialBlock.username, $password)
            }
        }
        catch {
            $isDnsFailure = $false
            if ($_.Exception.Data -and $_.Exception.Data.Contains('RangerKeyVaultDnsFailure')) {
                $isDnsFailure = [bool]$_.Exception.Data['RangerKeyVaultDnsFailure']
            }

            if ($isDnsFailure -and $AllowPrompt) {
                Write-Warning $_.Exception.Message
                Write-Warning "Falling back to interactive prompt for '$Name' credential because Key Vault is unreachable."
            }
            else {
                throw
            }
        }
    }

    if ($AllowPrompt -and $Name -ne 'azure') {
        try {
            return Get-Credential -Message "Enter the $Name credential for Azure Local Ranger"
        }
        catch {
            return $null
        }
    }

    return $null
}

function Resolve-RangerAzureCredentialSettings {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [switch]$SkipSecretResolution
    )

    $settings = if ($Config.credentials.azure) { ConvertTo-RangerHashtable -InputObject $Config.credentials.azure } else { [ordered]@{} }
    if (-not $settings.method) {
        $settings.method = 'existing-context'
    }

    if (-not $settings.Contains('tenantId') -and -not [string]::IsNullOrWhiteSpace($Config.targets.azure.tenantId)) {
        $settings.tenantId = $Config.targets.azure.tenantId
    }

    if (-not $settings.Contains('subscriptionId') -and -not [string]::IsNullOrWhiteSpace($Config.targets.azure.subscriptionId)) {
        $settings.subscriptionId = $Config.targets.azure.subscriptionId
    }

    if (-not $settings.Contains('useAzureCliFallback')) {
        $settings.useAzureCliFallback = $true
    }

    if (-not $SkipSecretResolution) {
        if ($settings.clientSecretRef) {
            $settings.clientSecretSecureString = Get-RangerSecretFromUri -Uri $settings.clientSecretRef
        }
        elseif ($settings.clientSecret) {
            $settings.clientSecretSecureString = ConvertTo-RangerSecureString -Value ([string]$settings.clientSecret)
        }
    }

    return $settings
}

function Resolve-RangerCredentialMap {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [hashtable]$Overrides
    )

    $allowPrompt = [bool]$Config.behavior.promptForMissingCredentials
    $overrides = if ($Overrides) { $Overrides } else { @{} }
    [ordered]@{
        azure    = Resolve-RangerAzureCredentialSettings -Config $Config
        cluster  = Resolve-RangerCredentialDefinition -Name 'cluster' -CredentialBlock $Config.credentials.cluster -OverrideCredential $overrides.cluster -AllowPrompt $allowPrompt
        domain   = Resolve-RangerCredentialDefinition -Name 'domain' -CredentialBlock $Config.credentials.domain -OverrideCredential $overrides.domain -AllowPrompt $allowPrompt
        bmc      = Resolve-RangerCredentialDefinition -Name 'bmc' -CredentialBlock $Config.credentials.bmc -OverrideCredential $overrides.bmc -AllowPrompt $allowPrompt
        firewall = Resolve-RangerCredentialDefinition -Name 'firewall' -CredentialBlock $Config.credentials.firewall -OverrideCredential $overrides.firewall -AllowPrompt $allowPrompt
        switch   = Resolve-RangerCredentialDefinition -Name 'switch' -CredentialBlock $Config.credentials.switch -OverrideCredential $overrides.switch -AllowPrompt $allowPrompt
    }
}
