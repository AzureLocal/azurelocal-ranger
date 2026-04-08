function Get-RangerDefaultConfig {
    [ordered]@{
        environment = [ordered]@{
            name        = 'prod-azlocal-01'
            clusterName = 'azlocal-prod-01'
            description = 'Primary production Azure Local instance'
        }
        targets = [ordered]@{
            cluster = [ordered]@{
                fqdn  = 'azlocal-prod-01.contoso.com'
                nodes = @(
                    'azl-node-01.contoso.com',
                    'azl-node-02.contoso.com'
                )
            }
            azure = [ordered]@{
                subscriptionId = '00000000-0000-0000-0000-000000000000'
                resourceGroup  = 'rg-azlocal-prod-01'
                tenantId       = '11111111-1111-1111-1111-111111111111'
            }
            bmc = [ordered]@{
                endpoints = @(
                    [ordered]@{ host = 'idrac-node-01.contoso.com'; node = 'azl-node-01.contoso.com' },
                    [ordered]@{ host = 'idrac-node-02.contoso.com'; node = 'azl-node-02.contoso.com' }
                )
            }
            switches  = @()
            firewalls = @()
        }
        credentials = [ordered]@{
            azure = [ordered]@{
                method             = 'existing-context'
                useAzureCliFallback = $true
            }
            cluster = [ordered]@{
                username    = 'CONTOSO\ranger-read'
                passwordRef = 'keyvault://kv-ranger/cluster-read'
            }
            domain = [ordered]@{
                username    = 'CONTOSO\ranger-read'
                passwordRef = 'keyvault://kv-ranger/domain-read'
            }
            bmc = [ordered]@{
                username    = 'root'
                passwordRef = 'keyvault://kv-ranger/idrac-root'
            }
        }
        domains = [ordered]@{
            include = @()
            exclude = @()
            hints   = [ordered]@{
                fixtures           = [ordered]@{}
                networkDeviceConfigs = @()
            }
        }
        output = [ordered]@{
            mode            = 'current-state'
            formats         = @('html', 'markdown', 'json', 'svg')
            rootPath        = './artifacts'
            diagramFormat   = 'svg'
            keepRawEvidence = $true
        }
        behavior = [ordered]@{
            promptForMissingCredentials   = $true
            skipUnavailableOptionalDomains = $true
            failOnSchemaViolation         = $true
            logLevel                      = 'info'
            retryCount                    = 2
            timeoutSeconds                = 60
            continueToRendering           = $true
        }
    }
}

function ConvertTo-RangerYaml {
    param(
        [Parameter(Mandatory = $true)]
        $InputObject,

        [int]$Indent = 0
    )

    $prefix = ' ' * $Indent
    $lines = New-Object System.Collections.Generic.List[string]

    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($key in $InputObject.Keys) {
            $value = $InputObject[$key]
            if ($value -is [System.Collections.IDictionary]) {
                $lines.Add(('{0}{1}:' -f $prefix, $key))
                foreach ($line in (ConvertTo-RangerYaml -InputObject $value -Indent ($Indent + 2))) {
                    $lines.Add($line)
                }
                continue
            }

            if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
                $lines.Add(('{0}{1}:' -f $prefix, $key))
                foreach ($item in $value) {
                    if ($item -is [System.Collections.IDictionary]) {
                        $first = $true
                        foreach ($itemKey in $item.Keys) {
                            $itemValue = $item[$itemKey]
                            if ($itemValue -is [System.Collections.IDictionary] -or ($itemValue -is [System.Collections.IEnumerable] -and $itemValue -isnot [string])) {
                                $lines.Add((if ($first) { ('{0}  - {1}:' -f $prefix, $itemKey) } else { ('{0}    {1}:' -f $prefix, $itemKey) }))
                                foreach ($childLine in (ConvertTo-RangerYaml -InputObject $itemValue -Indent ($Indent + 6))) {
                                    $lines.Add($childLine)
                                }
                            }
                            else {
                                $scalar = ConvertTo-RangerYamlScalar -Value $itemValue
                                $lines.Add((if ($first) { ('{0}  - {1}: {2}' -f $prefix, $itemKey, $scalar) } else { ('{0}    {1}: {2}' -f $prefix, $itemKey, $scalar) }))
                            }
                            $first = $false
                        }
                    }
                    else {
                        $lines.Add("$prefix  - $(ConvertTo-RangerYamlScalar -Value $item)")
                    }
                }
                continue
            }

            $lines.Add(('{0}{1}: {2}' -f $prefix, $key, (ConvertTo-RangerYamlScalar -Value $value)))
        }

        return $lines
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        foreach ($item in $InputObject) {
            $lines.Add("$prefix- $(ConvertTo-RangerYamlScalar -Value $item)")
        }

        return $lines
    }

    return @("$prefix$(ConvertTo-RangerYamlScalar -Value $InputObject)")
}

