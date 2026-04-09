BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
    $script:fixtureRoot = Join-Path $script:repoRoot 'tests\maproom\Fixtures'
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

    It 'validates manifests against the standalone schema contract' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $config.output.rootPath = Join-Path $TestDrive 'schema-artifacts'
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

        $result = Invoke-AzureLocalRanger -ConfigObject $config -OutputPath (Join-Path $TestDrive 'schema-output') -NoRender
        $result.ManifestSchema.IsValid | Should -BeTrue

        InModuleScope AzureLocalRanger {
            $contract = Get-RangerManifestSchemaContract
            $contract.schemaVersion | Should -Be '1.1.0-draft'
            @($contract.requiredTopLevelKeys).Count | Should -BeGreaterThan 5
        }
    }

    It 'continues packaging when collectors return degraded fixture results' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $config.output.rootPath = Join-Path $TestDrive 'degraded-artifacts'
        $config.behavior.promptForMissingCredentials = $false
        $config.behavior.continueToRendering = $false
        $config.credentials.cluster = $null
        $config.credentials.domain = $null
        $config.credentials.bmc = $null
        $config.domains.hints.fixtures = [ordered]@{
            'topology-cluster' = (Join-Path $fixtureRoot 'topology-cluster.json')
            'hardware' = (Join-Path $fixtureRoot 'hardware.json')
            'storage-networking' = (Join-Path $fixtureRoot 'storage-networking-degraded.json')
            'workload-identity-azure' = (Join-Path $fixtureRoot 'workload-identity-azure.json')
            'monitoring-observability' = (Join-Path $fixtureRoot 'monitoring-observability.json')
            'management-performance' = (Join-Path $fixtureRoot 'management-performance-degraded.json')
        }

        $result = Invoke-AzureLocalRanger -ConfigObject $config -OutputPath (Join-Path $TestDrive 'degraded-output') -NoRender
        $result.Manifest.collectors['storage-networking'].status | Should -Be 'partial'
        $result.Manifest.collectors['management-performance'].status | Should -Be 'partial'
        @($result.Manifest.findings).Count | Should -BeGreaterThan 1
        $result.ManifestSchema.IsValid | Should -BeTrue
    }
}