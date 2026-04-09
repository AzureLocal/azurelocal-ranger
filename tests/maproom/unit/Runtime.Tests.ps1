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

    It 'runs unattended without interactive prompts and writes run status metadata' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $config.output.rootPath = Join-Path $TestDrive 'unattended-artifacts'
        $config.behavior.promptForMissingCredentials = $true
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

        InModuleScope AzureLocalRanger {
            param($TestConfig, $OutputRoot)

            Mock Invoke-RangerInteractiveInput { throw 'interactive input should not run in unattended mode' }
            Mock Get-Credential { throw 'credential prompt should not run in unattended mode' }

            $result = Invoke-AzureLocalRanger -ConfigObject $TestConfig -OutputPath $OutputRoot -NoRender -Unattended
            $runStatus = Get-Content -Path (Join-Path $result.PackageRoot 'run-status.json') -Raw | ConvertFrom-Json -Depth 100

            $result.Manifest.run.unattended | Should -BeTrue
            $runStatus.unattended | Should -BeTrue
            $runStatus.status | Should -Be 'success'

            Assert-MockCalled Invoke-RangerInteractiveInput -Times 0 -Exactly
            Assert-MockCalled Get-Credential -Times 0 -Exactly
        } -Parameters @{ TestConfig = $config; OutputRoot = (Join-Path $TestDrive 'unattended-output') }
    }

    It 'writes a drift report and renders a drift section when a baseline manifest is supplied' {
        $baselineConfig = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $baselineConfig.output.rootPath = Join-Path $TestDrive 'baseline-artifacts'
        $baselineConfig.behavior.promptForMissingCredentials = $false
        $baselineConfig.behavior.continueToRendering = $false
        $baselineConfig.credentials.cluster = $null
        $baselineConfig.credentials.domain = $null
        $baselineConfig.credentials.bmc = $null
        $baselineConfig.domains.hints.fixtures = [ordered]@{
            'topology-cluster' = (Join-Path $fixtureRoot 'topology-cluster.json')
            'hardware' = (Join-Path $fixtureRoot 'hardware.json')
            'storage-networking' = (Join-Path $fixtureRoot 'storage-networking.json')
            'workload-identity-azure' = (Join-Path $fixtureRoot 'workload-identity-azure.json')
            'monitoring-observability' = (Join-Path $fixtureRoot 'monitoring-observability.json')
            'management-performance' = (Join-Path $fixtureRoot 'management-performance.json')
        }

        $baselineResult = Invoke-AzureLocalRanger -ConfigObject $baselineConfig -OutputPath (Join-Path $TestDrive 'baseline-output') -NoRender

        $driftConfig = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $driftConfig.output.rootPath = Join-Path $TestDrive 'drift-artifacts'
        $driftConfig.output.formats = @('html')
        $driftConfig.behavior.promptForMissingCredentials = $false
        $driftConfig.behavior.continueToRendering = $true
        $driftConfig.credentials.cluster = $null
        $driftConfig.credentials.domain = $null
        $driftConfig.credentials.bmc = $null
        $driftConfig.domains.hints.fixtures = [ordered]@{
            'topology-cluster' = (Join-Path $fixtureRoot 'topology-cluster.json')
            'hardware' = (Join-Path $fixtureRoot 'hardware.json')
            'storage-networking' = (Join-Path $fixtureRoot 'storage-networking-degraded.json')
            'workload-identity-azure' = (Join-Path $fixtureRoot 'workload-identity-azure.json')
            'monitoring-observability' = (Join-Path $fixtureRoot 'monitoring-observability.json')
            'management-performance' = (Join-Path $fixtureRoot 'management-performance.json')
        }

        $driftResult = Invoke-AzureLocalRanger -ConfigObject $driftConfig -OutputPath (Join-Path $TestDrive 'drift-output') -BaselineManifestPath $baselineResult.ManifestPath
        $driftReport = Get-Content -Path (Join-Path $driftResult.PackageRoot 'manifest\drift-report.json') -Raw | ConvertFrom-Json -Depth 100
        $technicalHtml = Get-ChildItem -Path (Join-Path $driftResult.PackageRoot 'reports') -Filter '*Technical-Deep-Dive.html' | Select-Object -First 1
        $technicalHtmlContent = Get-Content -Path $technicalHtml.FullName -Raw

        $driftResult.Manifest.run.drift.status | Should -Be 'generated'
        $driftReport.status | Should -Be 'generated'
        $driftReport.summary.totalChanges | Should -BeGreaterThan 0
        $technicalHtmlContent | Should -Match 'Drift Analysis'
        $technicalHtmlContent | Should -Match 'Total detected changes'
    }

    It 'caches failed WinRM preflight results and avoids repeated probes' -Skip:(-not $IsWindows) {
        InModuleScope AzureLocalRanger {
            $script:RangerWinRmProbeCache = @{}

            Mock Test-RangerCommandAvailable {
                param($Name)
                $Name -in @('Test-NetConnection', 'Test-WSMan')
            }

            Mock Test-NetConnection {
                [pscustomobject]@{ TcpTestSucceeded = $false }
            }

            Mock Test-WSMan { }

            { Invoke-RangerRemoteCommand -ComputerName @('node01.contoso.com') -ScriptBlock { 'ok' } } | Should -Throw
            { Invoke-RangerRemoteCommand -ComputerName @('node01.contoso.com') -ScriptBlock { 'ok' } } | Should -Throw

            Assert-MockCalled Test-NetConnection -Times 2 -Exactly
            Assert-MockCalled Test-WSMan -Times 0
        }
    }

    It 'prefers HTTPS WinRM when HTTP is unavailable but WSMan over SSL succeeds' -Skip:(-not $IsWindows) {
        InModuleScope AzureLocalRanger {
            $script:RangerWinRmProbeCache = @{}

            Mock Test-RangerCommandAvailable {
                param($Name)
                $Name -in @('Test-NetConnection', 'Test-WSMan')
            }

            Mock Test-NetConnection {
                param($ComputerName, $Port)

                [pscustomobject]@{
                    TcpTestSucceeded = ($Port -eq 5986)
                }
            }

            Mock Test-WSMan {
                param($ComputerName, $Authentication, $ErrorAction, [switch]$UseSSL)

                if (-not $UseSSL) {
                    throw 'HTTP WSMan unavailable'
                }

                [pscustomobject]@{ ProductVersion = 'OS: 0.0.0 SP: 0.0 Stack: 3.0' }
            }

            $result = Test-RangerWinRmTarget -ComputerName 'node01.contoso.com' -Credential $null

            $result.Reachable | Should -BeTrue
            $result.Transport | Should -Be 'https'
            $result.Port | Should -Be 5986
            Assert-MockCalled Test-NetConnection -Times 2 -Exactly
            Assert-MockCalled Test-WSMan -Times 1 -Exactly -ParameterFilter { $UseSSL }
        }
    }
}