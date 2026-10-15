# Azure Local 12.2609 (latest) platform evidence (v2.7.0).
#
# Read-only helpers that surface what the Azure Local 12.2609 release added or made visible:
#   * Arc gateway resources and per-node routing        https://learn.microsoft.com/azure/azure-local/deploy/deployment-azure-arc-gateway-overview
#   * Security baseline compliance score                https://learn.microsoft.com/azure/azure-local/manage/manage-secure-baseline
#   * Secure Boot 2023 certificate status               https://learn.microsoft.com/azure/azure-local/manage/manage-secure-boot-updates
#   * Backup key vault / automatic key backup (preview) https://learn.microsoft.com/azure/azure-local/manage/trusted-launch-vm-overview
#   * Local identity with Key Vault (+ internal DNS)    https://learn.microsoft.com/azure/azure-local/deploy/deployment-local-identity-with-key-vault
#   * Rack aware cluster fault domains                  https://learn.microsoft.com/azure/azure-local/concepts/rack-aware-cluster-reference-architecture
#   * Solution Builder Extension / OEM update detail    https://learn.microsoft.com/azure/azure-local/update/solution-builder-extension
#   * Disaggregated / SAN storage indicators            https://learn.microsoft.com/azure/well-architected/service-guides/azure-local
#   * Private path network                              https://learn.microsoft.com/azure/azure-local/concepts/private-path-network-overview
#
# Every function here only reads. The shaping functions are pure (input in, hashtable out) so they run
# against fixtures; the Get-* functions call Azure Resource Manager or the nodes through the existing
# Invoke-RangerAzureQuery / Invoke-RangerClusterCommand wrappers. Secrets are never read: BitLocker
# recovery keys and Key Vault secret values are out of scope by design.

function ConvertFrom-RangerAzcmagentShow {
    <#
    .SYNOPSIS
        Parses 'azcmagent show' (and optionally 'azcmagent check') text into Arc gateway routing facts.
    .DESCRIPTION
        Learn: with the Arc gateway enabled, 'azcmagent show' reports 'Using HTTPS Proxy' as
        http://localhost:40343, 'Azure Arc Proxy' as running, agent version 1.45 or later, and
        'azcmagent check' reports connection.type = gateway.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [AllowEmptyString()][string]$ShowText = '',
        [AllowEmptyString()][string]$CheckText = ''
    )

    $pairs = @{}
    foreach ($line in ($ShowText -split "`r?`n")) {
        if ($line -match '^\s*([A-Za-z][A-Za-z0-9 ./_-]*?)\s*:\s*(.*?)\s*$') { $pairs[$Matches[1].Trim().ToLowerInvariant()] = $Matches[2] }
    }
    $connectionType = $null
    foreach ($line in ($CheckText -split "`r?`n")) {
        if ($line -match 'connection\.type\s*[:=]?\s*(\S+)' -or $line -match '^\s*connection\.type\s+(\S+)') { $connectionType = $Matches[1].ToLowerInvariant(); break }
    }
    if (-not $connectionType) {
        # azcmagent check prints a table; the row for the connection type contains 'gateway' or 'direct'.
        if ($CheckText -match '(?im)connection\.type\D+(gateway|direct|proxy)') { $connectionType = $Matches[1].ToLowerInvariant() }
    }

    $agentVersion = [string]$pairs['agent version']
    $versionOk = $false
    $parsed = $null
    if ($agentVersion -and [version]::TryParse(($agentVersion -replace '[^0-9.].*$', ''), [ref]$parsed)) { $versionOk = ($parsed -ge [version]'1.45') }
    $httpsProxy = [string]$pairs['using https proxy']
    $arcProxy = [string]$pairs['azure arc proxy']
    $viaLocalProxy = ($httpsProxy -match 'localhost:40343')
    $proxyRunning = ($arcProxy -match '(?i)running')

    $status = if ($connectionType -eq 'gateway' -or ($viaLocalProxy -and $proxyRunning)) { 'routed' }
    elseif ($ShowText -or $CheckText) { 'not-routed' }
    else { 'unknown' }

    return [ordered]@{
        agentVersion       = $agentVersion
        agentVersionMeetsGatewayMinimum = $versionOk
        agentStatus        = [string]$pairs['agent status']
        usingHttpsProxy    = $httpsProxy
        upstreamProxy      = [string]$pairs['upstream proxy']
        azureArcProxy      = $arcProxy
        connectionType     = $connectionType
        status             = $status
    }
}

