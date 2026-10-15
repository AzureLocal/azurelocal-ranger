# Design versus as-built comparison (v2.7.0).
#
#   ConvertTo-RangerAsBuiltSnapshot  manifest  -> 'as-built-snapshot.v1' (also Export-AzureLocalRangerReport -Formats as-built-snapshot)
#   ConvertFrom-RangerDesignRecord   design    -> the same canonical shape (environment file, Trailwright infrastructure.yml or a snapshot)
#   Compare-RangerDesign             both      -> findings table (match / drift / missing / extra / not-captured) with severity and Learn links
#
# The as-built-snapshot.v1 core (schema, capturedAt, source, cluster.name/release, identity, witness, nodes, vlans,
# intents, volumes, dnsServers) is the contract Azure Local Trailwright's As-built compare reads; the additional
# optional fields (cluster.sbeVersion, azure, sdn, nodes[].bmcType, intents[].qos/jumbo/rdma ...) are ignored by
# readers that do not know them. The field-path mapping is documented in docs/reference/design-vs-as-built.md.

$script:RangerDesignLearn = [ordered]@{
    release  = 'https://learn.microsoft.com/azure/azure-local/release-information-23h2'
    identity = 'https://learn.microsoft.com/azure/azure-local/deploy/deployment-local-identity-with-key-vault'
    witness  = 'https://learn.microsoft.com/azure/azure-local/manage/witness'
    volumes  = 'https://learn.microsoft.com/azure/azure-local/concepts/fault-tolerance'
    intents  = 'https://learn.microsoft.com/azure/azure-local/concepts/network-atc-overview'
    network  = 'https://learn.microsoft.com/azure/azure-local/concepts/host-network-requirements'
    sbe      = 'https://learn.microsoft.com/azure/azure-local/update/solution-builder-extension'
    rack     = 'https://learn.microsoft.com/azure/azure-local/concepts/rack-aware-cluster-reference-architecture'
}

function Get-RangerNested {
    # Null-safe nested lookup: Get-RangerNested $obj 'a','b' returns $obj['a']['b'] or $null.
    param($Object, [string[]]$Path)
    $cur = $Object
    foreach ($p in $Path) {
        if ($cur -is [System.Collections.IDictionary] -and $cur.Contains($p)) { $cur = $cur[$p] } else { return $null }
    }
    return $cur
}