function ConvertTo-RangerYamlScalar {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return 'null'
    }

    if ($Value -is [bool]) {
        return $Value.ToString().ToLowerInvariant()
    }

    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double]) {
        return [string]$Value
    }

    $text = [string]$Value
    if ($text -match '^[A-Za-z0-9._/-]+$') {
        return $text
    }

    return "'$($text -replace '''', '''''')'"
}

function Merge-RangerConfiguration {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$BaseConfig,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$OverrideConfig
    )

    $result = ConvertTo-RangerHashtable -InputObject $BaseConfig
    foreach ($key in $OverrideConfig.Keys) {
        $overrideValue = $OverrideConfig[$key]
        if ($result.Contains($key) -and $result[$key] -is [System.Collections.IDictionary] -and $overrideValue -is [System.Collections.IDictionary]) {
            $result[$key] = Merge-RangerConfiguration -BaseConfig $result[$key] -OverrideConfig $overrideValue
            continue
        }

        $result[$key] = ConvertTo-RangerHashtable -InputObject $overrideValue
    }

    $result
}

function Import-RangerConfiguration {
    param(
        [string]$ConfigPath,
        $ConfigObject
    )

    if ($ConfigObject) {
        return Merge-RangerConfiguration -BaseConfig (Get-RangerDefaultConfig) -OverrideConfig (ConvertTo-RangerHashtable -InputObject $ConfigObject)
    }

    if (-not $ConfigPath) {
        throw 'Either ConfigPath or ConfigObject must be supplied.'
    }

    $resolvedConfigPath = Resolve-RangerPath -Path $ConfigPath
    if (-not (Test-Path -Path $resolvedConfigPath)) {
        throw "Configuration file not found: $resolvedConfigPath"
    }

    $extension = [System.IO.Path]::GetExtension($resolvedConfigPath).ToLowerInvariant()
    switch ($extension) {
        '.json' {
            $loaded = Get-Content -Path $resolvedConfigPath -Raw | ConvertFrom-Json -Depth 100
        }
        '.psd1' {
            $loaded = Import-PowerShellDataFile -Path $resolvedConfigPath
        }
        '.yml' {
            $loaded = Import-RangerYamlFile -Path $resolvedConfigPath
        }
        '.yaml' {
            $loaded = Import-RangerYamlFile -Path $resolvedConfigPath
        }
        default {
            throw "Unsupported configuration format: $extension"
        }
    }

    return Merge-RangerConfiguration -BaseConfig (Get-RangerDefaultConfig) -OverrideConfig (ConvertTo-RangerHashtable -InputObject $loaded)
}

function Import-RangerYamlFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-RangerCommandAvailable -Name 'ConvertFrom-Yaml') {
        return Get-Content -Path $Path -Raw | ConvertFrom-Yaml
    }

    if (Get-Module -ListAvailable -Name 'powershell-yaml') {
        Import-Module powershell-yaml -ErrorAction Stop
        return Get-Content -Path $Path -Raw | ConvertFrom-Yaml
    }

    throw 'YAML parsing requires the powershell-yaml module or a runtime that provides ConvertFrom-Yaml.'
}

function Resolve-RangerCanonicalDomainName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $aliases = Get-RangerDomainAliases
    $key = $Name.Trim().ToLowerInvariant()
    if ($aliases.Keys -contains $key) {
        return $aliases[$key]
    }

    return $key
}

function Resolve-RangerSelectedCollectors {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config
    )

    $definitions = Get-RangerCollectorDefinitions
    $include = @($Config.domains.include | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { Resolve-RangerCanonicalDomainName -Name $_ })
    $exclude = @($Config.domains.exclude | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { Resolve-RangerCanonicalDomainName -Name $_ })
    $selected = New-Object System.Collections.ArrayList

    foreach ($definition in $definitions.Values) {
        $covers = @($definition.Covers | ForEach-Object { Resolve-RangerCanonicalDomainName -Name $_ })
        $isIncluded = $include.Count -eq 0 -or @($covers | Where-Object { $_ -in $include }).Count -gt 0
        $isExcluded = @($covers | Where-Object { $_ -in $exclude }).Count -gt 0
        if ($isIncluded -and -not $isExcluded) {
            [void]$selected.Add($definition)
        }
    }

    return @($selected)
}