function ConvertTo-RangerArcGatewayEvidence {
    <#
    .SYNOPSIS
        Shapes Arc gateway ARM resources plus per-node azcmagent facts into the arcGateways / arcGatewayNodeRouting payloads.
    #>
    [CmdletBinding()]
    param(
        [object[]]$GatewayResources = @(),
        [object[]]$NodeAgentFacts = @()
    )

    $gateways = @(foreach ($g in @($GatewayResources | Where-Object { $_ })) {
            $p = if ($g.Properties) { $g.Properties } elseif ($g.properties) { $g.properties } else { $null }
            $name = [string](Get-RangerObjectValue -InputObject $g -CandidateNames @('Name', 'name'))
            $endpoint = [string](Get-RangerObjectValue -InputObject $p -CandidateNames @('gatewayEndpoint', 'GatewayEndpoint'))
            if ($endpoint -and $endpoint -notmatch '^https?://') { $endpoint = "https://$endpoint" }
            [ordered]@{
                name              = $name
                resourceGroup     = [string](Get-RangerObjectValue -InputObject $g -CandidateNames @('ResourceGroupName', 'resourceGroup'))
                location          = [string](Get-RangerObjectValue -InputObject $g -CandidateNames @('Location', 'location'))
                gatewayEndpoint   = $endpoint
                gatewayId         = [string](Get-RangerObjectValue -InputObject $p -CandidateNames @('gatewayId', 'GatewayId'))
                gatewayType       = [string](Get-RangerObjectValue -InputObject $p -CandidateNames @('gatewayType', 'GatewayType'))
                provisioningState = [string](Get-RangerObjectValue -InputObject $p -CandidateNames @('provisioningState', 'ProvisioningState'))
                allowedFeatures   = @(Get-RangerObjectValue -InputObject $p -CandidateNames @('allowedFeatures', 'AllowedFeatures'))
                resourceId        = [string](Get-RangerObjectValue -InputObject $g -CandidateNames @('ResourceId', 'Id', 'id'))
            }
        })

    $single = if ($gateways.Count -eq 1) { $gateways[0] } else { $null }
    $routing = @(foreach ($f in @($NodeAgentFacts | Where-Object { $_ })) {
            [ordered]@{
                node          = [string]$f.node
                status        = [string]$f.status
                routedThrough = if ($f.status -eq 'routed' -and $single) { $single.name } else { $null }
                gatewayUrl    = if ($f.status -eq 'routed' -and $single) { $single.gatewayEndpoint } else { $null }
                agentVersion  = [string]$f.agentVersion
                agentVersionMeetsGatewayMinimum = [bool]$f.agentVersionMeetsGatewayMinimum
                connectionType = [string]$f.connectionType
            }
        })

    return [ordered]@{ arcGateways = @($gateways); arcGatewayNodeRouting = @($routing) }
}

function ConvertTo-RangerSecurityBaselineScore {
    <#
    .SYNOPSIS
        Computes the security baseline compliance score from a Machine Configuration assignment report.
    .DESCRIPTION
        Learn: Azure Local assigns 'AzureWindowsBaseline' in Audit mode to every machine; the expected score is
        below 100 percent by design because customer-defined settings (for example minimum password length)
        are not drift controlled.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$MachineName,
        [AllowNull()]$Assignment
    )

    if (-not $Assignment) {
        return [ordered]@{ machine = $MachineName; assignment = 'AzureWindowsBaseline'; status = 'not-assigned'; scorePercent = $null; compliantRules = 0; totalRules = 0; nonCompliantRules = @() }
    }
    $p = if ($Assignment.Properties) { $Assignment.Properties } elseif ($Assignment.properties) { $Assignment.properties } else { $Assignment }
    $report = Get-RangerObjectValue -InputObject $p -CandidateNames @('latestAssignmentReport', 'LatestAssignmentReport')
    $resources = @()
    if ($report) {
        $resources = @(Get-RangerObjectValue -InputObject $report -CandidateNames @('resources', 'Resources'))
    }
    $rules = New-Object System.Collections.Generic.List[object]
    foreach ($res in $resources) {
        $reasons = @(Get-RangerObjectValue -InputObject $res -CandidateNames @('reasons', 'Reasons'))
        $name = [string](Get-RangerObjectValue -InputObject $res -CandidateNames @('resourceId', 'ResourceId', 'name', 'Name'))
        $isCompliant = [bool](Get-RangerObjectValue -InputObject $res -CandidateNames @('complianceStatus', 'ComplianceStatus', 'compliant'))
        $rules.Add([pscustomobject]@{ name = $name; compliant = $isCompliant; reason = [string](($reasons | ForEach-Object { Get-RangerObjectValue -InputObject $_ -CandidateNames @('phrase', 'Phrase') }) -join '; ') })
    }
    $total = $rules.Count
    $ok = @($rules | Where-Object { $_.compliant }).Count
    $overall = [string](Get-RangerObjectValue -InputObject $p -CandidateNames @('complianceStatus', 'ComplianceStatus'))
    $score = if ($total -gt 0) { [math]::Round(100.0 * $ok / $total, 1) } else { $null }
    return [ordered]@{
        machine           = $MachineName
        assignment        = 'AzureWindowsBaseline'
        status            = if ($overall) { $overall } else { 'unknown' }
        lastChecked       = [string](Get-RangerObjectValue -InputObject $p -CandidateNames @('lastComplianceStatusChecked', 'LastComplianceStatusChecked'))
        scorePercent      = $score
        compliantRules    = $ok
        totalRules        = $total
        nonCompliantRules = @($rules | Where-Object { -not $_.compliant } | Select-Object -First 25 | ForEach-Object { [ordered]@{ name = $_.name; reason = $_.reason } })
    }
}

