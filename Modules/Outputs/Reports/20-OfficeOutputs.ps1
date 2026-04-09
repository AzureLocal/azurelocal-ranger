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
        foreach ($entry in @($section.body)) {
            $lines.Add("- $entry")
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
        foreach ($entry in @($section.body)) {
            $paragraphs.Add((New-RangerDocxParagraphXml -Text "- $entry" -Style 'ListParagraph'))
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

    $allLines = @(Get-RangerReportPlainTextLines -Report $Report -WrapWidth 92)
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