BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
    $script:fixtureRoot = Join-Path $script:repoRoot 'tests\maproom\Fixtures'
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
    $script:manifestPath = Join-Path $script:fixtureRoot 'synthetic-manifest.json'
    $script:envPath = Join-Path $script:fixtureRoot 'design\environment.example.yml'
    $script:infraPath = Join-Path $script:fixtureRoot 'design\infrastructure.example.yml'
    $script:schemaPath = Join-Path $script:repoRoot 'docs\reference\as-built-snapshot.v1.schema.json'

    # A manifest in the shape the real collectors write (per-node networking, Get-NetIntent flags, copies for resiliency).
    function script:New-RealShapeManifest {
        [ordered]@{
            run      = [ordered]@{ toolVersion = '2.7.0'; schemaVersion = '1.1.0-draft'; startTimeUtc = '2026-10-15T08:00:00Z'; endTimeUtc = '2026-10-15T08:10:00Z' }
            target   = [ordered]@{ clusterName = 'azlocal-iic-01'; subscriptionId = '33333333-3333-3333-3333-333333333333'; resourceGroup = 'rg-iic-compute-01' }
            topology = [ordered]@{ identityMode = 'local-key-vault' }
            domains  = [ordered]@{
                clusterNode = [ordered]@{
                    cluster = [ordered]@{ name = 'azlocal-iic-01'; domain = 'iic.local'; currentBuild = '26100' }
                    nodes   = @([ordered]@{ name = 'azl-iic-n01' }, [ordered]@{ name = 'azl-iic-n02' })
                    quorum  = [ordered]@{ quorumType = 'CloudWitness'; witnessDetail = [ordered]@{ type = 'Cloud Witness' } }
                    updatePosture = [ordered]@{ solutionUpdateEnv = [ordered]@{ State = 'AppliedSuccessfully'; CurrentVersion = '12.2609.1003.7'; CurrentSbeVersion = '4.1.2312.5' } }
                }
                hardware    = [ordered]@{ nodes = @([ordered]@{ node = 'azl-iic-n01'; serviceTag = 'ABC1234'; manufacturer = 'Dell Inc.' }, [ordered]@{ node = 'azl-iic-n02'; serialNumber = 'SER-0002'; manufacturer = 'HPE' }) }
                networking  = [ordered]@{
                    nodes = @(
                        [ordered]@{
                            node = 'azl-iic-n01'
                            hostVirtualNics = @([ordered]@{ name = 'vManagement(Management)'; ipAddress = '10.0.0.11'; isManagementNic = $true; vlanId = 2203 }, [ordered]@{ name = 'vSMB(Storage#1)'; ipAddress = '10.0.1.11' })
                            intents = @([ordered]@{ Name = 'Mgmt_Compute'; IsComputeIntent = $true; IsStorageIntent = $false }, [ordered]@{ Name = 'Storage'; IsStorageIntent = $true; IsComputeIntent = $false })
                            intentOverrides = @([ordered]@{ name = 'Mgmt_Compute'; adapters = @('NIC1', 'NIC2'); isManagementIntent = $true }, [ordered]@{ name = 'Storage'; adapters = @('NIC3', 'NIC4') })
                            vlan = @([ordered]@{ VMNetworkAdapterName = 'vManagement'; AccessVlanId = 2203 })
                            dns = @([ordered]@{ InterfaceAlias = 'vManagement'; ServerAddresses = @('192.168.10.10') })
                            dcb = [ordered]@{ trafficClasses = @([ordered]@{ Name = 'SMB'; Priority = 3; BandwidthPercentage = 50 }) }
                        },
                        [ordered]@{ node = 'azl-iic-n02'; hostVirtualNics = @([ordered]@{ name = 'vManagement(Management)'; ipAddress = '10.0.0.12'; isManagementNic = $true }) }
                    )
                    adapters = @(
                        [ordered]@{ node = 'azl-iic-n01'; name = 'NIC1'; mtuSize = 1514; rdmaCapable = $false },
                        [ordered]@{ node = 'azl-iic-n01'; name = 'NIC3'; mtuSize = 9014; rdmaCapable = $true },
                        [ordered]@{ node = 'azl-iic-n01'; name = 'NIC4'; mtuSize = 9014; rdmaCapable = $true }
                    )
                    sdn = @([ordered]@{ node = 'azl-iic-n01'; sdn = [ordered]@{ deployed = $false } })
                }
                storage     = [ordered]@{
                    virtualDisks = @(
                        [ordered]@{ friendlyName = 'csv-iic-azlocal-01-vmstore-01'; resiliencySettingName = 'Mirror'; numberOfDataCopies = 3; sizeGiB = 2000 },
                        [ordered]@{ friendlyName = 'Infrastructure_1'; resiliencySettingName = 'Mirror'; numberOfDataCopies = 2; sizeGiB = 256 }
                    )
                }
            }
        }
    }
}