function Get-RangerShortName {
    param([AllowNull()][string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return '' }
    return ($Name.Trim().Split('.')[0]).ToLowerInvariant()
}

function Get-RangerFirstValue {
    param([object[]]$Candidates)
    foreach ($c in $Candidates) {
        if ($null -ne $c -and -not ($c -is [string] -and [string]::IsNullOrWhiteSpace($c))) { return $c }
    }
    return $null
}

function Get-RangerPerNodeCollection {
    # domains.networking.nodes[] keeps per-node data; the flattened collections lose the node name in real runs.
    param([System.Collections.IDictionary]$Manifest, [string]$Name)
    $result = New-Object System.Collections.Generic.List[object]
    $perNode = @($Manifest.domains.networking.nodes | Where-Object { $_ })
    foreach ($n in $perNode) {
        $nodeName = [string](Get-RangerObjectValue -InputObject $n -CandidateNames @('node', 'Node', 'name'))
        foreach ($item in @(Get-RangerObjectValue -InputObject $n -CandidateNames @($Name))) {
            if ($null -ne $item) { $result.Add([pscustomobject]@{ node = $nodeName; item = $item }) }
        }
    }
    if ($result.Count -eq 0) {
        $net = $Manifest.domains.networking
        $flat = if ($net -is [System.Collections.IDictionary] -and $net.Contains($Name)) { $net[$Name] } else { @() }
        foreach ($item in @($flat | Where-Object { $_ })) {
            $result.Add([pscustomobject]@{ node = [string](Get-RangerObjectValue -InputObject $item -CandidateNames @('node', 'Node')); item = $item })
        }
    }
    return $result.ToArray()
}

function Get-RangerSnapshotNodes {
    param([System.Collections.IDictionary]$Manifest)
    $nodes = @($Manifest.domains.clusterNode.nodes | Where-Object { $_ })
    $hw = @($Manifest.domains.hardware.nodes | Where-Object { $_ })
    $oem = @($Manifest.domains.oemIntegration.managementPosture | Where-Object { $_ })
    $endpoints = @($Manifest.domains.oemIntegration.endpoints | Where-Object { $_ })
    $vnics = @(Get-RangerPerNodeCollection -Manifest $Manifest -Name 'hostVirtualNics')
    $ips = @(Get-RangerPerNodeCollection -Manifest $Manifest -Name 'ipAddresses')

    $out = foreach ($n in $nodes) {
        $name = [string](Get-RangerObjectValue -InputObject $n -CandidateNames @('name', 'Name'))
        $short = Get-RangerShortName $name
        $h = $hw | Where-Object { (Get-RangerShortName ([string](Get-RangerObjectValue -InputObject $_ -CandidateNames @('node', 'name')))) -eq $short } | Select-Object -First 1
        $o = $oem | Where-Object { (Get-RangerShortName ([string](Get-RangerObjectValue -InputObject $_ -CandidateNames @('node')))) -eq $short } | Select-Object -First 1
        $e = $endpoints | Where-Object { (Get-RangerShortName ([string](Get-RangerObjectValue -InputObject $_ -CandidateNames @('node')))) -eq $short } | Select-Object -First 1

        $row = [ordered]@{ name = $name }
        $serial = Get-RangerFirstValue @((Get-RangerObjectValue -InputObject $h -CandidateNames @('serialNumber', 'SerialNumber')), (Get-RangerObjectValue -InputObject $h -CandidateNames @('serviceTag', 'ServiceTag')))
        if ($serial) { $row['serial'] = [string]$serial }

        # Management IP: management host vNIC, else an address on an adapter alias that says management.
        $mine = @($vnics | Where-Object { (Get-RangerShortName $_.node) -eq $short })
        $mgmt = $mine | Where-Object { [bool](Get-RangerObjectValue -InputObject $_.item -CandidateNames @('isManagementNic')) -or ([string](Get-RangerObjectValue -InputObject $_.item -CandidateNames @('name')) -match '(?i)manage|mgmt') } | Select-Object -First 1
        $mgmtIp = if ($mgmt) { [string](Get-RangerObjectValue -InputObject $mgmt.item -CandidateNames @('ipAddress')) } else { '' }
        if (-not $mgmtIp) {
            $m2 = @($ips | Where-Object { (Get-RangerShortName $_.node) -eq $short -and ([string](Get-RangerObjectValue -InputObject $_.item -CandidateNames @('InterfaceAlias')) -match '(?i)manage|mgmt') }) | Select-Object -First 1
            if ($m2) { $mgmtIp = [string](Get-RangerObjectValue -InputObject $m2.item -CandidateNames @('IPAddress')) }
        }
        if ($mgmtIp) { $row['managementIp'] = $mgmtIp }
        $storage = @($mine | Where-Object { [string](Get-RangerObjectValue -InputObject $_.item -CandidateNames @('name')) -match '(?i)smb|storage' } | ForEach-Object { [string](Get-RangerObjectValue -InputObject $_.item -CandidateNames @('ipAddress')) } | Where-Object { $_ })
        if ($storage.Count -eq 0) {
            $storage = @($ips | Where-Object { (Get-RangerShortName $_.node) -eq $short -and ([string](Get-RangerObjectValue -InputObject $_.item -CandidateNames @('InterfaceAlias')) -match '(?i)smb|storage') } | ForEach-Object { [string](Get-RangerObjectValue -InputObject $_.item -CandidateNames @('IPAddress')) } | Where-Object { $_ })
        }
        if ($storage.Count -gt 0) { $row['storageIps'] = @($storage | Select-Object -Unique) }

        $manager = [string](Get-RangerObjectValue -InputObject $o -CandidateNames @('managerModel', 'managerType'))
        $maker = [string](Get-RangerObjectValue -InputObject $h -CandidateNames @('manufacturer'))
        $bmcType = if ($manager -match '(?i)idrac') { 'idrac' } elseif ($manager -match '(?i)\bilo') { 'ilo' } elseif ($manager -match '(?i)xclarity|xcc') { 'xclarity' } elseif ($maker -match '(?i)dell') { 'idrac' } elseif ($maker -match '(?i)hpe|hewlett') { 'ilo' } elseif ($maker -match '(?i)lenovo') { 'xclarity' } elseif ($manager) { $manager.ToLowerInvariant() } else { $null }
        if ($bmcType) { $row['bmcType'] = $bmcType }
        $bmcIp = Get-RangerFirstValue @((Get-RangerObjectValue -InputObject $e -CandidateNames @('ip')), (Get-RangerObjectValue -InputObject $h -CandidateNames @('ipmiAddress', 'bmcAddress')))
        if ($bmcIp -and "$bmcIp" -match '^\d+\.\d+\.\d+\.\d+$') { $row['bmcIp'] = [string]$bmcIp }
        $row
    }
    return @($out)
}

function ConvertTo-RangerAsBuiltSnapshot {
    <#
    .SYNOPSIS
        Exports a Ranger manifest as an 'as-built-snapshot.v1' document (read-only, no cluster or Azure access).
    .DESCRIPTION
        Core fields follow the contract documented by Azure Local Trailwright (docs/AS-BUILT.md); optional extra
        fields carry the SBE version, BMC type, QoS / jumbo / RDMA per intent, SDN and the subscription / resource
        group. Sections the manifest cannot support are left out and read as 'not captured' by the comparison.
    .PARAMETER Manifest
        A Ranger manifest (ordered dictionary or hashtable).
    .PARAMETER Release
        The deployed release build (for example 12.2609.1003.7) when the manifest does not carry it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Manifest,
        [string]$Release
    )

    $d = $Manifest.domains
    $snap = [ordered]@{
        schema     = 'as-built-snapshot.v1'
        capturedAt = $($stamp = Get-RangerFirstValue @($Manifest.run.endTimeUtc, $Manifest.run.startTimeUtc); if ($stamp -is [datetime]) { $stamp.ToUniversalTime().ToString('o') } else { [string]$stamp })
        source     = [ordered]@{ tool = 'ranger'; version = [string]$Manifest.run.toolVersion; note = "manifest schema $($Manifest.run.schemaVersion)" }
    }

    # cluster
    $env = $d.clusterNode.updatePosture.solutionUpdateEnv
    $cluster = [ordered]@{}
    $clusterName = Get-RangerFirstValue @($d.clusterNode.cluster.name, $Manifest.target.clusterName)
    if ($clusterName) { $cluster['name'] = [string]$clusterName }
    $rel = Get-RangerFirstValue @($Release, (Get-RangerObjectValue -InputObject $env -CandidateNames @('currentVersion', 'CurrentVersion', 'version', 'Version')))
    if ($rel -and "$rel" -match '^\d+\.\d+\.\d+\.\d+$') { $cluster['release'] = [string]$rel }
    $sbe = Get-RangerFirstValue @($d.clusterNode.solutionUpdateDetail.currentSbeVersion, (Get-RangerObjectValue -InputObject $env -CandidateNames @('currentSbeVersion', 'CurrentSbeVersion', 'sbeVersion', 'SbeVersion')))
    if ($sbe) { $cluster['sbeVersion'] = [string]$sbe }
    if ($d.clusterNode.cluster.currentBuild) { $cluster['osBuild'] = [string]$d.clusterNode.cluster.currentBuild }
    if ($cluster.Count) { $snap['cluster'] = $cluster }

    # azure scope
    $az = [ordered]@{}
    $sub = Get-RangerFirstValue @($Manifest.target.subscriptionId, $d.azureIntegration.context.subscriptionId)
    $rg = Get-RangerFirstValue @($Manifest.target.resourceGroup, $d.azureIntegration.context.resourceGroup)
    if ($sub) { $az['subscriptionId'] = [string]$sub }
    if ($rg) { $az['resourceGroup'] = [string]$rg }
    if ($az.Count) { $snap['azure'] = $az }

    # identity (topology.identityMode is 'ad' or 'local-key-vault')
    $mode = Get-RangerFirstValue @($Manifest.topology.identityMode, $d.clusterNode.cluster.operatingModel.identityMode, $d.identitySecurity.localIdentity.identityMode)
    if ($mode) {
        $model = switch -Regex ([string]$mode) { '^(local-key-vault|local-identity)' { 'local-identity-key-vault' } '^(ad|active-directory)$' { 'active-directory' } default { $null } }
        if ($model) {
            $snap['identity'] = [ordered]@{ model = $model }
            if ($d.clusterNode.cluster.domain -and $model -eq 'active-directory') { $snap['identity']['domain'] = [string]$d.clusterNode.cluster.domain }
        }
    }

    # witness
    $q = $d.clusterNode.quorum
    if ($q) {
        $wt = [string](Get-RangerFirstValue @((Get-RangerObjectValue -InputObject $q.witnessDetail -CandidateNames @('type')), (Get-RangerObjectValue -InputObject $q -CandidateNames @('type', 'quorumType'))))
        if ($wt) { $snap['witness'] = [ordered]@{ type = $(if ($wt -match 'Cloud') { 'cloud' } elseif ($wt -match 'FileShare|File Share') { 'file-share' } else { 'none' }) } }
    }

    $nodes = @(Get-RangerSnapshotNodes -Manifest $Manifest)
    if ($nodes.Count) { $snap['nodes'] = $nodes }

    # VLANs: management OS virtual adapters (AccessVlanId); host vNIC VLANs as fallback
    $vlanItems = @(Get-RangerPerNodeCollection -Manifest $Manifest -Name 'vlan')
    $vlanIds = @($vlanItems | ForEach-Object { Get-RangerObjectValue -InputObject $_.item -CandidateNames @('AccessVlanId', 'accessVlanId') } | Where-Object { $null -ne $_ -and [int]$_ -gt 0 } | ForEach-Object { [int]$_ })
    if ($vlanIds.Count -eq 0) { $vlanIds = @(@($d.networking.hostVirtualNics | ForEach-Object { Get-RangerObjectValue -InputObject $_ -CandidateNames @('vlanId', 'VlanId') }) | Where-Object { $null -ne $_ -and [int]$_ -gt 0 } | ForEach-Object { [int]$_ }) }
    $vlanIds = @($vlanIds | Sort-Object -Unique)
    if ($vlanIds.Count) { $snap['vlans'] = @($vlanIds | ForEach-Object { [ordered]@{ id = $_ } }) }

    # intents (+ QoS / jumbo / RDMA)
    $intentItems = @(Get-RangerPerNodeCollection -Manifest $Manifest -Name 'intents')
    $overrideItems = @(Get-RangerPerNodeCollection -Manifest $Manifest -Name 'intentOverrides')
    if ($d.networking.intentOverrides -and $overrideItems.Count -eq 0) { $overrideItems = @(@($d.networking.intentOverrides) | ForEach-Object { foreach ($i in @(Get-RangerObjectValue -InputObject $_ -CandidateNames @('intentOverrides'))) { [pscustomobject]@{ node = ''; item = $i } } }) }
    $adapters = @($d.networking.adapters | Where-Object { $_ })
    if ($adapters.Count -eq 0) { $adapters = @(Get-RangerPerNodeCollection -Manifest $Manifest -Name 'adapters' | ForEach-Object { $_.item }) }
    $trafficClasses = @(Get-RangerPerNodeCollection -Manifest $Manifest -Name 'dcb' | ForEach-Object { Get-RangerObjectValue -InputObject $_.item -CandidateNames @('trafficClasses') } | Where-Object { $_ })
    if ($trafficClasses.Count -eq 0) { $trafficClasses = @(@($d.networking.dcb) | ForEach-Object { Get-RangerObjectValue -InputObject (Get-RangerObjectValue -InputObject $_ -CandidateNames @('dcb')) -CandidateNames @('trafficClasses') } | Where-Object { $_ }) }
    $seen = @{}
    $intents = foreach ($entry in $intentItems) {
        $i = $entry.item
        $iname = [string](Get-RangerFirstValue @((Get-RangerObjectValue -InputObject $i -CandidateNames @('name', 'Name'))))
        if (-not $iname -or $seen.ContainsKey($iname.ToLowerInvariant())) { continue }
        $seen[$iname.ToLowerInvariant()] = $true
        $ov = @($overrideItems | Where-Object { [string](Get-RangerObjectValue -InputObject $_.item -CandidateNames @('name')) -eq $iname } | Select-Object -First 1)
        $traffic = @()
        $tt = Get-RangerObjectValue -InputObject $i -CandidateNames @('trafficType', 'trafficTypes')
        if ($tt) { $traffic = @($tt | ForEach-Object { ([string]$_).ToLowerInvariant() }) }
        else {
            $isStorage = [bool](Get-RangerObjectValue -InputObject $i -CandidateNames @('IsStorageIntent', 'isStorageIntent'))
            $isCompute = [bool](Get-RangerObjectValue -InputObject $i -CandidateNames @('IsComputeIntent', 'isComputeIntent'))
            $isMgmt = [bool](Get-RangerObjectValue -InputObject $i -CandidateNames @('IsManagementIntent', 'isManagementIntent'))
            if ($ov.Count -and $ov[0]) { $isMgmt = $isMgmt -or [bool](Get-RangerObjectValue -InputObject $ov[0].item -CandidateNames @('isManagementIntent')) }
            if ($isMgmt -or $iname -match '(?i)manage') { $traffic += 'management' }
            if ($isCompute) { $traffic += 'compute' }
            if ($isStorage) { $traffic += 'storage' }
        }
        $names = @()
        if ($ov.Count -and $ov[0]) { $names = @(Get-RangerObjectValue -InputObject $ov[0].item -CandidateNames @('adapters') | Where-Object { $_ }) }
        if ($names.Count -eq 0) { $names = @(Get-RangerObjectValue -InputObject $i -CandidateNames @('adapter', 'adapters') | Where-Object { $_ }) }
        $row = [ordered]@{ name = $iname; traffic = @($traffic | Select-Object -Unique); adapters = @($names) }
        $mine = @($adapters | Where-Object { [string](Get-RangerObjectValue -InputObject $_ -CandidateNames @('name')) -in $names -or [string](Get-RangerObjectValue -InputObject $_ -CandidateNames @('interfaceDescription')) -in $names })
        $mtus = @($mine | ForEach-Object { Get-RangerObjectValue -InputObject $_ -CandidateNames @('mtuSize', 'MtuSize') } | Where-Object { $_ } | ForEach-Object { [int]$_ })
        if ($mtus.Count) { $row['jumbo'] = [int](($mtus | Measure-Object -Minimum).Minimum) }
        $rdma = @($mine | ForEach-Object { Get-RangerObjectValue -InputObject $_ -CandidateNames @('rdmaCapable', 'rdmaEnabled') } | Where-Object { $null -ne $_ })
        if ($rdma.Count) { $row['rdma'] = [bool]($rdma -contains $true) }
        if ('storage' -in $traffic -and $trafficClasses.Count) {
            $smb = @($trafficClasses | Where-Object { [string](Get-RangerObjectValue -InputObject $_ -CandidateNames @('Name', 'name')) -match '(?i)smb|storage|cluster' } | Select-Object -First 1)
            if ($smb.Count -and $smb[0]) { $row['qos'] = [ordered]@{ priority = Get-RangerObjectValue -InputObject $smb[0] -CandidateNames @('Priority', 'priority'); bandwidthPercent = Get-RangerObjectValue -InputObject $smb[0] -CandidateNames @('BandwidthPercentage', 'bandwidthPercentage') } }
        }
        $row
    }
    $intents = @($intents)
    if ($intents.Count) { $snap['intents'] = $intents }

    # DNS
    $dns = @($d.networking.dns | ForEach-Object { Get-RangerObjectValue -InputObject $_ -CandidateNames @('ServerAddresses', 'serverAddresses', 'server') } | ForEach-Object { $_ } | Where-Object { $_ } | Select-Object -Unique)
    if ($dns.Count) { $snap['dnsServers'] = @($dns | ForEach-Object { [string]$_ }) }

    # volumes: virtualDisks (real collector: friendlyName, resiliencySettingName + numberOfDataCopies, sizeGiB; older shape: resiliencyName, size in bytes)
    $vds = @($d.storage.virtualDisks | Where-Object { $_ })
    if ($vds.Count) {
        $count = @($d.clusterNode.nodes | Where-Object { $_ }).Count
        $snap['volumes'] = @($vds | ForEach-Object {
                $v = $_
                $resName = [string](Get-RangerFirstValue @((Get-RangerObjectValue -InputObject $v -CandidateNames @('resiliencySettingName')), (Get-RangerObjectValue -InputObject $v -CandidateNames @('resiliencyName'))))
                $copies = Get-RangerObjectValue -InputObject $v -CandidateNames @('numberOfDataCopies', 'NumberOfDataCopies')
                $res = switch -Regex ($resName) {
                    'Parity' { 'parity' }
                    'Mirror' { if ($null -eq $copies) { $null } else { switch ([int]$copies) { 2 { 'two-way' } 3 { 'three-way' } 4 { if ($count -eq 2) { 'nested-two-way' } else { 'four-way' } } default { $null } } } }
                    default { $null }
                }
                $o = [ordered]@{ name = [string](Get-RangerObjectValue -InputObject $v -CandidateNames @('friendlyName', 'FriendlyName', 'name')) }
                $size = Get-RangerFirstValue @((Get-RangerObjectValue -InputObject $v -CandidateNames @('sizeGiB')), $(if (Get-RangerObjectValue -InputObject $v -CandidateNames @('size', 'Size')) { [math]::Round([double](Get-RangerObjectValue -InputObject $v -CandidateNames @('size', 'Size')) / 1GB, 2) }))
                if ($null -ne $size) { $o['sizeGiB'] = [double]$size }
                if ($res) { $o['resiliency'] = $res }
                $o
            })
    }

    # SDN (Network Controller deployed flag, Arc logical networks)
    $sdnDeployed = @($d.networking.sdn | ForEach-Object { Get-RangerObjectValue -InputObject (Get-RangerObjectValue -InputObject $_ -CandidateNames @('sdn')) -CandidateNames @('deployed') } | Where-Object { $null -ne $_ })
    $lnets = @($d.networking.logicalNetworks | Where-Object { $_ })
    if ($sdnDeployed.Count -or $lnets.Count) {
        $sdn = [ordered]@{}
        if ($sdnDeployed.Count) { $sdn['enabled'] = [bool]($sdnDeployed -contains $true) }
        if ($lnets.Count) {
            $sdn['logicalNetworks'] = @($lnets | ForEach-Object {
                    $sub0 = @(Get-RangerObjectValue -InputObject $_ -CandidateNames @('subnets') | Where-Object { $_ } | Select-Object -First 1)
                    $o = [ordered]@{ name = [string](Get-RangerObjectValue -InputObject $_ -CandidateNames @('name')) }
                    if ($sub0.Count -and $sub0[0]) {
                        $vl = Get-RangerObjectValue -InputObject $sub0[0] -CandidateNames @('vlan', 'vlanId'); if ($null -ne $vl) { $o['vlan'] = [int]$vl }
                        $pf = Get-RangerObjectValue -InputObject $sub0[0] -CandidateNames @('addressPrefix'); if ($pf) { $o['subnet'] = [string]$pf }
                    }
                    $o
                })
        }
        $snap['sdn'] = $sdn
    }
    return $snap
}

