function ConvertTo-RangerCsvSafeText {
    <#
    .SYNOPSIS
        v1.6.0 (#210): sanitise a value for CSV output.
        - Prefix values starting with =/+/-/@ with a space to block formula injection.
        - Replace embedded newlines / tabs with a single space.
        - Escape embedded double quotes by doubling them.
    #>
    param([AllowNull()]$Value)
    $text = ConvertTo-RangerOfficeText -Value $Value
    if ([string]::IsNullOrEmpty($text)) { return '' }
    if ($text.Length -gt 0 -and $text[0] -in @('=', '+', '-', '@')) { $text = ' ' + $text }
    $text = $text -replace "[\r\n\t]+", ' '
    if ($text.Contains(',') -or $text.Contains('"')) {
        $text = '"' + ($text -replace '"', '""') + '"'
    }
    return $text
}

function Write-RangerCsvFile {
    <#
    .SYNOPSIS
        v1.6.0 (#210): write an array of ordered dictionaries to CSV with
        formula-injection sanitisation.
    #>
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string[]]$Columns,
        [object[]]$Rows
    )
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(($Columns -join ','))
    foreach ($row in @($Rows)) {
        $cells = @($Columns | ForEach-Object {
            $col = $_
            $v = if ($row -is [System.Collections.IDictionary] -and $row.Contains($col)) { $row[$col] }
                 elseif ($row.PSObject -and $row.PSObject.Properties[$col]) { $row.$col }
                 else { $null }
            ConvertTo-RangerCsvSafeText -Value $v
        })
        $lines.Add($cells -join ',')
    }
    [System.IO.File]::WriteAllLines($Path, $lines, [System.Text.UTF8Encoding]::new($false))
}

