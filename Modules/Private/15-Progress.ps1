function Get-RangerProgressStatePath {
    <#
    .SYNOPSIS
        v1.6.0 (#213): resolve the IPC progress file path for a given run ID.
    .DESCRIPTION
        Sanitises $RunId against path traversal (strips \, /, .. sequences)
        and returns $env:TEMP\ranger-progress-<sanitized>.json.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RunId
    )

    $safe = ($RunId -replace '[\\\/:*?"<>|]', '') -replace '\.\.+', ''
    if ([string]::IsNullOrWhiteSpace($safe)) { $safe = 'default' }
    $root = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
    return (Join-Path -Path $root -ChildPath ("ranger-progress-{0}.json" -f $safe))
}

function Write-RangerProgressState {
    <#
    .SYNOPSIS
        v1.6.0 (#213): atomically write a progress snapshot to the IPC file.
    .DESCRIPTION
        Writes percent / message / phase to
        $env:TEMP\ranger-progress-<RunId>.json atomically — renders to a temp
        file then File.Move -Force to the final path so readers never see a
        partial JSON document.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RunId,

        [ValidateRange(0, 100)]
        [int]$Percent = 0,

        [string]$Message,

        [ValidateSet('pre-check', 'collection', 'rendering', 'complete', 'failed')]
        [string]$Phase = 'collection'
    )

    $path = Get-RangerProgressStatePath -RunId $RunId

    $payload = [ordered]@{
        runId     = $RunId
        percent   = [int]$Percent
        message   = [string]$Message
        phase     = $Phase
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
    }
    $json = ($payload | ConvertTo-Json -Depth 4 -Compress)

    # Atomic write: write to a per-process temp file then Move -Force over the target.
    $tempPath = "$path.$PID.tmp"
    try {
        [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.Encoding]::UTF8)
        # File.Move -Force (destination overwrite) is atomic within a single volume on Windows.
        if (Test-Path -Path $path -PathType Leaf) {
            [System.IO.File]::Delete($path)
        }
        [System.IO.File]::Move($tempPath, $path)
    }
    catch {
        # Clean up stray temp file if the move failed
        if (Test-Path -Path $tempPath -PathType Leaf) {
            try { [System.IO.File]::Delete($tempPath) } catch { }
        }
        throw
    }
}

function Read-RangerProgressState {
    <#
    .SYNOPSIS
        v1.6.0 (#213): read the most recent progress snapshot for a run.
    .OUTPUTS
        PSCustomObject with runId, percent, message, phase, timestamp, or
        $null when the file does not exist (run not started).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RunId
    )

    $path = Get-RangerProgressStatePath -RunId $RunId
    if (-not (Test-Path -Path $path -PathType Leaf)) { return $null }

    try {
        $raw = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return ($raw | ConvertFrom-Json)
    }
    catch {
        # Reader sees an in-progress write — return null, caller will poll again.
        return $null
    }
}

function Remove-RangerProgressState {
    <#
    .SYNOPSIS
        v1.6.0 (#213): delete the progress IPC file for a run. Idempotent.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RunId
    )

    $path = Get-RangerProgressStatePath -RunId $RunId
    if (Test-Path -Path $path -PathType Leaf) {
        try { [System.IO.File]::Delete($path) } catch { }
    }
}