Describe 'as-built-snapshot.v1 export' {
    It 'exports the synthetic manifest and validates against the published JSON Schema' {
        $m = Get-Content $script:manifestPath -Raw | ConvertFrom-Json -AsHashtable
        $snap = ConvertTo-RangerAsBuiltSnapshot -Manifest $m
        $snap.schema | Should -Be 'as-built-snapshot.v1'
        $snap.cluster.name | Should -Be 'azlocal-iic-01'
        @($snap.nodes).Count | Should -Be 3
        $snap.nodes[0].serial | Should -Be 'ABC1234'
        $snap.nodes[0].bmcType | Should -Be 'idrac'
        $snap.identity.model | Should -Be 'active-directory'
        $snap.witness.type | Should -Be 'cloud'
        (@($snap.intents | ForEach-Object { $_.traffic }) -contains 'storage') | Should -BeTrue
        ($snap | ConvertTo-Json -Depth 20) | Test-Json -SchemaFile $script:schemaPath | Should -BeTrue
    }

    It 'reads the real collector shape: per-node host vNICs, Get-NetIntent flags, copies and SBE version' {
        $snap = ConvertTo-RangerAsBuiltSnapshot -Manifest (script:New-RealShapeManifest)
        $snap.cluster.release | Should -Be '12.2609.1003.7'
        $snap.cluster.sbeVersion | Should -Be '4.1.2312.5'
        $snap.identity.model | Should -Be 'local-identity-key-vault'
        $n1 = $snap.nodes | Where-Object name -eq 'azl-iic-n01'
        $n1.managementIp | Should -Be '10.0.0.11'
        $n1.storageIps | Should -Contain '10.0.1.11'
        $n1.serial | Should -Be 'ABC1234'
        ($snap.nodes | Where-Object name -eq 'azl-iic-n02').bmcType | Should -Be 'ilo'
        $mgmt = $snap.intents | Where-Object name -eq 'Mgmt_Compute'
        $mgmt.traffic | Should -Be @('management', 'compute')
        $mgmt.adapters | Should -Be @('NIC1', 'NIC2')
        $stor = $snap.intents | Where-Object name -eq 'Storage'
        $stor.jumbo | Should -Be 9014
        $stor.rdma | Should -BeTrue
        $stor.qos.priority | Should -Be 3
        ($snap.volumes | Where-Object name -eq 'csv-iic-azlocal-01-vmstore-01').resiliency | Should -Be 'three-way'
        $snap.vlans[0].id | Should -Be 2203
        ($snap | ConvertTo-Json -Depth 20) | Test-Json -SchemaFile $script:schemaPath | Should -BeTrue
    }

    It 'writes the snapshot as an output format' {
        $out = Join-Path $TestDrive 'snap-package'
        Export-AzureLocalRangerReport -ManifestPath $script:manifestPath -OutputPath $out -Formats @('as-built-snapshot') | Out-Null
        $f = Get-ChildItem -Path (Join-Path $out 'reports') -Filter '*-as-built-snapshot.json'
        $f.Count | Should -Be 1
        (Get-Content $f.FullName -Raw | ConvertFrom-Json).schema | Should -Be 'as-built-snapshot.v1'
    }
}