function ConvertTo-RangerSecureBootStatus {
    <#
    .SYNOPSIS
        Maps raw Secure Boot facts for one node onto the Azure Local staged certificate model.
    .DESCRIPTION
        Learn: stage 0 = 2023 CA not in firmware databases, stage 1 = 2023 CA present, stage 2 = boots with the
        2023 CA signed boot manager. The Windows servicing registry value UEFICA2023Status reads 'Updated'
        when the update is complete; Test-AzSSecureBootUpdateCompleted returns True when the steps are done.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Node, [AllowNull()]$Raw)

    if (-not $Raw) {
        return [ordered]@{ node = $Node; secureBootEnabled = $null; uefiCa2023Status = $null; updateCompleted = $null; state = 'unknown'; actionRequired = $false }
    }
    $status = [string](Get-RangerObjectValue -InputObject $Raw -CandidateNames @('uefiCa2023Status', 'UEFICA2023Status'))
    $completed = Get-RangerObjectValue -InputObject $Raw -CandidateNames @('updateCompleted', 'UpdateCompleted')
    $enabled = Get-RangerObjectValue -InputObject $Raw -CandidateNames @('secureBootEnabled', 'SecureBootEnabled')
    $state = if ($enabled -eq $false) { 'secure-boot-disabled' }
    elseif ($status -match '^(?i)updated$' -or $completed -eq $true) { 'updated' }
    elseif ($status -match '(?i)progress|pending') { 'in-progress' }
    elseif ($status) { 'not-updated' }
    elseif ($completed -eq $false) { 'not-updated' }
    else { 'unknown' }
    return [ordered]@{
        node              = $Node
        secureBootEnabled = $enabled
        uefiCa2023Status  = $status
        uefiCa2023Error   = [string](Get-RangerObjectValue -InputObject $Raw -CandidateNames @('uefiCa2023Error', 'UEFICA2023Error'))
        updateCompleted   = $completed
        state             = $state
        actionRequired    = ($state -in @('not-updated', 'in-progress'))
    }
}

function Get-RangerRackAwareSummary {
    <#
    .SYNOPSIS
        Derives rack aware cluster facts from Get-ClusterFaultDomain output (Rack zones and their nodes).
    .DESCRIPTION
        Learn: a rack aware cluster has two local availability zones (Rack fault domains) with up to 4+4 nodes.
        Rack fault domains were previously only counted as multi-rack indicators.
    #>
    [CmdletBinding()]
    param([object[]]$FaultDomains = @(), [object[]]$NodeNames = @())

    $domains = @($FaultDomains | Where-Object { $_ })
    $type = { param($d) [string](Get-RangerObjectValue -InputObject $d -CandidateNames @('FaultDomainType', 'faultDomainType', 'Type')) }
    $racks = @($domains | Where-Object { (& $type $_) -match 'Rack' })
    $sites = @($domains | Where-Object { (& $type $_) -match 'Site' })
    $nodeDomains = @($domains | Where-Object { (& $type $_) -match 'Node' })
    $zones = @(foreach ($r in $racks) {
            $name = [string](Get-RangerObjectValue -InputObject $r -CandidateNames @('Name', 'name'))
            $children = @(Get-RangerObjectValue -InputObject $r -CandidateNames @('ChildrenNames', 'childrenNames') | Where-Object { $_ })
            if ($children.Count -eq 0) {
                $children = @($nodeDomains | Where-Object { [string](Get-RangerObjectValue -InputObject $_ -CandidateNames @('ParentName', 'parentName')) -eq $name } | ForEach-Object { [string](Get-RangerObjectValue -InputObject $_ -CandidateNames @('Name', 'name')) })
            }
            [ordered]@{ name = $name; location = [string](Get-RangerObjectValue -InputObject $r -CandidateNames @('Location', 'location')); nodes = @($children); nodeCount = $children.Count }
        })
    $counts = @($zones | ForEach-Object { $_.nodeCount })
    $isRackAware = ($zones.Count -eq 2 -and @($counts | Where-Object { $_ -gt 0 }).Count -eq 2)
    $balanced = ($counts.Count -gt 0 -and (($counts | Measure-Object -Minimum -Maximum).Minimum -eq ($counts | Measure-Object -Minimum -Maximum).Maximum))
    $unassigned = @($NodeNames | Where-Object { $n = $_; $n -and -not @($zones | Where-Object { $n -in $_.nodes -or ($_.nodes | Where-Object { $_ -like "$n.*" -or $n -like "$_.*" }) }).Count })
    return [ordered]@{
        isRackAware       = $isRackAware
        rackCount         = $racks.Count
        siteCount         = $sites.Count
        zones             = @($zones)
        layout            = if ($zones.Count -gt 0) { ($counts -join '+') } else { $null }
        balanced          = $balanced
        nodesWithoutZone  = @($unassigned)
        reference         = 'https://learn.microsoft.com/azure/azure-local/concepts/rack-aware-cluster-reference-architecture'
    }
}

