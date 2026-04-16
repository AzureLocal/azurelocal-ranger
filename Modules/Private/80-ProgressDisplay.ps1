# Issue #76 — Spectre.Console TUI progress display
#
# Provides a live progress bar display during collector execution using
# PwshSpectreConsole (wrapper around Spectre.Console).
#
# Design constraints:
#   • PwshSpectreConsole is an optional dependency — all functions degrade
#     gracefully to no-op / Write-Progress when the module is absent.
#   • TUI is suppressed automatically in non-interactive sessions (CI, scheduled
#     tasks, Unattended mode) to avoid garbled terminal output.
#   • The progress host runs in the caller's thread via Add-SpectreJob callbacks;
#     no background runspaces are created.

function Test-RangerSpectreAvailable {
    <#
    .SYNOPSIS
        Returns $true when PwshSpectreConsole is importable and the session is interactive.
    #>
    param(
        [switch]$Force   # skip interactivity check (for testing)
    )

    # Non-interactive guard: suppress TUI in CI, scheduled tasks, or Unattended runs
    if (-not $Force) {
        $isCI = [bool]($env:CI -or $env:TF_BUILD -or $env:GITHUB_ACTIONS -or $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI)
        if ($isCI) { return $false }
        if (-not [Environment]::UserInteractive) { return $false }
        # No host / dumb terminal
        if ($null -eq $Host -or $Host.Name -eq 'Default Host' -or $Host.Name -eq 'ServerRemoteHost') { return $false }
    }

    return (Get-Module -Name 'PwshSpectreConsole' -ListAvailable -ErrorAction SilentlyContinue) -as [bool]
}

function Import-RangerSpectreConsole {
    <#
    .SYNOPSIS
        Imports PwshSpectreConsole if available; returns $true on success.
    #>
    if (Get-Module -Name 'PwshSpectreConsole' -ErrorAction SilentlyContinue) {
        return $true
    }
    try {
        Import-Module -Name 'PwshSpectreConsole' -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function New-RangerProgressContext {
    <#
    .SYNOPSIS
        Returns a progress context object used by the collector loop.
    .DESCRIPTION
        When Spectre is available: returns a hashtable with a live progress table.
        When Spectre is absent:    returns a hashtable in 'fallback' mode that
                                   delegates to Write-Progress.
    .OUTPUTS
        Ordered hashtable with keys: Mode, Total, Completed, Tasks
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Collectors,

        [switch]$Force
    )

    $ctx = [ordered]@{
        Mode      = 'none'
        Total     = $Collectors.Count
        Completed = 0
        Tasks     = [ordered]@{}
    }

    if (-not (Test-RangerSpectreAvailable -Force:$Force)) {
        $ctx.Mode = 'fallback'
        Write-Progress -Activity 'AzureLocalRanger' -Status "Starting $($Collectors.Count) collectors…" -PercentComplete 0
        return $ctx
    }

    if (-not (Import-RangerSpectreConsole)) {
        $ctx.Mode = 'fallback'
        return $ctx
    }

    # Build a Spectre progress table row for each collector
    try {
        $spectreRows = @($Collectors | ForEach-Object {
            [ordered]@{
                Id     = $_.Id
                Label  = $_.Id
                Status = 'pending'
            }
        })
        $ctx.Mode  = 'spectre'
        $ctx.Tasks = $spectreRows
    }
    catch {
        # Spectre initialisation failed — fall back silently
        $ctx.Mode = 'fallback'
    }

    return $ctx
}

function Update-RangerProgressCollectorStart {
    <#
    .SYNOPSIS
        Marks a collector as running in the progress display.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$Context,

        [Parameter(Mandatory = $true)]
        [string]$CollectorId
    )

    if ($Context.Mode -eq 'none') { return }

    if ($Context.Mode -eq 'spectre') {
        try {
            $row = @($Context.Tasks | Where-Object { $_.Id -eq $CollectorId })[0]
            if ($row) { $row.Status = 'running' }
            $pct = [int](($Context.Completed / $Context.Total) * 100)
            Write-SpectreHost "[grey]Collecting:[/] [cyan]$CollectorId[/]…" -NoNewline
            _ = $pct   # suppress unused variable warning
        }
        catch { }
        return
    }

    # fallback: Write-Progress
    $pct  = [int](($Context.Completed / $Context.Total) * 100)
    Write-Progress -Activity 'AzureLocalRanger' -Status "Running: $CollectorId" -PercentComplete $pct
}