function Get-RangerDesignRedactionLiterals {
    <# Names and identifiers in a design record that must be redacted together with the manifest (design-only values are not in the manifest). #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Design)
    $lits = New-Object System.Collections.Generic.List[object]
    $add = { param($v, $k) if ($v) { $lits.Add(@{ Value = [string]$v; Kind = $k }) } }
    & $add $Design['cluster']['name'] 'host'
    & $add $Design['azure']['subscriptionId'] 'guid'
    & $add $Design['azure']['resourceGroup'] 'rg'
    & $add $Design['identity']['domain'] 'generic'
    foreach ($n in @($Design['nodes'] | Where-Object { $_ })) {
        & $add $n['name'] $(if ([string]$n['name'] -match '\.') { 'fqdn' } else { 'host' })
        & $add $n['serial'] 'serial'
    }
    foreach ($v in @($Design['volumes'] | Where-Object { $_ })) { & $add $v['name'] 'generic' }
    foreach ($l in @($Design['sdn']['logicalNetworks'] | Where-Object { $_ })) { & $add $l['name'] 'generic' }
    & $add $Design['sdn']['prefix'] 'generic'
    return $lits.ToArray()
}

function ConvertFrom-RangerDesignRecord {
    <#
    .SYNOPSIS
        Reads a design record and returns it in the canonical snapshot shape used by Compare-RangerDesign.
    .PARAMETER Path
        A file (YAML or JSON) or a snapshot JSON.
    .PARAMETER InputObject
        An already parsed dictionary.
    .PARAMETER Kind
        auto (default), environment (deploy automation environment file), infrastructure (Trailwright infrastructure.yml) or snapshot.
    #>
    [CmdletBinding()]
    param(
        [string]$Path,
        $InputObject,
        [ValidateSet('auto', 'environment', 'infrastructure', 'snapshot')][string]$Kind = 'auto'
    )

    if ($Path) {
        $full = Resolve-RangerPath -Path $Path
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Design record not found: $full" }
        $InputObject = if ($full -match '\.(ya?ml)$') { Import-RangerYamlFile -Path $full } else { Get-Content -LiteralPath $full -Raw | ConvertFrom-Json -AsHashtable -Depth 100 }
    }
    if ($null -eq $InputObject) { throw 'Supply -Path or -InputObject.' }
    $r = ConvertTo-RangerHashtable -InputObject $InputObject

    if ($Kind -eq 'auto') {
        $Kind = if ($r['schema'] -eq 'as-built-snapshot.v1') { 'snapshot' }
        elseif ($r.Contains('_metadata') -or $r.Contains('azure_platform') -or $r.Contains('compute')) { 'infrastructure' }
        elseif ($r.Contains('nodes') -or $r.Contains('cluster_name') -or $r.Contains('intents')) { 'environment' }
        else { throw 'Cannot tell the design record kind. Pass -Kind environment, infrastructure or snapshot.' }
    }
    if ($Kind -eq 'snapshot') { $r['_kind'] = 'snapshot'; return $r }

    $idMap = @{ 'local-identity-keyvault' = 'local-identity-key-vault'; 'local-identity-key-vault' = 'local-identity-key-vault'; 'local-identity' = 'local-identity-key-vault'; 'ad-joined' = 'active-directory'; 'active-directory' = 'active-directory'; 'hybrid' = 'active-directory' }
    $resMap = @{ 'two-way-mirror' = 'two-way'; 'three-way-mirror' = 'three-way'; 'nested-two-way-mirror' = 'nested-two-way'; 'two-way' = 'two-way'; 'three-way' = 'three-way'; 'four-way' = 'four-way'; 'four-way-mirror' = 'four-way'; 'parity' = 'parity'; 'nested-two-way' = 'nested-two-way' }
    $witMap = { param($v) $x = ([string]$v).ToLowerInvariant(); if ($x -match 'cloud') { 'cloud' } elseif ($x -match 'file') { 'file-share' } elseif ($x) { 'none' } else { $null } }
    $snap = [ordered]@{ schema = 'as-built-snapshot.v1'; _kind = $Kind }

    if ($Kind -eq 'environment') {
        $cluster = [ordered]@{}
        if ($r['cluster_name']) { $cluster['name'] = [string]$r['cluster_name'] }
        if ($r['release'] -is [System.Collections.IDictionary]) {
            if ((Get-RangerNested $r 'release','azure_local_version')) { $cluster['release'] = [string](Get-RangerNested $r 'release','azure_local_version') }
            $sv = Get-RangerFirstValue @((Get-RangerNested $r 'release','sbe_version'), (Get-RangerNested $r 'sbe','version'))
            if ($sv) { $cluster['sbeVersion'] = [string]$sv }
        }
        elseif ($r['sbe'] -is [System.Collections.IDictionary] -and (Get-RangerNested $r 'sbe','version')) { $cluster['sbeVersion'] = [string](Get-RangerNested $r 'sbe','version') }
        if ($cluster.Count) { $snap['cluster'] = $cluster }
        if ($r['subscription_id']) { $snap['azure'] = [ordered]@{ subscriptionId = [string]$r['subscription_id'] } }
        if ($r['identity'] -is [System.Collections.IDictionary] -and (Get-RangerNested $r 'identity','model')) { $snap['identity'] = [ordered]@{ model = $idMap[[string](Get-RangerNested $r 'identity','model')] } }
        if ($r['witness'] -is [System.Collections.IDictionary]) { $w = & $witMap (Get-RangerNested $r 'witness','type'); if ($w) { $snap['witness'] = [ordered]@{ type = $w } } }
        if ($r['nodes']) {
            $snap['nodes'] = @(@($r['nodes']) | ForEach-Object {
                    $n = [ordered]@{ name = [string]$_['name'] }
                    if ($_['management_ip']) { $n['managementIp'] = [string]$_['management_ip'] }
                    if ($_['service_tag']) { $n['serial'] = [string]$_['service_tag'] }
                    if ($_['bmc_ip']) { $n['bmcIp'] = [string]$_['bmc_ip'] }
                    if ($_['storage_ips'] -is [System.Collections.IDictionary]) { $n['storageIps'] = @($_['storage_ips'].Values | Where-Object { $_ } | ForEach-Object { [string]$_ }) }
                    $n
                })
        }
        if ($r['vlans'] -is [System.Collections.IDictionary]) {
            $snap['vlans'] = @($r['vlans'].GetEnumerator() | Where-Object { $_.Value -is [System.Collections.IDictionary] -and $_.Value['id'] } | ForEach-Object { [ordered]@{ id = [int]$_.Value['id']; name = [string](Get-RangerFirstValue @($_.Value['name'], $_.Key)) } } | Sort-Object { $_.id })
        }
        if ($r['intents']) {
            $qos = $r['qos']
            $snap['intents'] = @(@($r['intents']) | ForEach-Object {
                    $i = $_
                    $row = [ordered]@{ name = [string]$i['name']; traffic = @(@($i['traffic_types']) | ForEach-Object { ([string]$_).ToLowerInvariant() }); adapters = @(@($i['adapters']) | ForEach-Object { [string]$_ }) }
                    $ov = $i['overrides']
                    $jumbo = Get-RangerFirstValue @($(if ($ov -is [System.Collections.IDictionary]) { $ov['jumbo_packet'] }), $(if ('storage' -in $row.traffic -and $qos -is [System.Collections.IDictionary]) { $qos['jumbo_frame_size'] }))
                    if ($jumbo) { $row['jumbo'] = [int]$jumbo }
                    if ($ov -is [System.Collections.IDictionary] -and $null -ne $ov['rdma_enabled']) { $row['rdma'] = [bool]$ov['rdma_enabled'] }
                    elseif ('storage' -in $row.traffic -and $ov -is [System.Collections.IDictionary] -and $ov['rdma_protocol']) { $row['rdma'] = $true }
                    if ('storage' -in $row.traffic -and $qos -is [System.Collections.IDictionary]) { $row['qos'] = [ordered]@{ priority = $qos['storage_priority']; bandwidthPercent = $qos['storage_bandwidth_percent'] } }
                    $row
                })
        }
        if ($r['ip_plan'] -is [System.Collections.IDictionary] -and (Get-RangerNested $r 'ip_plan','dns_servers')) { $snap['dnsServers'] = @(@((Get-RangerNested $r 'ip_plan','dns_servers')) | ForEach-Object { [string]$_ }) }
        if ($r['storage'] -is [System.Collections.IDictionary] -and (Get-RangerNested $r 'storage','volumes')) {
            $snap['volumes'] = @(@((Get-RangerNested $r 'storage','volumes')) | ForEach-Object { [ordered]@{ name = [string]$_['name']; sizeGiB = [double]$_['size_gb']; resiliency = $resMap[[string]$_['resiliency']] } })
        }
        if ($r['sdn'] -is [System.Collections.IDictionary] -or $r['logical_networks']) {
            $sdn = [ordered]@{}
            if ($r['sdn'] -is [System.Collections.IDictionary]) { if ($null -ne (Get-RangerNested $r 'sdn','enabled')) { $sdn['enabled'] = [bool](Get-RangerNested $r 'sdn','enabled') }; if ((Get-RangerNested $r 'sdn','prefix')) { $sdn['prefix'] = [string](Get-RangerNested $r 'sdn','prefix') } }
            if ($r['logical_networks']) { $sdn['logicalNetworks'] = @(@($r['logical_networks']) | ForEach-Object { [ordered]@{ name = [string]$_['name']; vlan = [int]$_['vlan_id']; subnet = [string]$_['subnet'] } }) }
            $snap['sdn'] = $sdn
        }
    }
    else {
        # Trailwright infrastructure.yml (schema_version 4.0.0 subset)
        $cluster = [ordered]@{}
        $nm = Get-RangerFirstValue @((Get-RangerNested $r 'azure_platform','instance_name'), (Get-RangerNested $r '_metadata','environment_name'))
        if ($nm) { $cluster['name'] = [string]$nm }
        if ((Get-RangerNested $r '_metadata','azure_local_release')) { $cluster['release'] = [string](Get-RangerNested $r '_metadata','azure_local_release') }
        if ($cluster.Count) { $snap['cluster'] = $cluster }
        $az = [ordered]@{}
        if ((Get-RangerNested $r 'azure_platform','subscriptions','sub_azure_local_id')) { $az['subscriptionId'] = [string](Get-RangerNested $r 'azure_platform','subscriptions','sub_azure_local_id') }
        if ((Get-RangerNested $r 'azure_platform','resource_groups','rg_azurelocal_cluster')) { $az['resourceGroup'] = [string](Get-RangerNested $r 'azure_platform','resource_groups','rg_azurelocal_cluster') }
        if ($az.Count) { $snap['azure'] = $az }
        if ((Get-RangerNested $r 'identity','mode')) { $snap['identity'] = [ordered]@{ model = $idMap[[string](Get-RangerNested $r 'identity','mode')] } }
        $w = & $witMap (Get-RangerNested $r 'compute','cluster','witness_type'); if ($w) { $snap['witness'] = [ordered]@{ type = $w } }
        if ((Get-RangerNested $r 'compute','nodes')) {
            $snap['nodes'] = @(@((Get-RangerNested $r 'compute','nodes')) | ForEach-Object {
                    $n = [ordered]@{ name = [string]$_['name'] }
                    if ($_['ip']) { $n['managementIp'] = [string]$_['ip'] }
                    if ($_['serial']) { $n['serial'] = [string]$_['serial'] }
                    $n
                })
        }
        if ((Get-RangerNested $r 'networking','vlans')) { $snap['vlans'] = @(@((Get-RangerNested $r 'networking','vlans')) | ForEach-Object { [ordered]@{ id = [int]$_['id']; name = [string]$_['name'] } } | Sort-Object { $_.id }) }
        if ((Get-RangerNested $r 'networking','intents')) {
            $snap['intents'] = @(@((Get-RangerNested $r 'networking','intents')) | ForEach-Object { [ordered]@{ name = [string]$_['name']; traffic = @(@($_['traffic']) | ForEach-Object { ([string]$_).ToLowerInvariant() }); adapters = @(@($_['adapters']) | ForEach-Object { [string]$_ }) } })
        }
        if ((Get-RangerNested $r 'infrastructure_network','dns_servers')) { $snap['dnsServers'] = @(@((Get-RangerNested $r 'infrastructure_network','dns_servers')) | ForEach-Object { [string]$_ }) }
        if ((Get-RangerNested $r 'storage','volumes')) {
            $snap['volumes'] = @(@((Get-RangerNested $r 'storage','volumes')) | ForEach-Object { [ordered]@{ name = [string]$_['name']; sizeGiB = [double]$_['size_gib']; resiliency = $resMap[[string]$_['resiliency']] } })
        }
        if ($r['sdn'] -is [System.Collections.IDictionary]) {
            $sdn = [ordered]@{ enabled = [bool](Get-RangerNested $r 'sdn','enabled') }
            if ((Get-RangerNested $r 'sdn','prefix')) { $sdn['prefix'] = [string](Get-RangerNested $r 'sdn','prefix') }
            if ((Get-RangerNested $r 'sdn','logical_networks')) { $sdn['logicalNetworks'] = @(@((Get-RangerNested $r 'sdn','logical_networks')) | ForEach-Object { [ordered]@{ name = [string]$_['name']; vlan = [int]$_['vlan']; subnet = [string]$_['address_prefix'] } }) }
            $snap['sdn'] = $sdn
        }
    }
    return $snap
}