function Invoke-RangerPowerBiExport {
    <#
    .SYNOPSIS
        v1.6.0 (#210): export Ranger manifest data as a Power BI CSV + star-schema bundle.
    .DESCRIPTION
        Produces one flat CSV per entity type (nodes, volumes, storage-pools,
        health-checks, network-adapters) plus _relationships.json and
        _metadata.json. All string values are sanitised to prevent CSV
        formula injection and embedded-newline issues.
    #>
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary]$Manifest,
        [Parameter(Mandatory = $true)] [string]$OutputRoot
    )

    if (-not (Test-Path -Path $OutputRoot)) {
        New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
    }

    $summary   = Get-RangerManifestSummary -Manifest $Manifest
    $clusterId = if ($summary.ClusterName) { [string]$summary.ClusterName } else { 'unknown-cluster' }
    $runTs     = if ($Manifest.run.endTimeUtc) { [string]$Manifest.run.endTimeUtc } else { (Get-Date).ToUniversalTime().ToString('o') }

    # nodes.csv
    $nodeRows = @(
        @($Manifest.domains.clusterNode.nodes) | ForEach-Object {
            $n = $_
            $short = if ($n.name) { [string]$n.name } elseif ($n.NodeName) { [string]$n.NodeName } else { '—' }
            [ordered]@{
                NodeId        = $short
                NodeName      = $short
                NodeFqdn      = if ($n.fqdn) { [string]$n.fqdn } else { '' }
                ClusterId     = $clusterId
                Status        = if ($n.state) { [string]$n.state } else { '' }
                Model         = if ($n.model) { [string]$n.model } else { '' }
                CpuSockets    = if ($null -ne $n.cpuSocketCount) { [string]$n.cpuSocketCount } else { '' }
                PhysicalCores = if ($null -ne $n.logicalProcessorCount) { [string]$n.logicalProcessorCount } else { '' }
                MemoryGiB     = if ($null -ne $n.totalMemoryGiB) { [string][math]::Round([double]$n.totalMemoryGiB, 0) } else { '' }
                OsVersion     = if ($n.osVersion) { [string]$n.osVersion } elseif ($n.osCaption) { [string]$n.osCaption } else { '' }
                ArcConnected  = if ($n.arcConnected) { 'True' } else { 'False' }
                LastUpdated   = $runTs
            }
        }
    )
    Write-RangerCsvFile -Path (Join-Path $OutputRoot 'nodes.csv') `
        -Columns @('NodeId','NodeName','NodeFqdn','ClusterId','Status','Model','CpuSockets','PhysicalCores','MemoryGiB','OsVersion','ArcConnected','LastUpdated') `
        -Rows $nodeRows

    # storage-pools.csv
    $poolRows = @(
        @($Manifest.domains.storage.pools) | ForEach-Object {
            $p = $_
            [ordered]@{
                PoolId          = if ($p.friendlyName) { [string]$p.friendlyName } elseif ($p.name) { [string]$p.name } else { '' }
                PoolName        = if ($p.friendlyName) { [string]$p.friendlyName } elseif ($p.name) { [string]$p.name } else { '' }
                ClusterId       = $clusterId
                SizeTiB         = if ($null -ne $p.rawCapacityGiB)    { [string][math]::Round([double]$p.rawCapacityGiB / 1024, 2) } else { '' }
                AllocatedTiB    = if ($null -ne $p.usedUsableCapacityGiB) { [string][math]::Round([double]$p.usedUsableCapacityGiB / 1024, 2) } else { '' }
                FreeTiB         = if ($null -ne $p.freeUsableCapacityGiB) { [string][math]::Round([double]$p.freeUsableCapacityGiB / 1024, 2) } else { '' }
                FaultDomainType = if ($p.faultDomainType) { [string]$p.faultDomainType } else { '' }
                Health          = if ($p.healthStatus) { [string]$p.healthStatus } else { '' }
                LastUpdated     = $runTs
            }
        }
    )
    Write-RangerCsvFile -Path (Join-Path $OutputRoot 'storage-pools.csv') `
        -Columns @('PoolId','PoolName','ClusterId','SizeTiB','AllocatedTiB','FreeTiB','FaultDomainType','Health','LastUpdated') `
        -Rows $poolRows

    # volumes.csv
    $volRows = @(
        @($Manifest.domains.storage.virtualDisks) | ForEach-Object {
            $v = $_
            [ordered]@{
                VolumeId    = if ($v.friendlyName) { [string]$v.friendlyName } elseif ($v.name) { [string]$v.name } else { '' }
                VolumeName  = if ($v.friendlyName) { [string]$v.friendlyName } elseif ($v.name) { [string]$v.name } else { '' }
                PoolId      = if ($v.storagePoolFriendlyName) { [string]$v.storagePoolFriendlyName } elseif ($v.poolName) { [string]$v.poolName } else { '' }
                SizeTiB     = if ($null -ne $v.sizeGiB) { [string][math]::Round([double]$v.sizeGiB / 1024, 2) } else { '' }
                UsedTiB     = if ($null -ne $v.usedGiB) { [string][math]::Round([double]$v.usedGiB / 1024, 2) } else { '' }
                FreePct     = if ($null -ne $v.freePct) { [string]$v.freePct } else { '' }
                Resiliency  = if ($v.resiliencySetting) { [string]$v.resiliencySetting } else { '' }
                Health      = if ($v.healthStatus) { [string]$v.healthStatus } else { '' }
                LastUpdated = $runTs
            }
        }
    )
    Write-RangerCsvFile -Path (Join-Path $OutputRoot 'volumes.csv') `
        -Columns @('VolumeId','VolumeName','PoolId','SizeTiB','UsedTiB','FreePct','Resiliency','Health','LastUpdated') `
        -Rows $volRows

    # health-checks.csv (sourced from findings)
    $checkRows = @(
        @($Manifest.findings) | ForEach-Object {
            $f = $_
            [ordered]@{
                CheckId     = if ($f.id) { [string]$f.id } else { [string]$f.title }
                Domain      = if ($f.domain) { [string]$f.domain } else { '' }
                CheckName   = if ($f.title) { [string]$f.title } else { '' }
                Severity    = if ($f.severity) { [string]$f.severity } else { '' }
                Status      = if ($f.severity -eq 'good') { 'Healthy' } elseif ($f.severity -eq 'critical') { 'Critical' } elseif ($f.severity -eq 'warning') { 'Warning' } else { 'Informational' }
                NodeId      = if ($f.affectedComponents) { [string](@($f.affectedComponents) -join '; ') } else { '' }
                Finding     = if ($f.description) { [string]$f.description } else { '' }
                Remediation = if ($f.recommendation) { [string]$f.recommendation } else { '' }
                LastUpdated = $runTs
            }
        }
    )
    Write-RangerCsvFile -Path (Join-Path $OutputRoot 'health-checks.csv') `
        -Columns @('CheckId','Domain','CheckName','Severity','Status','NodeId','Finding','Remediation','LastUpdated') `
        -Rows $checkRows

    # network-adapters.csv
    $adapterRows = @(
        @($Manifest.domains.networking.adapters) | ForEach-Object {
            $a = $_
            [ordered]@{
                AdapterId     = if ($a.name) { ('{0}::{1}' -f ($a.node ?? ''), $a.name) } else { '' }
                NodeId        = if ($a.node) { [string]$a.node } else { '' }
                AdapterName   = if ($a.name) { [string]$a.name } else { '' }
                LinkSpeedGbps = if ($a.linkSpeedGbps) { [string]$a.linkSpeedGbps } elseif ($a.linkSpeed) { [string]$a.linkSpeed } else { '' }
                IntentName    = if ($a.intentName) { [string]$a.intentName } else { '' }
                SubnetMask    = if ($a.subnetMask) { [string]$a.subnetMask } else { '' }
                IpAddress     = if ($a.ipAddress) { [string]$a.ipAddress } else { '' }
                VlanId        = if ($a.vlanId) { [string]$a.vlanId } else { '' }
                LastUpdated   = $runTs
            }
        }
    )
    Write-RangerCsvFile -Path (Join-Path $OutputRoot 'network-adapters.csv') `
        -Columns @('AdapterId','NodeId','AdapterName','LinkSpeedGbps','IntentName','SubnetMask','IpAddress','VlanId','LastUpdated') `
        -Rows $adapterRows

    # _relationships.json (star schema)
    $relationships = [ordered]@{
        version = '1.0'
        tables  = @('nodes','volumes','storage-pools','health-checks','network-adapters')
        relationships = @(
            [ordered]@{ from = 'volumes';          fromColumn = 'PoolId';    to = 'storage-pools'; toColumn = 'PoolId' }
            [ordered]@{ from = 'storage-pools';    fromColumn = 'ClusterId'; to = 'nodes';         toColumn = 'ClusterId' }
            [ordered]@{ from = 'health-checks';    fromColumn = 'NodeId';    to = 'nodes';         toColumn = 'NodeId' }
            [ordered]@{ from = 'network-adapters'; fromColumn = 'NodeId';    to = 'nodes';         toColumn = 'NodeId' }
        )
    }
    ($relationships | ConvertTo-Json -Depth 10) | Set-Content -Path (Join-Path $OutputRoot '_relationships.json') -Encoding UTF8

    # _metadata.json
    $metadata = [ordered]@{
        runId         = if ($Manifest.run.runId) { [string]$Manifest.run.runId } else { [guid]::NewGuid().ToString() }
        clusterName   = $clusterId
        mode          = [string]$Manifest.run.mode
        rangerVersion = [string]$Manifest.run.toolVersion
        generatedAt   = $runTs
    }
    ($metadata | ConvertTo-Json -Depth 5) | Set-Content -Path (Join-Path $OutputRoot '_metadata.json') -Encoding UTF8

    return $OutputRoot
}

