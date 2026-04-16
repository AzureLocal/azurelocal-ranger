# Issue #30 — Disconnected / semi-connected discovery
#
# Provides a pre-run connectivity matrix that classifies the runner's access posture
# (connected / semi-connected / disconnected) and lets each collector declare its
# transport requirements so the runtime can skip collectors gracefully rather than
# letting them fail mid-run with unhelpful errors.

# ─────────────────────────────────────────────────────────────────────────────
# Azure endpoint reachability probe
# ─────────────────────────────────────────────────────────────────────────────

function Test-RangerAzureConnectivity {
    <#
    .SYNOPSIS
        Probes whether the Azure management plane is reachable from the current runner.
    .OUTPUTS
        Boolean — $true if management.azure.com:443 is reachable within the timeout.
    #>
    param(
        [int]$TimeoutSeconds = 10
    )

    if (-not (Test-RangerCommandAvailable -Name 'Test-NetConnection')) {
        # On platforms without Test-NetConnection fall back to a TCP socket attempt
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $async = $tcp.BeginConnect('management.azure.com', 443, $null, $null)
            $wait = $async.AsyncWaitHandle.WaitOne([System.TimeSpan]::FromSeconds($TimeoutSeconds))
            if ($wait) {
                $tcp.EndConnect($async)
                $tcp.Close()
                return $true
            }
            $tcp.Close()
            return $false
        }
        catch {
            return $false
        }
    }

    try {
        $result = Test-NetConnection -ComputerName 'management.azure.com' -Port 443 `
            -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        return [bool]$result
    }
    catch {
        return $false
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Per-target WinRM reachability probe (non-caching, used in matrix only)
# ─────────────────────────────────────────────────────────────────────────────

function Test-RangerTargetTcpReachability {
    <#
    .SYNOPSIS
        Tests whether a host responds on port 5985 or 5986 within the timeout.
    .OUTPUTS
        Ordered hashtable: { Reachable, Port, TransportHint }
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [int]$TimeoutSeconds = 10
    )

    foreach ($port in @(5985, 5986)) {
        $reachable = $false
        if (Test-RangerCommandAvailable -Name 'Test-NetConnection') {
            try {
                $r = Test-NetConnection -ComputerName $ComputerName -Port $port `
                    -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                $reachable = [bool]$r
            }
            catch { $reachable = $false }
        }
        else {
            try {
                $tcp = New-Object System.Net.Sockets.TcpClient
                $async = $tcp.BeginConnect($ComputerName, $port, $null, $null)
                $wait = $async.AsyncWaitHandle.WaitOne([System.TimeSpan]::FromSeconds($TimeoutSeconds))
                if ($wait) { $tcp.EndConnect($async); $reachable = $true }
                $tcp.Close()
            }
            catch { $reachable = $false }
        }

        if ($reachable) {
            return [ordered]@{
                Reachable     = $true
                Port          = $port
                TransportHint = if ($port -eq 5986) { 'https' } else { 'http' }
            }
        }
    }

    return [ordered]@{
        Reachable     = $false
        Port          = $null
        TransportHint = $null
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Full connectivity matrix
# ─────────────────────────────────────────────────────────────────────────────

function Get-RangerConnectivityMatrix {
    <#
    .SYNOPSIS
        Probes all transport surfaces (cluster WinRM, Azure management plane, BMC HTTPS)
        and returns a structured matrix for the current runner.

    .DESCRIPTION
        Called once before collectors run. Results are stored in manifest.run.connectivity
        and passed to Invoke-RangerCollectorExecution so collectors can skip rather than
        fail when their required transport is unavailable.

    .OUTPUTS
        Ordered hashtable:
        {
            posture          # 'connected' | 'semi-connected' | 'disconnected'
            probeTimeUtc     # ISO-8601 timestamp
            cluster          # { reachable, targets[] }
            azure            # { reachable, endpoint }
            bmc              # { reachable, endpoints[] }
            arc              # { available }    — Arc transport feasibility (set later by #26)
        }
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [int]$TimeoutSeconds = 10
    )

    $probeTime = (Get-Date).ToUniversalTime().ToString('o')
    $clusterReachable = $false
    $clusterTargetResults = New-Object System.Collections.ArrayList

    # — Cluster WinRM probes —
    $clusterTargets = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace([string]$Config.targets.cluster.fqdn) -and
        -not (Test-RangerPlaceholderValue -Value $Config.targets.cluster.fqdn -FieldName 'targets.cluster.fqdn')) {
        $clusterTargets.Add([string]$Config.targets.cluster.fqdn)
    }
    foreach ($node in @($Config.targets.cluster.nodes)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$node) -and
            -not (Test-RangerPlaceholderValue -Value $node -FieldName 'targets.cluster.node') -and
            $node -notin $clusterTargets) {
            $clusterTargets.Add([string]$node)
        }
    }

    foreach ($target in $clusterTargets) {
        $probe = Test-RangerTargetTcpReachability -ComputerName $target -TimeoutSeconds $TimeoutSeconds
        [void]$clusterTargetResults.Add([ordered]@{
            target    = $target
            reachable = $probe.Reachable
            port      = $probe.Port
            transport = $probe.TransportHint
        })
        if ($probe.Reachable) { $clusterReachable = $true }
    }

    # — Azure management plane probe —
    $azureEnabled = (-not [string]::IsNullOrWhiteSpace([string]$Config.targets.azure.subscriptionId) -and
                     -not (Test-RangerPlaceholderValue -Value $Config.targets.azure.subscriptionId -FieldName 'targets.azure.subscriptionId'))
    $azureReachable = $false
    if ($azureEnabled) {
        $azureReachable = Test-RangerAzureConnectivity -TimeoutSeconds $TimeoutSeconds
    }

    # — BMC HTTPS probes —
    $bmcReachable = $false
    $bmcEndpointResults = New-Object System.Collections.ArrayList
    foreach ($ep in @($Config.targets.bmc.endpoints)) {
        $host = if ($ep -is [System.Collections.IDictionary]) { [string]$ep['host'] } else { [string]$ep }
        if ([string]::IsNullOrWhiteSpace($host)) { continue }
        $probe = $false
        if (Test-RangerCommandAvailable -Name 'Test-NetConnection') {
            try {
                $probe = [bool](Test-NetConnection -ComputerName $host -Port 443 `
                    -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue)
            }
            catch { $probe = $false }
        }
        else {
            try {
                $tcp = New-Object System.Net.Sockets.TcpClient
                $async = $tcp.BeginConnect($host, 443, $null, $null)
                $wait = $async.AsyncWaitHandle.WaitOne([System.TimeSpan]::FromSeconds($TimeoutSeconds))
                if ($wait) { $tcp.EndConnect($async); $probe = $true }
                $tcp.Close()
            }
            catch { $probe = $false }
        }
        [void]$bmcEndpointResults.Add([ordered]@{ host = $host; reachable = $probe })
        if ($probe) { $bmcReachable = $true }
    }

    # — Posture classification —
    $posture = switch ($true) {
        ($clusterReachable -and $azureReachable)  { 'connected'; break }
        ($clusterReachable -and -not $azureReachable -and $azureEnabled) { 'semi-connected'; break }
        ($clusterReachable -and -not $azureEnabled) { 'connected'; break }   # Azure not configured — not a degradation
        default { 'disconnected' }
    }

    [ordered]@{
        posture      = $posture
        probeTimeUtc = $probeTime
        cluster      = [ordered]@{
            reachable = $clusterReachable
            targets   = @($clusterTargetResults)
        }
        azure        = [ordered]@{
            reachable = $azureReachable
            enabled   = $azureEnabled
            endpoint  = 'management.azure.com:443'
        }
        bmc          = [ordered]@{
            reachable  = $bmcReachable
            endpoints  = @($bmcEndpointResults)
        }
        arc          = [ordered]@{
            available = $false   # updated by Arc transport init in 40-Execution.ps1 (#26)
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Collector dependency resolution
# ─────────────────────────────────────────────────────────────────────────────

function Test-RangerCollectorConnectivitySatisfied {
    <#
    .SYNOPSIS
        Returns $true if the connectivity matrix satisfies the transport requirements
        of the given collector definition.

    .DESCRIPTION
        Used by Invoke-RangerCollectorExecution to decide whether to skip a collector
        rather than attempt a run that will fail.

        Transport requirements by RequiredCredential:
          'cluster'  → needs cluster.reachable = $true
          'azure'    → needs azure.reachable = $true
          'bmc'      → needs bmc.reachable = $true (only relevant when endpoints configured)
          'none'     → always satisfied
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$Definition,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$ConnectivityMatrix
    )

    switch ($Definition.RequiredCredential) {
        'cluster' {
            return [bool]$ConnectivityMatrix.cluster.reachable
        }
        'azure' {
            # Azure collectors are skippable in disconnected mode; they must not fail the run.
            return [bool]$ConnectivityMatrix.azure.reachable
        }
        'bmc' {
            # BMC is optional; skip gracefully when no endpoints are configured or reachable.
            if (-not $ConnectivityMatrix.bmc.endpoints -or @($ConnectivityMatrix.bmc.endpoints).Count -eq 0) {
                return $false   # no endpoints configured → skip
            }
            return [bool]$ConnectivityMatrix.bmc.reachable
        }
        'none' {
            return $true
        }
        default {
            return $true
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Connectivity finding factory
# ─────────────────────────────────────────────────────────────────────────────

function New-RangerConnectivityFinding {
    <#
    .SYNOPSIS
        Creates a structured finding for a connectivity gap discovered during the matrix probe.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('cluster', 'azure', 'bmc')]
        [string]$Surface,

        [string]$Detail
    )

    $titles = @{
        cluster = 'Cluster WinRM targets unreachable from runner'
        azure   = 'Azure management plane unreachable — Azure-dependent collectors skipped'
        bmc     = 'BMC endpoints unreachable — hardware collector skipped'
    }
    $recs = @{
        cluster = 'Verify network routing and WinRM firewall rules between the runner and cluster nodes. Use Test-NetConnection to diagnose port reachability.'
        azure   = 'Confirm the runner has outbound HTTPS to management.azure.com. In disconnected environments, use Arc Run Command transport or pre-collect Azure data offline.'
        bmc     = 'Confirm BMC endpoint IPs are reachable on port 443 from the runner and that iDRAC/iLO HTTPS is enabled.'
    }

    New-RangerFinding -Severity warning `
        -Title $titles[$Surface] `
        -Description "Connectivity probe detected that the $Surface surface is unreachable." `
        -CurrentState ($Detail ?? 'probe timed out or TCP refused') `
        -Recommendation $recs[$Surface]
}