Describe 'design record readers' {
    It 'normalises the deploy automation environment file' {
        $d = InModuleScope AzureLocalRanger -Parameters @{ p = $script:envPath } { param($p) ConvertFrom-RangerDesignRecord -Path $p }
        $d._kind | Should -Be 'environment'
        $d.cluster.release | Should -Be '12.2609.1003.7'
        $d.identity.model | Should -Be 'active-directory'
        $d.witness.type | Should -Be 'cloud'
        @($d.nodes).Count | Should -Be 3
        ($d.nodes | Where-Object name -eq 'azl-iic-n01').storageIps | Should -Contain '10.0.2.11'
        @($d.vlans | ForEach-Object { $_.id }) | Should -Contain 711
        ($d.volumes | Where-Object name -eq 'csv-iic-azlocal-01-vmstore-02').resiliency | Should -Be 'two-way'
        ($d.intents | Where-Object name -eq 'Storage').jumbo | Should -Be 9014
    }

    It 'normalises a Trailwright infrastructure.yml' {
        $d = InModuleScope AzureLocalRanger -Parameters @{ p = $script:infraPath } { param($p) ConvertFrom-RangerDesignRecord -Path $p }
        $d._kind | Should -Be 'infrastructure'
        $d.cluster.name | Should -Be 'azlocal-iic-01'
        $d.azure.resourceGroup | Should -Be 'rg-iic-compute-01'
        @($d.nodes).Count | Should -Be 3
        ($d.nodes[0]).serial | Should -Be 'ABC1234'
    }

    It 'rejects a file it cannot classify' {
        $p = Join-Path $TestDrive 'odd.json'
        '{ "something": 1 }' | Set-Content $p
        { InModuleScope AzureLocalRanger -Parameters @{ p = $p } { param($p) ConvertFrom-RangerDesignRecord -Path $p } } | Should -Throw '*Cannot tell*'
    }
}