function Resolve-RangerHeadlessBrowser {
    <#
    .SYNOPSIS
        v1.6.0 (#207): locate a headless-capable browser for PDF generation.
    .OUTPUTS
        Hashtable @{ Path; Name; Version } or $null when no browser was found.
    #>
    $candidates = @(
        @{ Name = 'msedge';   Probe = { (Get-Command -Name 'msedge' -ErrorAction SilentlyContinue).Source } }
        @{ Name = 'msedge';   Probe = { Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe' } }
        @{ Name = 'msedge';   Probe = { Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe' } }
        @{ Name = 'chrome';   Probe = { (Get-Command -Name 'chrome' -ErrorAction SilentlyContinue).Source } }
        @{ Name = 'chrome';   Probe = { Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe' } }
        @{ Name = 'chrome';   Probe = { Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe' } }
        @{ Name = 'chromium'; Probe = { (Get-Command -Name 'chromium' -ErrorAction SilentlyContinue).Source } }
    )

    foreach ($c in $candidates) {
        try {
            $path = & $c.Probe
            if ([string]::IsNullOrWhiteSpace($path)) { continue }
            if (-not (Test-Path -Path $path -PathType Leaf)) { continue }

            $ver = $null
            try {
                $verOutput = & $path --version 2>$null
                if ($verOutput) { $ver = ($verOutput | Select-Object -First 1).ToString().Trim() }
            } catch { }

            return @{ Path = $path; Name = $c.Name; Version = $ver }
        } catch { }
    }

    return $null
}

function Invoke-RangerHeadlessPdf {
    <#
    .SYNOPSIS
        v1.6.0 (#207): render an HTML file to PDF via headless Edge / Chrome.
    .DESCRIPTION
        Invokes the resolved browser with --headless=new --print-to-pdf.
        Returns $true on success; $false when no browser is available or the
        output file is missing / zero-byte after rendering.
    #>
    param(
        [Parameter(Mandatory = $true)] [string]$HtmlPath,
        [Parameter(Mandatory = $true)] [string]$OutputPath,
        [int]$TimeoutSeconds = 60
    )

    $browser = Resolve-RangerHeadlessBrowser
    if (-not $browser) {
        Write-RangerLog -Level warn -Message 'PDF generation requires Microsoft Edge or Google Chrome. Neither was found. Install Edge (bundled with Windows 11/Server 2022) or add Chrome to PATH.'
        return $false
    }

    $fileUri = ([uri]::new($HtmlPath)).AbsoluteUri
    $argList = @(
        '--headless=new',
        '--disable-gpu',
        '--no-sandbox',
        "--print-to-pdf=$OutputPath",
        '--print-to-pdf-no-header',
        $fileUri
    )

    try {
        $proc = Start-Process -FilePath $browser.Path -ArgumentList $argList -NoNewWindow -PassThru -RedirectStandardOutput ([System.IO.Path]::GetTempFileName()) -RedirectStandardError ([System.IO.Path]::GetTempFileName())
        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            try { $proc.Kill() } catch { }
            Write-RangerLog -Level warn -Message "Headless PDF render timed out after ${TimeoutSeconds}s — output may be incomplete."
            return $false
        }
        if ($proc.ExitCode -ne 0) {
            Write-RangerLog -Level warn -Message "Headless browser exited with code $($proc.ExitCode) while rendering PDF."
            return $false
        }
    } catch {
        Write-RangerLog -Level warn -Message "Headless PDF render threw: $($_.Exception.Message)"
        return $false
    }

    if (-not (Test-Path -Path $OutputPath -PathType Leaf)) {
        Write-RangerLog -Level warn -Message "Headless browser completed but PDF output is missing: $OutputPath"
        return $false
    }
    $size = (Get-Item -Path $OutputPath).Length
    if ($size -lt 512) {
        Write-RangerLog -Level warn -Message "Headless browser produced a suspiciously small PDF ($size bytes) — treating as failed."
        return $false
    }

    Write-RangerLog -Level info -Message "PDF rendered via $($browser.Name) ($($browser.Version)) — $OutputPath ($size bytes)."
    return $true
}

function ConvertTo-RangerXmlText {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return ''
    }

    return [System.Security.SecurityElement]::Escape([string]$Value)
}

function ConvertTo-RangerOfficeText {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -is [bool]) {
        return $(if ($Value) { 'Yes' } else { 'No' })
    }

    if ($Value -is [datetime]) {
        return $Value.ToString('u').TrimEnd('Z').Trim()
    }

    if ($Value -is [System.Collections.IDictionary]) {
        return ((@($Value.Keys | ForEach-Object { '{0}={1}' -f $_, (ConvertTo-RangerOfficeText -Value $Value[$_]) })) -join '; ')
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return ((@($Value | ForEach-Object { ConvertTo-RangerOfficeText -Value $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) -join '; ')
    }

    return [string]$Value
}

function Get-RangerObjectValue {
    param(
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [string[]]$CandidateNames
    )

    foreach ($name in $CandidateNames) {
        if ($null -eq $InputObject) {
            continue
        }

        if ($InputObject -is [System.Collections.IDictionary] -and $InputObject.Contains($name)) {
            return $InputObject[$name]
        }

        $property = $InputObject.PSObject.Properties[$name]
        if ($property) {
            return $property.Value
        }
    }

    return $null
}

function Split-RangerWrappedText {
    param(
        [AllowNull()]
        [string]$Text,

        [int]$Width = 96
    )

    if ([string]::IsNullOrEmpty($Text)) {
        return @('')
    }

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($rawLine in (($Text -replace "`r", '') -split "`n")) {
        if ($rawLine.Length -le $Width) {
            $lines.Add($rawLine)
            continue
        }

        $remaining = $rawLine.TrimEnd()
        while ($remaining.Length -gt $Width) {
            $window = $remaining.Substring(0, $Width)
            $breakIndex = $window.LastIndexOf(' ')
            if ($breakIndex -lt ([math]::Floor($Width / 2))) {
                $breakIndex = $Width
            }
            $lines.Add($remaining.Substring(0, $breakIndex).TrimEnd())
            $remaining = $remaining.Substring($breakIndex).TrimStart()
        }
        $lines.Add($remaining)
    }

    return @($lines)
}

function Get-RangerReportPlainTextLines {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Report,

        [int]$WrapWidth = 96
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add($Report.Title)
    $lines.Add(('=' * [math]::Max(8, $Report.Title.Length)))
    $lines.Add('')
    $lines.Add("Cluster: $($Report.ClusterName)")
    $lines.Add("Mode: $($Report.Mode)")
    $lines.Add("Ranger Version: $($Report.Version)")
    $lines.Add("Generated: $($Report.GeneratedAt)")
    $lines.Add('')
    $lines.Add('Table of Contents')
    $lines.Add('-----------------')
    foreach ($heading in @($Report.TableOfContents)) {
        $lines.Add("- $heading")
    }
    $lines.Add('')

    foreach ($section in @($Report.Sections)) {
        $lines.Add($section.heading)
        $lines.Add(('-' * [math]::Max(6, $section.heading.Length)))
        switch ($section.type) {
            'table' {
                # Render headers
                if ($section.headers) {
                    $lines.Add(($section.headers -join '  |  '))
                    $lines.Add(('-' * 80))
                }
                foreach ($row in @($section.rows)) {
                    $lines.Add(($row -join '  |  '))
                }
            }
            'kv' {
                foreach ($pair in @($section.rows)) {
                    $lines.Add(('{0,-28} {1}' -f ($pair[0] + ':'), $pair[1]))
                }
            }
            'sign-off' {
                $lines.Add('Role                         Name             Date         Signature')
                $lines.Add(('-' * 80))
                $lines.Add('Implementation Engineer      _______________  ___________  _______________')
                $lines.Add('Technical Reviewer           _______________  ___________  _______________')
                $lines.Add('Customer Representative      _______________  ___________  _______________')
            }
            default {
                foreach ($entry in @($section.body)) {
                    $lines.Add("- $entry")
                }
            }
        }
        $lines.Add('')
    }

    $lines.Add('Recommendations')
    $lines.Add('---------------')
    if (@($Report.Recommendations).Count -eq 0) {
        $lines.Add('- No recommendations were surfaced for this output tier.')
    }
    else {
        foreach ($recommendation in @($Report.Recommendations)) {
            $lines.Add(("- [{0}] {1}: {2}" -f $recommendation.severity.ToUpperInvariant(), $recommendation.title, $recommendation.recommendation))
        }
    }
    $lines.Add('')

    $lines.Add('Findings')
    $lines.Add('--------')
    if (@($Report.Findings).Count -eq 0) {
        $lines.Add('- No findings were recorded for this output tier.')
    }
    else {
        foreach ($finding in @($Report.Findings)) {
            $lines.Add(("[{0}] {1}" -f $finding.severity.ToUpperInvariant(), $finding.title))
            foreach ($wrappedLine in @(Split-RangerWrappedText -Text $finding.description -Width $WrapWidth)) {
                $lines.Add("  $wrappedLine")
            }
            if ($finding.currentState) {
                $lines.Add("  Current state: $($finding.currentState)")
            }
            if ($finding.recommendation) {
                $lines.Add("  Recommendation: $($finding.recommendation)")
            }
            if (@($finding.affectedComponents).Count -gt 0) {
                $lines.Add(("  Affected components: {0}" -f (@($finding.affectedComponents) -join ', ')))
            }
            $lines.Add('')
        }
    }

    $wrapped = New-Object System.Collections.Generic.List[string]
    foreach ($line in @($lines)) {
        foreach ($wrappedLine in @(Split-RangerWrappedText -Text $line -Width $WrapWidth)) {
            $wrapped.Add($wrappedLine)
        }
    }

    return @($wrapped)
}

function Write-RangerZipEntry {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.Compression.ZipArchive]$Archive,

        [Parameter(Mandatory = $true)]
        [string]$EntryPath,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    $entry = $Archive.CreateEntry($EntryPath)
    $stream = $entry.Open()
    try {
        $writer = New-Object System.IO.StreamWriter($stream, [System.Text.UTF8Encoding]::new($false))
        try {
            $writer.Write($Content)
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function New-RangerDocxParagraphXml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [string]$Style = 'Normal'
    )

    $escaped = ConvertTo-RangerXmlText -Value $Text
    $styleXml = if ($Style -and $Style -ne 'Normal') { '<w:pPr><w:pStyle w:val="{0}"/></w:pPr>' -f $Style } else { '' }
    '<w:p>{0}<w:r><w:t xml:space="preserve">{1}</w:t></w:r></w:p>' -f $styleXml, $escaped
}

function New-RangerDocxTableXml {
    <#
    .SYNOPSIS
        v1.6.0 (#208): render a tabular OOXML <w:tbl> from headers + rows.
        Header row is styled bold and repeats on page breaks.
    #>
    param(
        [string[]]$Headers,
        [object[][]]$Rows,
        [string]$Caption
    )

    if ($null -eq $Rows -or @($Rows).Count -eq 0) {
        return (New-RangerDocxParagraphXml -Text 'No data available.' -Style 'Normal')
    }

    $tblPr = '<w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="0" w:type="auto"/><w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/><w:left w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/><w:right w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/><w:insideH w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/></w:tblBorders></w:tblPr>'

    $headerCells = ($Headers | ForEach-Object {
        $txt = ConvertTo-RangerXmlText -Value $_
        "<w:tc><w:tcPr><w:shd w:val='clear' w:color='auto' w:fill='1E3A5F'/></w:tcPr><w:p><w:pPr><w:rPr><w:b/><w:color w:val='FFFFFF'/></w:rPr></w:pPr><w:r><w:rPr><w:b/><w:color w:val='FFFFFF'/></w:rPr><w:t xml:space='preserve'>$txt</w:t></w:r></w:p></w:tc>"
    }) -join ''
    $headerRow = "<w:tr><w:trPr><w:tblHeader/></w:trPr>$headerCells</w:tr>"

    $bodyRows = @($Rows | ForEach-Object {
        $cells = @($_ | ForEach-Object {
            $txt = ConvertTo-RangerXmlText -Value $_
            "<w:tc><w:p><w:r><w:t xml:space='preserve'>$txt</w:t></w:r></w:p></w:tc>"
        }) -join ''
        "<w:tr>$cells</w:tr>"
    }) -join ''

    $xml = "<w:tbl>$tblPr$headerRow$bodyRows</w:tbl>"
    if (-not [string]::IsNullOrWhiteSpace($Caption)) {
        $cap = ConvertTo-RangerXmlText -Value $Caption
        $xml += "<w:p><w:pPr><w:rPr><w:i/><w:color w:val='64748B'/></w:rPr></w:pPr><w:r><w:rPr><w:i/><w:color w:val='64748B'/></w:rPr><w:t xml:space='preserve'>$cap</w:t></w:r></w:p>"
    }
    return $xml
}

function New-RangerDocxKvTableXml {
    <#
    .SYNOPSIS
        v1.6.0 (#208): render a two-column key/value table.
    #>
    param([object[][]]$Pairs)
    if ($null -eq $Pairs -or @($Pairs).Count -eq 0) { return '' }

    $tblPr = '<w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblBorders><w:bottom w:val="single" w:sz="2" w:space="0" w:color="F1F5F9"/><w:insideH w:val="single" w:sz="2" w:space="0" w:color="F1F5F9"/></w:tblBorders></w:tblPr>'
    $rows = @($Pairs | ForEach-Object {
        $k = ConvertTo-RangerXmlText -Value ([string]$_[0])
        $v = ConvertTo-RangerXmlText -Value ([string]$_[1])
        "<w:tr><w:tc><w:tcPr><w:tcW w:w='3600' w:type='dxa'/></w:tcPr><w:p><w:pPr><w:rPr><w:b/><w:color w:val='475569'/></w:rPr></w:pPr><w:r><w:rPr><w:b/><w:color w:val='475569'/></w:rPr><w:t xml:space='preserve'>$k</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t xml:space='preserve'>$v</w:t></w:r></w:p></w:tc></w:tr>"
    }) -join ''
    return "<w:tbl>$tblPr$rows</w:tbl>"
}

function Write-RangerDocxReport {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Report,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
    }

    $paragraphs = New-Object System.Collections.Generic.List[string]
    $paragraphs.Add((New-RangerDocxParagraphXml -Text $Report.Title -Style 'Title'))
    $paragraphs.Add((New-RangerDocxParagraphXml -Text "Cluster: $($Report.ClusterName)"))
    $paragraphs.Add((New-RangerDocxParagraphXml -Text "Mode: $($Report.Mode)"))
    $paragraphs.Add((New-RangerDocxParagraphXml -Text "Ranger Version: $($Report.Version)"))
    $paragraphs.Add((New-RangerDocxParagraphXml -Text "Generated: $($Report.GeneratedAt)"))
    $paragraphs.Add((New-RangerDocxParagraphXml -Text 'Table of Contents' -Style 'Heading1'))
    foreach ($heading in @($Report.TableOfContents)) {
        $paragraphs.Add((New-RangerDocxParagraphXml -Text "- $heading" -Style 'ListParagraph'))
    }

    foreach ($section in @($Report.Sections)) {
        $paragraphs.Add((New-RangerDocxParagraphXml -Text $section.heading -Style 'Heading1'))
        # v1.6.0 (#208): render section.type='table' and 'kv' as OOXML tables.
        switch ($section.type) {
            'table' {
                $paragraphs.Add((New-RangerDocxTableXml -Headers $section.headers -Rows $section.rows -Caption $section.caption))
            }
            'kv' {
                $paragraphs.Add((New-RangerDocxKvTableXml -Pairs $section.rows))
            }
            'sign-off' {
                $paragraphs.Add((New-RangerDocxTableXml -Headers @('Role','Name','Date','Signature') -Rows @(
                    ,@('Implementation Engineer','','','')
                    ,@('Technical Reviewer','','','')
                    ,@('Customer Representative','','','')
                )))
            }
            default {
                foreach ($entry in @($section.body)) {
                    $paragraphs.Add((New-RangerDocxParagraphXml -Text "- $entry" -Style 'ListParagraph'))
                }
            }
        }
    }

    $paragraphs.Add((New-RangerDocxParagraphXml -Text 'Recommendations' -Style 'Heading1'))
    if (@($Report.Recommendations).Count -eq 0) {
        $paragraphs.Add((New-RangerDocxParagraphXml -Text '- No recommendations were surfaced for this output tier.' -Style 'ListParagraph'))
    }
    else {
        foreach ($recommendation in @($Report.Recommendations)) {
            $paragraphs.Add((New-RangerDocxParagraphXml -Text ("- [{0}] {1}: {2}" -f $recommendation.severity.ToUpperInvariant(), $recommendation.title, $recommendation.recommendation) -Style 'ListParagraph'))
        }
    }

    $paragraphs.Add((New-RangerDocxParagraphXml -Text 'Findings' -Style 'Heading1'))
    if (@($Report.Findings).Count -eq 0) {
        $paragraphs.Add((New-RangerDocxParagraphXml -Text '- No findings were recorded for this output tier.' -Style 'ListParagraph'))
    }
    else {
        foreach ($finding in @($Report.Findings)) {
            $paragraphs.Add((New-RangerDocxParagraphXml -Text ("[{0}] {1}" -f $finding.severity.ToUpperInvariant(), $finding.title) -Style 'Heading2'))
            $paragraphs.Add((New-RangerDocxParagraphXml -Text $finding.description))
            if ($finding.currentState) {
                $paragraphs.Add((New-RangerDocxParagraphXml -Text "Current state: $($finding.currentState)"))
            }
            if ($finding.recommendation) {
                $paragraphs.Add((New-RangerDocxParagraphXml -Text "Recommendation: $($finding.recommendation)"))
            }
            if (@($finding.affectedComponents).Count -gt 0) {
                $paragraphs.Add((New-RangerDocxParagraphXml -Text ("Affected components: {0}" -f (@($finding.affectedComponents) -join ', '))))
            }
        }
    }

    $documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:w10="urn:schemas-microsoft-com:office:word" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" mc:Ignorable="w14 wp14">
  <w:body>
    $($paragraphs -join "`n    ")
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>
"@

    $stylesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>
  <w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:rPr><w:b/><w:sz w:val="32"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:rPr><w:b/><w:sz w:val="24"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="ListParagraph"><w:name w:val="List Paragraph"/><w:basedOn w:val="Normal"/><w:ind w:left="360"/></w:style>
</w:styles>
"@

    $contentTypesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
"@

    $rootRelsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
"@

    $documentRelsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
"@

    $coreXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>$(ConvertTo-RangerXmlText -Value $Report.Title)</dc:title>
  <dc:creator>AzureLocalRanger</dc:creator>
  <cp:lastModifiedBy>AzureLocalRanger</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">$((Get-Date).ToUniversalTime().ToString('s'))Z</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$((Get-Date).ToUniversalTime().ToString('s'))Z</dcterms:modified>
</cp:coreProperties>
"@

    $appXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>AzureLocalRanger</Application>
</Properties>
"@

    $archive = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        Write-RangerZipEntry -Archive $archive -EntryPath '[Content_Types].xml' -Content $contentTypesXml
        Write-RangerZipEntry -Archive $archive -EntryPath '_rels/.rels' -Content $rootRelsXml
        Write-RangerZipEntry -Archive $archive -EntryPath 'docProps/core.xml' -Content $coreXml
        Write-RangerZipEntry -Archive $archive -EntryPath 'docProps/app.xml' -Content $appXml
        Write-RangerZipEntry -Archive $archive -EntryPath 'word/document.xml' -Content $documentXml
        Write-RangerZipEntry -Archive $archive -EntryPath 'word/styles.xml' -Content $stylesXml
        Write-RangerZipEntry -Archive $archive -EntryPath 'word/_rels/document.xml.rels' -Content $documentRelsXml
    }
    finally {
        $archive.Dispose()
    }
}

function ConvertTo-RangerPdfLiteral {
    param(
        [AllowNull()]
        [string]$Text
    )

    if ($null -eq $Text) {
        return ''
    }

    return (($Text -replace '\\', '\\\\') -replace '\(', '\\(' -replace '\)', '\\)')
}

function Write-RangerPdfReport {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Report,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Cover page lines (#96)
    $coverLines = @(
        '',
        '',
        '',
        '  Azure Local Ranger',
        ('  ' + ('=' * 60)),
        '',
        "  $($Report.Title)",
        '',
        "  Cluster:          $($Report.ClusterName)",
        "  Mode:             $($Report.Mode)",
        "  Ranger Version:   $($Report.Version)",
        "  Generated:        $($Report.GeneratedAt)",
        '',
        ('  ' + ('=' * 60)),
        '',
        '  CONFIDENTIAL — INTERNAL USE ONLY',
        '',
        '  This document was generated automatically by Azure Local Ranger.',
        '  Review all findings and recommendations before use as a formal record.'
    )

    $allLines = @($coverLines) + @('') + @(Get-RangerReportPlainTextLines -Report $Report -WrapWidth 92)
    $linesPerPage = 50
    $pageSets = New-Object System.Collections.Generic.List[object]
    for ($index = 0; $index -lt $allLines.Count; $index += $linesPerPage) {
        $remaining = $allLines.Count - $index
        $take = [math]::Min($linesPerPage, $remaining)
        $pageSets.Add(@($allLines[$index..($index + $take - 1)]))
    }
    if ($pageSets.Count -eq 0) {
        $pageSets.Add(@('AzureLocalRanger report'))
    }

    $objectBodies = @{}
    $pageObjectIds = New-Object System.Collections.Generic.List[int]
    $fontObjectId = (3 + ($pageSets.Count * 2))
    $nextObjectId = 3

    foreach ($pageLines in $pageSets) {
        $contentBuilder = New-Object System.Text.StringBuilder
        [void]$contentBuilder.AppendLine('BT')
        [void]$contentBuilder.AppendLine('/F1 10 Tf')
        [void]$contentBuilder.AppendLine('50 780 Td')
        [void]$contentBuilder.AppendLine('14 TL')
        foreach ($line in @($pageLines)) {
            $literal = ConvertTo-RangerPdfLiteral -Text $(if ([string]::IsNullOrEmpty($line)) { ' ' } else { $line })
            [void]$contentBuilder.AppendLine("($literal) Tj")
            [void]$contentBuilder.AppendLine('T*')
        }
        [void]$contentBuilder.AppendLine('ET')

        $contentStream = $contentBuilder.ToString()
        $contentObjectId = $nextObjectId
        $pageObjectId = $nextObjectId + 1
        $nextObjectId += 2

        $objectBodies[$contentObjectId] = "<< /Length $([System.Text.Encoding]::ASCII.GetByteCount($contentStream)) >>`nstream`n$contentStream`nendstream"
        $objectBodies[$pageObjectId] = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 $fontObjectId 0 R >> >> /Contents $contentObjectId 0 R >>"
        $pageObjectIds.Add($pageObjectId)
    }

    $objectBodies[1] = '<< /Type /Catalog /Pages 2 0 R >>'
    $objectBodies[2] = "<< /Type /Pages /Count $($pageObjectIds.Count) /Kids [$((@($pageObjectIds) | ForEach-Object { "$_ 0 R" }) -join ' ')] >>"
    $objectBodies[$fontObjectId] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append("%PDF-1.4`n%Ranger`n")
    $offsets = New-Object System.Collections.Generic.List[int]
    $offsets.Add(0)
    for ($objectId = 1; $objectId -le $fontObjectId; $objectId++) {
        $offsets.Add([System.Text.Encoding]::ASCII.GetByteCount($builder.ToString()))
        [void]$builder.Append("$objectId 0 obj`n$($objectBodies[$objectId])`nendobj`n")
    }
    $xrefOffset = [System.Text.Encoding]::ASCII.GetByteCount($builder.ToString())
    [void]$builder.Append("xref`n0 $($fontObjectId + 1)`n")
    [void]$builder.Append("0000000000 65535 f `n")
    for ($objectId = 1; $objectId -le $fontObjectId; $objectId++) {
        [void]$builder.Append(([string]::Format('{0:0000000000} 00000 n `n', $offsets[$objectId])))
    }
    [void]$builder.Append("trailer`n<< /Size $($fontObjectId + 1) /Root 1 0 R >>`nstartxref`n$xrefOffset`n%%EOF")
    [System.IO.File]::WriteAllText($Path, $builder.ToString(), [System.Text.Encoding]::ASCII)
}

function ConvertTo-RangerExcelColumnName {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Index
    )

    $name = ''
    $current = $Index
    while ($current -gt 0) {
        $remainder = ($current - 1) % 26
        $name = [char](65 + $remainder) + $name
        $current = [math]::Floor(($current - 1) / 26)
    }
    return $name
}

function Get-RangerExcelSheetDefinitions {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $summary = Get-RangerManifestSummary -Manifest $Manifest

    $overviewRows = @(
        [ordered]@{ Metric = 'Cluster'; Value = $summary.ClusterName }
        [ordered]@{ Metric = 'Mode'; Value = $Manifest.run.mode }
        [ordered]@{ Metric = 'Generated'; Value = $Manifest.run.endTimeUtc }
        [ordered]@{ Metric = 'Nodes'; Value = $summary.NodeCount }
        [ordered]@{ Metric = 'VMs'; Value = $summary.VmCount }
        [ordered]@{ Metric = 'Azure resources'; Value = $summary.AzureResourceCount }
        [ordered]@{ Metric = 'Successful collectors'; Value = $summary.SuccessfulCollectors }
        [ordered]@{ Metric = 'Partial collectors'; Value = $summary.PartialCollectors }
        [ordered]@{ Metric = 'Failed collectors'; Value = $summary.FailedCollectors }
    )

    $nodeRows = @(
        @($Manifest.domains.clusterNode.nodes) | ForEach-Object {
            [ordered]@{
                Node         = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('name', 'node'))
                State        = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('state', 'status'))
                Manufacturer = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('manufacturer'))
                Model        = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('model'))
                Serial       = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('serialNumber', 'serial'))
                CPU          = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('processorModel', 'cpuModel'))
                MemoryGiB    = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('memoryGiB', 'memoryGb'))
                OS           = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('osVersion', 'operatingSystem'))
            }
        }
    )

    $storageRows = @(
        @($Manifest.domains.storage.physicalDisks) | ForEach-Object {
            [ordered]@{
                Disk          = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('friendlyName', 'name'))
                MediaType     = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('mediaType'))
                HealthStatus  = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('healthStatus'))
                Operational   = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('operationalStatus'))
                SizeGiB       = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('sizeGiB'))
                Usage         = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('usage'))
                Serial        = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('serialNumber', 'serial'))
                Slot          = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('slot', 'slotNumber'))
            }
        }
    )

    $networkRows = @(
        @($Manifest.domains.networking.adapters) | ForEach-Object {
            [ordered]@{
                Node           = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('node'))
                Adapter        = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('name', 'interfaceAlias'))
                Status         = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('status', 'state'))
                LinkSpeedGbps  = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('linkSpeedGbps', 'linkSpeedGb'))
                MacAddress     = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('macAddress'))
                VirtualSwitch  = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('virtualSwitch', 'vswitch'))
                RdmaEnabled    = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('rdmaEnabled'))
                DriverVersion  = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('driverVersion'))
            }
        }
    )

    $vmRows = @(
        @($Manifest.domains.virtualMachines.inventory) | ForEach-Object {
            [ordered]@{
                VM             = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('name'))
                Host           = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('host', 'computerName'))
                State          = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('state', 'status'))
                Generation     = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('generation'))
                VcpuCount      = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('processorCount', 'vcpuCount'))
                MemoryStartup  = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('memoryStartupGb', 'memoryStartupGiB', 'memoryStartupMb'))
                Checkpoints    = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('checkpointCount'))
                GuestIp        = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('primaryIpAddress'))
                IpSource       = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('ipAddressSource'))
                WorkloadFamily = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('workloadFamily'))
            }
        }
    )

    $azureRows = @(
        @($Manifest.domains.azureIntegration.resources) | ForEach-Object {
            [ordered]@{
                Name          = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('Name', 'name'))
                ResourceType  = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('ResourceType', 'resourceType', 'Type', 'type'))
                Location      = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('Location', 'location'))
                ResourceGroup = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('ResourceGroupName', 'resourceGroup'))
                Subscription  = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('SubscriptionId', 'subscriptionId'))
                Id            = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('ResourceId', 'Id', 'id'))
            }
        }
    )

    $findingRows = @(
        @($Manifest.findings) | ForEach-Object {
            [ordered]@{
                Severity           = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('severity'))
                Title              = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('title'))
                Description        = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('description'))
                CurrentState       = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('currentState'))
                Recommendation     = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('recommendation'))
                AffectedComponents = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $_ -CandidateNames @('affectedComponents'))
            }
        }
    )

    $collectorRows = @(
        @($Manifest.collectors.Keys | Sort-Object | ForEach-Object {
            $collector = $Manifest.collectors[$_]
            [ordered]@{
                Collector   = $_
                Status      = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $collector -CandidateNames @('status'))
                TargetScope = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $collector -CandidateNames @('targetScope'))
                DurationMs  = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $collector -CandidateNames @('durationMs', 'durationMilliseconds'))
                Evidence    = ConvertTo-RangerOfficeText -Value (Get-RangerObjectValue -InputObject $collector -CandidateNames @('rawEvidencePath'))
            }
        })
    )

    return @(
        [ordered]@{ Name = 'Overview'; Columns = @('Metric', 'Value'); Rows = $overviewRows }
        [ordered]@{ Name = 'Nodes'; Columns = @('Node', 'State', 'Manufacturer', 'Model', 'Serial', 'CPU', 'MemoryGiB', 'OS'); Rows = $nodeRows }
        [ordered]@{ Name = 'Storage'; Columns = @('Disk', 'MediaType', 'HealthStatus', 'Operational', 'SizeGiB', 'Usage', 'Serial', 'Slot'); Rows = $storageRows }
        [ordered]@{ Name = 'Networking'; Columns = @('Node', 'Adapter', 'Status', 'LinkSpeedGbps', 'MacAddress', 'VirtualSwitch', 'RdmaEnabled', 'DriverVersion'); Rows = $networkRows }
        [ordered]@{ Name = 'VirtualMachines'; Columns = @('VM', 'Host', 'State', 'Generation', 'VcpuCount', 'MemoryStartup', 'Checkpoints', 'GuestIp', 'IpSource', 'WorkloadFamily'); Rows = $vmRows }
        [ordered]@{ Name = 'AzureResources'; Columns = @('Name', 'ResourceType', 'Location', 'ResourceGroup', 'Subscription', 'Id'); Rows = $azureRows }
        [ordered]@{ Name = 'Findings'; Columns = @('Severity', 'Title', 'Description', 'CurrentState', 'Recommendation', 'AffectedComponents'); Rows = $findingRows }
        [ordered]@{ Name = 'Collectors'; Columns = @('Collector', 'Status', 'TargetScope', 'DurationMs', 'Evidence'); Rows = $collectorRows }
    )
}

