BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
    $script:fixtureRoot = Join-Path $script:repoRoot 'tests\maproom\Fixtures'
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
    $script:fx = Get-Content (Join-Path $script:fixtureRoot 'platform-2609.json') -Raw | ConvertFrom-Json -AsHashtable
}

# Learn references for each item are listed in docs/reference/platform-2609-evidence.md.
Describe 'Azure Local 12.2609 (latest) platform evidence' {
    It 'Arc gateway: parses azcmagent show/check and shapes gateway + per-node routing' {
        $r = InModuleScope AzureLocalRanger -Parameters @{ fx = $script:fx } {
            param($fx)
            $routed = ConvertFrom-RangerAzcmagentShow -ShowText $fx.azcmagentShowRouted -CheckText $fx.azcmagentCheckRouted
            $routed['node'] = 'node-01'
            $direct = ConvertFrom-RangerAzcmagentShow -ShowText $fx.azcmagentShowDirect -CheckText $fx.azcmagentCheckDirect
            $direct['node'] = 'node-02'
            [pscustomobject]@{
                Routed = $routed; Direct = $direct
                Evidence = ConvertTo-RangerArcGatewayEvidence -GatewayResources $fx.gatewayResources -NodeAgentFacts @($routed, $direct)
            }
        }
        $r.Routed.status | Should -Be 'routed'
        $r.Routed.agentVersionMeetsGatewayMinimum | Should -BeTrue
        $r.Routed.connectionType | Should -Be 'gateway'
        $r.Direct.status | Should -Be 'not-routed'
        $r.Direct.agentVersionMeetsGatewayMinimum | Should -BeFalse
        $r.Evidence.arcGateways.Count | Should -Be 1
        $r.Evidence.arcGateways[0].gatewayEndpoint | Should -Be 'https://arcgw-example-01.gw.arc.azure.com'
        $r.Evidence.arcGatewayNodeRouting[0].routedThrough | Should -Be 'arcgw-example-01'
        $r.Evidence.arcGatewayNodeRouting[1].routedThrough | Should -BeNullOrEmpty
    }

    It 'Security baseline: computes the compliance score from the AzureWindowsBaseline assignment report' {
        $s = InModuleScope AzureLocalRanger -Parameters @{ fx = $script:fx } { param($fx) ConvertTo-RangerSecurityBaselineScore -MachineName 'node-01' -Assignment $fx.baselineAssignment }
        $s.assignment | Should -Be 'AzureWindowsBaseline'
        $s.totalRules | Should -Be 4
        $s.compliantRules | Should -Be 3
        $s.scorePercent | Should -Be 75
        $s.nonCompliantRules[0].name | Should -Be 'Minimum password length'
        (InModuleScope AzureLocalRanger { ConvertTo-RangerSecurityBaselineScore -MachineName 'n' -Assignment $null }).status | Should -Be 'not-assigned'
    }

    It 'Secure Boot: maps registry and cmdlet facts to updated / not-updated and flags action' {
        $r = InModuleScope AzureLocalRanger -Parameters @{ fx = $script:fx } {
            param($fx)
            [pscustomobject]@{
                Ok   = ConvertTo-RangerSecureBootStatus -Node 'node-01' -Raw $fx.secureBootUpdated
                Todo = ConvertTo-RangerSecureBootStatus -Node 'node-02' -Raw $fx.secureBootPending
                None = ConvertTo-RangerSecureBootStatus -Node 'node-03' -Raw $null
            }
        }
        $r.Ok.state | Should -Be 'updated'
        $r.Ok.actionRequired | Should -BeFalse
        $r.Todo.state | Should -Be 'not-updated'
        $r.Todo.actionRequired | Should -BeTrue
        $r.None.state | Should -Be 'unknown'
    }

    It 'Rack aware: reads Rack fault domains as local availability zones with their nodes' {
        $r = InModuleScope AzureLocalRanger -Parameters @{ fx = $script:fx } { param($fx) Get-RangerRackAwareSummary -FaultDomains $fx.faultDomainsRackAware -NodeNames @('node-01', 'node-02', 'node-03', 'node-04', 'node-05') }
        $r.isRackAware | Should -BeTrue
        $r.rackCount | Should -Be 2
        $r.layout | Should -Be '2+2'
        $r.balanced | Should -BeTrue
        $r.zones[0].nodes | Should -Contain 'node-02'
        $r.nodesWithoutZone | Should -Be @('node-05')
    }

    It 'Rack aware: a single rack is not rack aware' {
        $r = InModuleScope AzureLocalRanger { Get-RangerRackAwareSummary -FaultDomains @(@{ name = 'Rack01'; faultDomainType = 'Rack'; location = 'x' }) -NodeNames @('a') }
        $r.isRackAware | Should -BeFalse
        $r.rackCount | Should -Be 1
    }

    It 'SBE / OEM update detail: surfaces the SBE state, AdditionalContentRequired and Pending OEM Validation' {
        $d = InModuleScope AzureLocalRanger -Parameters @{ fx = $script:fx } { param($fx) Get-RangerSolutionUpdateDetail -Environment $fx.solutionUpdateEnv -Updates $fx.solutionUpdates }
        $d.sbeFamily | Should -Be 'Example Gen 1'
        $d.currentSbeVersion | Should -Be '4.1.2312.5'
        $d.sbeInstalled | Should -BeTrue
        $d.additionalContentRequired | Should -Be 1
        $d.pendingOemValidation | Should -Be 1
        $d.updates[0].sbeReleaseLink | Should -Be 'https://example.test/sbe/release-notes'
    }

    It 'Disaggregated / SAN indicators: CSVs without Storage Spaces Direct and Fibre Channel disks' {
        $i = InModuleScope AzureLocalRanger -Parameters @{ fx = $script:fx } { param($fx) Get-RangerStorageArchitectureIndicators -Manifest $fx.sanManifest }
        $i.likelyDisaggregated | Should -BeTrue
        $i.disaggregatedOrSanIndicators | Should -Contain 'csv-without-storage-spaces-direct'
        $i.disaggregatedOrSanIndicators | Should -Contain 'disk-bus-fibre channel'
    }

    It 'Key backup + local identity + private path: metadata only, never secret values' {
        $r = InModuleScope AzureLocalRanger -Parameters @{ fx = $script:fx } {
            param($fx)
            $kb = ConvertTo-RangerKeyBackupEvidence -Vaults $fx.keyVaults
            $li = Get-RangerLocalIdentityEvidence -IdentitySnapshots @(@{ domain = 'WORKGROUP' }, @{ domain = 'WORKGROUP' }) -AdAware 2 -KeyVaults @('kv-example-backup') -DnsServers @('192.0.2.10')
            $pp = Get-RangerPrivatePathEvidence -Gateways @(@{ name = 'g' }) -AzureResources @(@{ Name = 'pe1'; ResourceType = 'Microsoft.Network/privateEndpoints' })
            [pscustomobject]@{ KeyBackup = $kb; Local = $li; Private = $pp }
        }
        $r.KeyBackup.status | Should -Be 'candidate-key-vault-present'
        $r.KeyBackup.backupKeyVaultCandidates[0].purgeProtection | Should -BeTrue
        ($r.KeyBackup | ConvertTo-Json -Depth 6) | Should -Not -Match '(?i)"(value|secretValue|recoveryKey|password)"\s*:'
        $r.Local.identityMode | Should -Be 'local-identity'
        $r.Local.usesKeyVault | Should -BeTrue
        $r.Local.internalDnsPreview | Should -BeTrue
        $r.Private.likelyPrivatePath | Should -BeTrue
    }

    It 'Platform analysis adds rackAware, solutionUpdateDetail and architectureIndicators to a manifest and is idempotent' {
        $m = Get-Content (Join-Path $script:fixtureRoot 'synthetic-manifest.json') -Raw | ConvertFrom-Json -AsHashtable
        $m.domains.clusterNode.updatePosture.solutionUpdateEnv = $script:fx.solutionUpdateEnv
        $m.domains.clusterNode.updatePosture.pendingSolutionUpdates = $script:fx.solutionUpdates
        $m.domains.identitySecurity.localIdentity = [ordered]@{ identityMode = 'local-identity' }
        InModuleScope AzureLocalRanger -Parameters @{ m = $m } { param($m) $null = Invoke-RangerPlatform2609Analysis -Manifest $m; $null = Invoke-RangerPlatform2609Analysis -Manifest $m }
        $m.domains.clusterNode.rackAware.rackCount | Should -Be 1
        $m.domains.clusterNode.rackAware.isRackAware | Should -BeFalse
        $m.domains.clusterNode.solutionUpdateDetail.currentSbeVersion | Should -Be '4.1.2312.5'
        $m.domains.storage.architectureIndicators.storageSpacesDirectEnabled | Should -BeTrue
        $m.domains.identitySecurity.localIdentity.dnsServers.Count | Should -BeGreaterThan 0
    }

    It 'Evidence orchestration returns every 12.2609 block (collectors mocked, no Azure or node access)' {
        $r = InModuleScope AzureLocalRanger -Parameters @{ fx = $script:fx } {
            param($fx)
            Mock Get-RangerArcGatewayAzureResources { $fx.gatewayResources }
            Mock Get-RangerNodeArcAgentFacts { @([ordered]@{ node = 'node-01'; status = 'routed'; agentVersion = '1.47'; agentVersionMeetsGatewayMinimum = $true; connectionType = 'gateway' }) }
            Mock Get-RangerSecurityBaselineAzure { @(ConvertTo-RangerSecurityBaselineScore -MachineName 'node-01' -Assignment $fx.baselineAssignment) }
            Mock Get-RangerNodeSecureBootFacts { @(ConvertTo-RangerSecureBootStatus -Node 'node-01' -Raw $fx.secureBootUpdated) }
            Mock Get-RangerKeyVaultMetadata { $fx.keyVaults }
            Mock Get-RangerClusterAdAware { 2 }
            Invoke-RangerPlatform2609Evidence -Config @{ targets = @{ azure = @{ resourceGroup = 'rg'; subscriptionId = 's' } } } -CredentialMap @{ azure = @{}; cluster = $null } -ArcMachines @(@{ Name = 'node-01' }) -IdentitySnapshots @(@{ domain = 'WORKGROUP' })
        }
        foreach ($k in 'arcGateways', 'arcGatewayNodeRouting', 'securityBaseline', 'secureBootCertificates', 'keyBackup', 'localIdentity', 'privatePath') { $r.Contains($k) | Should -BeTrue -Because $k }
        $r.arcGatewayNodeRouting[0].routedThrough | Should -Be 'arcgw-example-01'
        $r.securityBaseline[0].scorePercent | Should -Be 75
    }
}