Describe 'Compare-RangerDesign' {
    It 'environment file versus the as-built manifest: statuses, severity and Learn links' {
        $r = Compare-RangerDesign -ManifestPath $script:manifestPath -DesignPath $script:envPath
        $r.schema | Should -Be 'design-comparison.v1'
        $row = { param($area, $key) $r.findings | Where-Object { $_.area -eq $area -and $_.key -eq $key } | Select-Object -First 1 }
        (& $row 'cluster' 'name').status | Should -Be 'match'
        (& $row 'identity' 'model').status | Should -Be 'match'
        (& $row 'identity' 'model').learn | Should -Match 'learn.microsoft.com'
        (& $row 'cluster' 'release').status | Should -Be 'not-captured'
        (& $row 'nodes' 'azl-iic-n04').status | Should -Be 'missing'
        (& $row 'nodes' 'azl-iic-n04').severity | Should -Be 'error'
        (& $row 'nodes' 'azl-iic-n03').status | Should -Be 'drift'
        (& $row 'vlans' 'vlan 711').status | Should -Be 'missing'
        (& $row 'vlans' 'vlan 2203').status | Should -Be 'match'
        (& $row 'volumes' 'csv-iic-azlocal-01-vmstore-01.sizeGiB').status | Should -Be 'match'
        (& $row 'volumes' 'csv-iic-azlocal-01-vmstore-02.sizeGiB').status | Should -Be 'drift'
        (& $row 'volumes' 'csv-iic-azlocal-01-archive-09').status | Should -Be 'missing'
        (& $row 'network' 'dnsServers').status | Should -Be 'match'
        $r.summary.total | Should -Be @($r.findings).Count
        $r.summary.errors | Should -BeGreaterThan 0
    }

    It 'real-shaped manifest: release, resiliency drift, intent traffic and per-node IPs' {
        $m = script:New-RealShapeManifest
        $d = [ordered]@{
            schema = 'as-built-snapshot.v1'
            cluster = [ordered]@{ name = 'azlocal-iic-01'; release = '12.2609.1003.7'; sbeVersion = '4.2.0.0' }
            identity = [ordered]@{ model = 'active-directory' }
            witness = [ordered]@{ type = 'file-share' }
            nodes = @([ordered]@{ name = 'azl-iic-n01'; managementIp = '10.0.0.99' }, [ordered]@{ name = 'azl-iic-n02'; managementIp = '10.0.0.12' })
            intents = @([ordered]@{ name = 'Mgmt_Compute'; traffic = @('management', 'compute', 'storage'); adapters = @('NIC1', 'NIC2') })
            volumes = @([ordered]@{ name = 'csv-iic-azlocal-01-vmstore-01'; sizeGiB = 2000; resiliency = 'two-way' })
        }
        $path = Join-Path $TestDrive 'design-snapshot.json'
        $d | ConvertTo-Json -Depth 10 | Set-Content $path
        $r = Compare-RangerDesign -Manifest $m -DesignPath $path
        $row = { param($area, $key) $r.findings | Where-Object { $_.area -eq $area -and $_.key -eq $key } | Select-Object -First 1 }
        (& $row 'cluster' 'release').status | Should -Be 'match'
        (& $row 'cluster' 'sbeVersion').status | Should -Be 'drift'
        (& $row 'identity' 'model').severity | Should -Be 'error'
        (& $row 'witness' 'type').severity | Should -Be 'error'
        (& $row 'nodes' 'azl-iic-n01.managementIp').status | Should -Be 'drift'
        (& $row 'nodes' 'azl-iic-n02.managementIp').status | Should -Be 'match'
        (& $row 'intents' 'Mgmt_Compute.traffic').severity | Should -Be 'error'
        (& $row 'intents' 'Mgmt_Compute.adapters').status | Should -Be 'match'
        (& $row 'volumes' 'csv-iic-azlocal-01-vmstore-01.resiliency').severity | Should -Be 'error'
        (& $row 'volumes' 'Infrastructure_1').severity | Should -Be 'info'
    }

    It 'Trailwright infrastructure.yml: a release train matches the 12.<train> build' {
        $m = script:New-RealShapeManifest
        $r = Compare-RangerDesign -Manifest $m -DesignPath $script:infraPath
        ($r.findings | Where-Object { $_.area -eq 'cluster' -and $_.key -eq 'release' }).status | Should -Be 'match'
        ($r.findings | Where-Object { $_.area -eq 'azure' -and $_.key -eq 'resourceGroup' }).status | Should -Be 'match'
        ($r.findings | Where-Object { $_.area -eq 'nodes' -and $_.key -eq 'azl-iic-n03' }).status | Should -Be 'missing'
    }

    It 'writes design-comparison.json and a self-contained html section' {
        $out = Join-Path $TestDrive 'compare-out'
        $null = Compare-RangerDesign -ManifestPath $script:manifestPath -DesignPath $script:envPath -OutputPath $out
        (Get-Content (Join-Path $out 'design-comparison.json') -Raw | ConvertFrom-Json).schema | Should -Be 'design-comparison.v1'
        (Get-Content (Join-Path $out 'design-comparison.html') -Raw) | Should -Match '<h2>Design vs as-built</h2>'
    }

    It 'adds a Design vs as-built section to the reports and survives redaction' {
        $out = Join-Path $TestDrive 'compare-report'
        Export-AzureLocalRangerReport -ManifestPath $script:manifestPath -OutputPath $out -Formats @('markdown') -DesignPath $script:envPath | Out-Null
        $md = Get-ChildItem (Join-Path $out 'reports') -Filter '*Technical*.md' | Select-Object -First 1
        (Get-Content $md.FullName -Raw) | Should -Match 'Design vs as-built'

        $red = Join-Path $TestDrive 'compare-report-redacted'
        Export-AzureLocalRangerReport -ManifestPath $script:manifestPath -OutputPath $red -Formats @('markdown') -DesignPath $script:envPath -Redact | Out-Null
        $text = (Get-ChildItem $red -Recurse -File -Include *.md, *.json | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"
        $text | Should -Match 'Design vs as-built'
        $text | Should -Not -Match 'azl-iic-n0'
        $text | Should -Not -Match '33333333-3333-3333-3333-333333333333'
    }

    It 'is exported by the module and documented in the manifest' {
        (Get-Command Compare-RangerDesign).Source | Should -Be 'AzureLocalRanger'
        (Get-Command ConvertTo-RangerAsBuiltSnapshot).Source | Should -Be 'AzureLocalRanger'
        (Test-ModuleManifest (Join-Path $script:repoRoot 'AzureLocalRanger.psd1')).ExportedFunctions.Keys | Should -Contain 'Compare-RangerDesign'
    }
}