function Write-RangerExcelWorkbook {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
    }

    $sheetDefinitions = @(Get-RangerExcelSheetDefinitions -Manifest $Manifest)
    $worksheetEntries = New-Object System.Collections.Generic.List[object]
    $sheetId = 1
    foreach ($sheetDefinition in $sheetDefinitions) {
        $columns = @($sheetDefinition.Columns)
        $rows = @($sheetDefinition.Rows)
        $maxRow = [math]::Max(2, $rows.Count + 1)
        $lastColumnName = ConvertTo-RangerExcelColumnName -Index $columns.Count
        $sheetDataRows = New-Object System.Collections.Generic.List[string]

        $headerCells = New-Object System.Collections.Generic.List[string]
        for ($columnIndex = 0; $columnIndex -lt $columns.Count; $columnIndex++) {
            $cellReference = '{0}1' -f (ConvertTo-RangerExcelColumnName -Index ($columnIndex + 1))
            $headerCells.Add(('<c r="{0}" t="inlineStr" s="1"><is><t xml:space="preserve">{1}</t></is></c>' -f $cellReference, (ConvertTo-RangerXmlText -Value $columns[$columnIndex])))
        }
        $sheetDataRows.Add(('<row r="1">{0}</row>' -f ($headerCells -join '')))

        for ($rowIndex = 0; $rowIndex -lt $rows.Count; $rowIndex++) {
            $row = $rows[$rowIndex]
            $cellXml = New-Object System.Collections.Generic.List[string]
            for ($columnIndex = 0; $columnIndex -lt $columns.Count; $columnIndex++) {
                $columnName = $columns[$columnIndex]
                $value = ConvertTo-RangerOfficeText -Value $(if ($row -is [System.Collections.IDictionary] -and $row.Contains($columnName)) { $row[$columnName] } else { $null })
                # v1.6.0 (#209): prevent Excel formula injection — cell values
                # that begin with =, +, -, @ are prefixed with an apostrophe
                # so Excel treats them as literal text.
                if ($value -is [string] -and $value.Length -gt 0 -and $value[0] -in @('=', '+', '-', '@')) {
                    $value = "'" + $value
                }
                $cellReference = '{0}{1}' -f (ConvertTo-RangerExcelColumnName -Index ($columnIndex + 1)), ($rowIndex + 2)
                $cellXml.Add(('<c r="{0}" t="inlineStr"><is><t xml:space="preserve">{1}</t></is></c>' -f $cellReference, (ConvertTo-RangerXmlText -Value $value)))
            }
            $sheetDataRows.Add(('<row r="{0}">{1}</row>' -f ($rowIndex + 2), ($cellXml -join '')))
        }

        $worksheetXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <dimension ref="A1:$lastColumnName$maxRow"/>
  <sheetViews>
    <sheetView workbookViewId="0">
      <pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>
    </sheetView>
  </sheetViews>
  <sheetFormatPr defaultRowHeight="15"/>
  <sheetData>
    $($sheetDataRows -join "`n    ")
  </sheetData>
  <autoFilter ref="A1:$lastColumnName$maxRow"/>
</worksheet>
"@

        $worksheetEntries.Add([ordered]@{
            Name = $sheetDefinition.Name
            Path = "xl/worksheets/sheet$sheetId.xml"
            RelId = "rId$sheetId"
            Xml = $worksheetXml
            SheetId = $sheetId
        })
        $sheetId++
    }

    $sheetListXml = @($worksheetEntries | ForEach-Object { '<sheet name="{0}" sheetId="{1}" r:id="{2}"/>' -f (ConvertTo-RangerXmlText -Value $_.Name), $_.SheetId, $_.RelId }) -join "`n    "
    $workbookXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    $sheetListXml
  </sheets>
