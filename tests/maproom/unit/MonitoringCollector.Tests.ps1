BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
}

Describe 'Azure Local Ranger monitoring collector' {
    It 'returns success when monitoring findings are advisory and collection completed' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $config.targets.azure.subscriptionId = '11111111-1111-1111-1111-111111111111'
        $config.targets.azure.resourceGroup = 'rg-tplabs'
        $definition = [pscustomobject]@{ Id = 'monitoring-observability' }
        $credentialMap = [ordered]@{
            cluster = $null
            azure   = [ordered]@{ method = 'existing-context'; subscriptionId = $config.targets.azure.subscriptionId }
        }

        InModuleScope AzureLocalRanger {
            param($TestConfig, $TestDefinition, $TestCredentialMap, $TestPackageRoot)

            Mock Get-RangerCollectorFixtureData { $null }
            Mock Get-RangerAzureResources {
                @([ordered]@{ ResourceType = 'Microsoft.AzureStackHCI/clusters'; Name = 'tplabs-clus01'; ResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-tplabs/providers/Microsoft.AzureStackHCI/clusters/tplabs-clus01' })
            }
            Mock Invoke-RangerSafeAction {
                param($Label, $DefaultValue, $ScriptBlock)
                $DefaultValue
            }

            $result = Invoke-RangerMonitoringCollector -Config $TestConfig -CredentialMap $TestCredentialMap -Definition $TestDefinition -PackageRoot $TestPackageRoot

            $result.Status | Should -Be 'success'
            (@($result.Findings | Where-Object { $_.title -eq 'Minimal Azure monitoring evidence detected' })).Count | Should -Be 1
            (@($result.Findings | Where-Object { $_.title -eq 'No alerting artifacts were discovered in the scoped Azure resources' })).Count | Should -Be 1
        } -Parameters @{ TestConfig = $config; TestDefinition = $definition; TestCredentialMap = $credentialMap; TestPackageRoot = $TestDrive }
    }
}
