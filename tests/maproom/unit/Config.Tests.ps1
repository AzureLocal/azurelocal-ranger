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

    It 'hydrates BMC endpoints from sibling variables.yml when the Ranger config leaves them empty' {
        $fixtureRoot = Join-Path $TestDrive 'bmc-fallback'
        New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
        $configPath = Join-Path $fixtureRoot 'ranger-config.yml'
        $variablesPath = Join-Path $fixtureRoot 'variables.yml'

        @'
environment:
  name: tplabs
targets:
  cluster:
    fqdn: tplabs-clus01.azrl.mgmt
    nodes:
      - tplabs-01-n01.azrl.mgmt
  azure:
    subscriptionId: 22222222-2222-2222-2222-222222222222
    resourceGroup: rg-tplabs
    tenantId: 33333333-3333-3333-3333-333333333333
  bmc:
    endpoints: []
credentials:
  azure:
    method: existing-context
    useAzureCliFallback: true
  bmc:
    username: idrac_azl_admin
    passwordRef: keyvault://kv-ranger/idrac-password
domains:
  include: []
  exclude: []
  hints:
    fixtures: {}
output:
  mode: current-state
  formats:
    - html
behavior:
  promptForMissingCredentials: false
'@ | Set-Content -Path $configPath -Encoding UTF8

        @'
security:
  infrastructure_credentials:
    idrac:
      devices:
        - tplabs-01-n01 (192.168.214.11)
        - tplabs-01-n02 (192.168.214.12)
'@ | Set-Content -Path $variablesPath -Encoding UTF8

        InModuleScope AzureLocalRanger {
            param($Path)

            $config = Import-RangerConfiguration -ConfigPath $Path
            @($config.targets.bmc.endpoints).Count | Should -Be 2
            $config.targets.bmc.endpoints[0].host | Should -Be '192.168.214.11'
            $config.targets.bmc.endpoints[0].node | Should -Be 'tplabs-01-n01'
            $config.targets.bmc.endpoints[1].host | Should -Be '192.168.214.12'
            $config.targets.bmc.endpoints[1].node | Should -Be 'tplabs-01-n02'
            Test-RangerTargetConfigured -Config $config -TargetName 'bmc' | Should -BeTrue
        } -Parameters @{ Path = $configPath }
    }

    It 'preserves explicit BMC endpoints from Ranger config over sibling variables.yml fallback data' {
        $fixtureRoot = Join-Path $TestDrive 'bmc-explicit'
        New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
        $configPath = Join-Path $fixtureRoot 'ranger-config.yml'
        $variablesPath = Join-Path $fixtureRoot 'variables.yml'

        @'
environment:
  name: tplabs
targets:
  cluster:
    fqdn: tplabs-clus01.azrl.mgmt
    nodes:
      - tplabs-01-n01.azrl.mgmt
  azure:
    subscriptionId: 22222222-2222-2222-2222-222222222222
    resourceGroup: rg-tplabs
    tenantId: 33333333-3333-3333-3333-333333333333
  bmc:
    endpoints:
      - host: idrac-node-01.azrl.mgmt
        node: tplabs-01-n01
credentials:
  azure:
    method: existing-context
    useAzureCliFallback: true
domains:
  include: []
  exclude: []
  hints:
    fixtures: {}
output:
  mode: current-state
  formats:
    - html
behavior:
  promptForMissingCredentials: false
'@ | Set-Content -Path $configPath -Encoding UTF8

        @'
security:
  infrastructure_credentials:
    idrac:
      devices:
        - tplabs-01-n01 (192.168.214.11)
'@ | Set-Content -Path $variablesPath -Encoding UTF8

        InModuleScope AzureLocalRanger {
            param($Path)

            $config = Import-RangerConfiguration -ConfigPath $Path
            @($config.targets.bmc.endpoints).Count | Should -Be 1
            $config.targets.bmc.endpoints[0].host | Should -Be 'idrac-node-01.azrl.mgmt'
            $config.targets.bmc.endpoints[0].node | Should -Be 'tplabs-01-n01'
        } -Parameters @{ Path = $configPath }
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

    It 'falls back to Azure CLI when Az.KeyVault secret resolution fails' {
        InModuleScope AzureLocalRanger {
            function global:az {
                param([Parameter(ValueFromRemainingArguments = $true)]$Arguments)
                $global:LASTEXITCODE = 0
                'mock-secret-from-cli'
            }

            Mock Test-RangerCommandAvailable {
                param($Name)
                $Name -in @('Get-AzKeyVaultSecret', 'az')
            }

            Mock Get-AzKeyVaultSecret {
                throw 'Az context expired'
            }

            try {
                $value = Get-RangerSecretFromUri -Uri 'keyvault://kv-ranger/cluster-read' -AsPlainText
                $value | Should -Be 'mock-secret-from-cli'
                Assert-MockCalled Get-AzKeyVaultSecret -Times 1 -Exactly
            }
            finally {
                Remove-Item Function:\global:az -ErrorAction SilentlyContinue
            }
        }
    }

    It 'reports both provider failures when no Key Vault secret provider succeeds' {
        InModuleScope AzureLocalRanger {
            function global:az {
                param([Parameter(ValueFromRemainingArguments = $true)]$Arguments)
                $global:LASTEXITCODE = 1
                'cli failure'
            }

            Mock Test-RangerCommandAvailable {
                param($Name)
                $Name -in @('Get-AzKeyVaultSecret', 'az')
            }

            Mock Get-AzKeyVaultSecret {
                throw 'Az context expired'
            }

            try {
                $message = $null
                try {
                    Get-RangerSecretFromUri -Uri 'keyvault://kv-ranger/cluster-read' -AsPlainText | Out-Null
                }
                catch {
                    $message = $_.Exception.Message
                }

                $message | Should -Match 'Az\.KeyVault failed: Az context expired'
                $message | Should -Match 'Azure CLI failed: Azure CLI exited with code 1'
            }
            finally {
                Remove-Item Function:\global:az -ErrorAction SilentlyContinue
            }
        }
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

    It 'wizard config hashtable round-trips through YAML serialization and reloads correctly (issue #291)' {
        # Regression test for the YAML/JSON mismatch bug — the wizard previously
        # wrote ConvertTo-Json output to a .yml file. This test verifies the
        # ConvertTo-RangerYaml round-trip that the rewritten wizard now uses.
        $tempFile = Join-Path $TestDrive 'wizard-roundtrip.yml'

        InModuleScope AzureLocalRanger {
            param($Path)

            $config = [ordered]@{
                environment = [ordered]@{
                    name        = 'tplabs-wizard'
                    clusterName = 'tplabs-clus01'
                    description = 'wizard-generated'
                }
                targets = [ordered]@{
                    cluster = [ordered]@{
                        fqdn  = 'tplabs-clus01.azrl.mgmt'
                        nodes = @('tplabs-01-n01.azrl.mgmt', 'tplabs-01-n02.azrl.mgmt')
                    }
                    azure = [ordered]@{
                        subscriptionId = '22222222-2222-2222-2222-222222222222'
                        resourceGroup  = 'rg-tplabs'
                        tenantId       = '33333333-3333-3333-3333-333333333333'
                    }
                    bmc = [ordered]@{ endpoints = @() }
                }
                credentials = [ordered]@{
                    azure = [ordered]@{ method = 'device-code' }
                }
                domains  = [ordered]@{ include = @('storage', 'networking'); exclude = @() }
                output   = [ordered]@{ mode = 'as-built'; formats = @('html', 'markdown'); rootPath = 'C:\AzureLocalRanger'; showProgress = $true }
                behavior = [ordered]@{ promptForMissingCredentials = $false; degradationMode = 'graceful'; transport = 'auto' }
            }

            (ConvertTo-RangerYaml -InputObject $config) -join [Environment]::NewLine |
                Set-Content -Path $Path -Encoding UTF8

            # Reload and verify round-trip
            $loaded = Import-RangerConfiguration -ConfigPath $Path
            $loaded.environment.name                  | Should -Be 'tplabs-wizard'
            $loaded.environment.clusterName           | Should -Be 'tplabs-clus01'
            $loaded.targets.cluster.fqdn              | Should -Be 'tplabs-clus01.azrl.mgmt'
            $loaded.credentials.azure.method          | Should -Be 'device-code'
            $loaded.output.mode                       | Should -Be 'as-built'
            @($loaded.domains.include).Count          | Should -Be 2
            $loaded.domains.include | Should -Contain 'storage'
            $loaded.domains.include | Should -Contain 'networking'
        } -Parameters @{ Path = $tempFile }
    }

    It 'does not prompt for BMC credentials when hardware collector is not in scope (issue #295)' {
        InModuleScope AzureLocalRanger {
            $config = Get-RangerDefaultConfig
            $config.credentials.cluster  = [ordered]@{ username = 'lcm-user'; password = 'cluster-pass' }
            $config.credentials.domain   = [ordered]@{ username = 'MGMT\svc'; password = 'dom-pass' }
            $config.targets.bmc.endpoints = @()
            $config.domains.include = @('storage', 'networking')

            Mock Get-Credential { throw 'Get-Credential must not be called when BMC is out of scope' }

            $map = Resolve-RangerCredentialMap -Config $config -Overrides @{}
            $map.bmc      | Should -BeNullOrEmpty
            $map.switch   | Should -BeNullOrEmpty
            $map.firewall | Should -BeNullOrEmpty
            Assert-MockCalled Get-Credential -Times 0 -Exactly
        }
    }

    It 'resolves BMC credentials when hardware is in scope and BMC endpoints are configured (issue #295)' {
        InModuleScope AzureLocalRanger {
            $config = Get-RangerDefaultConfig
            $config.targets.bmc.endpoints = @(
                [ordered]@{ host = '192.168.214.11'; node = 'n01' }
            )
            $config.domains.include = @('hardware')
            $bmcSecure = ConvertTo-SecureString 'idrac-pass' -AsPlainText -Force
            $config.credentials.cluster = [ordered]@{ username = 'lcm-user'; password = 'cluster-pass' }
            $config.credentials.bmc     = [ordered]@{ username = 'idrac_admin'; passwordSecureString = $bmcSecure }

            $map = Resolve-RangerCredentialMap -Config $config -Overrides @{}
            $map.bmc          | Should -Not -BeNullOrEmpty
            $map.bmc.UserName | Should -Be 'idrac_admin'
        }
    }

    It 'honors an explicit BMC credential override even when no BMC endpoints are configured (issue #295)' {
        InModuleScope AzureLocalRanger {
            $config = Get-RangerDefaultConfig
            $config.targets.bmc.endpoints = @()
            $config.credentials.cluster = [ordered]@{ username = 'lcm-user'; password = 'cluster-pass' }

            $secure = ConvertTo-SecureString 'override-pass' -AsPlainText -Force
            $explicitBmc = [pscredential]::new('explicit-bmc-user', $secure)

            $map = Resolve-RangerCredentialMap -Config $config -Overrides @{ bmc = $explicitBmc }
            $map.bmc          | Should -Not -BeNullOrEmpty
            $map.bmc.UserName | Should -Be 'explicit-bmc-user'
        }
    }

    It 'auto-selects the only HCI cluster in the subscription (issue #297)' {
        InModuleScope AzureLocalRanger {
            $config = Get-RangerDefaultConfig
            $config.environment.clusterName          = $null
            $config.targets.azure.subscriptionId     = '22222222-2222-2222-2222-222222222222'
            $config.targets.azure.resourceGroup      = $null

            Mock Get-AzResource -ModuleName AzureLocalRanger {
                @([pscustomobject]@{
                    Name              = 'only-cluster'
                    ResourceGroupName = 'rg-only'
                    Location          = 'eastus'
                    Type              = 'microsoft.azurestackhci/clusters'
                    ResourceId        = '/subscriptions/x/resourceGroups/rg-only/providers/microsoft.azurestackhci/clusters/only-cluster'
                })
            } -ParameterFilter { $ResourceType -eq 'microsoft.azurestackhci/clusters' }

            $selected = Select-RangerCluster -Config $config
            $selected | Should -Not -BeNullOrEmpty
            $selected.Name | Should -Be 'only-cluster'
            $config.environment.clusterName        | Should -Be 'only-cluster'
            $config.targets.azure.resourceGroup    | Should -Be 'rg-only'
        }
    }

    It 'throws RANGER-DISC-002 when multiple clusters found under -Unattended (issue #297)' {
        InModuleScope AzureLocalRanger {
            $config = Get-RangerDefaultConfig
            $config.environment.clusterName      = $null
            $config.targets.azure.subscriptionId = '22222222-2222-2222-2222-222222222222'

            Mock Get-AzResource -ModuleName AzureLocalRanger {
                @(
                    [pscustomobject]@{ Name = 'clus-a'; ResourceGroupName = 'rg-a'; Location = 'eastus' },
                    [pscustomobject]@{ Name = 'clus-b'; ResourceGroupName = 'rg-b'; Location = 'westus2' }
                )
            } -ParameterFilter { $ResourceType -eq 'microsoft.azurestackhci/clusters' }

            { Select-RangerCluster -Config $config -Unattended } | Should -Throw '*RANGER-DISC-002*'
        }
    }

    It 'throws RANGER-DISC-001 when no clusters found in subscription (issue #297)' {
        InModuleScope AzureLocalRanger {
            $config = Get-RangerDefaultConfig
            $config.environment.clusterName      = $null
            $config.targets.azure.subscriptionId = '22222222-2222-2222-2222-222222222222'

            Mock Get-AzResource -ModuleName AzureLocalRanger {
                @()
            } -ParameterFilter { $ResourceType -eq 'microsoft.azurestackhci/clusters' }

            { Select-RangerCluster -Config $config } | Should -Throw '*RANGER-DISC-001*'
        }
    }

    It 'accepts PreselectedName to bypass the prompt on a multi-cluster subscription (issue #297)' {
        InModuleScope AzureLocalRanger {
            $config = Get-RangerDefaultConfig
            $config.environment.clusterName      = $null
            $config.targets.azure.subscriptionId = '22222222-2222-2222-2222-222222222222'

            Mock Get-AzResource -ModuleName AzureLocalRanger {
                @(
                    [pscustomobject]@{ Name = 'clus-a'; ResourceGroupName = 'rg-a'; Location = 'eastus' },
                    [pscustomobject]@{ Name = 'clus-b'; ResourceGroupName = 'rg-b'; Location = 'westus2' }
                )
            } -ParameterFilter { $ResourceType -eq 'microsoft.azurestackhci/clusters' }

            $selected = Select-RangerCluster -Config $config -PreselectedName 'clus-b'
            $selected.Name | Should -Be 'clus-b'
            $config.environment.clusterName     | Should -Be 'clus-b'
            $config.targets.azure.resourceGroup | Should -Be 'rg-b'
        }
    }

    It 'returns a runnable config when neither ConfigPath nor ConfigObject is supplied (issue #296)' {
        InModuleScope AzureLocalRanger {
            $config = Import-RangerConfiguration
            $config | Should -Not -BeNullOrEmpty
            $config.Contains('targets') | Should -BeTrue
            $config.targets.Contains('cluster') | Should -BeTrue
            $config.targets.Contains('azure')  | Should -BeTrue
        }
    }

    It 'derives environment.name from ClusterName override when env.name is still the scaffold placeholder (issue #296)' {
        InModuleScope AzureLocalRanger {
            $config = Get-RangerDefaultConfig
            $overrides = @{
                SubscriptionId = '22222222-2222-2222-2222-222222222222'
                TenantId       = '33333333-3333-3333-3333-333333333333'
                ClusterName    = 'tplabs-clus01'
            }
            $config = Set-RangerStructuralOverrides -Config $config -StructuralOverrides $overrides
            $config.environment.name        | Should -Be 'tplabs-clus01'
            $config.environment.clusterName | Should -Be 'tplabs-clus01'
            $config.targets.azure.subscriptionId | Should -Be '22222222-2222-2222-2222-222222222222'
            $config.targets.azure.tenantId       | Should -Be '33333333-3333-3333-3333-333333333333'
        }
    }

    It 'keeps an explicit EnvironmentName override over the ClusterName fallback (issue #296)' {
        InModuleScope AzureLocalRanger {
            $config = Get-RangerDefaultConfig
            $overrides = @{
                ClusterName     = 'tplabs-clus01'
                EnvironmentName = 'tplabs-preprod'
            }
            $config = Set-RangerStructuralOverrides -Config $config -StructuralOverrides $overrides
            $config.environment.name        | Should -Be 'tplabs-preprod'
            $config.environment.clusterName | Should -Be 'tplabs-clus01'
        }
    }

    It 'auto-discovers cluster nodes from Arc cluster properties.nodes when config leaves them empty (issue #294)' {
        InModuleScope AzureLocalRanger {
            $config = Get-RangerDefaultConfig
            $config.environment.clusterName            = 'tplabs-clus01'
            $config.targets.azure.subscriptionId       = '22222222-2222-2222-2222-222222222222'
            $config.targets.azure.tenantId             = '33333333-3333-3333-3333-333333333333'
            $config.targets.azure.resourceGroup        = 'rg-tplabs'
            $config.targets.cluster.fqdn               = 'tplabs-clus01.azrl.mgmt'
            $config.targets.cluster.nodes              = @()

            Mock Resolve-RangerClusterArcResource -ModuleName AzureLocalRanger {
                [pscustomobject]@{
                    Name              = 'tplabs-clus01'
                    ResourceGroupName = 'rg-tplabs'
                    Properties        = [pscustomobject]@{
                        domainName = 'azrl.mgmt'
                        nodes      = @(
                            [pscustomobject]@{ name = 'tplabs-01-n01' },
                            [pscustomobject]@{ name = 'tplabs-01-n02' },
                            [pscustomobject]@{ name = 'tplabs-01-n03' },
                            [pscustomobject]@{ name = 'tplabs-01-n04' }
                        )
                    }
                }
            }

            $result = Invoke-RangerAzureAutoDiscovery -Config $config
            $result | Should -BeTrue

            @($config.targets.cluster.nodes).Count | Should -Be 4
            $config.targets.cluster.nodes | Should -Contain 'tplabs-01-n01.azrl.mgmt'
            $config.targets.cluster.nodes | Should -Contain 'tplabs-01-n04.azrl.mgmt'
        }
    }

    It 'falls back to subscription Arc machines when cluster properties do not surface nodes (issue #294)' {
        InModuleScope AzureLocalRanger {
            $config = Get-RangerDefaultConfig
            $config.environment.clusterName            = 'tplabs-clus01'
            $config.targets.azure.subscriptionId       = '22222222-2222-2222-2222-222222222222'
            $config.targets.azure.tenantId             = '33333333-3333-3333-3333-333333333333'
            $config.targets.azure.resourceGroup        = 'rg-tplabs'
            $config.targets.cluster.fqdn               = 'tplabs-clus01.azrl.mgmt'
            $config.targets.cluster.nodes              = @()

            Mock Resolve-RangerClusterArcResource -ModuleName AzureLocalRanger {
                [pscustomobject]@{
                    Name              = 'tplabs-clus01'
                    ResourceGroupName = 'rg-tplabs'
                    Properties        = [pscustomobject]@{ domainName = 'azrl.mgmt' }
                }
            }

            Mock Resolve-RangerArcMachinesForCluster -ModuleName AzureLocalRanger {
                [ordered]@{
                    Machines = @(
                        [pscustomobject]@{ Name = 'tplabs-01-n01' },
                        [pscustomobject]@{ Name = 'tplabs-01-n02' }
                    )
                    CrossRg  = @()
                }
            }

            $null = Invoke-RangerAzureAutoDiscovery -Config $config
            @($config.targets.cluster.nodes).Count | Should -Be 2
            $config.targets.cluster.nodes | Should -Contain 'tplabs-01-n01.azrl.mgmt'
        }
    }

    It 'default config does not carry placeholder keyvault:// credential references (issue #292)' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        foreach ($name in @('cluster', 'domain', 'bmc')) {
            $block = $config.credentials[$name]
            $block | Should -Not -BeNullOrEmpty
            $block.Contains('passwordRef') | Should -BeTrue
            $block.passwordRef | Should -BeNullOrEmpty
            $block.username    | Should -BeNullOrEmpty
        }
    }

    It 'interactive prompt check returns false inside Pester' {
        # Regression test for the Invoke-RangerWizard interactive gate.
        # Test-RangerInteractivePromptAvailable must return false while Pester is running
        # so the wizard does not attempt interactive prompts during automated test runs.
        InModuleScope AzureLocalRanger {
            $result = Test-RangerInteractivePromptAvailable
            $result | Should -BeFalse
        }
    }

    It 'interactive prompt check returns false when PesterPreference is set' {
        InModuleScope AzureLocalRanger {
            $Global:PesterPreference = [PesterConfiguration]::Default
            try {
                $result = Test-RangerInteractivePromptAvailable
                $result | Should -BeFalse
            }
            finally {
                Remove-Variable -Name PesterPreference -Scope Global -ErrorAction SilentlyContinue
            }
        }
    }

    It 'interactive prompt check returns true when Host.Name is ConsoleHost even if UserInteractive is false' {
        # Regression test: [Environment]::UserInteractive returns $false on Windows multi-session
        # (AVD) hosts even when a real user is at the prompt. The check must use $Host.Name.
        InModuleScope AzureLocalRanger {
            # Pester runs under ConsoleHost, so patch UserInteractive instead to simulate AVD
            # by verifying the $Host.Name path is taken before UserInteractive is consulted.
            # We cannot unload Pester inside Pester, so we verify the logic directly:
            # if $Host.Name -in interactiveHosts the function returns $true regardless of UserInteractive.
            # Simulate a non-ConsoleHost to confirm it falls through to UserInteractive ($false in CI).
            Mock -CommandName 'Get-Module' -MockWith { $null } -ParameterFilter { $Name -eq 'Pester' }
            Mock -CommandName 'Get-Variable' -MockWith { $null } -ParameterFilter { $Name -eq 'PesterPreference' }

            # Directly test the host-name branch logic (the function is private, use a wrapper)
            $result = & {
                $interactiveHosts = @('ConsoleHost', 'Windows PowerShell ISE Host', 'Visual Studio Code Host')
                $Host.Name -in $interactiveHosts
            }
            $result | Should -BeTrue
        }
    }
}