</workbook>
"@

    $workbookRelsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    $((@($worksheetEntries | ForEach-Object { '<Relationship Id="{0}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{1}.xml"/>' -f $_.RelId, $_.SheetId }) + '<Relationship Id="rId99" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>') -join "`n  ")
</Relationships>
"@

    $stylesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2">
    <font><sz val="11"/><name val="Calibri"/></font>
    <font><b/><sz val="11"/><name val="Calibri"/><color rgb="FFFFFFFF"/></font>
  </fonts>
  <fills count="3">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF0F4C81"/><bgColor indexed="64"/></patternFill></fill>
  </fills>
  <borders count="2">
    <border><left/><right/><top/><bottom/><diagonal/></border>
    <border><left style="thin"/><right style="thin"/><top style="thin"/><bottom style="thin"/><diagonal/></border>
  </borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="2">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
  </cellXfs>
  <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>
"@

    $contentTypesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
    $(@($worksheetEntries | ForEach-Object { '<Override PartName="/xl/worksheets/sheet{0}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' -f $_.SheetId }) -join "`n  ")
</Types>
"@

    $rootRelsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>
"@

    $archive = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        Write-RangerZipEntry -Archive $archive -EntryPath '[Content_Types].xml' -Content $contentTypesXml
        Write-RangerZipEntry -Archive $archive -EntryPath '_rels/.rels' -Content $rootRelsXml
        Write-RangerZipEntry -Archive $archive -EntryPath 'xl/workbook.xml' -Content $workbookXml
        Write-RangerZipEntry -Archive $archive -EntryPath 'xl/_rels/workbook.xml.rels' -Content $workbookRelsXml
        Write-RangerZipEntry -Archive $archive -EntryPath 'xl/styles.xml' -Content $stylesXml
        foreach ($worksheetEntry in $worksheetEntries) {
            Write-RangerZipEntry -Archive $archive -EntryPath $worksheetEntry.Path -Content $worksheetEntry.Xml
        }
    }
    finally {
        $archive.Dispose()
    }
}