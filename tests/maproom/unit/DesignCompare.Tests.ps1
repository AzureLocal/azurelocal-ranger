BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
    $script:fixtureRoot = Join-Path $script:repoRoot 'tests\maproom\Fixtures'
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
    $script:manifestPath = Join-Path $script:fixtureRoot 'synthetic-manifest.json'
    $script:envPath = Join-Path $script:fixtureRoot 'design\environment.example.yml'
    $script:infraPath = Join-Path $script:fixtureRoot 'design\infrastructure.example.yml'
    $script:ztpPath = Join-Path $script:fixtureRoot 'design\infrastructure.ztp.example.yml'
    $script:twPath = Join-Path $script:fixtureRoot 'design\infrastructure.trailwright-export.yml'
    $script:infraV4Path = Join-Path $script:fixtureRoot 'design\infrastructure.schema4.example.yml'
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

    It 'still reads a Trailwright infrastructure.yml of schema 4 (one-release reader, with a warning)' {
        $d = InModuleScope AzureLocalRanger -Parameters @{ p = $script:infraV4Path } { param($p) ConvertFrom-RangerDesignRecord -Path $p -WarningAction SilentlyContinue }
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

    It 'Trailwright schema 4 infrastructure.yml: a release train matches the 12.<train> build' {
        $m = script:New-RealShapeManifest
        $r = Compare-RangerDesign -Manifest $m -DesignPath $script:infraV4Path
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

Describe 'infrastructure.yml (schema 5) as the design record' {
    It 'reads cluster, release, identity, witness, nodes, serials, BMC, Azure scope, VLANs, intents, DNS, volumes and SDN from the registry example' {
        $d = InModuleScope AzureLocalRanger -Parameters @{ p = $script:infraPath } { param($p) ConvertFrom-RangerDesignRecord -Path $p }
        $d._kind | Should -Be 'infrastructure'
        $d.cluster.name | Should -Be 'iic-azl-01'
        $d.cluster.release | Should -Be '12.2611.1004.9'
        $d.azure.resourceGroup | Should -Be 'rg-iic-azl-01'
        $d.azure.subscriptionId | Should -Be '00000000-0000-0000-0000-000000000000'
        $d.identity.model | Should -Be 'active-directory'
        $d.identity.domain | Should -Be 'improbability.cloud'
        $d.witness.type | Should -Be 'cloud'
        @($d.nodes).Count | Should -Be 2
        $n1 = $d.nodes | Where-Object name -eq 'iic-azl-n01'
        $n1.serial | Should -Be 'SERIAL01'
        $n1.managementIp | Should -Be '192.0.2.11'
        $n1.bmcIp | Should -Be '198.51.100.11'
        $n1.bmcType | Should -Be 'idrac'
        @($d.vlans | ForEach-Object { $_.id }) | Should -Contain 711
        @($d.vlans | ForEach-Object { $_.id }) | Should -Contain 2204
        $storage = $d.intents | Where-Object name -eq 'compute_storage'
        $storage.traffic | Should -Be @('compute', 'storage')
        $storage.adapters | Should -Be @('Port3', 'Port4')
        $d.dnsServers | Should -Be @('192.0.2.4', '192.0.2.5')
        $v = $d.volumes | Where-Object name -eq 'vol-workloads-01'
        $v.sizeGiB | Should -Be 4096
        $v.resiliency | Should -Be 'two-way'
        $d.sdn.enabled | Should -BeFalse
        ($d.sdn.logicalNetworks | Where-Object name -eq 'lnet-workloads').vlan | Should -Be 2204
    }

    It 'maps every registry resiliency value, and never leaves a written value null' {
        InModuleScope AzureLocalRanger {
            ConvertTo-RangerResiliencyName 'two_way' | Should -Be 'two-way'
            ConvertTo-RangerResiliencyName 'three_way' | Should -Be 'three-way'
            ConvertTo-RangerResiliencyName 'four_way' | Should -Be 'four-way'
            ConvertTo-RangerResiliencyName 'nested_two_way' | Should -Be 'nested-two-way'
            ConvertTo-RangerResiliencyName 'parity' | Should -Be 'parity'
            ConvertTo-RangerResiliencyName 'two-way-mirror' | Should -Be 'two-way'
            ConvertTo-RangerResiliencyName 'mirror_accelerated_parity' | Should -Be 'mirror-accelerated-parity'
            ConvertTo-RangerResiliencyName 'nested_mirror_accelerated_parity' | Should -Be 'nested-mirror-accelerated-parity'
            ConvertTo-RangerResiliencyName $null | Should -BeNullOrEmpty
        }
    }

    It 'reads the management address of a 5.2+ file from the management network adapter, and the BMC of a ZTP-scope file' {
        $d = InModuleScope AzureLocalRanger -Parameters @{ p = $script:ztpPath } { param($p) ConvertFrom-RangerDesignRecord -Path $p }
        $d._kind | Should -Be 'infrastructure'
        $d.cluster.release | Should -Be '12.2611.1004.9'
        $n2 = $d.nodes | Where-Object name -eq 'iic-azl-n02'
        $n2.managementIp | Should -Be '192.0.2.12'
        $n2.serial | Should -Be 'SERIAL02'
        $n2.bmcIp | Should -Be '198.51.100.12'
        $d.dnsServers | Should -Be @('192.0.2.30', '192.0.2.31')
    }

    It 'reads a Trailwright schema 5 export: local identity, no witness, three-way volumes (resiliency is never null)' {
        $d = InModuleScope AzureLocalRanger -Parameters @{ p = $script:twPath } { param($p) ConvertFrom-RangerDesignRecord -Path $p }
        $d.identity.model | Should -Be 'local-identity-key-vault'
        $d.identity.domain | Should -BeNullOrEmpty
        $d.witness.type | Should -Be 'none'
        @($d.nodes).Count | Should -Be 3
        @($d.volumes).Count | Should -Be 3
        foreach ($v in $d.volumes) { $v.resiliency | Should -Be 'three-way' }
    }

    It 'compares the registry example with itself: every row matches and the rows cover cluster, release, identity, witness, nodes, serial, BMC and Azure scope' {
        $snap = InModuleScope AzureLocalRanger -Parameters @{ p = $script:infraPath } { param($p) ConvertFrom-RangerDesignRecord -Path $p }
        $r = Compare-RangerDesign -Snapshot $snap -DesignPath $script:infraPath
        $r.designKind | Should -Be 'infrastructure'
        $r.summary.comparable | Should -BeTrue
        $r.summary.drift | Should -Be 0
        $r.summary.missing | Should -Be 0
        $r.summary.errors | Should -Be 0
        $row = { param($area, $key) $r.findings | Where-Object { $_.area -eq $area -and $_.key -eq $key } | Select-Object -First 1 }
        (& $row 'cluster' 'name').status | Should -Be 'match'
        (& $row 'cluster' 'release').status | Should -Be 'match'
        (& $row 'identity' 'model').status | Should -Be 'match'
        (& $row 'identity' 'domain').status | Should -Be 'match'
        (& $row 'witness' 'type').status | Should -Be 'match'
        (& $row 'nodes' 'iic-azl-n01').status | Should -Be 'match'
        (& $row 'nodes' 'iic-azl-n01.serial').status | Should -Be 'match'
        (& $row 'nodes' 'iic-azl-n01.bmcIp').status | Should -Be 'match'
        (& $row 'nodes' 'iic-azl-n01.bmcType').status | Should -Be 'match'
        (& $row 'nodes' 'iic-azl-n01.managementIp').status | Should -Be 'match'
        (& $row 'azure' 'subscriptionId').status | Should -Be 'match'
        (& $row 'azure' 'resourceGroup').status | Should -Be 'match'
        (& $row 'volumes' 'vol-workloads-01.resiliency').status | Should -Be 'match'
        (& $row 'volumes' 'vol-workloads-01.resiliency').design | Should -Be 'two-way'
    }

    It 'compares the registry example with the Ranger manifest: the build is another instance, so cluster, nodes and Azure scope show as drift or missing' {
        $r = Compare-RangerDesign -ManifestPath $script:manifestPath -DesignPath $script:infraPath
        $row = { param($area, $key) $r.findings | Where-Object { $_.area -eq $area -and $_.key -eq $key } | Select-Object -First 1 }
        (& $row 'cluster' 'name').status | Should -Be 'drift'
        (& $row 'cluster' 'release').status | Should -Be 'not-captured'
        (& $row 'identity' 'model').status | Should -Be 'match'
        (& $row 'witness' 'type').status | Should -Be 'match'
        (& $row 'nodes' 'iic-azl-n01').status | Should -Be 'missing'
        (& $row 'azure' 'subscriptionId').status | Should -Be 'drift'
        (& $row 'azure' 'subscriptionId').severity | Should -Be 'error'
        $r.summary.errors | Should -BeGreaterThan 0
    }

    It 'matches a node set, release and serials against a real-shaped manifest when the design names the same machines' {
        $m = script:New-RealShapeManifest
        $design = [ordered]@{
            _metadata    = [ordered]@{ schema_version = '5.6.0' }
            scenario     = [ordered]@{ identity = 'local_identity' }
            cluster      = [ordered]@{ name = 'azlocal-iic-01'; witness = [ordered]@{ type = 'cloud' } }
            provisioning = [ordered]@{ os_version = '12.2609.1003.7' }
            nodes        = @(
                [ordered]@{ name = 'azl-iic-n01'; serial_number = 'ABC1234'; management = [ordered]@{ ip_address = '10.0.0.11' }; bmc = [ordered]@{ type = 'idrac' } },
                [ordered]@{ name = 'azl-iic-n02'; serial_number = 'SER-0002'; management = [ordered]@{ ip_address = '10.0.0.12' }; bmc = [ordered]@{ type = 'ilo' } }
            )
            storage      = [ordered]@{ volumes = @([ordered]@{ name = 'csv-iic-azlocal-01-vmstore-01'; size_gib = 2000; resiliency = 'three_way' }) }
        }
        $p = Join-Path $TestDrive 'design-v5.json'
        $design | ConvertTo-Json -Depth 10 | Set-Content $p
        $r = Compare-RangerDesign -Manifest $m -DesignPath $p
        $row = { param($area, $key) $r.findings | Where-Object { $_.area -eq $area -and $_.key -eq $key } | Select-Object -First 1 }
        (& $row 'cluster' 'name').status | Should -Be 'match'
        (& $row 'cluster' 'release').status | Should -Be 'match'
        (& $row 'identity' 'model').status | Should -Be 'match'
        (& $row 'nodes' 'azl-iic-n01.serial').status | Should -Be 'match'
        (& $row 'nodes' 'azl-iic-n01.managementIp').status | Should -Be 'match'
        (& $row 'nodes' 'azl-iic-n01.bmcType').status | Should -Be 'match'
        (& $row 'nodes' 'azl-iic-n02.bmcType').status | Should -Be 'match'
        (& $row 'volumes' 'csv-iic-azlocal-01-vmstore-01.resiliency').status | Should -Be 'match'
    }

    It 'says not comparable when the design record holds no section Ranger compares' {
        $p = Join-Path $TestDrive 'stub-v5.json'
        '{ "_metadata": { "schema_version": "5.6.0", "scope": "other" }, "scenario": { "os_install": "simplified" }, "tags": { "Owner": "x" } }' | Set-Content $p
        $r = Compare-RangerDesign -ManifestPath $script:manifestPath -DesignPath $p
        $r.summary.comparable | Should -BeFalse
        $r.summary.notComparable | Should -Be 1
        $r.summary.coveragePercent | Should -Be 0
        @($r.findings).Count | Should -Be 1
        $r.findings[0].status | Should -Be 'not-comparable'
        $r.findings[0].severity | Should -Be 'warning'
        $html = InModuleScope AzureLocalRanger -Parameters @{ r = $r } { param($r) New-RangerDesignComparisonHtml -Comparison $r }
        $html | Should -Match '1 not comparable'
    }

    It 'warns that the retired environment file and the schema 4 export have a one-release reader' {
        $w1 = InModuleScope AzureLocalRanger -Parameters @{ p = $script:envPath } { param($p) $null = ConvertFrom-RangerDesignRecord -Path $p; $null } 3>&1 | Out-String
        $w1 | Should -Match 'environment.yml'
        $w2 = InModuleScope AzureLocalRanger -Parameters @{ p = $script:infraV4Path } { param($p) $null = ConvertFrom-RangerDesignRecord -Path $p; $null } 3>&1 | Out-String
        $w2 | Should -Match 'schema 4'
    }
}