function New-RangerDesignRow {
    param($Area, $Key, $Design, $AsBuilt, $Status, $Severity, $Learn, $Note)
    [ordered]@{ area = $Area; key = $Key; design = $Design; asBuilt = $AsBuilt; status = $Status; severity = $Severity; learn = $Learn; note = $Note }
}

function Compare-RangerSets {
    param([object[]]$A, [object[]]$B)
    $x = @($A | Where-Object { $_ } | ForEach-Object { ([string]$_).ToLowerInvariant() } | Sort-Object -Unique)
    $y = @($B | Where-Object { $_ } | ForEach-Object { ([string]$_).ToLowerInvariant() } | Sort-Object -Unique)
    return (($x -join '|') -eq ($y -join '|'))
}

function Compare-RangerDesign {
    <#
    .SYNOPSIS
        Compares a Ranger manifest (or as-built-snapshot.v1) with a design record and returns a findings table.
    .DESCRIPTION
        Status: match, drift (both have it and it differs, or the build has something the design does not),
        missing (the design has it and the build does not), not-captured (the snapshot has no data for it).
        Severity: ok, info, warning, error. Release, identity, witness, node set, intent traffic and volume
        resiliency drift are errors; other drift is a warning; missing is an error.
    .PARAMETER ManifestPath
        Ranger audit-manifest.json.
    .PARAMETER Manifest
        A loaded manifest dictionary.
    .PARAMETER Snapshot
        A loaded or file-based as-built-snapshot.v1 (alternative to the manifest).
    .PARAMETER DesignPath
        The design record: the deploy automation environment file (YAML/JSON), Trailwright infrastructure.yml, or a snapshot.
    .PARAMETER DesignKind
        auto (default), environment, infrastructure or snapshot.
    .PARAMETER OutputPath
        Folder for design-comparison.json and design-comparison.html. Nothing is written when omitted.
    .PARAMETER Release
        Deployed release build when the manifest does not carry it.
    .EXAMPLE
        Compare-RangerDesign -ManifestPath .\manifest\audit-manifest.json -DesignPath .\environment.yml -OutputPath .\compare
    #>
    [CmdletBinding()]
    param(
        [string]$ManifestPath,
        [System.Collections.IDictionary]$Manifest,
        $Snapshot,
        [Parameter(Mandatory)][string]$DesignPath,
        [ValidateSet('auto', 'environment', 'infrastructure', 'snapshot')][string]$DesignKind = 'auto',
        [string]$OutputPath,
        [string]$Release
    )

    if ($Snapshot -is [string]) { $Snapshot = ConvertTo-RangerHashtable -InputObject (Get-Content -LiteralPath (Resolve-RangerPath -Path $Snapshot) -Raw | ConvertFrom-Json -AsHashtable -Depth 100) }
    if (-not $Snapshot) {
        if (-not $Manifest) {
            if (-not $ManifestPath) { throw 'Supply -ManifestPath, -Manifest or -Snapshot.' }
            $mp = Resolve-RangerPath -Path $ManifestPath
            if (-not (Test-Path -LiteralPath $mp -PathType Leaf)) { throw "Manifest not found: $mp" }
            $Manifest = ConvertTo-RangerHashtable -InputObject (Get-Content -LiteralPath $mp -Raw | ConvertFrom-Json -AsHashtable -Depth 100)
        }
        $Snapshot = ConvertTo-RangerAsBuiltSnapshot -Manifest $Manifest -Release $Release
    }
    $design = ConvertFrom-RangerDesignRecord -Path $DesignPath -Kind $DesignKind
    $L = $script:RangerDesignLearn
    $rows = New-Object System.Collections.Generic.List[object]
    $addRow = { param($row) $rows.Add($row) }

    # --- scalar helper: design value vs as-built value
    $scalar = {
        param($Area, $Key, $D, $A, $ErrorOnDrift, $Learn, $Equal)
        if ($null -eq $D -or "$D" -eq '') { return }
        if ($null -eq $A -or "$A" -eq '') { & $addRow (New-RangerDesignRow $Area $Key $D $null 'not-captured' 'info' $Learn 'The as-built snapshot has no data for this item.'); return }
        $same = if ($Equal) { & $Equal $D $A } else { ([string]$D).ToLowerInvariant() -eq ([string]$A).ToLowerInvariant() }
        if ($same) { & $addRow (New-RangerDesignRow $Area $Key $D $A 'match' 'ok' $Learn $null) }
        else { & $addRow (New-RangerDesignRow $Area $Key $D $A 'drift' $(if ($ErrorOnDrift) { 'error' } else { 'warning' }) $Learn $null) }
    }

    $dc = if ($design['cluster']) { $design['cluster'] } else { @{} }; $ac = if ($Snapshot['cluster']) { $Snapshot['cluster'] } else { @{} }
    & $scalar 'cluster' 'name' $dc['name'] $ac['name'] $false $null $null
    & $scalar 'cluster' 'release' $dc['release'] $ac['release'] $true $L.release {
        param($d, $a)
        if ("$d" -match '^\d{4}$') { "$a" -like "12.$d.*" -or "$a" -like "*.$d.*" } else { ([string]$d) -eq ([string]$a) -or ("$d" -match '^12\.\d{4}$' -and "$a" -like "$d.*") }
    }
    & $scalar 'cluster' 'sbeVersion' $dc['sbeVersion'] $ac['sbeVersion'] $false $L.sbe $null
    & $scalar 'azure' 'subscriptionId' (Get-RangerNested $design 'azure','subscriptionId') (Get-RangerNested $Snapshot 'azure','subscriptionId') $true $null $null
    & $scalar 'azure' 'resourceGroup' (Get-RangerNested $design 'azure','resourceGroup') (Get-RangerNested $Snapshot 'azure','resourceGroup') $false $null $null
    & $scalar 'identity' 'model' (Get-RangerNested $design 'identity','model') (Get-RangerNested $Snapshot 'identity','model') $true $L.identity $null
    & $scalar 'witness' 'type' (Get-RangerNested $design 'witness','type') (Get-RangerNested $Snapshot 'witness','type') $true $L.witness $null

    $dn = @($design['nodes'] | Where-Object { $_ }); $an = @($Snapshot['nodes'] | Where-Object { $_ })
    if ($dn.Count -gt 0) {
        if ($an.Count -eq 0) { & $addRow (New-RangerDesignRow 'nodes' 'set' (@($dn | ForEach-Object { $_['name'] }) -join ', ') $null 'not-captured' 'info' $null 'The as-built snapshot has no nodes.') }
        else {
            foreach ($n in $dn) {
                $short = Get-RangerShortName $n['name']
                $b = $an | Where-Object { (Get-RangerShortName $_['name']) -eq $short } | Select-Object -First 1
                if (-not $b) { & $addRow (New-RangerDesignRow 'nodes' $n['name'] $n['name'] $null 'missing' 'error' $null 'Designed node not found in the as-built cluster.'); continue }
                & $addRow (New-RangerDesignRow 'nodes' $n['name'] $n['name'] $b['name'] 'match' 'ok' $null $null)
                & $scalar 'nodes' "$($n['name']).managementIp" $n['managementIp'] $b['managementIp'] $false $null $null
                & $scalar 'nodes' "$($n['name']).serial" $n['serial'] $b['serial'] $false $null $null
                & $scalar 'nodes' "$($n['name']).bmcIp" $n['bmcIp'] $b['bmcIp'] $false $null $null
                if ($n['storageIps']) {
                    if (-not $b['storageIps']) { & $addRow (New-RangerDesignRow 'nodes' "$($n['name']).storageIps" (@($n['storageIps']) -join ', ') $null 'not-captured' 'info' $null 'The as-built snapshot has no storage IPs for this node.') }
                    elseif (Compare-RangerSets $n['storageIps'] $b['storageIps']) { & $addRow (New-RangerDesignRow 'nodes' "$($n['name']).storageIps" (@($n['storageIps']) -join ', ') (@($b['storageIps']) -join ', ') 'match' 'ok' $null $null) }
                    else { & $addRow (New-RangerDesignRow 'nodes' "$($n['name']).storageIps" (@($n['storageIps']) -join ', ') (@($b['storageIps']) -join ', ') 'drift' 'warning' $null $null) }
                }
            }
            foreach ($b in $an) {
                if (-not ($dn | Where-Object { (Get-RangerShortName $_['name']) -eq (Get-RangerShortName $b['name']) })) { & $addRow (New-RangerDesignRow 'nodes' $b['name'] $null $b['name'] 'drift' 'error' $null 'The as-built cluster has a node the design does not list.') }
            }
        }
    }

    # VLANs by id
    $dv = @($design['vlans'] | Where-Object { $_ }); $av = @($Snapshot['vlans'] | Where-Object { $_ })
    if ($dv.Count -gt 0) {
        if ($av.Count -eq 0) { & $addRow (New-RangerDesignRow 'vlans' 'set' (@($dv | ForEach-Object { $_['id'] }) -join ', ') $null 'not-captured' 'info' $L.network 'The as-built snapshot has no VLANs.') }
        else {
            foreach ($v in $dv) {
                if ($av | Where-Object { [int]$_['id'] -eq [int]$v['id'] }) { & $addRow (New-RangerDesignRow 'vlans' "vlan $($v['id'])" $v['id'] $v['id'] 'match' 'ok' $L.network $null) }
                else { & $addRow (New-RangerDesignRow 'vlans' "vlan $($v['id'])" $v['id'] $null 'missing' 'error' $L.network "Designed VLAN $($v['name']) is not on any management OS adapter.") }
            }
            foreach ($v in $av) { if (-not ($dv | Where-Object { [int]$_['id'] -eq [int]$v['id'] })) { & $addRow (New-RangerDesignRow 'vlans' "vlan $($v['id'])" $null $v['id'] 'drift' 'warning' $L.network 'VLAN present in the build but not in the design.') } }
        }
    }

    # intents: by name, then by the traffic they carry
    $di = @($design['intents'] | Where-Object { $_ }); $ai = @($Snapshot['intents'] | Where-Object { $_ })
    if ($di.Count -gt 0) {
        if ($ai.Count -eq 0) { & $addRow (New-RangerDesignRow 'intents' 'set' (@($di | ForEach-Object { $_['name'] }) -join ', ') $null 'not-captured' 'info' $L.intents 'The as-built snapshot has no intents.') }
        else {
            foreach ($i in $di) {
                $b = $ai | Where-Object { ([string]$_['name']).ToLowerInvariant() -eq ([string]$i['name']).ToLowerInvariant() } | Select-Object -First 1
                if (-not $b) { $b = $ai | Where-Object { Compare-RangerSets $_['traffic'] $i['traffic'] } | Select-Object -First 1 }
                if (-not $b) { & $addRow (New-RangerDesignRow 'intents' $i['name'] (@($i['traffic']) -join '+') $null 'missing' 'error' $L.intents 'No as-built intent carries this traffic.'); continue }
                if (Compare-RangerSets $i['traffic'] $b['traffic']) { & $addRow (New-RangerDesignRow 'intents' "$($i['name']).traffic" (@($i['traffic']) -join '+') (@($b['traffic']) -join '+') 'match' 'ok' $L.intents $null) }
                else { & $addRow (New-RangerDesignRow 'intents' "$($i['name']).traffic" (@($i['traffic']) -join '+') (@($b['traffic']) -join '+') 'drift' 'error' $L.intents $null) }
                if (@($i['adapters']).Count -gt 0) {
                    if (@($b['adapters']).Count -eq 0) { & $addRow (New-RangerDesignRow 'intents' "$($i['name']).adapters" (@($i['adapters']) -join ', ') $null 'not-captured' 'info' $L.intents 'The as-built snapshot has no adapter names for this intent.') }
                    elseif (Compare-RangerSets $i['adapters'] $b['adapters']) { & $addRow (New-RangerDesignRow 'intents' "$($i['name']).adapters" (@($i['adapters']) -join ', ') (@($b['adapters']) -join ', ') 'match' 'ok' $L.intents $null) }
                    else { & $addRow (New-RangerDesignRow 'intents' "$($i['name']).adapters" (@($i['adapters']) -join ', ') (@($b['adapters']) -join ', ') 'drift' 'warning' $L.intents 'Adapter names differ; the design may use port labels while the OS reports its own names.') }
                }
                & $scalar 'intents' "$($i['name']).jumbo" $i['jumbo'] $b['jumbo'] $false $L.network { param($d, $a) [int]$d -eq [int]$a }
                if ($null -ne $i['rdma']) { & $scalar 'intents' "$($i['name']).rdma" ([string]$i['rdma']) $(if ($null -ne $b['rdma']) { [string]$b['rdma'] }) $false $L.network $null }
                if ($i['qos']) {
                    & $scalar 'intents' "$($i['name']).qos.priority" $i['qos']['priority'] (Get-RangerNested $b 'qos', 'priority') $false $L.network { param($d, $a) [int]$d -eq [int]$a }
                    & $scalar 'intents' "$($i['name']).qos.bandwidthPercent" $i['qos']['bandwidthPercent'] (Get-RangerNested $b 'qos', 'bandwidthPercent') $false $L.network { param($d, $a) [int]$d -eq [int]$a }
                }
            }
        }
    }

    # volumes by name; size within 1 percent (or 1 GiB); resiliency is an error
    $dvol = @($design['volumes'] | Where-Object { $_ }); $avol = @($Snapshot['volumes'] | Where-Object { $_ })
    if ($dvol.Count -gt 0) {
        if ($avol.Count -eq 0) { & $addRow (New-RangerDesignRow 'volumes' 'set' (@($dvol | ForEach-Object { $_['name'] }) -join ', ') $null 'not-captured' 'info' $L.volumes 'The as-built snapshot has no volumes.') }
        else {
            foreach ($v in $dvol) {
                $b = $avol | Where-Object { ([string]$_['name']).ToLowerInvariant() -eq ([string]$v['name']).ToLowerInvariant() } | Select-Object -First 1
                if (-not $b) { & $addRow (New-RangerDesignRow 'volumes' $v['name'] $v['name'] $null 'missing' 'error' $L.volumes 'Designed volume not found.'); continue }
                & $addRow (New-RangerDesignRow 'volumes' $v['name'] $v['name'] $b['name'] 'match' 'ok' $L.volumes $null)
                & $scalar 'volumes' "$($v['name']).resiliency" $v['resiliency'] $b['resiliency'] $true $L.volumes $null
                & $scalar 'volumes' "$($v['name']).sizeGiB" $v['sizeGiB'] $b['sizeGiB'] $false $L.volumes { param($d, $a) $diff = [math]::Abs([double]$d - [double]$a); ($diff -le 1.0) -or ($diff -le 0.01 * [double]$d) }
            }
            foreach ($b in $avol) {
                if (-not ($dvol | Where-Object { ([string]$_['name']).ToLowerInvariant() -eq ([string]$b['name']).ToLowerInvariant() })) {
                    $system = ([string]$b['name']) -match '(?i)^(infrastructure|clusterperformancehistory|userstorage|collect)'
                    & $addRow (New-RangerDesignRow 'volumes' $b['name'] $null $b['name'] 'drift' $(if ($system) { 'info' } else { 'warning' }) $L.volumes $(if ($system) { 'Platform-managed volume.' } else { 'Volume present in the build but not in the design.' }))
                }
            }
        }
    }

    # DNS
    $dDns = @($design['dnsServers'] | Where-Object { $_ }); $aDns = @($Snapshot['dnsServers'] | Where-Object { $_ })
    if ($dDns.Count -gt 0) {
        if ($aDns.Count -eq 0) { & $addRow (New-RangerDesignRow 'network' 'dnsServers' ($dDns -join ', ') $null 'not-captured' 'info' $null 'The as-built snapshot has no DNS servers.') }
        elseif (Compare-RangerSets $dDns $aDns) { & $addRow (New-RangerDesignRow 'network' 'dnsServers' ($dDns -join ', ') ($aDns -join ', ') 'match' 'ok' $null $null) }
        else { & $addRow (New-RangerDesignRow 'network' 'dnsServers' ($dDns -join ', ') ($aDns -join ', ') 'drift' 'warning' $null $null) }
    }

    # SDN
    $ds = $design['sdn']; $as = if ($Snapshot['sdn']) { $Snapshot['sdn'] } else { @{} }
    if ($ds) {
        & $scalar 'sdn' 'enabled' $(if ($null -ne $ds['enabled']) { [string]$ds['enabled'] }) $(if ($null -ne $as['enabled']) { [string]$as['enabled'] }) $false $null $null
        & $scalar 'sdn' 'prefix' $ds['prefix'] $as['prefix'] $false $null $null
        $asLn = @($as['logicalNetworks'] | Where-Object { $_ })
        foreach ($ln in @($ds['logicalNetworks'] | Where-Object { $_ })) {
            if ($asLn.Count -eq 0) { & $addRow (New-RangerDesignRow 'sdn' $ln['name'] $ln['name'] $null 'not-captured' 'info' $null 'The as-built snapshot has no logical networks.'); continue }
            $b = $asLn | Where-Object { ([string]$_['name']).ToLowerInvariant() -eq ([string]$ln['name']).ToLowerInvariant() } | Select-Object -First 1
            if (-not $b) { & $addRow (New-RangerDesignRow 'sdn' $ln['name'] $ln['name'] $null 'missing' 'error' $null 'Designed logical network not found.'); continue }
            & $addRow (New-RangerDesignRow 'sdn' $ln['name'] $ln['name'] $b['name'] 'match' 'ok' $null $null)
            & $scalar 'sdn' "$($ln['name']).vlan" $ln['vlan'] $b['vlan'] $false $null { param($d, $a) [int]$d -eq [int]$a }
            & $scalar 'sdn' "$($ln['name']).subnet" $ln['subnet'] $b['subnet'] $false $null $null
        }
    }

    $all = $rows.ToArray()
    $summary = [ordered]@{
        total       = $all.Count
        match       = @($all | Where-Object { $_.status -eq 'match' }).Count
        drift       = @($all | Where-Object { $_.status -eq 'drift' }).Count
        missing     = @($all | Where-Object { $_.status -eq 'missing' }).Count
        notCaptured = @($all | Where-Object { $_.status -eq 'not-captured' }).Count
        errors      = @($all | Where-Object { $_.severity -eq 'error' }).Count
        warnings    = @($all | Where-Object { $_.severity -eq 'warning' }).Count
        # Share of design items the as-built snapshot could actually be compared on (red-team review: report coverage separately).
        coveragePercent = if ($all.Count -gt 0) { [math]::Round(100.0 * ($all.Count - @($all | Where-Object { $_.status -eq 'not-captured' }).Count) / $all.Count, 1) } else { $null }
    }
    $result = [ordered]@{
        schema         = 'design-comparison.v1'
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        designKind     = [string]$design['_kind']
        designSource   = [System.IO.Path]::GetFileName($DesignPath)
        snapshotSource = $Snapshot['source']
        summary        = $summary
        findings       = $all
    }

    if ($OutputPath) {
        $out = Resolve-RangerPath -Path $OutputPath
        New-Item -ItemType Directory -Path $out -Force | Out-Null
        $result | ConvertTo-Json -Depth 20 | Set-Content -Path (Join-Path $out 'design-comparison.json') -Encoding UTF8
        New-RangerDesignComparisonHtml -Comparison $result | Set-Content -Path (Join-Path $out 'design-comparison.html') -Encoding UTF8
    }
    return $result
}

