function Get-RangerTimestamp {
    (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
}

function Get-RangerLogLevelRank {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Level
    )

    switch ($Level.ToLowerInvariant()) {
        'debug' { 0 }
        'info' { 1 }
        'warn' { 2 }
        'error' { 3 }
        default { 1 }
    }
}

function Write-RangerLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('debug', 'info', 'warn', 'error')]
        [string]$Level = 'info'
    )

    $currentLevel = if ($script:RangerLogLevel) { $script:RangerLogLevel } else { 'info' }
    if ((Get-RangerLogLevelRank -Level $Level) -lt (Get-RangerLogLevelRank -Level $currentLevel)) {
        return
    }

    $timestamp = (Get-Date).ToString('s')
    Write-Verbose "[$timestamp][$($Level.ToUpperInvariant())] $Message"
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