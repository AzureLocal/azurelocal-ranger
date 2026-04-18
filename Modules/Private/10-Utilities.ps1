function Get-RangerTimestamp {
    (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
}

function Resolve-RangerLogLevel {
    param(
        [AllowNull()]
        [string]$Level
    )

    switch (($Level ?? 'info').ToLowerInvariant()) {
        'verbose' { 'debug' }
        'warning' { 'warn' }
        default { ($Level ?? 'info').ToLowerInvariant() }
    }
}

function Get-RangerLogLevelRank {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Level
    )

    switch (Resolve-RangerLogLevel -Level $Level) {
        'debug' { 0 }
        'info' { 1 }
        'warn' { 2 }
        'error' { 3 }
        default { 1 }
    }
}

function ConvertTo-RangerLogMessage {
    param(
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return ''
    }

    if ($InputObject -is [System.Management.Automation.WarningRecord]) {
        return [string]$InputObject.Message
    }

    if ($InputObject -is [System.Management.Automation.ErrorRecord]) {
        return [string]$InputObject.ToString()
    }

    if ($InputObject -is [System.Management.Automation.InformationRecord]) {
        return [string]$InputObject.MessageData
    }

    return [string]$InputObject
}

function Write-RangerLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('debug', 'info', 'warn', 'error')]
        [string]$Level = 'info'
    )

    $normalizedLevel = Resolve-RangerLogLevel -Level $Level
    $timestamp = (Get-Date).ToString('s')
    $levelTag = $normalizedLevel.ToUpperInvariant().PadRight(5)
    $line = "[$timestamp][$levelTag] $Message"

    # Issue #328: $VerbosePreference set by -Debug/-Verbose on Invoke-AzureLocalRanger does not
    # propagate into nested module function scopes. Force it locally when the flag is set so every
    # log entry — including DEBUG — appears in the running PowerShell terminal.
    if ($script:RangerVerboseToConsole) { $VerbosePreference = 'Continue' }
    Write-Verbose $line

    # Issue #318 / #320: bootstrap buffer phase — log file not yet open. Buffer ALL entries
    # without level filtering so debug entries from config load, auto-discovery, and validation
    # are preserved. Initialize-RangerFileLog applies the level filter at flush time, after
    # $script:RangerLogLevel has been elevated by -Debug/-Verbose (issue #320).
    if (-not $script:RangerLogPath -and $null -ne $script:RangerPreLogBuffer) {
        $script:RangerPreLogBuffer.Add([pscustomobject]@{ Level = $normalizedLevel; Line = $line })
        return
    }

    # Issue #109: write to file log when package root is known
    if ($script:RangerLogPath) {
        $currentLevel = Resolve-RangerLogLevel -Level $(if ($script:RangerLogLevel) { $script:RangerLogLevel } else { 'info' })
        if ((Get-RangerLogLevelRank -Level $normalizedLevel) -lt (Get-RangerLogLevelRank -Level $currentLevel)) {
            return
        }
        try {
            Add-Content -LiteralPath $script:RangerLogPath -Value $line -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            # Swallow file write errors — never let logging crash the run
        }
    }
}

function Initialize-RangerFileLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageRoot
    )

    $logPath = Join-Path -Path $PackageRoot -ChildPath 'ranger.log'
    $script:RangerLogPath = $logPath
    $header = "# AzureLocalRanger log — started $(Get-Date -Format 'o')"
    try {
        Set-Content -LiteralPath $logPath -Value $header -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        $script:RangerLogPath = $null
    }

    # Issue #318: flush bootstrap-phase buffer — entries captured before the log file was open.
    # Apply the now-configured log level so debug entries are only written when the operator asked for them.
    if ($script:RangerLogPath -and $script:RangerPreLogBuffer -and $script:RangerPreLogBuffer.Count -gt 0) {
        try {
            $configuredLevel = Resolve-RangerLogLevel -Level $(if ($script:RangerLogLevel) { $script:RangerLogLevel } else { 'info' })
            $flushLines = @($script:RangerPreLogBuffer |
                Where-Object { (Get-RangerLogLevelRank -Level $_.Level) -ge (Get-RangerLogLevelRank -Level $configuredLevel) } |
                ForEach-Object { $_.Line })
            if ($flushLines.Count -gt 0) {
                Add-Content -LiteralPath $script:RangerLogPath -Value '' -Encoding UTF8 -ErrorAction Stop
                Add-Content -LiteralPath $script:RangerLogPath -Value '# bootstrap phase' -Encoding UTF8 -ErrorAction Stop
                Add-Content -LiteralPath $script:RangerLogPath -Value $flushLines -Encoding UTF8 -ErrorAction Stop
                Add-Content -LiteralPath $script:RangerLogPath -Value '' -Encoding UTF8 -ErrorAction Stop
                Add-Content -LiteralPath $script:RangerLogPath -Value '# run phase' -Encoding UTF8 -ErrorAction Stop
            }
        }
        catch { }
        $script:RangerPreLogBuffer = $null
    }

    return $logPath
}

