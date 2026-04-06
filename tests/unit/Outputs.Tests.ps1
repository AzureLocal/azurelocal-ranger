BeforeAll {
    $script:repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $script:fixtureRoot = Join-Path $script:repoRoot 'tests\Fixtures'
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
}

Describe 'Azure Local Ranger cached outputs' {
    It 'renders reports and diagrams from a saved manifest' {
        $outputRoot = Join-Path $TestDrive 'rendered-package'
        $manifestPath = Join-Path $fixtureRoot 'manifest-sample.json'

        $null = Export-AzureLocalRangerReport -ManifestPath $manifestPath -OutputPath $outputRoot -Formats @('html', 'markdown', 'svg')

        (Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*.html').Count | Should -Be 3
        (Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*.md').Count | Should -Be 3
        (Get-ChildItem -Path (Join-Path $outputRoot 'diagrams') -Filter '*.drawio').Count | Should -BeGreaterThan 0
        (Get-ChildItem -Path (Join-Path $outputRoot 'diagrams') -Filter '*.svg').Count | Should -BeGreaterThan 0
        Test-Path -Path (Join-Path $outputRoot 'README.md') | Should -BeTrue
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