BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
}

Describe 'Azure Local Ranger workload collector' {
    It 'uses Arc network profile IPs when Hyper-V data exchange did not return guest addresses' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $config.targets.azure.subscriptionId = '11111111-1111-1111-1111-111111111111'
        $config.targets.azure.resourceGroup = 'rg-tplabs'
        $config.targets.azure.tenantId = '22222222-2222-2222-2222-222222222222'
        $definition = [pscustomobject]@{ Id = 'workload-identity-azure' }
        $credentialMap = [ordered]@{
            cluster = $null
            azure   = [ordered]@{ method = 'existing-context'; tenantId = $config.targets.azure.tenantId; subscriptionId = $config.targets.azure.subscriptionId; useAzureCliFallback = $true }
        }

        InModuleScope AzureLocalRanger {
            param($TestConfig, $TestDefinition, $TestCredentialMap, $TestPackageRoot)

            Mock Get-RangerCollectorFixtureData { $null }
            Mock Resolve-RangerClusterArcResource { $null }
            Mock Resolve-RangerDomainContext {
                [ordered]@{ FQDN = 'corp.contoso.com'; NetBIOS = 'CORP'; ResolvedBy = 'test'; IsWorkgroup = $false; Confidence = 'high' }
            }
            Mock Get-RangerAzureResources { @() }
            Mock Invoke-RangerSafeAction {
                param($Label, $DefaultValue, $ScriptBlock)

                switch ($Label) {
                    'VM inventory snapshot' {
                        return @([ordered]@{
                            name               = 'vm-arc-ip'
                            hostNode           = 'node01'
                            state              = 'Running'
                            isClustered        = $true
                            generation         = 2
                            processorCount     = 4
                            memoryAssignedMb   = 4096
                            checkpointCount    = 0
                            checkpoints        = @()
                            nicsAdvanced       = @()
                            guestClusterCandidate = $false
                            switchNames        = @('vSwitch-01')
                            nicDetail          = @([ordered]@{ name = 'Network Adapter'; ipAddresses = @() })
                        })
                    }
                    'Identity and security snapshot' {
                        return @([ordered]@{
                            node                    = 'node01'
                            partOfDomain            = $true
                            domain                  = 'corp.contoso.com'
                            localAdmins             = @()
                            localAdminDetail        = [ordered]@{}
                            certificates            = @()
                            bitlocker               = @()
                            bitlockerProtectors     = @()
                            defender                = [ordered]@{}
                            defenderExclusions      = $null
                            deviceGuard             = $null
                            wdacInfo                = [ordered]@{ enforcementMode = 'None' }
                            adDomain                = $null
                            adForest                = $null
                            appLocker               = @()
                            secureBoot              = $true
                            credSsp                 = $false
                            auditPolicy             = @()
                            entraJoinStatus         = [ordered]@{}
                            aadkerbConfigured       = $false
                            adObjects               = $null
                            adSite                  = $null
                            securedCoreDetail       = [ordered]@{ systemGuardEnabled = $false }
                            syslogDetail            = [ordered]@{ wefSubscriptions = @(); syslogAgents = @() }
                            driftControl            = [ordered]@{}
                            clusterServiceAccountModel = 'LocalSystem'
                            physicalCoreCount       = 16
                            secretRotationState     = [ordered]@{ autoRotationEnabled = $false }
                        })
                    }
                    'Arc Connected Machine detail' {
                        return @([ordered]@{
                            Name               = 'vm-arc-ip'
                            Status             = 'Connected'
                            AgentVersion       = '1.0.0'
                            OsName             = 'Windows Server 2019 Datacenter'
                            OsVersion          = '10.0.17763'
                            ProvisioningState  = 'Succeeded'
                            LastStatusChange   = (Get-Date)
                            ResourceId         = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-tplabs/providers/Microsoft.HybridCompute/machines/vm-arc-ip'
                            NetworkIpAddresses = @('10.25.30.40')
                            NetworkProfile     = [ordered]@{ ipAddresses = @('10.25.30.40') }
                        })
                    }
                    'Arc ESU license profile' {
                        return @([ordered]@{ name = 'vm-arc-ip'; queryStatus = 'success'; assignedLicense = $null; esuEligibility = 'Eligible' })
                    }
                    default {
                        return $DefaultValue
                    }
                }
            }

            $result = Invoke-RangerWorkloadIdentityAzureCollector -Config $TestConfig -CredentialMap $TestCredentialMap -Definition $TestDefinition -PackageRoot $TestPackageRoot
            $vm = @($result.Domains.virtualMachines.inventory)[0]

            $vm.primaryIpAddress | Should -Be '10.25.30.40'
            $vm.ipAddressSource | Should -Be 'arc-network-profile'
            $vm.arcIpFallbackUsed | Should -BeTrue
            $result.Domains.virtualMachines.summary.vmsUsingArcIpFallback | Should -Be 1
        } -Parameters @{ TestConfig = $config; TestDefinition = $definition; TestCredentialMap = $credentialMap; TestPackageRoot = $TestDrive }
    }

    It 'classifies ESU enrollment as enrolled, not-enrolled, and ineligible for Arc-connected VMs' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $config.targets.azure.subscriptionId = '11111111-1111-1111-1111-111111111111'
        $config.targets.azure.resourceGroup = 'rg-tplabs'
        $config.targets.azure.tenantId = '22222222-2222-2222-2222-222222222222'
        $definition = [pscustomobject]@{ Id = 'workload-identity-azure' }
        $credentialMap = [ordered]@{
            cluster = $null
            azure   = [ordered]@{ method = 'existing-context'; tenantId = $config.targets.azure.tenantId; subscriptionId = $config.targets.azure.subscriptionId; useAzureCliFallback = $true }
        }

        InModuleScope AzureLocalRanger {
            param($TestConfig, $TestDefinition, $TestCredentialMap, $TestPackageRoot)

            Mock Get-RangerCollectorFixtureData { $null }
            Mock Resolve-RangerClusterArcResource { $null }
            Mock Resolve-RangerDomainContext {
                [ordered]@{ FQDN = 'corp.contoso.com'; NetBIOS = 'CORP'; ResolvedBy = 'test'; IsWorkgroup = $false; Confidence = 'high' }
            }
            Mock Get-RangerAzureResources { @() }
            Mock Invoke-RangerSafeAction {
                param($Label, $DefaultValue, $ScriptBlock)

                switch ($Label) {
                    'VM inventory snapshot' {
                        return @(
                            [ordered]@{ name = 'vm-2016'; hostNode = 'node01'; state = 'Running'; isClustered = $true; generation = 2; processorCount = 2; memoryAssignedMb = 2048; checkpointCount = 0; checkpoints = @(); nicsAdvanced = @(); guestClusterCandidate = $false; switchNames = @(); nicDetail = @([ordered]@{ ipAddresses = @('10.0.0.10') }) },
                            [ordered]@{ name = 'vm-2019'; hostNode = 'node01'; state = 'Running'; isClustered = $true; generation = 2; processorCount = 2; memoryAssignedMb = 2048; checkpointCount = 0; checkpoints = @(); nicsAdvanced = @(); guestClusterCandidate = $false; switchNames = @(); nicDetail = @([ordered]@{ ipAddresses = @('10.0.0.11') }) },
                            [ordered]@{ name = 'vm-2022'; hostNode = 'node02'; state = 'Running'; isClustered = $true; generation = 2; processorCount = 2; memoryAssignedMb = 2048; checkpointCount = 0; checkpoints = @(); nicsAdvanced = @(); guestClusterCandidate = $false; switchNames = @(); nicDetail = @([ordered]@{ ipAddresses = @('10.0.0.12') }) }
                        )
                    }
                    'Identity and security snapshot' {
                        return @([ordered]@{
                            node                    = 'node01'
                            partOfDomain            = $true
                            domain                  = 'corp.contoso.com'
                            localAdmins             = @()
                            localAdminDetail        = [ordered]@{}
                            certificates            = @()
                            bitlocker               = @()
                            bitlockerProtectors     = @()
                            defender                = [ordered]@{}
                            defenderExclusions      = $null
                            deviceGuard             = $null
                            wdacInfo                = [ordered]@{ enforcementMode = 'None' }
                            adDomain                = $null
                            adForest                = $null
                            appLocker               = @()
                            secureBoot              = $true
                            credSsp                 = $false
                            auditPolicy             = @()
                            entraJoinStatus         = [ordered]@{}
                            aadkerbConfigured       = $false
                            adObjects               = $null
                            adSite                  = $null
                            securedCoreDetail       = [ordered]@{ systemGuardEnabled = $false }
                            syslogDetail            = [ordered]@{ wefSubscriptions = @(); syslogAgents = @() }
                            driftControl            = [ordered]@{}
                            clusterServiceAccountModel = 'LocalSystem'
                            physicalCoreCount       = 16
                            secretRotationState     = [ordered]@{ autoRotationEnabled = $false }
                        })
                    }
                    'Arc Connected Machine detail' {
                        return @(
                            [ordered]@{ Name = 'vm-2016'; Status = 'Connected'; AgentVersion = '1.0.0'; OsName = 'Windows Server 2016 Datacenter'; OsVersion = '10.0.14393'; ProvisioningState = 'Succeeded'; LastStatusChange = (Get-Date); ResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-tplabs/providers/Microsoft.HybridCompute/machines/vm-2016'; NetworkIpAddresses = @('10.0.0.10') },
                            [ordered]@{ Name = 'vm-2019'; Status = 'Connected'; AgentVersion = '1.0.0'; OsName = 'Windows Server 2019 Datacenter'; OsVersion = '10.0.17763'; ProvisioningState = 'Succeeded'; LastStatusChange = (Get-Date); ResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-tplabs/providers/Microsoft.HybridCompute/machines/vm-2019'; NetworkIpAddresses = @('10.0.0.11') },
                            [ordered]@{ Name = 'vm-2022'; Status = 'Connected'; AgentVersion = '1.0.0'; OsName = 'Windows Server 2022 Datacenter'; OsVersion = '10.0.20348'; ProvisioningState = 'Succeeded'; LastStatusChange = (Get-Date); ResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-tplabs/providers/Microsoft.HybridCompute/machines/vm-2022'; NetworkIpAddresses = @('10.0.0.12') }
                        )
                    }
                    'Arc ESU license profile' {
                        return @(
                            [ordered]@{ name = 'vm-2016'; queryStatus = 'success'; assignedLicense = $null; esuEligibility = 'Eligible' },
                            [ordered]@{ name = 'vm-2019'; queryStatus = 'success'; assignedLicense = '/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.HybridCompute/licenses/esu-01'; esuEligibility = 'Eligible' },
                            [ordered]@{ name = 'vm-2022'; queryStatus = 'success'; assignedLicense = $null; esuEligibility = 'Ineligible' }
                        )
                    }
                    default {
                        return $DefaultValue
                    }
                }
            }

            $result = Invoke-RangerWorkloadIdentityAzureCollector -Config $TestConfig -CredentialMap $TestCredentialMap -Definition $TestDefinition -PackageRoot $TestPackageRoot
            $esuInventory = @($result.Domains.azureIntegration.costAnalysis.esuInventory)

            (@($esuInventory | Where-Object { $_.name -eq 'vm-2016' }).Count) | Should -Be 1
            (@($esuInventory | Where-Object { $_.name -eq 'vm-2019' }).Count) | Should -Be 1
            (@($esuInventory | Where-Object { $_.name -eq 'vm-2022' }).Count) | Should -Be 1

            (@($esuInventory | Where-Object { $_.name -eq 'vm-2016' })[0]).esuProfileStatus | Should -Be 'not-enrolled'
            (@($esuInventory | Where-Object { $_.name -eq 'vm-2019' })[0]).esuProfileStatus | Should -Be 'enrolled'
            (@($esuInventory | Where-Object { $_.name -eq 'vm-2022' })[0]).esuProfileStatus | Should -Be 'ineligible'

            $result.Domains.azureIntegration.costAnalysis.summary.eligibleVmCount | Should -Be 2
            $result.Domains.azureIntegration.costAnalysis.summary.enrolledVmCount | Should -Be 1
            $result.Domains.azureIntegration.costAnalysis.summary.notEnrolledVmCount | Should -Be 1
            $result.Domains.azureIntegration.costAnalysis.summary.ineligibleVmCount | Should -Be 1

            (@($result.Findings | Where-Object { $_.title -like 'Eligible VM is not enrolled in Arc ESU*' })).Count | Should -Be 1
            (@($result.Findings | Where-Object { $_.title -like 'Eligible VM is enrolled in Arc ESU*' })).Count | Should -Be 1
        } -Parameters @{ TestConfig = $config; TestDefinition = $definition; TestCredentialMap = $credentialMap; TestPackageRoot = $TestDrive }
    }
}