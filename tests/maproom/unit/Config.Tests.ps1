BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
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

        It 'normalizes inline empty YAML lists into empty collections' {
                $path = Join-Path $TestDrive 'inline-empty-config.yml'
                @'
environment:
    name: tplabs-lab
targets:
    cluster:
        fqdn: tplabs-clus01.contoso.com
        nodes:
            - tplabs-01-n01.contoso.com
    azure:
        subscriptionId: 22222222-2222-2222-2222-222222222222
        resourceGroup: rg-tplabs
        tenantId: 33333333-3333-3333-3333-333333333333
    bmc:
        endpoints: []
    switches: []
    firewalls: []
credentials:
    azure:
        method: existing-context
        useAzureCliFallback: true
domains:
    include: []
    exclude: []
    hints:
        fixtures: {}
        networkDeviceConfigs: []
output:
    mode: current-state
    formats:
        - html
    rootPath: C:\AzureLocalRanger
    diagramFormat: svg
    keepRawEvidence: true
behavior:
    promptForMissingCredentials: false
    promptForMissingRequired: false
    skipUnavailableOptionalDomains: true
    failOnSchemaViolation: true
    logLevel: info
    retryCount: 1
    timeoutSeconds: 30
    continueToRendering: true
'@ | Set-Content -Path $path -Encoding UTF8

                InModuleScope AzureLocalRanger {
                        param($ConfigPath)

                        $config = Import-RangerConfiguration -ConfigPath $ConfigPath
                        @($config.targets.bmc.endpoints).Count | Should -Be 0
                        @($config.domains.hints.networkDeviceConfigs).Count | Should -Be 0
                        Test-RangerTargetConfigured -Config $config -TargetName 'bmc' | Should -BeFalse
                } -Parameters @{ ConfigPath = $path }
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

    It 'resolves domain context through remoting when a cluster credential is supplied' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $config.targets.cluster.fqdn = 'tplabs-clus01.contoso.com'
        $config.targets.cluster.nodes = @('tplabs-01-n01.contoso.com', 'tplabs-01-n02.contoso.com')
        $credential = [pscredential]::new('CONTOSO\ranger-read', (ConvertTo-SecureString 'placeholder-password' -AsPlainText -Force))

        InModuleScope AzureLocalRanger {
            param($TestConfig, $TestCredential)

            Mock Invoke-RangerRemoteCommand {
                [ordered]@{
                    Domain       = 'corp.contoso.com'
                    PartOfDomain = $true
                    Workgroup    = $null
                }
            }

            $result = Resolve-RangerDomainContext -Config $TestConfig -ArcResource $null -ClusterCredential $TestCredential
            $result.FQDN | Should -Be 'corp.contoso.com'
            $result.NetBIOS | Should -Be 'CORP'
            $result.ResolvedBy | Should -Be 'node-cim'
            Assert-MockCalled Invoke-RangerRemoteCommand -Times 1 -Exactly
        } -Parameters @{ TestConfig = $config; TestCredential = $credential }
    }
}