function New-RangerDesignComparisonHtml {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Comparison)

    $enc = { param($v) [System.Net.WebUtility]::HtmlEncode([string]$v) }
    $s = $Comparison['summary']
    $rowsHtml = foreach ($r in @($Comparison['findings'])) {
        $learn = if ($r['learn']) { "<a href=`"$(& $enc $r['learn'])`">Learn</a>" } else { '' }
        "<tr class=`"sev-$($r['severity']) st-$($r['status'])`"><td>$(& $enc $r['area'])</td><td>$(& $enc $r['key'])</td><td>$(& $enc $r['design'])</td><td>$(& $enc $r['asBuilt'])</td><td>$(& $enc $r['status'])</td><td>$(& $enc $r['severity'])</td><td>$learn $(& $enc $r['note'])</td></tr>"
    }
    @"
<section class="design-comparison">
<h2>Design vs as-built</h2>
<p>$($s['match']) match, $($s['drift']) drift, $($s['missing']) missing, $($s['notCaptured']) not captured ($($s['errors']) errors, $($s['warnings']) warnings).</p>
<table>
<thead><tr><th>Area</th><th>Item</th><th>Design</th><th>As-built</th><th>Status</th><th>Severity</th><th>Reference</th></tr></thead>
<tbody>
$($rowsHtml -join "`n")
</tbody>
</table>
</section>
"@
}
