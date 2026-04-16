function Get-RangerHintValue {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $hints = $Config.domains.hints
    if ($hints -and $hints.Contains($Name)) {
        return $hints[$Name]
    }

    return $null
}

function Get-RangerCollectorFixtureData {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory = $true)]
        [string]$CollectorId
    )

    $fixtures = Get-RangerHintValue -Config $Config -Name 'fixtures'
    if ($fixtures -and $fixtures.Contains($CollectorId) -and -not [string]::IsNullOrWhiteSpace([string]$fixtures[$CollectorId])) {
        return Get-RangerFixtureData -Path ([string]$fixtures[$CollectorId])
    }

    return $null
}

function Get-RangerClusterTargets {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [switch]$SingleTarget
    )

    $targets = @($Config.targets.cluster.nodes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($targets.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($Config.targets.cluster.fqdn)) {
        $targets = @($Config.targets.cluster.fqdn)
    }

    if ($targets.Count -eq 0) {
        $targets = @($env:COMPUTERNAME)
    }

    if ($SingleTarget) {
        return @($targets | Select-Object -First 1)
    }

    return @($targets)
}

function Invoke-RangerClusterCommand {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [PSCredential]$Credential,
        [object[]]$ArgumentList,
        [string]$NodeName,
        [switch]$SingleTarget
    )

    $targets = if (-not [string]::IsNullOrWhiteSpace($NodeName)) {
        @($NodeName)
    }
    else {
        Get-RangerClusterTargets -Config $Config -SingleTarget:$SingleTarget
    }
    $currentNames = @($env:COMPUTERNAME, [System.Net.Dns]::GetHostName()) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($targets.Count -eq 1 -and $targets[0] -in $currentNames -and -not $Credential) {
        return & $ScriptBlock @ArgumentList
    }

    # Issue #113: honour behavior.retryCount and behavior.timeoutSeconds from config
    $retryCount = if ($Config.behavior -and $Config.behavior.retryCount -gt 0) { [int]$Config.behavior.retryCount } else { 1 }
    $timeoutSec  = if ($Config.behavior -and $Config.behavior.timeoutSeconds -gt 0) { [int]$Config.behavior.timeoutSeconds } else { 0 }

    # Issue #26: pass transport mode and Arc context from config so Invoke-RangerRemoteCommand
    # can fall back to Arc Run Command when WinRM is unreachable.
    $transportMode  = if ($Config.behavior -and $Config.behavior.transport) { [string]$Config.behavior.transport } else { 'auto' }
    $arcRg          = [string]$Config.targets.azure.resourceGroup
    $arcSubId       = [string]$Config.targets.azure.subscriptionId
    $remoteParams   = @{
        ComputerName      = $targets
        Credential        = $Credential
        ScriptBlock       = $ScriptBlock
        ArgumentList      = $ArgumentList
        RetryCount        = $retryCount
        TimeoutSeconds    = $timeoutSec
        TransportMode     = $transportMode
        ArcResourceGroup  = $arcRg
        ArcSubscriptionId = $arcSubId
    }

    return Invoke-RangerRemoteCommand @remoteParams
}

function Invoke-RangerSafeAction {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $true)]
        [string]$Label,

        [AllowNull()]
        $DefaultValue = $null,

        [string[]]$RetryOnExceptionType = @(
            'System.Net.WebException',
            'System.TimeoutException',
            'System.Net.Http.HttpRequestException',
            'Microsoft.Management.Infrastructure.CimException',
            'System.Management.Automation.Remoting.PSRemotingTransportException'
        )
    )

    try {
        $retryCount = if ($script:RangerBehaviorRetryCount -gt 0) { [int]$script:RangerBehaviorRetryCount } else { 0 }
        if ($retryCount -gt 0) {
            return Invoke-RangerRetry -ScriptBlock $ScriptBlock -RetryCount $retryCount -DelaySeconds 1 -Exponential -Label $Label -Target $Label -RetryOnExceptionType $RetryOnExceptionType
        }

        return & $ScriptBlock
    }
    catch {
        Write-RangerLog -Level warn -Message "$Label failed: $($_.Exception.Message)"
        return $DefaultValue
    }
}

