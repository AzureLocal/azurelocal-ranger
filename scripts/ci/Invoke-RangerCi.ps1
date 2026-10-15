#Requires -Version 7.0
<#
.SYNOPSIS
    The checks CI runs, runnable locally with the same arguments.
.DESCRIPTION
    Analyzer  PSScriptAnalyzer with PSScriptAnalyzerSettings.psd1 over Modules, the root module files and the sample scripts, and
              tests/PSScriptAnalyzerSettings.psd1 over tests. Fails on any Error or Warning that is left after the settings.
    Manifest  Test-ModuleManifest, import the module and check the exported commands match the manifest.
    Pester    One PowerShell process per test file (so one slow file cannot hide another and shards can be balanced).
    Links     Relative Markdown links (scripts/ci/Test-MarkdownLinks.ps1).
    Nothing here reaches Azure or a cluster.
.PARAMETER Check
    Analyzer, Manifest, Pester, Links or All.
.PARAMETER TestFile
    For Pester: test file names (for example Config.Tests.ps1). Defaults to every *.Tests.ps1 under tests/.
.PARAMETER ResultPath
    Optional JSON result file.
#>
[CmdletBinding()]
param(
    [ValidateSet('Analyzer', 'Manifest', 'Pester', 'Links', 'All')]
    [string]$Check = 'All',
    [string[]]$TestFile,
    [string]$ResultPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$results = [ordered]@{}
$failed = $false

function Invoke-AnalyzerCheck {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    $module = @(
        Invoke-ScriptAnalyzer -Path (Join-Path $root 'Modules') -Recurse -Settings (Join-Path $root 'PSScriptAnalyzerSettings.psd1')
        Invoke-ScriptAnalyzer -Path (Join-Path $root 'AzureLocalRanger.psm1') -Settings (Join-Path $root 'PSScriptAnalyzerSettings.psd1')
        Invoke-ScriptAnalyzer -Path (Join-Path $root 'AzureLocalRanger.psd1') -Settings (Join-Path $root 'PSScriptAnalyzerSettings.psd1')
    )
    $tests = @(Invoke-ScriptAnalyzer -Path (Join-Path $root 'tests') -Recurse -Settings (Join-Path $root 'tests\PSScriptAnalyzerSettings.psd1'))
    $scripts = @(Invoke-ScriptAnalyzer -Path (Join-Path $root 'scripts') -Recurse -Settings (Join-Path $root 'PSScriptAnalyzerSettings.psd1'))
    $all = @($module) + @($tests) + @($scripts)
    $blocking = @($all | Where-Object { $_.Severity -in 'Error', 'Warning' })
    foreach ($f in $blocking) { Write-Host ("{0} {1} {2}:{3} {4}" -f $f.Severity, $f.RuleName, [System.IO.Path]::GetRelativePath($root, $f.ScriptPath), $f.Line, $f.Message) }
    [ordered]@{
        passed   = ($blocking.Count -eq 0)
        errors   = @($all | Where-Object Severity -eq 'Error').Count
        warnings = @($all | Where-Object Severity -eq 'Warning').Count
        information = @($all | Where-Object Severity -eq 'Information').Count
    }
}

function Invoke-ManifestCheck {
    $manifestPath = Join-Path $root 'AzureLocalRanger.psd1'
    $m = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    if ($m.PowerShellVersion -lt [version]'7.0') { throw 'The manifest must require PowerShell 7.0 or later.' }
    if (@($m.CompatiblePSEditions) -notcontains 'Core') { throw "CompatiblePSEditions must list 'Core' (Windows PowerShell 5.1 is not supported)." }
    Import-Module $manifestPath -Force
    $exported = @((Get-Module AzureLocalRanger).ExportedFunctions.Keys | Sort-Object)
    $declared = @($m.ExportedFunctions.Keys | Sort-Object)
    $missing = @($declared | Where-Object { $_ -notin $exported })
    if ($missing.Count) { throw "Declared but not exported: $($missing -join ', ')" }
    $changelog = Get-Content (Join-Path $root 'CHANGELOG.md') -Raw
    if ($changelog -notmatch [regex]::Escape("## [$($m.Version)]") -and $changelog -notmatch '## \[Unreleased\]') { throw "CHANGELOG.md has no section for version $($m.Version) or Unreleased." }
    [ordered]@{ passed = $true; version = $m.Version.ToString(); exportedFunctions = $exported.Count }
}

function Invoke-PesterCheck {
    $dir = Join-Path $root 'tests'
    # pwsh -File passes a comma list as one string; accept both forms.
    $TestFile = @($TestFile | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
    $files = @(if ($TestFile.Count -gt 0) { $TestFile | ForEach-Object { Get-ChildItem -Path $dir -Recurse -Filter $_ } } else { Get-ChildItem -Path $dir -Recurse -Filter '*.Tests.ps1' })
    if ($files.Count -eq 0) { throw 'No test files matched.' }
    $rows = @(foreach ($file in $files) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $cmd = "Import-Module Pester -RequiredVersion 5.9.1; `$c = New-PesterConfiguration; `$c.Run.Path = '$($file.FullName)'; `$c.Run.PassThru = `$true; `$c.Output.Verbosity = 'Normal'; `$r = Invoke-Pester -Configuration `$c; '{0}|{1}|{2}' -f `$r.PassedCount, `$r.FailedCount, `$r.SkippedCount"
        $out = & pwsh -NoProfile -Command $cmd
        $line = @($out)[-1]
        $out | Select-Object -SkipLast 1 | ForEach-Object { Write-Host $_ }
        $p, $f, $s = ($line -split '\|')
        [ordered]@{ file = $file.Name; passed = [int]$p; failed = [int]$f; skipped = [int]$s; seconds = [int]$sw.Elapsed.TotalSeconds }
    })
    [ordered]@{
        passed = (@($rows | Where-Object { $_['failed'] -gt 0 }).Count -eq 0)
        totalPassed = [int](@($rows | ForEach-Object { $_.passed }) | Measure-Object -Sum).Sum
        totalFailed = [int](@($rows | ForEach-Object { $_.failed }) | Measure-Object -Sum).Sum
        files  = @($rows)
    }
}

function Invoke-LinksCheck {
    $broken = @(& (Join-Path $PSScriptRoot 'Test-MarkdownLinks.ps1') -Root $root)
    foreach ($b in $broken) { Write-Host "Broken link: $($b.File):$($b.Line) -> $($b.Target)" }
    [ordered]@{ passed = ($broken.Count -eq 0); broken = @($broken) }
}

$checks = if ($Check -eq 'All') { @('Analyzer', 'Manifest', 'Links', 'Pester') } else { @($Check) }
foreach ($c in $checks) {
    Write-Host "== $c"
    try { $results[$c] = & "Invoke-${c}Check" }
    catch { $results[$c] = [ordered]@{ passed = $false; error = $_.Exception.Message }; Write-Host "ERROR: $($_.Exception.Message)" }
    if (-not $results[$c].passed) { $failed = $true }
}
if ($ResultPath) { $results | ConvertTo-Json -Depth 8 | Set-Content -Path $ResultPath -Encoding UTF8 }
foreach ($k in $results.Keys) { Write-Host ("{0,-9} {1}" -f $k, $(if ($results[$k].passed) { 'passed' } else { 'FAILED' })) }
if ($failed) { exit 1 }
