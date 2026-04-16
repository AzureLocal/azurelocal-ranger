BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
    $script:fixtureRoot = Join-Path $script:repoRoot 'tests\maproom\Fixtures'
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
}

Describe 'Azure Local Ranger cached outputs' {
    It 'renders reports and diagrams from a saved manifest' {
        $outputRoot = Join-Path $TestDrive 'rendered-package'
        $manifestPath = Join-Path $fixtureRoot 'manifest-sample.json'

        $result = Export-AzureLocalRangerReport -ManifestPath $manifestPath -OutputPath $outputRoot -Formats @('html', 'markdown', 'docx', 'xlsx', 'pdf', 'svg')

        (Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*.html').Count | Should -Be 3
        (Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*.md').Count | Should -Be 3
        (Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*.docx').Count | Should -Be 3
        (Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*.pdf').Count | Should -Be 3
        (Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*.xlsx').Count | Should -Be 1
        (Get-ChildItem -Path (Join-Path $outputRoot 'diagrams') -Filter '*.drawio').Count | Should -BeGreaterThan 0
        (Get-ChildItem -Path (Join-Path $outputRoot 'diagrams') -Filter '*.svg').Count | Should -BeGreaterThan 0
        Test-Path -Path (Join-Path $outputRoot 'README.md') | Should -BeTrue
        @($result.Artifacts | Where-Object { $_.type -eq 'docx-report' }).Count | Should -Be 3
        @($result.Artifacts | Where-Object { $_.type -eq 'pdf-report' }).Count | Should -Be 3
        @($result.Artifacts | Where-Object { $_.type -eq 'xlsx-workbook' }).Count | Should -Be 1

        $technicalMarkdown = Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*Technical-Deep-Dive.md' | Select-Object -First 1
        $htmlReport = Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*.html' | Select-Object -First 1
        $docxReport = Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*Executive-Summary.docx' | Select-Object -First 1
        $xlsxWorkbook = Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*.xlsx' | Select-Object -First 1
        $pdfReport = Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*Technical-Deep-Dive.pdf' | Select-Object -First 1
        $technicalMarkdownContent = Get-Content -Path $technicalMarkdown.FullName -Raw
        $htmlReportContent = Get-Content -Path $htmlReport.FullName -Raw
        $pdfHeader = [System.IO.File]::ReadAllText($pdfReport.FullName, [System.Text.Encoding]::ASCII)

        $technicalMarkdownContent | Should -Match 'Table of Contents'
        $technicalMarkdownContent | Should -Match 'Priority Recommendations'
        $technicalMarkdownContent | Should -Match 'Domain Summary'
        $htmlReportContent | Should -Match 'Collector Overview'
        $htmlReportContent | Should -Match 'Priority Recommendations'
        $pdfHeader | Should -Match '%PDF-1.4'

        $docxArchive = [System.IO.Compression.ZipFile]::OpenRead($docxReport.FullName)
        try {
            ($docxArchive.Entries.FullName -contains 'word/document.xml') | Should -BeTrue
        }
        finally {
            $docxArchive.Dispose()
        }

        $xlsxArchive = [System.IO.Compression.ZipFile]::OpenRead($xlsxWorkbook.FullName)
        try {
            ($xlsxArchive.Entries.FullName -contains 'xl/workbook.xml') | Should -BeTrue
            (@($xlsxArchive.Entries | Where-Object { $_.FullName -like 'xl/worksheets/*.xml' })).Count | Should -BeGreaterThan 3
        }
        finally {
            $xlsxArchive.Dispose()
        }
    }

    It 'records skipped diagram artifacts when required data is absent' {
        InModuleScope AzureLocalRanger {
            param($ManifestFile, $PackageRoot)

            $manifest = Get-Content -Path $ManifestFile -Raw | ConvertFrom-Json -Depth 100
            $manifest.domains.monitoring = [ordered]@{
                telemetry = @()
                ama = @()
                dcr = @()
                dce = @()
                insights = @()
                alerts = @()
                health = @()
            }

            $result = Invoke-RangerOutputGeneration -Manifest (ConvertTo-RangerHashtable -InputObject $manifest) -PackageRoot $PackageRoot -Formats @('svg') -Mode 'current-state'
            @($result.Artifacts | Where-Object { $_.status -eq 'skipped' }).Count | Should -BeGreaterThan 0
        } -Parameters @{ ManifestFile = (Join-Path $fixtureRoot 'manifest-sample.json'); PackageRoot = (Join-Path $TestDrive 'artifact-check') }
    }
}