function New-RangerRelationship {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceType,

        [Parameter(Mandatory = $true)]
        [string]$SourceId,

        [Parameter(Mandatory = $true)]
        [string]$TargetType,

        [Parameter(Mandatory = $true)]
        [string]$TargetId,

        [Parameter(Mandatory = $true)]
        [string]$RelationshipType,

        [System.Collections.IDictionary]$Properties
    )

    [ordered]@{
        source           = [ordered]@{ type = $SourceType; id = $SourceId }
        target           = [ordered]@{ type = $TargetType; id = $TargetId }
        relationshipType = $RelationshipType
        properties       = if ($Properties) { ConvertTo-RangerHashtable -InputObject $Properties } else { [ordered]@{} }
    }
}

function Test-RangerDomainPopulated {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $false
    }

    if ($Value -is [string]) {
        return -not [string]::IsNullOrWhiteSpace($Value)
    }

    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            if (Test-RangerDomainPopulated -Value $Value[$key]) {
                return $true
            }
        }

        return $false
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        foreach ($item in $Value) {
            if (Test-RangerDomainPopulated -Value $item) {
                return $true
            }
        }

        return $false
    }

    return $true
}

function Get-RangerAzureResources {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        $AzureCredentialSettings,

        [string[]]$ResourceTypes = @()
    )

    $resourceGroup = $Config.targets.azure.resourceGroup
    $effectiveAzureSettings = if ($AzureCredentialSettings) { $AzureCredentialSettings } else { Resolve-RangerAzureCredentialSettings -Config $Config }
    $result = Invoke-RangerAzureQuery -AzureCredentialSettings $effectiveAzureSettings -ArgumentList @($resourceGroup) -ScriptBlock {
        param($Rg)

        if (-not (Get-Command -Name Get-AzResource -ErrorAction SilentlyContinue)) {
            return @()
        }

        if ([string]::IsNullOrWhiteSpace($Rg)) {
            return @()
        }

        Get-AzResource -ResourceGroupName $Rg -ErrorAction Stop |
            Select-Object Name, ResourceType, ResourceGroupName, Location, ResourceId, Tags
    }

    $resources = @($result)
    if ($resources.Count -eq 0 -and [bool]$effectiveAzureSettings.useAzureCliFallback -and -not [string]::IsNullOrWhiteSpace($resourceGroup) -and (Test-RangerAzureCliAuthenticated)) {
        $cliArgs = @('resource', 'list', '--resource-group', $resourceGroup, '--output', 'json')
        if ($effectiveAzureSettings.subscriptionId) {
            $cliArgs += @('--subscription', $effectiveAzureSettings.subscriptionId)
        }

        $cliResult = & az @cliArgs 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$cliResult)) {
            $resources = @(
                ($cliResult | ConvertFrom-Json -Depth 100) | ForEach-Object {
                    [ordered]@{
                        Name              = $_.name
                        ResourceType      = $_.type
                        ResourceGroupName = $_.resourceGroup
                        Location          = $_.location
                        ResourceId        = $_.id
                        Tags              = ConvertTo-RangerHashtable -InputObject $_.tags
                    }
                }
            )
        }
    }

    if ($ResourceTypes.Count -eq 0) {
        return $resources
    }

    return @(
        $resources | Where-Object {
            $_.ResourceType -in $ResourceTypes
        }
    )
}

function Get-RangerArtifactPrefix {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $clusterName = if (-not [string]::IsNullOrWhiteSpace($Manifest.target.clusterName)) { $Manifest.target.clusterName } else { $Manifest.target.environmentLabel }
    $timestamp = if ($Manifest.run.endTimeUtc) { $Manifest.run.endTimeUtc } else { $Manifest.run.startTimeUtc }
    $parsedTimestamp = [datetime]::Parse($timestamp).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    '{0}-{1}-{2}' -f (Get-RangerSafeName -Value $clusterName), (Get-RangerSafeName -Value $Manifest.run.mode), $parsedTimestamp
}
