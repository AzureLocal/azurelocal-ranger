# Issue #110 / #111 — Arc-first node inventory and domain auto-detection
# Resolver functions that centralise authoritative lookups so collectors can
# call Resolve-RangerNodeInventory / Resolve-RangerDomainContext instead of
# hard-coding a single static-config path.

function Resolve-RangerClusterArcResource {
    <#
    .SYNOPSIS
        Fetches the microsoft.azurestackhci/clusters Arc resource for the configured environment.
    .NOTES
        Returns $null gracefully when Arc is unavailable or the Az module is not signed in.
        Callers must always null-check the return value.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config
    )

    $subscriptionId = $Config.targets.azure.subscriptionId
    $resourceGroup  = $Config.targets.azure.resourceGroup
    $clusterName    = $Config.environment.clusterName

    if ([string]::IsNullOrWhiteSpace($subscriptionId) -or
        $subscriptionId -eq '00000000-0000-0000-0000-000000000000' -or
        [string]::IsNullOrWhiteSpace($resourceGroup)) {
        Write-RangerLog -Level debug -Message 'Resolve-RangerClusterArcResource: Azure target not configured — skipping Arc query'
        return $null
    }

    if (-not (Get-Command -Name Get-AzResource -ErrorAction SilentlyContinue)) {
        Write-RangerLog -Level debug -Message 'Resolve-RangerClusterArcResource: Az module unavailable — skipping Arc query'
        return $null
    }

    try {
        $resources = @(Get-AzResource `
            -ResourceType 'microsoft.azurestackhci/clusters' `
            -ResourceGroupName $resourceGroup `
            -ErrorAction Stop)

        if ($resources.Count -eq 0) {
            Write-RangerLog -Level debug -Message "Resolve-RangerClusterArcResource: no HCI cluster resource found in $resourceGroup"
            return $null
        }

        # If there are multiple clusters in the RG, narrow by name
        $resource = if ($resources.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace($clusterName)) {
            $resources | Where-Object { $_.Name -ieq $clusterName } | Select-Object -First 1
        } else {
            $resources | Select-Object -First 1
        }

        if (-not $resource) {
            return $null
        }

        # Fetch extended properties with a versioned API for richer node list
        $fullResource = try {
            Get-AzResource -ResourceId $resource.ResourceId -ApiVersion '2024-02-15-preview' -ExpandProperties -ErrorAction Stop
        } catch {
            Write-RangerLog -Level debug -Message "Resolve-RangerClusterArcResource: full property fetch failed ($($_.Exception.Message)); using basic resource"
            $resource
        }

        Write-RangerLog -Level debug -Message "Resolve-RangerClusterArcResource: resolved Arc resource '$($fullResource.Name)' in $resourceGroup"
        return $fullResource
    }
    catch {
        Write-RangerLog -Level debug -Message "Resolve-RangerClusterArcResource: Arc query failed — $($_.Exception.Message)"
        return $null
    }
}

function Resolve-RangerNodeInventory {
    <#
    .SYNOPSIS
        Resolves the list of cluster node FQDNs using Arc-first, direct-cluster, then static-config priority.
    .OUTPUTS
        [ordered]@{
            Nodes         = @('node01.fqdn', ...)
            Sources       = @('arc' | 'direct' | 'config')
            Discrepancies = @('node05.fqdn')   # nodes in one source but not the other
            ArcResource   = <Az resource object or $null>
        }
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [PSCredential]$ClusterCredential
    )

    $result = [ordered]@{
        Nodes         = @()
        Sources       = @()
        Discrepancies = @()
        ArcResource   = $null
    }

    # ── Priority 1: Azure Arc  ───────────────────────────────────────────────
    $arcResource = Resolve-RangerClusterArcResource -Config $Config
    $result.ArcResource = $arcResource
    $arcNodes = @()

    if ($arcResource -and $arcResource.Properties) {
        $props = $arcResource.Properties
        # HCI cluster resource surfaces nodes under properties.nodes[] as objects
        # with a 'name' field, or as a flat string array depending on API version
        $rawNodes = if ($props.nodes) { @($props.nodes) } else { @() }
        $arcNodes = @($rawNodes | ForEach-Object {
            $n = if ($_ -is [string]) { $_ } elseif ($_.name) { $_.name } else { $null }
            $n
        } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

        if ($arcNodes.Count -gt 0) {
            $result.Sources += 'arc'
            Write-RangerLog -Level info -Message "Resolve-RangerNodeInventory: Arc returned $($arcNodes.Count) nodes"
        }
    }

    # ── Priority 2: Direct cluster scan  ─────────────────────────────────────
    $directNodes = @()
    try {
        $clusterTarget = if (-not [string]::IsNullOrWhiteSpace($Config.targets.cluster.fqdn)) {
            $Config.targets.cluster.fqdn
        } elseif ($Config.targets.cluster.nodes -and @($Config.targets.cluster.nodes).Count -gt 0) {
            @($Config.targets.cluster.nodes)[0]
        } else { $null }

        if ($clusterTarget) {
            $retryCount = if ($Config.behavior -and $Config.behavior.retryCount -gt 0) { [int]$Config.behavior.retryCount } else { 1 }
            $timeoutSec = if ($Config.behavior -and $Config.behavior.timeoutSeconds -gt 0) { [int]$Config.behavior.timeoutSeconds } else { 0 }
            $rawDirectNodes = @(Invoke-RangerRemoteCommand -ComputerName @($clusterTarget) -Credential $ClusterCredential -RetryCount $retryCount -TimeoutSeconds $timeoutSec -ScriptBlock {
                if (Get-Command Get-ClusterNode -ErrorAction SilentlyContinue) {
                    @(Get-ClusterNode | Select-Object -ExpandProperty Name)
                }
                else {
                    @()
                }
            })
            $directNodes = @($rawDirectNodes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

            # Get-ClusterNode returns short NetBIOS names — reconcile back to
            # config FQDNs where they match, so callers keep the full FQDN.
            if ($directNodes.Count -gt 0 -and $Config.targets.cluster.nodes) {
                $directNodes = @($directNodes | ForEach-Object {
                    $shortName   = $_.Split('.')[0].ToUpperInvariant()
                    $configMatch = @($Config.targets.cluster.nodes) | Where-Object {
                        $_.Split('.')[0].ToUpperInvariant() -eq $shortName
                    } | Select-Object -First 1
                    if ($configMatch) { $configMatch } else { $_ }
                })
            }

            if ($directNodes.Count -gt 0) {
                $result.Sources += 'direct'
                Write-RangerLog -Level info -Message "Resolve-RangerNodeInventory: direct scan returned $($directNodes.Count) nodes"
            }
        }
    }
    catch {
        Write-RangerLog -Level debug -Message "Resolve-RangerNodeInventory: direct cluster scan failed — $($_.Exception.Message)"
    }

    # ── Discrepancy check between Arc and direct  ────────────────────────────
    if ($arcNodes.Count -gt 0 -and $directNodes.Count -gt 0) {
        $arcSet    = @($arcNodes    | ForEach-Object { $_.Split('.')[0].ToUpperInvariant() })
        $directSet = @($directNodes | ForEach-Object { $_.Split('.')[0].ToUpperInvariant() })
        $onlyInArc    = @($arcSet    | Where-Object { $_ -notin $directSet })
        $onlyInDirect = @($directSet | Where-Object { $_ -notin $arcSet })
        if ($onlyInArc.Count -gt 0 -or $onlyInDirect.Count -gt 0) {
            $result.Discrepancies = @($onlyInArc + $onlyInDirect)
            Write-RangerLog -Level warn -Message "Resolve-RangerNodeInventory: Arc/direct node lists differ — arc-only: [$($onlyInArc -join ', ')], direct-only: [$($onlyInDirect -join ', ')]"
        }
    }

    # ── Select best node list  ────────────────────────────────────────────────
    if ($arcNodes.Count -gt 0) {
        $result.Nodes = $arcNodes
    } elseif ($directNodes.Count -gt 0) {
        $result.Nodes = $directNodes
    } else {
        # Priority 3: static config fallback
        $configNodes = @($Config.targets.cluster.nodes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($configNodes.Count -gt 0) {
            $result.Nodes   = $configNodes
            $result.Sources += 'config'
            Write-RangerLog -Level warn -Message "Resolve-RangerNodeInventory: using static config node list ($($configNodes.Count) nodes) — Arc and direct scan were unavailable"
        } else {
            Write-RangerLog -Level warn -Message "Resolve-RangerNodeInventory: no node source succeeded; node list is empty"
        }
    }

    return $result
}

function Resolve-RangerDomainContext {
    <#
    .SYNOPSIS
        Auto-detects the AD domain context for the cluster using Arc, CIM, and credential hints.
        Returns a workgroup indicator when no domain is found.
    .OUTPUTS
        [ordered]@{
            FQDN        = 'contoso.local'   # or $null for workgroup
            NetBIOS     = 'CONTOSO'         # or $null
            ResolvedBy  = 'arc' | 'node-cim' | 'config-credential' | 'none'
            IsWorkgroup = $false
            Confidence  = 'high' | 'medium' | 'low'
        }
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        $ArcResource,            # pass the object already fetched by Resolve-RangerClusterArcResource

        [PSCredential]$ClusterCredential
    )

    $ctx = [ordered]@{
        FQDN        = $null
        NetBIOS     = $null
        ResolvedBy  = 'none'
        IsWorkgroup = $false
        Confidence  = 'low'
    }

    # ── Priority 1: Azure Arc properties.domainName  ─────────────────────────
    if ($ArcResource -and $ArcResource.Properties -and
        -not [string]::IsNullOrWhiteSpace($ArcResource.Properties.domainName)) {

        $fqdn = $ArcResource.Properties.domainName.Trim()
        if ($fqdn -match '\.') {
            $ctx.FQDN       = $fqdn
            $ctx.NetBIOS    = $fqdn.Split('.')[0].ToUpperInvariant()
            $ctx.ResolvedBy = 'arc'
            $ctx.Confidence = 'high'
            Write-RangerLog -Level info -Message "Resolve-RangerDomainContext: domain '$fqdn' resolved from Arc"
            return $ctx
        }
    }

    # ── Priority 2: Live CIM on first reachable node  ─────────────────────────
    # Build a list: cluster FQDN first, then individual nodes as fallback.
    $cimCandidates = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($Config.targets.cluster.fqdn)) { $cimCandidates.Add($Config.targets.cluster.fqdn) }
    if ($Config.targets.cluster.nodes) { foreach ($n in @($Config.targets.cluster.nodes)) { if ($n -notin $cimCandidates) { $cimCandidates.Add($n) } } }

    $cs = $null
    $firstNode = $null
    $retryCount = if ($Config.behavior -and $Config.behavior.retryCount -gt 0) { [int]$Config.behavior.retryCount } else { 1 }
    $timeoutSec = if ($Config.behavior -and $Config.behavior.timeoutSeconds -gt 0) { [int]$Config.behavior.timeoutSeconds } else { 0 }
    foreach ($candidate in $cimCandidates) {
        try {
            $cs = Invoke-RangerRemoteCommand -ComputerName @($candidate) -Credential $ClusterCredential -RetryCount $retryCount -TimeoutSeconds $timeoutSec -ScriptBlock {
                $computerSystem = Get-CimInstance -ClassName 'Win32_ComputerSystem' -ErrorAction Stop
                [ordered]@{
                    Domain       = $computerSystem.Domain
                    PartOfDomain = [bool]$computerSystem.PartOfDomain
                    Workgroup    = $computerSystem.Workgroup
                }
            } | Select-Object -First 1
            $firstNode = $candidate
            break
        }
        catch {
            Write-RangerLog -Level debug -Message "Resolve-RangerDomainContext: CIM query failed on $candidate — $($_.Exception.Message)"
        }
    }

    if ($firstNode -and $cs) {
        if ($cs.PartOfDomain -and -not [string]::IsNullOrWhiteSpace($cs.Domain) -and $cs.Domain -match '\.') {
            $fqdn = $cs.Domain.Trim()
            $ctx.FQDN       = $fqdn
            $ctx.NetBIOS    = $fqdn.Split('.')[0].ToUpperInvariant()
            $ctx.ResolvedBy = 'node-cim'
            $ctx.Confidence = 'high'
            Write-RangerLog -Level info -Message "Resolve-RangerDomainContext: domain '$fqdn' resolved from node CIM ($firstNode)"
            return $ctx
        } elseif (-not $cs.PartOfDomain) {
            $ctx.IsWorkgroup = $true
            $ctx.ResolvedBy  = 'node-cim'
            $ctx.Confidence  = 'high'
            Write-RangerLog -Level info -Message "Resolve-RangerDomainContext: cluster is workgroup-joined (confirmed by CIM on $firstNode)"
            return $ctx
        }
    }

    # ── Priority 3: Parse domain account username  ────────────────────────────
    $domainUsername = $Config.credentials.domain.username
    if (-not [string]::IsNullOrWhiteSpace($domainUsername)) {
        # UPN format:  user@contoso.com
        if ($domainUsername -match '^[^@]+@([A-Za-z0-9.-]+\.[A-Za-z]{2,})$') {
            $fqdn = $Matches[1].Trim().ToLowerInvariant()
            $ctx.FQDN       = $fqdn
            $ctx.NetBIOS    = $fqdn.Split('.')[0].ToUpperInvariant()
            $ctx.ResolvedBy = 'config-credential'
            $ctx.Confidence = 'medium'
            Write-RangerLog -Level info -Message "Resolve-RangerDomainContext: domain '$fqdn' inferred from UPN credential"
            return $ctx
        }
        # DOMAIN\user format
        if ($domainUsername -match '^([A-Za-z0-9_-]+)\\') {
            $netbios = $Matches[1].Trim().ToUpperInvariant()
            $ctx.NetBIOS    = $netbios
            $ctx.ResolvedBy = 'config-credential'
            $ctx.Confidence = 'medium'
            # No FQDN from NetBIOS alone — leave FQDN null
            Write-RangerLog -Level info -Message "Resolve-RangerDomainContext: NetBIOS '$netbios' inferred from domain credential (FQDN unknown)"
            return $ctx
        }
    }

    # ── Priority 4: Workgroup fallback  ──────────────────────────────────────
    $ctx.IsWorkgroup = $true
    $ctx.Confidence  = 'low'
    Write-RangerLog -Level warn -Message 'Resolve-RangerDomainContext: could not resolve domain context — assuming workgroup or unavailable'
    return $ctx
}
