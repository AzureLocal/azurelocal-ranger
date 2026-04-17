# Issue #110 / #111 — Arc-first node inventory and domain auto-detection
# Resolver functions that centralise authoritative lookups so collectors can
# call Resolve-RangerNodeInventory / Resolve-RangerDomainContext instead of
# hard-coding a single static-config path.

function Resolve-RangerClusterFqdn {
    <#
    .SYNOPSIS
        v1.6.0 (#203): resolve a short cluster name to an FQDN using TrustedHosts
        and DNS before falling through to a prompt.
    .DESCRIPTION
        Three-step chain:
          1. Passthrough — dotted name is already an FQDN.
          2. WinRM TrustedHosts — match <shortname>.* entries.
          3. DNS — [System.Net.Dns]::GetHostEntry().
        Returns $null when all three fail; caller decides to prompt or throw.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $name = $Name.Trim()
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }

    # Step 1 — passthrough
    if ($name -match '\.') {
        return $name
    }

    $shortName = $name.Split('.')[0]

    # Step 2 — TrustedHosts scan
    try {
        $th = Get-Item -Path WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue
        if ($th -and -not [string]::IsNullOrWhiteSpace($th.Value)) {
            $entries = @($th.Value -split '\s*,\s*' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $match = $entries | Where-Object {
                $_ -match ("^{0}\." -f [regex]::Escape($shortName))
            } | Select-Object -First 1
            if ($match) {
                Write-RangerLog -Level debug -Message "Resolve-RangerClusterFqdn: '$shortName' matched TrustedHosts entry '$match'"
                return $match.Trim()
            }
        }
    } catch {
        Write-RangerLog -Level debug -Message "Resolve-RangerClusterFqdn: TrustedHosts lookup failed — $($_.Exception.Message)"
    }

    # Step 3 — DNS
    try {
        $entry = [System.Net.Dns]::GetHostEntry($shortName)
        if ($entry -and -not [string]::IsNullOrWhiteSpace($entry.HostName) -and $entry.HostName -match '\.') {
            Write-RangerLog -Level debug -Message "Resolve-RangerClusterFqdn: '$shortName' resolved via DNS to '$($entry.HostName)'"
            return $entry.HostName
        }
    } catch {
        Write-RangerLog -Level debug -Message "Resolve-RangerClusterFqdn: DNS GetHostEntry failed for '$shortName' — $($_.Exception.Message)"
    }

    return $null
}

function Resolve-RangerNodeFqdn {
    <#
    .SYNOPSIS
        v1.6.0 (#203): resolve a short node name to an FQDN by appending the
        cluster domain suffix or via DNS.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [string]$ClusterFqdn
    )

    $name = $Name.Trim()
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }

    # Step 1 — passthrough
    if ($name -match '\.') {
        return $name
    }

    # Step 2 — append cluster domain suffix
    if (-not [string]::IsNullOrWhiteSpace($ClusterFqdn) -and $ClusterFqdn -match '\.') {
        $suffix = $ClusterFqdn.Substring($ClusterFqdn.IndexOf('.') + 1)
        if (-not [string]::IsNullOrWhiteSpace($suffix)) {
            return ('{0}.{1}' -f $name, $suffix)
        }
    }

    # Step 3 — DNS
    try {
        $entry = [System.Net.Dns]::GetHostEntry($name)
        if ($entry -and -not [string]::IsNullOrWhiteSpace($entry.HostName) -and $entry.HostName -match '\.') {
            return $entry.HostName
        }
    } catch {
        Write-RangerLog -Level debug -Message "Resolve-RangerNodeFqdn: DNS GetHostEntry failed for '$name' — $($_.Exception.Message)"
    }

    return $null
}

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

    # v1.6.0 (#196): resourceGroup is no longer required — we fall back to a
    # subscription-wide ARM search by resource type + name when RG is missing.
    if ([string]::IsNullOrWhiteSpace($subscriptionId) -or
        $subscriptionId -eq '00000000-0000-0000-0000-000000000000') {
        Write-RangerLog -Level debug -Message 'Resolve-RangerClusterArcResource: subscriptionId not configured — skipping Arc query'
        return $null
    }

    if (-not (Get-Command -Name Get-AzResource -ErrorAction SilentlyContinue)) {
        Write-RangerLog -Level debug -Message 'Resolve-RangerClusterArcResource: Az module unavailable — skipping Arc query'
        return $null
    }

    try {
        $resources = if (-not [string]::IsNullOrWhiteSpace($resourceGroup)) {
            @(Get-AzResource `
                -ResourceType 'microsoft.azurestackhci/clusters' `
                -ResourceGroupName $resourceGroup `
                -ErrorAction Stop)
        }
        elseif (-not [string]::IsNullOrWhiteSpace($clusterName)) {
            # #196: subscription-wide search by type + name when RG is unknown
            Write-RangerLog -Level info -Message "Resolve-RangerClusterArcResource: resourceGroup not configured — searching subscription for HCI cluster '$clusterName'"
            @(Get-AzResource `
                -ResourceType 'microsoft.azurestackhci/clusters' `
                -Name $clusterName `
                -ErrorAction Stop)
        }
        else {
            Write-RangerLog -Level debug -Message 'Resolve-RangerClusterArcResource: neither resourceGroup nor clusterName set — skipping Arc query'
            return $null
        }

        if ($resources.Count -eq 0) {
            $scope = if ($resourceGroup) { "in $resourceGroup" } else { "matching name '$clusterName' in subscription $subscriptionId" }
            Write-RangerLog -Level debug -Message "Resolve-RangerClusterArcResource: no HCI cluster resource found $scope"
            return $null
        }

        # If multiple clusters are returned, narrow by exact name
        $resource = if ($resources.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace($clusterName)) {
            $resources | Where-Object { $_.Name -ieq $clusterName } | Select-Object -First 1
        } else {
            $resources | Select-Object -First 1
        }

        if (-not $resource) {
            if ($resources.Count -gt 1) {
                $names = @($resources | ForEach-Object { $_.Name }) -join ', '
                Write-RangerLog -Level warn -Message "Resolve-RangerClusterArcResource: multiple HCI clusters found in subscription [$names] and clusterName did not uniquely match — cannot auto-resolve"
            }
            return $null
        }

        # #196: when resourceGroup was discovered (not configured), write it back
        # into the resolved config so downstream callers see the discovered value.
        if ([string]::IsNullOrWhiteSpace($resourceGroup) -and $resource.ResourceGroupName) {
            $Config.targets.azure.resourceGroup = [string]$resource.ResourceGroupName
            Write-RangerLog -Level info -Message "Resolve-RangerClusterArcResource: auto-discovered resourceGroup '$($resource.ResourceGroupName)' for cluster '$($resource.Name)'"
        }

        # Fetch extended properties with a versioned API for richer node list
        $fullResource = try {
            Get-AzResource -ResourceId $resource.ResourceId -ApiVersion '2024-02-15-preview' -ExpandProperties -ErrorAction Stop
        } catch {
            Write-RangerLog -Level debug -Message "Resolve-RangerClusterArcResource: full property fetch failed ($($_.Exception.Message)); using basic resource"
            $resource
        }

        Write-RangerLog -Level debug -Message "Resolve-RangerClusterArcResource: resolved Arc resource '$($fullResource.Name)' in $($fullResource.ResourceGroupName)"
        return $fullResource
    }
    catch {
        # v1.6.0 (#206): classify and record the skip so partial runs surface it.
        $cls = Get-RangerArmErrorCategory -ErrorRecord $_
        Add-RangerSkippedResource -Scope 'subscription' -Target $subscriptionId -Category $cls.Category -Reason "Arc cluster query: $($cls.Detail)"
        Write-RangerLog -Level warn -Message "Resolve-RangerClusterArcResource: Arc query skipped ($($cls.Category)) — $($cls.Detail)"
        return $null
    }
}