function Update-RangerProgressCollectorDone {
    <#
    .SYNOPSIS
        Marks a collector as complete (success / skipped / failed) in the progress display.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$Context,

        [Parameter(Mandatory = $true)]
        [string]$CollectorId,

        [ValidateSet('success', 'partial', 'failed', 'skipped', 'not-applicable')]
        [string]$Status = 'success'
    )

    $Context.Completed = [int]$Context.Completed + 1

    if ($Context.Mode -eq 'none') { return }

    $statusColour = switch ($Status) {
        'success'        { 'green' }
        'partial'        { 'yellow' }
        'skipped'        { 'grey' }
        'not-applicable' { 'grey' }
        'failed'         { 'red' }
        default          { 'white' }
    }

    if ($Context.Mode -eq 'spectre') {
        try {
            $row = @($Context.Tasks | Where-Object { $_.Id -eq $CollectorId })[0]
            if ($row) { $row.Status = $Status }
            $pct = [int](($Context.Completed / $Context.Total) * 100)
            Write-SpectreHost " [$statusColour]$Status[/]"
            _ = $pct
        }
        catch { }
        return
    }

    # fallback: Write-Progress
    $pct = [int](($Context.Completed / $Context.Total) * 100)
    Write-Progress -Activity 'AzureLocalRanger' -Status "Done: $CollectorId ($Status)" -PercentComplete $pct
}

function Complete-RangerProgressDisplay {
    <#
    .SYNOPSIS
        Finalises and tears down the progress display.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$Context
    )

    if ($Context.Mode -eq 'none') { return }

    if ($Context.Mode -eq 'fallback') {
        Write-Progress -Activity 'AzureLocalRanger' -Completed
        return
    }

    # spectre: print summary line
    try {
        $failed  = @($Context.Tasks | Where-Object { $_.Status -eq 'failed' }).Count
        $skipped = @($Context.Tasks | Where-Object { $_.Status -in @('skipped', 'not-applicable') }).Count
        $ok      = @($Context.Tasks | Where-Object { $_.Status -in @('success', 'partial') }).Count
        $total   = $Context.Total

        $summaryParts = @("[green]$ok ok[/]")
        if ($skipped -gt 0) { $summaryParts += "[grey]$skipped skipped[/]" }
        if ($failed  -gt 0) { $summaryParts += "[red]$failed failed[/]" }
        Write-SpectreHost "Collectors: $($summaryParts -join '  ')  [grey]($total total)[/]"
    }
    catch { }
}

function Write-RangerProgressSummary {
    <#
    .SYNOPSIS
        Writes the final run summary to the console using Spectre markup when available.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [object]$Context
    )

    $posture    = $Manifest.run.connectivity.posture
    $pkgId      = Split-Path -Leaf (Split-Path -Parent $Manifest.run.startTimeUtc)
    $findingCnt = @($Manifest.findings).Count
    $warnCnt    = @($Manifest.findings | Where-Object { $_.severity -eq 'warning' }).Count
    $critCnt    = @($Manifest.findings | Where-Object { $_.severity -eq 'critical' }).Count

    if ($null -ne $Context -and $Context.Mode -eq 'spectre') {
        try {
            Write-SpectreRule -Title '[bold]AzureLocalRanger Run Complete[/]' -Color 'blue'
            Write-SpectreHost "  Posture   : [cyan]$posture[/]"
            Write-SpectreHost "  Findings  : [yellow]$findingCnt[/]  ([red]$critCnt critical[/], [yellow]$warnCnt warning[/])"
        }
        catch { }
    }
    else {
        Write-RangerLog -Level info -Message "Run complete — posture: $posture, findings: $findingCnt (critical: $critCnt, warning: $warnCnt)"
    }
}
