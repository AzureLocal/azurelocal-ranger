BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
    $script:bridge = Join-Path $script:repoRoot 'samples\configs\ranger.from-environment.ps1'
    $script:envFile = Join-Path $script:repoRoot 'tests\maproom\Fixtures\design\environment.example.yml'
}

Describe 'ranger.from-environment.ps1 (deploy automation environment file -> ranger.yml)' {
    It 'maps cluster, FQDNs, nodes, subscription and tenant from the environment file' {
        $c = & $script:bridge -EnvironmentPath $script:envFile -TenantId '00000000-0000-0000-0000-000000000000'
        $c.environment.clusterName | Should -Be 'azlocal-iic-01'
        $c.targets.cluster.fqdn | Should -Be 'azlocal-iic-01.iic.local'
        $c.targets.cluster.nodes | Should -Be @('azl-iic-n01.iic.local', 'azl-iic-n02.iic.local', 'azl-iic-n04.iic.local')
        $c.targets.azure.subscriptionId | Should -Be '33333333-3333-3333-3333-333333333333'
        $c.targets.azure.tenantId | Should -Be '00000000-0000-0000-0000-000000000000'
        @($c.targets.bmc.endpoints).Count | Should -Be 0
    }

    It 'adds BMC endpoints only with -IncludeBmc' {
        $c = & $script:bridge -EnvironmentPath $script:envFile -IncludeBmc
        @($c.targets.bmc.endpoints).Count | Should -Be 3
        $c.targets.bmc.endpoints[0].host | Should -Be '10.245.64.11'
        $c.targets.bmc.endpoints[0].node | Should -Be 'azl-iic-n01.iic.local'
    }

    It 'writes a ranger.yml that Ranger itself loads and validates' {
        $out = Join-Path $TestDrive 'ranger.yml'
        $null = & $script:bridge -EnvironmentPath $script:envFile -OutputPath $out -TenantId '00000000-0000-0000-0000-000000000000' -Mode as-built
        Test-Path $out | Should -BeTrue
        (Get-Content $out -Raw) | Should -Match 'azurelocal.cloud/azurelocal-ranger'
        (Get-Content $out -Raw) | Should -Not -Match '(?i)password|secret'
        $loaded = InModuleScope AzureLocalRanger -Parameters @{ p = $out } { param($p) Import-RangerConfiguration -ConfigPath $p }
        $loaded.targets.cluster.fqdn | Should -Be 'azlocal-iic-01.iic.local'
        $loaded.output.mode | Should -Be 'as-built'
        @($loaded.targets.cluster.nodes).Count | Should -Be 3
    }

    It 'writes JSON when the output path ends in .json and refuses a file without a cluster name' {
        $out = Join-Path $TestDrive 'ranger.json'
        $null = & $script:bridge -EnvironmentPath $script:envFile -OutputPath $out
        (Get-Content $out -Raw | ConvertFrom-Json).environment.clusterName | Should -Be 'azlocal-iic-01'
        $bad = Join-Path $TestDrive 'bad.json'
        '{ "nodes": [] }' | Set-Content $bad
        { & $script:bridge -EnvironmentPath $bad } | Should -Throw '*cluster_name*'
    }
}
