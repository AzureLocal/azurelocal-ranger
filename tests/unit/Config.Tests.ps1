BeforeAll {
    $script:repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
}

Describe 'Azure Local Ranger configuration helpers' {
    It 'parses Key Vault URIs into vault, secret, and version parts' {
        InModuleScope AzureLocalRanger {
            $parsed = ConvertFrom-RangerKeyVaultUri -Uri 'keyvault://kv-ranger/cluster-read/version-01'
            $parsed.VaultName | Should -Be 'kv-ranger'
            $parsed.SecretName | Should -Be 'cluster-read'
            $parsed.Version | Should -Be 'version-01'
        }
    }

    It 'resolves collectors from include and exclude domain filters' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $config.domains.include = @('hardware', 'monitoring')
        $config.domains.exclude = @('observability')

        InModuleScope AzureLocalRanger {
            param($TestConfig)

            $selected = Resolve-RangerSelectedCollectors -Config $TestConfig
            @($selected).Count | Should -Be 1
            $selected[0].Id | Should -Be 'hardware'
        } -Parameters @{ TestConfig = $config }
    }

    It 'creates a starter configuration file' {
        $path = Join-Path $TestDrive 'starter-config.json'
        $created = New-AzureLocalRangerConfig -Path $path -Format json -Force
        $created.FullName | Should -Be $path
        Test-Path -Path $path | Should -BeTrue
    }

    It 'rejects incomplete Azure service principal configuration' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $config.credentials.azure.method = 'service-principal'
        $config.credentials.azure.clientId = '11111111-1111-1111-1111-111111111111'
        $config.targets.azure.tenantId = ''
        $config.credentials.azure.clientSecret = ''

        InModuleScope AzureLocalRanger {
            param($TestConfig)

            $result = Test-RangerConfiguration -Config $TestConfig -PassThru
            $result.IsValid | Should -BeFalse
            ($result.Errors -join ' ') | Should -Match 'service-principal authentication requires'
        } -Parameters @{ TestConfig = $config }
    }

    It 'resolves Azure credential settings from config defaults' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        InModuleScope AzureLocalRanger {
            param($TestConfig)

            $settings = Resolve-RangerAzureCredentialSettings -Config $TestConfig -SkipSecretResolution
            $settings.method | Should -Be 'existing-context'
            $settings.subscriptionId | Should -Be $TestConfig.targets.azure.subscriptionId
            $settings.useAzureCliFallback | Should -BeTrue
        } -Parameters @{ TestConfig = $config }
    }
}