function Get-RangerSolutionUpdateDetail {
    <#
    .SYNOPSIS
        Shapes Get-SolutionUpdateEnvironment / Get-SolutionUpdate output into SBE / OEM update detail.
    .DESCRIPTION
        Learn states: AppliedSuccessfully, NeedsAttention, PreparationFailed, PreparationInProgress, UpdateAvailable,
        UpdateFailed, UpdateInProgress; update states include AdditionalContentRequired and (2608+) Pending OEM
        Validation. SBEReleaseLink / SBENotifyMessage live in AdditionalProperties.
    #>
    [CmdletBinding()]
    param([AllowNull()]$Environment, [object[]]$Updates = @())

    $sbeState = [string](Get-RangerObjectValue -InputObject $Environment -CandidateNames @('State', 'state'))
    $updateRows = @(foreach ($u in @($Updates | Where-Object { $_ })) {
            $ap = Get-RangerObjectValue -InputObject $u -CandidateNames @('AdditionalProperties', 'additionalProperties')
            [ordered]@{
                displayName      = [string](Get-RangerObjectValue -InputObject $u -CandidateNames @('DisplayName', 'displayName'))
                packageType      = [string](Get-RangerObjectValue -InputObject $u -CandidateNames @('PackageType', 'packageType'))
                version          = [string](Get-RangerObjectValue -InputObject $u -CandidateNames @('Version', 'version'))
                sbeVersion       = [string](Get-RangerObjectValue -InputObject $u -CandidateNames @('SbeVersion', 'sbeVersion'))
                state            = [string](Get-RangerObjectValue -InputObject $u -CandidateNames @('State', 'state'))
                sbeReleaseLink   = [string](Get-RangerObjectValue -InputObject $ap -CandidateNames @('SBEReleaseLink'))
                sbeNotifyMessage = [string](Get-RangerObjectValue -InputObject $ap -CandidateNames @('SBENotifyMessage'))
            }
        })
    return [ordered]@{
        sbeFamily          = [string](Get-RangerObjectValue -InputObject $Environment -CandidateNames @('SbeFamily', 'sbeFamily'))
        hardwareModel      = [string](Get-RangerObjectValue -InputObject $Environment -CandidateNames @('HardwareModel', 'hardwareModel'))
        currentSbeVersion  = [string](Get-RangerObjectValue -InputObject $Environment -CandidateNames @('CurrentSbeVersion', 'currentSbeVersion', 'SbeVersion'))
        state              = $sbeState
        needsAttention     = ($sbeState -in @('NeedsAttention', 'PreparationFailed', 'UpdateFailed'))
        sbeInstalled       = -not ([string](Get-RangerObjectValue -InputObject $Environment -CandidateNames @('CurrentSbeVersion', 'currentSbeVersion', 'SbeVersion')) -in @('', '2.1.0.0'))
        updates            = @($updateRows)
        additionalContentRequired = @($updateRows | Where-Object { $_.state -eq 'AdditionalContentRequired' }).Count
        pendingOemValidation      = @($updateRows | Where-Object { $_.state -match 'Pending OEM Validation|PendingOemValidation' }).Count
        reference          = 'https://learn.microsoft.com/azure/azure-local/update/solution-builder-extension'
    }
}