function Test-RangerConfiguration {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [switch]$PassThru
    )

    $errors = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]
    $include = @($Config.domains.include | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { Resolve-RangerCanonicalDomainName -Name $_ })
    $exclude = @($Config.domains.exclude | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { Resolve-RangerCanonicalDomainName -Name $_ })

    foreach ($domain in $include) {
        if ($domain -in $exclude) {
            $errors.Add("Domain '$domain' cannot appear in both include and exclude.")
        }
    }

    if ($Config.output.mode -notin @('current-state', 'as-built')) {
        $errors.Add("Output mode '$($Config.output.mode)' is not supported.")
    }

    $supportedFormats = @('html', 'markdown', 'md', 'svg', 'drawio', 'xml', 'json')
    foreach ($format in @($Config.output.formats)) {
        if ($format -notin $supportedFormats) {
            $errors.Add("Output format '$format' is not supported.")
        }
    }

    $azureSettings = Resolve-RangerAzureCredentialSettings -Config $Config -SkipSecretResolution
    $supportedAzureMethods = @('existing-context', 'managed-identity', 'device-code', 'service-principal', 'azure-cli')
    if ($azureSettings.method -notin $supportedAzureMethods) {
        $errors.Add("Azure credential method '$($azureSettings.method)' is not supported.")
    }

    if ($azureSettings.method -eq 'service-principal') {
        if ([string]::IsNullOrWhiteSpace($azureSettings.clientId)) {
            $errors.Add('Azure service-principal authentication requires credentials.azure.clientId.')
        }

        if ([string]::IsNullOrWhiteSpace($azureSettings.tenantId)) {
            $errors.Add('Azure service-principal authentication requires a tenantId in targets.azure or credentials.azure.')
        }

        if ([string]::IsNullOrWhiteSpace($Config.credentials.azure.clientSecret) -and [string]::IsNullOrWhiteSpace($Config.credentials.azure.clientSecretRef)) {
            $errors.Add('Azure service-principal authentication requires credentials.azure.clientSecret or credentials.azure.clientSecretRef.')
        }
    }

    foreach ($credentialName in @('cluster', 'domain', 'bmc', 'firewall', 'switch')) {
        $credentialBlock = $Config.credentials[$credentialName]
        if ($credentialBlock -and $credentialBlock.passwordRef) {
            try {
                ConvertFrom-RangerKeyVaultUri -Uri $credentialBlock.passwordRef | Out-Null
            }
            catch {
                $errors.Add("Credential '$credentialName' has an invalid Key Vault reference: $($_.Exception.Message)")
            }
        }
    }

    $selectedCollectors = Resolve-RangerSelectedCollectors -Config $Config
    foreach ($collector in $selectedCollectors) {
        foreach ($requiredTarget in $collector.RequiredTargets) {
            if (-not (Test-RangerTargetConfigured -Config $Config -TargetName $requiredTarget)) {
                if ($collector.Class -eq 'core') {
                    $errors.Add("Collector '$($collector.Id)' requires target '$requiredTarget'.")
                }
                else {
                    $warnings.Add("Collector '$($collector.Id)' will be skipped because target '$requiredTarget' is not configured.")
                }
            }
        }
    }

    if ($azureSettings.method -eq 'azure-cli' -and -not [bool]$Config.credentials.azure.useAzureCliFallback) {
        $warnings.Add('Azure CLI authentication was selected without CLI fallback enabled; Azure resource enumeration may be incomplete.')
    }

    $result = [ordered]@{
        IsValid  = $errors.Count -eq 0
        Errors   = @($errors)
        Warnings = @($warnings)
    }

    if ($PassThru) {
        return $result
    }

    if (-not $result.IsValid) {
        throw ($result.Errors -join [Environment]::NewLine)
    }
}

function Test-RangerTargetConfigured {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory = $true)]
        [string]$TargetName
    )

    switch ($TargetName) {
        'cluster' {
            $clusterTarget = $Config.targets.cluster
            if ($null -eq $clusterTarget) { return $false }
            return -not [string]::IsNullOrWhiteSpace($clusterTarget.fqdn) -or @($clusterTarget.nodes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0
        }
        'azure' {
            return -not [string]::IsNullOrWhiteSpace($Config.targets.azure.subscriptionId) -or -not [string]::IsNullOrWhiteSpace($Config.targets.azure.resourceGroup)
        }
        'bmc' {
            return @($Config.targets.bmc.endpoints | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0
        }
        default {
            return $false
        }
    }
}