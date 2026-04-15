BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
}

Describe 'Azure Local Ranger storage analysis' {
    It 'keeps fixture-backed storage findings as success when collection data is complete' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $definition = [pscustomobject]@{ Id = 'storage-networking' }
        $credentialMap = [ordered]@{ cluster = $null; azure = $null }

        InModuleScope AzureLocalRanger {
            param($TestConfig, $TestDefinition, $TestCredentialMap, $TestPackageRoot)

            Mock Get-RangerCollectorFixtureData {
                [ordered]@{
                    Status   = 'success'
                    Domains  = [ordered]@{
                        storage = [ordered]@{
                            pools = @([ordered]@{ friendlyName = 'Pool02'; healthStatus = 'Warning'; operationalStatus = 'Degraded'; sizeGiB = 300; allocatedSizeGiB = 200; provisionedCapacityGiB = 210; resiliencySettingName = 'Parity'; numberOfDataCopies = 1 })
                            physicalDisks = @(
                                1..6 | ForEach-Object { [ordered]@{ friendlyName = "Disk$_"; storagePoolFriendlyName = 'Pool02'; mediaType = 'HDD'; sizeGiB = 50; usage = 'Capacity'; healthStatus = 'Healthy'; operationalStatus = 'OK' } }
                            )
                            virtualDisks = @([ordered]@{ friendlyName = 'VD02'; storagePoolFriendlyName = 'Pool02'; resiliencySettingName = 'Parity'; numberOfDataCopies = 1; sizeGiB = 180; provisioningType = 'Thin' })
                            volumes = @([ordered]@{ sizeGiB = 180; sizeRemainingGiB = 10 })
                            csvs = @()
                            dedupStatus = @()
                            cacheConfig = [ordered]@{ CacheState = 'Enabled' }
                            scrubSchedule = @()
                            tiers = @()
                            subsystems = @()
                            resiliency = @()
                            jobs = @()
                            qos = @()
                            qosFlows = @()
                            healthFaults = @()
                            replica = @()
                            replicaDepth = @()
                            summary = [ordered]@{}
                        }
                    }
                    Findings = @()
                }
            }

            $result = Invoke-RangerStorageNetworkingCollector -Config $TestConfig -CredentialMap $TestCredentialMap -Definition $TestDefinition -PackageRoot $TestPackageRoot

            $result.Status | Should -Be 'success'
            (@($result.Findings | Where-Object { $_.title -like 'Storage reserve is below*' })).Count | Should -Be 1
            (@($result.Findings | Where-Object { $_.title -like 'Thin provisioning exceeds*' })).Count | Should -Be 1
        } -Parameters @{ TestConfig = $config; TestDefinition = $definition; TestCredentialMap = $credentialMap; TestPackageRoot = $TestDrive }
    }

    It 'models a healthy mirror pool reserve posture' {
        InModuleScope AzureLocalRanger {
            $storageDomain = [ordered]@{
                pools = @([ordered]@{ friendlyName = 'Pool01'; healthStatus = 'Healthy'; operationalStatus = 'OK'; sizeGiB = 240; allocatedSizeGiB = 120; provisionedCapacityGiB = 120; resiliencySettingName = 'Mirror'; numberOfDataCopies = 2 })
                physicalDisks = @(
                    1..8 | ForEach-Object { [ordered]@{ friendlyName = "Disk$_"; storagePoolFriendlyName = 'Pool01'; mediaType = 'SSD'; sizeGiB = 30; usage = 'Capacity'; healthStatus = 'Healthy'; operationalStatus = 'OK' } }
                )
                virtualDisks = @([ordered]@{ friendlyName = 'VD01'; storagePoolFriendlyName = 'Pool01'; resiliencySettingName = 'Mirror'; numberOfDataCopies = 2; sizeGiB = 120; provisioningType = 'Fixed' })
                volumes = @([ordered]@{ sizeGiB = 120; sizeRemainingGiB = 60 })
                csvs = @()
                dedupStatus = @()
                cacheConfig = [ordered]@{ CacheState = 'Enabled' }
                scrubSchedule = @()
                tiers = @()
                subsystems = @()
                resiliency = @()
                jobs = @()
                qos = @()
                qosFlows = @()
                healthFaults = @()
                replica = @()
                replicaDepth = @()
                summary = [ordered]@{}
            }

            $result = Update-RangerStorageDomainAnalysis -StorageDomain $storageDomain
            $analysis = @($result.poolAnalysis)[0]

            $analysis.usableCapacityGiB | Should -Be 120
            $analysis.recommendedReserveGiB | Should -Be 30
            $analysis.freeUsableCapacityGiB | Should -Be 60
            $analysis.projectedSafeAllocatableCapacityGiB | Should -Be 30
            $analysis.posture | Should -Be 'within safe range'
        }
    }

    It 'flags risky parity-style thin provisioning when reserve falls below threshold' {
        InModuleScope AzureLocalRanger {
            $storageDomain = [ordered]@{
                pools = @([ordered]@{ friendlyName = 'Pool02'; healthStatus = 'Warning'; operationalStatus = 'Degraded'; sizeGiB = 300; allocatedSizeGiB = 200; provisionedCapacityGiB = 210; resiliencySettingName = 'Parity'; numberOfDataCopies = 1 })
                physicalDisks = @(
                    1..6 | ForEach-Object { [ordered]@{ friendlyName = "Disk$_"; storagePoolFriendlyName = 'Pool02'; mediaType = 'HDD'; sizeGiB = 50; usage = 'Capacity'; healthStatus = 'Healthy'; operationalStatus = 'OK' } }
                )
                virtualDisks = @([ordered]@{ friendlyName = 'VD02'; storagePoolFriendlyName = 'Pool02'; resiliencySettingName = 'Parity'; numberOfDataCopies = 1; sizeGiB = 180; provisioningType = 'Thin' })
                volumes = @([ordered]@{ sizeGiB = 180; sizeRemainingGiB = 10 })
                csvs = @()
                dedupStatus = @()
                cacheConfig = [ordered]@{ CacheState = 'Enabled' }
                scrubSchedule = @()
                tiers = @()
                subsystems = @()
                resiliency = @()
                jobs = @()
                qos = @()
                qosFlows = @()
                healthFaults = @()
                replica = @()
                replicaDepth = @()
                summary = [ordered]@{}
            }

            $result = Update-RangerStorageDomainAnalysis -StorageDomain $storageDomain
            $analysis = @($result.poolAnalysis)[0]
            $findings = @(New-RangerStorageAnalysisFindings -StorageDomain $result)

            $analysis.reserveStatus | Should -Be 'below-threshold'
            $analysis.posture | Should -Be 'over-provisioned'
            $analysis.thinProvisioningRatio | Should -BeGreaterThan 1
            (@($findings | Where-Object { $_.title -like 'Storage reserve is below*' })).Count | Should -Be 1
            (@($findings | Where-Object { $_.title -like 'Thin provisioning exceeds*' })).Count | Should -Be 1
        }
    }
}
