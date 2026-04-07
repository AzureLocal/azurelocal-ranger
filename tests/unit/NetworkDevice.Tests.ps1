BeforeAll {
    $script:repoRoot    = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $script:fixtureRoot = Join-Path $script:repoRoot 'tests\Fixtures'
    $script:nxosFixture = Join-Path $script:fixtureRoot 'network-configs\switch-nxos-sample.txt'
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
}

Describe 'Network device config parser (issue #36)' {

    It 'parses VLAN range strings correctly' {
        InModuleScope AzureLocalRanger {
            $ids = Expand-RangerVlanRange -Range '10,20-22,30'
            $ids | Should -HaveCount 5
            $ids | Should -Contain 10
            $ids | Should -Contain 20
            $ids | Should -Contain 21
            $ids | Should -Contain 22
            $ids | Should -Contain 30
        }
    }

    It 'parses a single VLAN ID range' {
        InModuleScope AzureLocalRanger {
            $ids = Expand-RangerVlanRange -Range '110'
            $ids | Should -HaveCount 1
            $ids | Should -Contain 110
        }
    }

    It 'parses the IIC NX-OS sample fixture' {
        $result = InModuleScope AzureLocalRanger {
            param($FixturePath)

            $raw = Get-Content -Path $FixturePath -Raw
            ConvertFrom-RangerCiscoNxosConfig -RawContent $raw -FilePath $FixturePath -Role 'storage-switch'
        } -Parameters @{ FixturePath = $script:nxosFixture }

        $result.vendor      | Should -Be 'cisco-nxos'
        $result.parseStatus | Should -Be 'parsed'
        $result.role        | Should -Be 'storage-switch'
    }

    It 'discovers 5 VLANs from the NX-OS sample' {
        $result = InModuleScope AzureLocalRanger {
            param($FixturePath)

            $raw = Get-Content -Path $FixturePath -Raw
            ConvertFrom-RangerCiscoNxosConfig -RawContent $raw -FilePath $FixturePath -Role 'storage-switch'
        } -Parameters @{ FixturePath = $script:nxosFixture }

        @($result.vlans).Count | Should -Be 5
        ($result.vlans | Where-Object { $_.vlanId -eq 110 }).name | Should -Be 'storage_iic_rdma'
    }

    It 'discovers 3 port-channel interfaces from the NX-OS sample' {
        $result = InModuleScope AzureLocalRanger {
            param($FixturePath)

            $raw = Get-Content -Path $FixturePath -Raw
            ConvertFrom-RangerCiscoNxosConfig -RawContent $raw -FilePath $FixturePath -Role 'storage-switch'
        } -Parameters @{ FixturePath = $script:nxosFixture }

        @($result.portChannels).Count | Should -Be 3
        ($result.portChannels | Where-Object { $_.name -eq 'port-channel1' }).description | Should -Be 'IIC-AZL-N01_uplink'
    }

    It 'extracts ACL entries from the NX-OS sample' {
        $result = InModuleScope AzureLocalRanger {
            param($FixturePath)

            $raw = Get-Content -Path $FixturePath -Raw
            ConvertFrom-RangerCiscoNxosConfig -RawContent $raw -FilePath $FixturePath -Role 'storage-switch'
        } -Parameters @{ FixturePath = $script:nxosFixture }

        @($result.acls).Count | Should -BeGreaterOrEqual 1
        ($result.acls | Where-Object { $_.name -eq 'MGMT_IN' }) | Should -Not -BeNullOrEmpty
    }

    It 'returns empty arrays when hints are absent' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $result = InModuleScope AzureLocalRanger {
            param($TestConfig)

            Invoke-RangerNetworkDeviceConfigImport -Config $TestConfig
        } -Parameters @{ TestConfig = $config }

        @($result.switchConfig).Count   | Should -Be 0
        @($result.firewallConfig).Count | Should -Be 0
    }

    It 'imports the NX-OS fixture via the hint-driven import function' {
        $config = InModuleScope AzureLocalRanger {
            Get-RangerDefaultConfig
        }

        $config.domains.hints.networkDeviceConfigs = @(
            [ordered]@{
                path   = $script:nxosFixture
                vendor = 'cisco-nxos'
                role   = 'storage-switch'
            }
        )

        $result = InModuleScope AzureLocalRanger {
            param($TestConfig)

            Invoke-RangerNetworkDeviceConfigImport -Config $TestConfig
        } -Parameters @{ TestConfig = $config }

        @($result.switchConfig).Count   | Should -Be 1
        @($result.firewallConfig).Count | Should -Be 0
        $result.switchConfig[0].vendor  | Should -Be 'cisco-nxos'
        $result.switchConfig[0].parseStatus | Should -Be 'parsed'
    }
}