function Get-RangerStorageArchitectureIndicators {
    <#
    .SYNOPSIS
        Flags disaggregated / SAN-backed storage from data the storage collectors already gathered.
    .DESCRIPTION
        Learn (Azure Local WAF guide) calls out disaggregated deployments where the SAN provides encryption and
        key protection. Indicators: Storage Spaces Direct disabled with CSVs present, Fibre Channel or iSCSI
        physical disks, or FC / iSCSI initiator ports.
    #>
    [CmdletBinding()]
    param([System.Collections.IDictionary]$Manifest)

    $cluster = $Manifest.domains.clusterNode.cluster
    $s2d = if ($cluster -is [System.Collections.IDictionary] -and $cluster.Contains('s2dEnabled')) { [bool]$cluster['s2dEnabled'] } else { $null }
    $disks = @($Manifest.domains.storage.physicalDisks | Where-Object { $_ })
    $csvCount = @($Manifest.domains.storage.csvs | Where-Object { $_ }).Count
    $san = New-Object System.Collections.Generic.List[string]
    if ($s2d -eq $false -and $csvCount -gt 0) { $san.Add('csv-without-storage-spaces-direct') }
    foreach ($bus in ($disks | ForEach-Object { [string](Get-RangerObjectValue -InputObject $_ -CandidateNames @('BusType', 'busType')) } | Where-Object { $_ -match '(?i)fibre|fc|iscsi' } | Select-Object -Unique)) { $san.Add("disk-bus-$($bus.ToLowerInvariant())") }
    foreach ($port in @($Manifest.domains.storage.initiatorPorts | Where-Object { $_ })) {
        $t = [string](Get-RangerObjectValue -InputObject $port -CandidateNames @('ConnectionType', 'connectionType', 'Type'))
        if ($t -match '(?i)fibre|iscsi') { $san.Add("initiator-$($t.ToLowerInvariant())") }
    }
    $indicators = @($san | Select-Object -Unique)
    return [ordered]@{
        storageSpacesDirectEnabled = $s2d
        disaggregatedOrSanIndicators = $indicators
        likelyDisaggregated = ($indicators.Count -gt 0)
        reference = 'https://learn.microsoft.com/azure/well-architected/service-guides/azure-local'
    }
}

function Get-RangerLocalIdentityEvidence {
    <#
    .SYNOPSIS
        Local identity with Azure Key Vault (and internal DNS preview) indicators from the identity snapshots.
    .DESCRIPTION
        Learn: a local identity cluster reports ADAware = 2 (0 none, 1 AD, 2 local identity); nodes are WORKGROUP
        members; the recovery admin account is RecoveryAdmin; secrets are backed up to Key Vault.
    #>
    [CmdletBinding()]
    param([object[]]$IdentitySnapshots = @(), [object]$AdAware, [object[]]$KeyVaults = @(), [string[]]$DnsServers = @())

    $workgroupNodes = @($IdentitySnapshots | Where-Object { $_ -and [string]$_.domain -match '^(?i)WORKGROUP$' }).Count
    $adAwareValue = if ($null -ne $AdAware -and "$AdAware" -match '^\d+$') { [int]$AdAware } else { $null }
    $mode = switch ($adAwareValue) { 2 { 'local-identity' } 1 { 'active-directory' } 0 { 'none' } default { $(if ($workgroupNodes -gt 0 -and $workgroupNodes -eq @($IdentitySnapshots).Count) { 'local-identity' } else { 'unknown' }) } }
    return [ordered]@{
        adAware            = $adAwareValue
        identityMode       = $mode
        workgroupNodes     = $workgroupNodes
        usesKeyVault       = ($mode -eq 'local-identity' -and @($KeyVaults).Count -gt 0)
        keyVaults          = @($KeyVaults)
        dnsServers         = @($DnsServers)
        internalDnsPreview = ($mode -eq 'local-identity' -and @($DnsServers | Where-Object { $_ }).Count -gt 0)
        reference          = 'https://learn.microsoft.com/azure/azure-local/deploy/deployment-local-identity-with-key-vault'
    }
}

