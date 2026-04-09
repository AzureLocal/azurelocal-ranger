BeforeAll {
    $script:repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $script:fixtureRoot = Join-Path $script:repoRoot 'tests\Fixtures'
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
}