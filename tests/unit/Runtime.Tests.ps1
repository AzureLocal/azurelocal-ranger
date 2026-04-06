BeforeAll {
    $script:repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $script:fixtureRoot = Join-Path $script:repoRoot 'tests\Fixtures'
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
}

Describe 'Azure Local Ranger runtime' {
    It 'builds a manifest package from fixture-backed collectors' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $config.output.rootPath = Join-Path $TestDrive 'artifacts'
        $config.behavior.promptForMissingCredentials = $false
        $config.behavior.continueToRendering = $false
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

        $result = Invoke-AzureLocalRanger -ConfigObject $config -OutputPath (Join-Path $TestDrive 'output') -NoRender
        Test-Path -Path $result.ManifestPath | Should -BeTrue
        Test-Path -Path (Join-Path $result.PackageRoot 'package-index.json') | Should -BeTrue

        $manifest = Get-Content -Path $result.ManifestPath -Raw | ConvertFrom-Json -Depth 100
        @($manifest.collectors.PSObject.Properties).Count | Should -Be 6
        $manifest.domains.clusterNode.nodes.Count | Should -Be 2
        $manifest.domains.virtualMachines.inventory.Count | Should -Be 1
        $manifest.domains.monitoring.ama.Count | Should -Be 1
    }

    It 'reports selected collectors during prerequisite checks' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $config.behavior.promptForMissingCredentials = $false
        $config.credentials.cluster = $null
        $config.credentials.domain = $null
        $config.credentials.bmc = $null
        $config.domains.include = @('hardware', 'monitoring', 'performance')

        $result = Test-AzureLocalRangerPrerequisites -ConfigObject $config
        $result.SelectedCollectors | Should -Contain 'hardware'
        $result.SelectedCollectors | Should -Contain 'monitoring-observability'
        $result.SelectedCollectors | Should -Contain 'management-performance'
    }
}