function ConvertTo-RangerKeyBackupEvidence {
    <#
    .SYNOPSIS
        Key Vault inventory in the cluster resource group, as the candidate backup key vault for 2609 automatic key backup (preview).
    .DESCRIPTION
        Only vault metadata is read (name, soft delete, purge protection, RBAC authorisation, public network access).
        Secret and key values are never read. Whether the backup is actually enabled is a portal / deployment setting
        that has no read API yet, so the result is reported as a candidate list, not a verdict.
    #>
    [CmdletBinding()]
    param([object[]]$Vaults = @())

    $rows = @(foreach ($v in @($Vaults | Where-Object { $_ })) {
            $p = if ($v.Properties) { $v.Properties } elseif ($v.properties) { $v.properties } else { $null }
            [ordered]@{
                name                = [string](Get-RangerObjectValue -InputObject $v -CandidateNames @('Name', 'name'))
                resourceGroup       = [string](Get-RangerObjectValue -InputObject $v -CandidateNames @('ResourceGroupName', 'resourceGroup'))
                softDeleteEnabled   = Get-RangerObjectValue -InputObject $p -CandidateNames @('enableSoftDelete', 'EnableSoftDelete')
                purgeProtection     = Get-RangerObjectValue -InputObject $p -CandidateNames @('enablePurgeProtection', 'EnablePurgeProtection')
                rbacAuthorization   = Get-RangerObjectValue -InputObject $p -CandidateNames @('enableRbacAuthorization', 'EnableRbacAuthorization')
                publicNetworkAccess = [string](Get-RangerObjectValue -InputObject $p -CandidateNames @('publicNetworkAccess', 'PublicNetworkAccess'))
            }
        })
    return [ordered]@{
        backupKeyVaultCandidates = @($rows)
        status                   = if ($rows.Count -gt 0) { 'candidate-key-vault-present' } else { 'no-key-vault-found' }
        note                     = 'Automatic key backup (preview) is configured at deployment; Ranger lists Key Vaults in the cluster resource group and never reads secret values.'
        reference                = 'https://learn.microsoft.com/azure/azure-local/manage/trusted-launch-vm-overview'
    }
}

function Get-RangerPrivatePathEvidence {
    <#
    .SYNOPSIS
        Private path network indicators: Arc gateway present plus private endpoint / private link resources in scope.
    .DESCRIPTION
        Learn (2609): 'Register Azure Local with Azure Arc gateway and private path'. The read-only indicators are an
        Arc gateway resource, Private Link scopes / private endpoints in the resource group and gateway endpoints
        under *.privatelink.* names.
    #>
    [CmdletBinding()]
    param([object[]]$Gateways = @(), [object[]]$AzureResources = @())

    $pe = @($AzureResources | Where-Object { [string](Get-RangerObjectValue -InputObject $_ -CandidateNames @('ResourceType', 'resourceType')) -match '(?i)privateEndpoints|privateLinkScopes|privateLinkServices' })
    return [ordered]@{
        arcGatewayPresent     = (@($Gateways).Count -gt 0)
        privateEndpointCount  = $pe.Count
        privateLinkResources  = @($pe | ForEach-Object { [ordered]@{ name = [string](Get-RangerObjectValue -InputObject $_ -CandidateNames @('Name', 'name')); type = [string](Get-RangerObjectValue -InputObject $_ -CandidateNames @('ResourceType', 'resourceType')) } })
        likelyPrivatePath     = ((@($Gateways).Count -gt 0) -and $pe.Count -gt 0)
        reference             = 'https://learn.microsoft.com/azure/azure-local/concepts/private-path-network-overview'
    }
}

# --- Fetchers (read-only) ----------------------------------------------------------------------

function Get-RangerArcGatewayAzureResources {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Credential maps hold PSCredential objects or Key Vault references, never a plain-text secret.')]
    param([System.Collections.IDictionary]$Config, $CredentialMap)
    @(Invoke-RangerSafeAction -Label 'Arc gateway resources' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzResource -ErrorAction SilentlyContinue)) { return @() }
                $found = @()
                if (-not [string]::IsNullOrWhiteSpace($ResourceGroup)) {
                    $found = @(Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.HybridCompute/gateways' -ExpandProperties -ErrorAction SilentlyContinue)
                }
                if ($found.Count -eq 0) {
                    # Learn: the gateway only has to be in the same subscription as the deployment.
                    $found = @(Get-AzResource -ResourceType 'Microsoft.HybridCompute/gateways' -ExpandProperties -ErrorAction SilentlyContinue)
                }
                @($found)
            }
        })
}

function Get-RangerNodeArcAgentFacts {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Credential maps hold PSCredential objects or Key Vault references, never a plain-text secret.')]
    param([System.Collections.IDictionary]$Config, $CredentialMap)
    @(Invoke-RangerSafeAction -Label 'Arc agent gateway routing per node' -DefaultValue @() -ScriptBlock {
            Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -ScriptBlock {
                $exe = Join-Path $env:ProgramFiles 'AzureConnectedMachineAgent\azcmagent.exe'
                $show = ''; $check = ''
                if (Test-Path -LiteralPath $exe) {
                    $show = (& $exe show 2>$null | Out-String)
                    $check = (& $exe check 2>$null | Out-String)
                }
                [ordered]@{ node = $env:COMPUTERNAME; show = $show; check = $check }
            }
        }) | ForEach-Object {
        $parsed = ConvertFrom-RangerAzcmagentShow -ShowText ([string]$_.show) -CheckText ([string]$_.check)
        $parsed['node'] = [string]$_.node
        $parsed
    }
}