function ConvertTo-RangerHashtable {
    param(
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $InputObject.Keys) {
            $result[$key] = ConvertTo-RangerHashtable -InputObject $InputObject[$key]
        }

        return $result
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $items = @()
        foreach ($item in $InputObject) {
            $items += ConvertTo-RangerHashtable -InputObject $item
        }

        return $items
    }

    if ($InputObject -is [string] -or $InputObject -is [char] -or $InputObject -is [System.ValueType] -or $InputObject -is [datetime] -or $InputObject -is [version] -or $InputObject -is [guid]) {
        return $InputObject
    }

    $properties = $InputObject.PSObject.Properties
    if ($properties -and $properties.Count -gt 0) {
        $result = [ordered]@{}
        foreach ($property in $properties) {
            $result[$property.Name] = ConvertTo-RangerHashtable -InputObject $property.Value
        }

        return $result
    }

    return $InputObject
}

function Get-RangerSafeName {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return 'unnamed' }
    ($Value -replace '[^A-Za-z0-9._-]', '-').Trim('-')
}

function New-RangerFinding {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('critical', 'warning', 'informational', 'good')]
        [string]$Severity,

        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [string[]]$AffectedComponents = @(),
        [string]$CurrentState,
        [string]$Recommendation,
        [string[]]$EvidenceReferences = @()
    )

    [ordered]@{
        severity           = $Severity
        title              = $Title
        description        = $Description
        affectedComponents = @($AffectedComponents)
        currentState       = $CurrentState
        recommendation     = $Recommendation
        evidenceReferences = @($EvidenceReferences)
    }
}

function New-RangerArtifactRecord {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('generated', 'skipped', 'planned')]
        [string]$Status,

        [string]$Audience,
        [string]$Reason
    )

    [ordered]@{
        type         = $Type
        relativePath = $RelativePath
        status       = $Status
        audience     = $Audience
        reason       = $Reason
    }
}

function Resolve-RangerPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string]$BasePath = (Get-Location).Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path -Path $BasePath -ChildPath $Path))
}

function Test-RangerCommandAvailable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function ConvertTo-RangerPlainText {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [securestring]) {
        $credential = [System.Management.Automation.PSCredential]::new('ignored', $Value)
        return $credential.GetNetworkCredential().Password
    }

    return [string]$Value
}

function ConvertTo-RangerGiB {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }

    try {
        return [math]::Round(([double]$Value / 1GB), 2)
    }
    catch {
        return $null
    }
}

function Get-RangerFlattenedCollection {
    param(
        [AllowNull()]
        $Items
    )

    $results = New-Object System.Collections.ArrayList
    foreach ($item in @($Items)) {
        if ($null -eq $item) {
            continue
        }

        if ($item -is [System.Collections.IEnumerable] -and $item -isnot [string] -and $item -isnot [System.Collections.IDictionary]) {
            foreach ($child in $item) {
                if ($null -ne $child) {
                    [void]$results.Add($child)
                }
            }

            continue
        }

        [void]$results.Add($item)
    }

    return @($results)
}

function Get-RangerGroupedCount {
    param(
        [AllowNull()]
        $Items,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName
    )

    return @(
        @($Items | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_.($PropertyName)) }) |
            Group-Object -Property $PropertyName |
            Sort-Object -Property @(
                @{ Expression = 'Count'; Descending = $true },
                @{ Expression = 'Name'; Descending = $false }
            ) |
            ForEach-Object {
                [ordered]@{
                    name  = $_.Name
                    count = $_.Count
                }
            }
    )
}

function Get-RangerAverageValue {
    param(
        [AllowNull()]
        $Values
    )

    $numbers = @($Values | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ })
    if ($numbers.Count -eq 0) {
        return $null
    }

    return [math]::Round((($numbers | Measure-Object -Average).Average), 2)
}

function Add-RangerRetryDetail {
    param(
        [string]$Target,
        [string]$Label,
        [int]$Attempt,
        [string]$ExceptionType,
        [string]$Message
    )

    if ($script:RangerRetryDetails -isnot [System.Collections.IList]) {
        return
    }

    [void]$script:RangerRetryDetails.Add([ordered]@{
        timestampUtc  = (Get-Date).ToUniversalTime().ToString('o')
        target        = $Target
        label         = $Label
        attempt       = $Attempt
        exceptionType = $ExceptionType
        message       = $Message
    })
}