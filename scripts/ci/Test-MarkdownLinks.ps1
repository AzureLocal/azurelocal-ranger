#Requires -Version 7.0
<#
.SYNOPSIS
    Checks relative links in Markdown files (no network). Used by CI and by the Pester suite.
.DESCRIPTION
    Resolves inline links and reference definitions against the file system. External links (http, https, mailto),
    pure anchors and links inside fenced code blocks are skipped. VitePress style routes are accepted: a target
    resolves when the file exists as written, with .md added, or as a folder with index.md / README.md. A leading
    slash is resolved from the docs folder for files under docs/ and from the repository root otherwise.
.PARAMETER Root
    Repository root.
.PARAMETER Path
    Files or folders to scan, relative to Root. Defaults to the top-level Markdown files and docs/.
.OUTPUTS
    One object per broken link: File, Line, Target.
#>
[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string[]]$Path = @('README.md', 'CONTRIBUTING.md', 'STANDARDS.md', 'repo-intent.md', 'CHANGELOG.md', 'docs')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$files = foreach ($p in $Path) {
    $full = Join-Path $Root $p
    if (Test-Path -LiteralPath $full -PathType Container) {
        Get-ChildItem -LiteralPath $full -Recurse -File -Include '*.md' | Where-Object { $_.FullName -notmatch '[\\/](node_modules|\.vitepress[\\/]dist|\.vitepress[\\/]cache)[\\/]' }
    }
    elseif (Test-Path -LiteralPath $full -PathType Leaf) { Get-Item -LiteralPath $full }
}

$docsRoot = Join-Path $Root 'docs'
$broken = foreach ($file in $files) {
    $inFence = $false
    $lineNo = 0
    foreach ($line in [System.IO.File]::ReadLines($file.FullName)) {
        $lineNo++
        if ($line -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
        if ($inFence) { continue }
        $clean = [regex]::Replace($line, '`[^`]*`', '')
        $targets = @([regex]::Matches($clean, '(?<!\!)\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)') | ForEach-Object { $_.Groups[1].Value })
        $targets += @([regex]::Matches($clean, '(?<!\!)!\[[^\]]*\]\(\s*<?([^)\s>]+)>?\s*\)') | ForEach-Object { $_.Groups[1].Value })
        $targets += @([regex]::Matches($clean, '^\s*\[[^\]]+\]:\s*(\S+)') | ForEach-Object { $_.Groups[1].Value })
        foreach ($t in $targets) {
            if ($t -match '^(https?:|mailto:|tel:|data:|#|\{\{|<)') { continue }
            $target = ($t -split '[#?]')[0]
            if ([string]::IsNullOrWhiteSpace($target)) { continue }
            $target = [System.Uri]::UnescapeDataString($target)
            $base = if ($target.StartsWith('/')) { if ($file.FullName.StartsWith($docsRoot, [System.StringComparison]::OrdinalIgnoreCase)) { $docsRoot } else { $Root } } else { $file.DirectoryName }
            $candidate = Join-Path $base ($target.TrimStart('/'))
            $ok = (Test-Path -LiteralPath $candidate) -or (Test-Path -LiteralPath "$candidate.md") -or
                (Test-Path -LiteralPath (Join-Path $candidate 'index.md')) -or (Test-Path -LiteralPath (Join-Path $candidate 'README.md'))
            if (-not $ok) {
                [pscustomobject]@{ File = [System.IO.Path]::GetRelativePath($Root, $file.FullName); Line = $lineNo; Target = $t }
            }
        }
    }
}
$broken