function Get-RangerSecurityBaselineAzure {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Credential maps hold PSCredential objects or Key Vault references, never a plain-text secret.')]
    param([System.Collections.IDictionary]$Config, $CredentialMap, [string[]]$MachineNames)
    @(foreach ($machine in @($MachineNames | Where-Object { $_ })) {
            $assignment = Invoke-RangerSafeAction -Label "Security baseline assignment ($machine)" -DefaultValue $null -ScriptBlock {
                Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup, $machine) -ScriptBlock {
                    param($SubscriptionId, $ResourceGroup, $MachineName)
                    if (-not (Get-Command -Name Get-AzResource -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return $null }
                    $id = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.HybridCompute/machines/$MachineName/providers/Microsoft.GuestConfiguration/guestConfigurationAssignments/AzureWindowsBaseline"
                    Get-AzResource -ResourceId $id -ExpandProperties -ErrorAction SilentlyContinue
                }
            }
            ConvertTo-RangerSecurityBaselineScore -MachineName $machine -Assignment $assignment
        })
}

function Get-RangerNodeSecureBootFacts {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Credential maps hold PSCredential objects or Key Vault references, never a plain-text secret.')]
    param([System.Collections.IDictionary]$Config, $CredentialMap)
    @(Invoke-RangerSafeAction -Label 'Secure Boot 2023 certificate status per node' -DefaultValue @() -ScriptBlock {
            Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -ScriptBlock {
                $enabled = try { Confirm-SecureBootUEFI -ErrorAction Stop } catch { $null }
                $key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing'
                $item = try { Get-ItemProperty -Path $key -ErrorAction Stop } catch { $null }
                $completed = if (Get-Command -Name Test-AzSSecureBootUpdateCompleted -ErrorAction SilentlyContinue) { try { [bool](Test-AzSSecureBootUpdateCompleted) } catch { $null } } else { $null }
                [ordered]@{
                    node              = $env:COMPUTERNAME
                    secureBootEnabled = $enabled
                    uefiCa2023Status  = if ($item) { [string]$item.UEFICA2023Status } else { $null }
                    uefiCa2023Error   = if ($item) { [string]$item.UEFICA2023Error } else { $null }
                    updateCompleted   = $completed
                }
            }
        }) | ForEach-Object { ConvertTo-RangerSecureBootStatus -Node ([string]$_.node) -Raw $_ }
}

