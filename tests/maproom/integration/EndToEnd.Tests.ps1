BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
    $script:fixtureRoot = Join-Path $script:repoRoot 'tests\maproom\Fixtures'
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
}

Describe 'Azure Local Ranger end-to-end fixture package' {
    It 'builds reports and diagrams from the fixture-backed discovery pipeline' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $config.output.rootPath = Join-Path $TestDrive 'packages'
        $config.output.formats = @('html', 'markdown', 'docx', 'xlsx', 'pdf', 'svg')
        $config.behavior.promptForMissingCredentials = $false
        $config.behavior.continueToRendering = $true
        $config.credentials.cluster = $null
        $config.credentials.domain = $null
        $config.credentials.bmc = $null
        $config.domains.hints.fixtures = [ordered]@{
            'topology-cluster' = (Join-Path $fixtureRoot 'topology-cluster.json')
            'hardware' = (Join-Path $fixtureRoot 'hardware.json')
            'storage-networking' = (Join-Path $fixtureRoot 'storage-networking.json')
            'workload-identity-azure' = (Join-Path $fixtureRoot 'workload-identity-azure.json')
            'monitoring-observability' = (Join-Path $fixtureRoot 'monitoring-observability.json')
            'management-performance' = (Join-Path $fixtureRoot 'management-performance.json')
            'waf-assessment' = (Join-Path $fixtureRoot 'waf-assessment.json')
        }

        $result = Invoke-AzureLocalRanger -ConfigObject $config -OutputPath (Join-Path $TestDrive 'packages')
        Test-Path -Path $result.ManifestPath | Should -BeTrue
        (Get-ChildItem -Path (Join-Path $result.PackageRoot 'reports') -Filter '*.html').Count | Should -Be 3
        (Get-ChildItem -Path (Join-Path $result.PackageRoot 'reports') -Filter '*.docx').Count | Should -Be 3
        (Get-ChildItem -Path (Join-Path $result.PackageRoot 'reports') -Filter '*.pdf').Count | Should -Be 3
        (Get-ChildItem -Path (Join-Path $result.PackageRoot 'reports') -Filter '*.xlsx').Count | Should -Be 1
        (Get-ChildItem -Path (Join-Path $result.PackageRoot 'diagrams') -Filter '*.drawio').Count | Should -BeGreaterThan 0
        Test-Path -Path (Join-Path $result.PackageRoot 'README.md') | Should -BeTrue
        Test-Path -Path (Join-Path $result.PackageRoot 'package-index.json') | Should -BeTrue
    }

    It 'redacts the whole fixture-backed run: no fixture identifier survives anywhere in the package (-Redact)' {
        $config = InModuleScope AzureLocalRanger { Get-RangerDefaultConfig }
        $config.output.rootPath = Join-Path $TestDrive 'redacted-packages'
        $config.output.formats = @('html', 'markdown', 'svg', 'drawio', 'docx', 'xlsx', 'pdf', 'powerbi', 'pptx', 'json-evidence')
        $config.behavior.promptForMissingCredentials = $false
        $config.behavior.continueToRendering = $true
        $config.credentials.cluster = $null
        $config.credentials.domain = $null
        $config.credentials.bmc = $null
        $fixtures = [ordered]@{
            'topology-cluster' = (Join-Path $fixtureRoot 'topology-cluster.json')
            'hardware' = (Join-Path $fixtureRoot 'hardware.json')
            'storage-networking' = (Join-Path $fixtureRoot 'storage-networking.json')
            'workload-identity-azure' = (Join-Path $fixtureRoot 'workload-identity-azure.json')
            'monitoring-observability' = (Join-Path $fixtureRoot 'monitoring-observability.json')
            'management-performance' = (Join-Path $fixtureRoot 'management-performance.json')
            'waf-assessment' = (Join-Path $fixtureRoot 'waf-assessment.json')
        }
        $config.domains.hints.fixtures = $fixtures
        $mapPath = Join-Path $TestDrive 'private-map.json'

        $result = Invoke-AzureLocalRanger -ConfigObject $config -OutputPath (Join-Path $TestDrive 'redacted-packages') -Redact -RedactMapPath $mapPath

        # Identifiers = every IPv4 / GUID / *.local name found in the raw fixtures.
        $raw = ($fixtures.Values | ForEach-Object { Get-Content $_ -Raw }) -join ' '
        $ids = @(
            [regex]::Matches($raw, '\b(?:(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\b') | ForEach-Object Value | Where-Object { $_ -notmatch '^(?:0\.0\.0\.0|127\.|255\.|169\.254\.)' }
            [regex]::Matches($raw, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}') | ForEach-Object Value
            [regex]::Matches($raw, '\b[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.local\b', 'IgnoreCase') | ForEach-Object Value
        ) | Sort-Object -Unique
        $ids.Count | Should -BeGreaterThan 10

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $leaks = @()
        foreach ($file in Get-ChildItem -Path $result.PackageRoot -Recurse -File) {
            $text = if ($file.Extension -in '.docx', '.xlsx', '.pptx') {
                $zip = [System.IO.Compression.ZipFile]::OpenRead($file.FullName)
                try { ($zip.Entries | ForEach-Object { $r = [System.IO.StreamReader]::new($_.Open()); try { $r.ReadToEnd() } finally { $r.Dispose() } }) -join ' ' } finally { $zip.Dispose() }
            }
            elseif ($file.Extension -eq '.pdf') { [System.Text.Encoding]::Latin1.GetString([System.IO.File]::ReadAllBytes($file.FullName)) }
            else { [System.IO.File]::ReadAllText($file.FullName) }
            foreach ($id in $ids) {
                if ([regex]::IsMatch($text, '(?<![A-Za-z0-9])' + [regex]::Escape($id) + '(?![A-Za-z0-9])', 'IgnoreCase')) { $leaks += "$($file.Name): $id" }
            }
        }
        $leaks | Should -BeNullOrEmpty
        $result.Manifest.run.redaction.enabled | Should -BeTrue
        Test-Path $mapPath | Should -BeTrue
        $result.PackageRoot | Should -Match 'ranger-redacted'
    }
}