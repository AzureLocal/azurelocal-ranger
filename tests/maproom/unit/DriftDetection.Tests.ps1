BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
}

Describe 'Azure Local Ranger drift detection' {
    It 'detects added, removed, and changed items across multiple domains' {
        InModuleScope AzureLocalRanger {
            $baseline = [ordered]@{
                run = [ordered]@{ schemaVersion = '1.1.0-draft' }
                domains = [ordered]@{
                    clusterNode = [ordered]@{ nodes = @([ordered]@{ name = 'node01'; state = 'Up' }) }
                    hardware = [ordered]@{}
                    storage = [ordered]@{ pools = @([ordered]@{ friendlyName = 'Pool01'; healthStatus = 'Healthy'; sizeGiB = 240 }) }
                    networking = [ordered]@{}
                    virtualMachines = [ordered]@{}
                    azureIntegration = [ordered]@{ resources = @([ordered]@{ resourceId = '/subscriptions/1/resourceGroups/rg/providers/Microsoft.HybridCompute/machines/vm01'; status = 'Connected' }) }
                    identitySecurity = [ordered]@{}
                }
            }

            $current = [ordered]@{
                run = [ordered]@{ schemaVersion = '1.1.0-draft' }
                domains = [ordered]@{
                    clusterNode = [ordered]@{ nodes = @([ordered]@{ name = 'node01'; state = 'Paused' }, [ordered]@{ name = 'node02'; state = 'Up' }) }
                    hardware = [ordered]@{}
                    storage = [ordered]@{ pools = @([ordered]@{ friendlyName = 'Pool01'; healthStatus = 'Warning'; sizeGiB = 240 }) }
                    networking = [ordered]@{}
                    virtualMachines = [ordered]@{}
                    azureIntegration = [ordered]@{ resources = @() }
                    identitySecurity = [ordered]@{}
                }
            }

            $report = New-RangerDriftReport -CurrentManifest (ConvertTo-RangerHashtable -InputObject $current) -BaselineManifest (ConvertTo-RangerHashtable -InputObject $baseline) -BaselineManifestPath 'C:\baseline\audit-manifest.json'

            $report.status | Should -Be 'generated'
            $report.summary.totalChanges | Should -Be 4
            (@($report.changes | Where-Object { $_.path -eq 'clusterNode.nodes[node02]' -and $_.changeType -eq 'added' })).Count | Should -Be 1
            (@($report.changes | Where-Object { $_.path -eq 'clusterNode.nodes[node01].state' -and $_.changeType -eq 'changed' })).Count | Should -Be 1
            (@($report.changes | Where-Object { $_.path -eq 'storage.pools.healthStatus' -and $_.changeType -eq 'changed' })).Count | Should -Be 1
            (@($report.changes | Where-Object { $_.path -eq 'azureIntegration.resources' -and $_.changeType -eq 'removed' })).Count | Should -Be 1
        }
    }

    It 'gracefully skips drift generation when baseline schema versions differ' {
        InModuleScope AzureLocalRanger {
            $baseline = [ordered]@{
                run = [ordered]@{ schemaVersion = '1.0.0-draft' }
                domains = [ordered]@{ clusterNode = [ordered]@{}; hardware = [ordered]@{}; storage = [ordered]@{}; networking = [ordered]@{}; virtualMachines = [ordered]@{}; azureIntegration = [ordered]@{}; identitySecurity = [ordered]@{} }
            }
            $current = [ordered]@{
                run = [ordered]@{ schemaVersion = '1.1.0-draft' }
                domains = [ordered]@{ clusterNode = [ordered]@{}; hardware = [ordered]@{}; storage = [ordered]@{}; networking = [ordered]@{}; virtualMachines = [ordered]@{}; azureIntegration = [ordered]@{}; identitySecurity = [ordered]@{} }
            }

            $report = New-RangerDriftReport -CurrentManifest (ConvertTo-RangerHashtable -InputObject $current) -BaselineManifest (ConvertTo-RangerHashtable -InputObject $baseline) -BaselineManifestPath 'C:\baseline\audit-manifest.json'

            $report.status | Should -Be 'skipped'
            $report.summary.totalChanges | Should -Be 0
            $report.skippedReason | Should -Match 'schema version'
        }
    }
}