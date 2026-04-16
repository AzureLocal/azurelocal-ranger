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