function Get-RangerArmResourcesByGraph {
    <#
    .SYNOPSIS
        v1.6.0 (#205): single-query ARM discovery via Azure Resource Graph.
    .DESCRIPTION
        Builds a KQL query that returns all requested resource types across
        the specified scope in one round trip. Much faster than per-type
        Get-AzResource loops at scale. Falls back to $null when Az.ResourceGraph
        is unavailable so callers can retry with Get-AzResource.
    .OUTPUTS
        Hashtable keyed by lowercase resource type, each value is an array of
        the matching resources as returned by Search-AzGraph, or $null when
        the Resource Graph path is unusable.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ResourceTypes,

        [string]$SubscriptionId,
        [string]$ResourceGroup,
        [string[]]$ManagementGroups
    )

    if (-not (Get-Command -Name 'Search-AzGraph' -ErrorAction SilentlyContinue)) {
        Write-RangerLog -Level debug -Message 'Get-RangerArmResourcesByGraph: Az.ResourceGraph not installed — caller should fall back to Get-AzResource.'
        return $null
    }

    $types = @($ResourceTypes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.ToLowerInvariant() })
    if ($types.Count -eq 0) { return @{} }

    $quoted = ($types | ForEach-Object { "'$_'" }) -join ', '
    $filters = @("type in~ ($quoted)")
    if (-not [string]::IsNullOrWhiteSpace($ResourceGroup)) {
        $filters += "resourceGroup =~ '$ResourceGroup'"
    }
    $kql = @(
        'resources',
        '| where ' + ($filters -join ' and '),
        '| project id, name, type, location, resourceGroup, subscriptionId, properties, tags'
    ) -join "`n"

    $queryArgs = @{ Query = $kql; ErrorAction = 'Stop' }
    if (-not [string]::IsNullOrWhiteSpace($SubscriptionId)) {
        $queryArgs.Subscription = @($SubscriptionId)
    }
    if ($ManagementGroups -and $ManagementGroups.Count -gt 0) {
        $queryArgs.ManagementGroup = @($ManagementGroups)
    }

    try {
        $rows = @(Search-AzGraph @queryArgs)
    } catch {
        # Classify and record the skip for partial-discovery tracking (#206).
        try {
            $cls = Get-RangerArmErrorCategory -ErrorRecord $_
            $scope = if ($SubscriptionId) { "subscription/$SubscriptionId" } else { 'tenant' }
            Add-RangerSkippedResource -Scope 'resource-graph' -Target $scope -Category $cls.Category -Reason "Search-AzGraph: $($cls.Detail)"
        } catch { }
        Write-RangerLog -Level debug -Message "Get-RangerArmResourcesByGraph: Search-AzGraph failed ($($_.Exception.Message)) — caller should fall back."
        return $null
    }

    $grouped = @{}
    foreach ($t in $types) { $grouped[$t] = New-Object System.Collections.Generic.List[object] }
    foreach ($row in $rows) {
        $key = [string]$row.type
        if ($key) { $key = $key.ToLowerInvariant() }
        if (-not $grouped.ContainsKey($key)) { $grouped[$key] = New-Object System.Collections.Generic.List[object] }
        [void]$grouped[$key].Add($row)
    }

    # Materialise to arrays for easier downstream consumption.
    $result = @{}
    foreach ($k in $grouped.Keys) { $result[$k] = @($grouped[$k]) }
    return $result
}