function Get-RangerKeyVaultMetadata {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Credential maps hold PSCredential objects or Key Vault references, never a plain-text secret.')]
    param([System.Collections.IDictionary]$Config, $CredentialMap)
    @(Invoke-RangerSafeAction -Label 'Key Vault metadata in the cluster resource group' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.resourceGroup) -ScriptBlock {
                param($ResourceGroup)
                if (-not (Get-Command -Name Get-AzResource -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                @(Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.KeyVault/vaults' -ExpandProperties -ErrorAction SilentlyContinue)
            }
        })
}

function Get-RangerClusterAdAware {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Credential maps hold PSCredential objects or Key Vault references, never a plain-text secret.')]
    param([System.Collections.IDictionary]$Config, $CredentialMap)
    $r = @(Invoke-RangerSafeAction -Label 'Cluster ADAware parameter' -DefaultValue @() -ScriptBlock {
            Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -SingleTarget -ScriptBlock {
                if (-not (Get-Command -Name Get-ClusterResource -ErrorAction SilentlyContinue)) { return $null }
                try { (Get-Cluster | ForEach-Object { Get-ClusterResource -Name $_.Name } | Get-ClusterParameter -Name ADAware -ErrorAction Stop).Value } catch { $null }
            }
        })
    return $(if ($r.Count -gt 0) { $r[0] } else { $null })
}

function Invoke-RangerPlatform2609Evidence {
    <#
    .SYNOPSIS
        Collects every 12.2609 (latest) evidence block for the workload / identity / Azure collector in one call.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Credential maps hold PSCredential objects or Key Vault references, never a plain-text secret.')]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Config,
        [Parameter(Mandatory)]$CredentialMap,
        [object[]]$AzureResources = @(),
        [object[]]$ArcMachines = @(),
        [object[]]$IdentitySnapshots = @(),
        [string[]]$DnsServers = @()
    )

    $gwRes = Get-RangerArcGatewayAzureResources -Config $Config -CredentialMap $CredentialMap
    $agentFacts = Get-RangerNodeArcAgentFacts -Config $Config -CredentialMap $CredentialMap
    $gw = ConvertTo-RangerArcGatewayEvidence -GatewayResources $gwRes -NodeAgentFacts $agentFacts
    $machineNames = @($ArcMachines | ForEach-Object { [string](Get-RangerObjectValue -InputObject $_ -CandidateNames @('Name', 'name')) } | Where-Object { $_ })
    $baseline = Get-RangerSecurityBaselineAzure -Config $Config -CredentialMap $CredentialMap -MachineNames $machineNames
    $secureBoot = Get-RangerNodeSecureBootFacts -Config $Config -CredentialMap $CredentialMap
    $vaults = Get-RangerKeyVaultMetadata -Config $Config -CredentialMap $CredentialMap
    $keyBackup = ConvertTo-RangerKeyBackupEvidence -Vaults $vaults
    $adAware = Get-RangerClusterAdAware -Config $Config -CredentialMap $CredentialMap
    $local = Get-RangerLocalIdentityEvidence -IdentitySnapshots $IdentitySnapshots -AdAware $adAware -KeyVaults @($keyBackup.backupKeyVaultCandidates | ForEach-Object { $_.name }) -DnsServers $DnsServers
    $private = Get-RangerPrivatePathEvidence -Gateways $gw.arcGateways -AzureResources $AzureResources

    return [ordered]@{
        arcGateways           = $gw.arcGateways
        arcGatewayNodeRouting = $gw.arcGatewayNodeRouting
        securityBaseline      = @($baseline)
        secureBootCertificates = @($secureBoot)
        keyBackup             = $keyBackup
        localIdentity         = $local
        privatePath           = $private
    }
}

function Invoke-RangerPlatform2609Analysis {
    <#
    .SYNOPSIS
        Post-collection derivations that need only the manifest: rack aware summary, SBE detail, storage architecture indicators.
        Idempotent; existing fixture-provided values win.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Manifest)

    $cn = $Manifest.domains.clusterNode
    if ($cn -is [System.Collections.IDictionary]) {
        if (-not $cn.Contains('rackAware')) {
            $nodeNames = @($cn['nodes'] | Where-Object { $_ } | ForEach-Object { [string]$_.name })
            $cn['rackAware'] = Get-RangerRackAwareSummary -FaultDomains @($cn['faultDomains']) -NodeNames $nodeNames
        }
        if (-not $cn.Contains('solutionUpdateDetail')) {
            $up = $cn['updatePosture']
            $env = if ($up -is [System.Collections.IDictionary]) { $up['solutionUpdateEnv'] } else { $null }
            $pending = if ($up -is [System.Collections.IDictionary]) { @($up['pendingSolutionUpdates']) } else { @() }
            if ($env -or $pending.Count -gt 0) { $cn['solutionUpdateDetail'] = Get-RangerSolutionUpdateDetail -Environment $env -Updates $pending }
        }
    }
    # Local identity: add the configured DNS servers and flag servers that sit on a cluster adapter (internal DNS, preview).
    $idSec = $Manifest.domains.identitySecurity
    if ($idSec -is [System.Collections.IDictionary] -and $idSec['localIdentity'] -is [System.Collections.IDictionary]) {
        $li = $idSec['localIdentity']
        $servers = @($Manifest.domains.networking.dns | Where-Object { $_ } | ForEach-Object { [string](Get-RangerObjectValue -InputObject $_ -CandidateNames @('server', 'Server', 'address')) } | Where-Object { $_ } | Select-Object -Unique)
        if (-not $li.Contains('dnsServers') -or @($li['dnsServers']).Count -eq 0) { $li['dnsServers'] = @($servers) }
        $adapterText = ($Manifest.domains.networking.adapters | ConvertTo-Json -Depth 6 -Compress -ErrorAction SilentlyContinue)
        $li['internalDnsPreview'] = ($li['identityMode'] -eq 'local-identity' -and @($servers | Where-Object { $adapterText -and $adapterText.Contains($_) }).Count -gt 0)
    }

    $storage = $Manifest.domains.storage
    if ($storage -is [System.Collections.IDictionary] -and -not $storage.Contains('architectureIndicators')) {
        $storage['architectureIndicators'] = Get-RangerStorageArchitectureIndicators -Manifest $Manifest
    }
    return $Manifest
}
