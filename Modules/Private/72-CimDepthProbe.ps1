function Invoke-RangerCimDepthProbe {
    <#
    .SYNOPSIS
        v2.1.0 (#234): deep WinRM credential verification.
    .DESCRIPTION
        After WinRM preflight selects a credential, confirm the credential can
        actually read the CIM namespaces Ranger needs. An account with valid
        WinRM logon rights but no WMI / DCOM access rights passes the shallow
        preflight, then collectors fail mid-run with 'Invalid namespace' or
        'Access denied' from deep in Get-CimInstance.

        Issues one probe per representative namespace against the first
        reachable target:

          - root/MSCluster                  -> MSCluster_Cluster
          - root/virtualization/v2          -> Msvm_VirtualSystemManagementService
          - root/Microsoft/Windows/Storage  -> MSFT_StoragePool

        Returns a hashtable with overall CimDepth status:

          - 'sufficient'  all probes succeeded
          - 'partial'     one or more namespaces denied (warn, do not throw)
          - 'denied'      every probe failed (caller decides whether to throw)
          - 'skipped'     no reachable target or no credential
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Targets,
        [pscredential]$Credential,
        [int]$TimeoutSeconds = 15
    )

    if (-not $Targets -or $Targets.Count -eq 0) {
        return [ordered]@{ status = 'skipped'; reason = 'No targets supplied to CIM depth probe.'; probes = @() }
    }

    # Pick the first target that already resolves — the shallow preflight has
    # been run before us, so a DNS-resolvable name is a safe assumption.
    $target = [string]$Targets[0]

    $namespaces = @(
        [ordered]@{ Namespace = 'root/MSCluster';                  ClassName = 'MSCluster_Cluster';                  Label = 'Failover Cluster (MSCluster)' }
        [ordered]@{ Namespace = 'root/virtualization/v2';          ClassName = 'Msvm_VirtualSystemManagementService';Label = 'Hyper-V (virtualization/v2)' }
        [ordered]@{ Namespace = 'root/Microsoft/Windows/Storage';  ClassName = 'MSFT_StoragePool';                   Label = 'Storage Spaces (Storage)' }
    )

    $cimSession = $null
    try {
        $cimArgs = @{ ComputerName = $target; OperationTimeoutSec = $TimeoutSeconds; ErrorAction = 'Stop' }
        if ($Credential) { $cimArgs['Credential'] = $Credential }
        $cimSession = New-CimSession @cimArgs
    }
    catch {
        return [ordered]@{
            status  = 'skipped'
            reason  = "Could not establish a CIM session to $target : $($_.Exception.Message)"
            target  = $target
            probes  = @()
        }
    }

    $probes = New-Object System.Collections.Generic.List[pscustomobject]
    try {
        foreach ($ns in $namespaces) {
            $probe = [ordered]@{
                namespace = $ns.Namespace
                className = $ns.ClassName
                label     = $ns.Label
                status    = 'unknown'
                message   = $null
            }
            try {
                $null = Get-CimInstance -CimSession $cimSession -Namespace $ns.Namespace -ClassName $ns.ClassName -ErrorAction Stop | Select-Object -First 1
                $probe.status = 'ok'
            }
            catch {
                $msg = [string]$_.Exception.Message
                $probe.message = $msg
                if ($msg -match '(?i)Access is denied|0x80070005|HRESULT\s*:\s*0x80041003|WMI.*authoriz') {
                    $probe.status = 'denied'
                }
                elseif ($msg -match '(?i)Invalid namespace|WBEM_E_INVALID_NAMESPACE|0x8004100E') {
                    $probe.status = 'missing-namespace'
                }
                else {
                    $probe.status = 'error'
                }
            }
            [void]$probes.Add([pscustomobject]$probe)
        }
    }
    finally {
        if ($cimSession) {
            try { Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue } catch { }
        }
    }

    $okCount     = @($probes | Where-Object { $_.status -eq 'ok' }).Count
    $deniedCount = @($probes | Where-Object { $_.status -in @('denied','error','missing-namespace') }).Count

    $overall = if ($okCount -eq $namespaces.Count) { 'sufficient' }
               elseif ($okCount -eq 0)              { 'denied' }
               else                                   { 'partial' }

    return [ordered]@{
        status      = $overall
        target      = $target
        probedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        probes      = @($probes)
        summary     = [ordered]@{
            total   = $namespaces.Count
            ok      = $okCount
            denied  = $deniedCount
        }
    }
}