function Resolve-RangerArcMachinesForCluster {
    <#
    .SYNOPSIS
        v1.6.0 (#204): return Arc machines belonging to the cluster, with a
        subscription-wide fallback when they live outside the cluster RG.
    .OUTPUTS
        [ordered]@{
            Machines  = @(<Az Arc machine resource objects>)
            CrossRg   = @('node-name-in-other-rg', ...)
        }
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [string[]]$NodeHints
    )

    $subscriptionId = $Config.targets.azure.subscriptionId
    $clusterRg      = $Config.targets.azure.resourceGroup
    $result = [ordered]@{ Machines = @(); CrossRg = @() }

    if ([string]::IsNullOrWhiteSpace($subscriptionId) -or
        $subscriptionId -eq '00000000-0000-0000-0000-000000000000' -or
        -not (Get-Command -Name Get-AzResource -ErrorAction SilentlyContinue)) {
        return $result
    }

    $hints = @($NodeHints | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Split('.')[0].ToUpperInvariant() })

    # v1.6.0 (#205): prefer Resource Graph for a single-query fast path.
    $graph = Get-RangerArmResourcesByGraph -ResourceTypes @('microsoft.hybridcompute/machines') -SubscriptionId $subscriptionId
    if ($null -ne $graph -and $graph.ContainsKey('microsoft.hybridcompute/machines')) {
        $merged = New-Object System.Collections.Generic.List[object]
        foreach ($m in @($graph['microsoft.hybridcompute/machines'])) {
            if (-not $m -or -not $m.id) { continue }
            if ($hints.Count -gt 0) {
                $short = [string]$m.name.Split('.')[0].ToUpperInvariant()
                if ($short -notin $hints) { continue }
            }
            # Normalize a resource-like shape so existing callers keep working.
            $wrapped = [pscustomobject]@{
                Name               = [string]$m.name
                ResourceId         = [string]$m.id
                ResourceGroupName  = [string]$m.resourceGroup
                SubscriptionId     = [string]$m.subscriptionId
                Location           = [string]$m.location
                Type               = [string]$m.type
                Properties         = $m.properties
            }
            [void]$merged.Add($wrapped)
            if (-not [string]::IsNullOrWhiteSpace($clusterRg) -and
                $wrapped.ResourceGroupName -and $wrapped.ResourceGroupName -ne $clusterRg) {
                $result.CrossRg += $wrapped.Name
                Write-RangerLog -Level warn -Message ("Resolve-RangerArcMachinesForCluster: node '{0}' found in resource group '{1}' — not in cluster RG '{2}'." -f $wrapped.Name, $wrapped.ResourceGroupName, $clusterRg)
            }
        }
        $result.Machines = @($merged)
        Write-RangerLog -Level debug -Message "Resolve-RangerArcMachinesForCluster: Resource Graph returned $($merged.Count) machine(s)"
        return $result
    }

    # Step 1 — RG-scoped query (fast path).
    $rgMachines = @()
    if (-not [string]::IsNullOrWhiteSpace($clusterRg)) {
        try {
            $rgMachines = @(Get-AzResource -ResourceType 'Microsoft.HybridCompute/machines' -ResourceGroupName $clusterRg -ErrorAction Stop)
        } catch {
            Write-RangerLog -Level debug -Message "Resolve-RangerArcMachinesForCluster: RG-scoped query failed — $($_.Exception.Message)"
        }
    }

    # Decide if we need the subscription-wide fallback. Required when either
    # RG-scoped returned nothing, or its results don't cover all known nodes.
    $need = $hints.Count -gt 0 -and $rgMachines.Count -lt $hints.Count
    if ($rgMachines.Count -eq 0) { $need = $true }

    $subMachines = @()
    if ($need) {
        try {
            $subMachines = @(Get-AzResource -ResourceType 'Microsoft.HybridCompute/machines' -ErrorAction Stop)
        } catch {
            Write-RangerLog -Level debug -Message "Resolve-RangerArcMachinesForCluster: subscription-wide fallback failed — $($_.Exception.Message)"
        }
    }

    # Merge + dedupe by ResourceId
    $seen = New-Object System.Collections.Generic.HashSet[string]
    $merged = New-Object System.Collections.Generic.List[object]
    foreach ($m in @($rgMachines + $subMachines)) {
        if (-not $m -or -not $m.ResourceId) { continue }
        if ($seen.Add([string]$m.ResourceId)) {
            # When node hints are provided, filter by name match.
            if ($hints.Count -gt 0) {
                $short = [string]$m.Name.Split('.')[0].ToUpperInvariant()
                if ($short -notin $hints) { continue }
            }
            [void]$merged.Add($m)
            if (-not [string]::IsNullOrWhiteSpace($clusterRg) -and
                $m.ResourceGroupName -and $m.ResourceGroupName -ne $clusterRg) {
                $result.CrossRg += $m.Name
                Write-RangerLog -Level warn -Message ("Resolve-RangerArcMachinesForCluster: node '{0}' found in resource group '{1}' — not in cluster RG '{2}'." -f $m.Name, $m.ResourceGroupName, $clusterRg)
            }
        }
    }

    $result.Machines = @($merged)
    return $result
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

    # v1.6.0 (#204): when Arc cluster properties did not surface a node list
    # (or when we already have hints from config), supplement with a
    # subscription-wide Arc machines lookup that tolerates cross-RG placement.
    if ($arcNodes.Count -eq 0 -and @($Config.targets.cluster.nodes).Count -gt 0) {
        $hints = @($Config.targets.cluster.nodes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $arcMachines = Resolve-RangerArcMachinesForCluster -Config $Config -NodeHints $hints
        if ($arcMachines.Machines.Count -gt 0) {
            $arcNodes = @($arcMachines.Machines | ForEach-Object { $_.Name })
            $result.Sources += 'arc-machines'
            Write-RangerLog -Level info -Message "Resolve-RangerNodeInventory: Arc machines query returned $($arcNodes.Count) node(s); cross-RG: $($arcMachines.CrossRg.Count)"
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
