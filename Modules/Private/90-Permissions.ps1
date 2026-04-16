function Reset-RangerSkippedResources {
    <#
    .SYNOPSIS
        v1.6.0 (#206): initialise / clear the skipped-resources tracker.
    #>
    $script:RangerSkippedResources = [System.Collections.Generic.List[object]]::new()
}

function Add-RangerSkippedResource {
    <#
    .SYNOPSIS
        v1.6.0 (#206): record a skipped subscription / resource group / resource.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Scope,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Category,
        [string]$Reason
    )

    if (-not $script:RangerSkippedResources) { Reset-RangerSkippedResources }
    [void]$script:RangerSkippedResources.Add([pscustomobject]@{
        scope     = $Scope
        target    = $Target
        category  = $Category
        reason    = $Reason
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
    })
}

function Get-RangerSkippedResources {
    <#
    .SYNOPSIS
        v1.6.0 (#206): return and clear the skipped-resources tracker.
    #>
    if (-not $script:RangerSkippedResources) { return @() }
    $snapshot = @($script:RangerSkippedResources)
    $script:RangerSkippedResources = [System.Collections.Generic.List[object]]::new()
    return $snapshot
}

function Get-RangerArmErrorCategory {
    <#
    .SYNOPSIS
        v1.6.0 (#206): classify an ARM / Az exception into a stable category
        so callers can decide between skip / retry / abort.
    .OUTPUTS
        Hashtable with:
            Category   : 'Authorization' | 'NetworkUnreachable' | 'NotFound' | 'Throttled' | 'Other'
            Action     : 'Skip' | 'Retry' | 'Warn'
            Detail     : short human-friendly description
    #>
    param(
        [Parameter(Mandatory = $true)]
        $ErrorRecord
    )

    $message = ''
    try {
        if ($ErrorRecord.Exception) { $message = [string]$ErrorRecord.Exception.Message }
        if (-not $message -and $ErrorRecord.ErrorDetails) { $message = [string]$ErrorRecord.ErrorDetails.Message }
    } catch { }

    if ($message -match '(?i)AuthorizationFailed|403|does not have authorization') {
        return @{ Category = 'Authorization'; Action = 'Skip'; Detail = 'Caller is not authorised on the target.' }
    }
    if ($message -match '(?i)getaddrinfo failed|no such host|name or service not known|could not be resolved|No connection could be made|NetworkIssue|A connection attempt failed') {
        return @{ Category = 'NetworkUnreachable'; Action = 'Skip'; Detail = 'ARM endpoint unreachable from this host.' }
    }
    if ($message -match '(?i)ResourceGroupNotFound|ResourceNotFound|SubscriptionNotFound|NotFound|404') {
        return @{ Category = 'NotFound'; Action = 'Skip'; Detail = 'Target resource / resource group / subscription not found.' }
    }
    if ($message -match '(?i)TooManyRequests|throttled|429|SubscriptionRequestsThrottled') {
        return @{ Category = 'Throttled'; Action = 'Retry'; Detail = 'ARM throttling — retry with backoff.' }
    }
    return @{ Category = 'Other'; Action = 'Warn'; Detail = $message }
}

function Invoke-RangerPermissionAudit {
    <#
    .SYNOPSIS
        Core implementation of Test-RangerPermissions (v1.6.0 #202).
    .DESCRIPTION
        Runs a structured pre-run audit against the resolved config. Checks:
          - Az.Accounts context is present
          - Subscription Reader role on target subscription
          - HCI cluster read access (Microsoft.AzureStackHCI/clusters/read)
          - Arc Connected Machine read (Microsoft.HybridCompute/machines/read)
          - Key Vault secret read when keyvault:// refs are present in config
          - Required resource providers registered (AzureStackHCI, HybridCompute)

        Returns a [pscustomobject] with OverallReadiness, Checks, and Recommendations.
        Safe to call with no Azure session — returns Insufficient with guidance.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config
    )

    $checks          = New-Object System.Collections.Generic.List[pscustomobject]
    $recommendations = New-Object System.Collections.Generic.List[string]

    function Add-RangerPermCheck {
        param([string]$Name, [string]$Status, [string]$Message, [string]$Remediation)
        $checks.Add([pscustomobject]@{
            Name        = $Name
            Status      = $Status
            Message     = $Message
            Remediation = $Remediation
        })
        if ($Status -ne 'Pass' -and -not [string]::IsNullOrWhiteSpace($Remediation)) {
            [void]$recommendations.Add($Remediation)
        }
    }

    $subscriptionId = $Config.targets.azure.subscriptionId
    $resourceGroup  = $Config.targets.azure.resourceGroup
    $clusterName    = $Config.environment.clusterName
    $caller         = $null

    # Check 1 — Azure context
    if (-not (Get-Command -Name 'Get-AzContext' -ErrorAction SilentlyContinue)) {
        Add-RangerPermCheck -Name 'Azure context' -Status 'Fail' `
            -Message 'Az.Accounts module is not installed or not importable.' `
            -Remediation 'Install-Module Az.Accounts -Scope CurrentUser -Force'
    }
    else {
        $ctx = Get-AzContext -ErrorAction SilentlyContinue
        if (-not $ctx -or -not $ctx.Account) {
            Add-RangerPermCheck -Name 'Azure context' -Status 'Fail' `
                -Message 'No active Azure authentication context.' `
                -Remediation 'Run Connect-AzAccount, or set credentials.azure.method in config (service-principal, managed-identity, device-code).'
        }
        else {
            $caller = $ctx.Account.Id
            Add-RangerPermCheck -Name 'Azure context' -Status 'Pass' -Message "Signed in as $caller ($($ctx.Account.Type))" -Remediation $null
        }
    }

    # If no context, the rest of the ARM checks will fail. Skip gracefully.
    $hasContext = [bool](Get-AzContext -ErrorAction SilentlyContinue)

    if (-not $hasContext -or [string]::IsNullOrWhiteSpace($subscriptionId) -or $subscriptionId -eq '00000000-0000-0000-0000-000000000000') {
        Add-RangerPermCheck -Name 'Target subscription configured' -Status 'Fail' `
            -Message 'targets.azure.subscriptionId is not set or still a placeholder.' `
            -Remediation 'Set targets.azure.subscriptionId in config or pass -SubscriptionId.'
    }
    else {
        Add-RangerPermCheck -Name 'Target subscription configured' -Status 'Pass' `
            -Message "Subscription $subscriptionId" -Remediation $null

        # Check 2 — Subscription Reader (at minimum): attempt a cheap Get-AzResourceGroup
        try {
            $rgProbe = if (-not [string]::IsNullOrWhiteSpace($resourceGroup)) {
                Get-AzResourceGroup -Name $resourceGroup -ErrorAction Stop
            }
            else {
                # List up to one RG to prove Reader works at subscription scope
                Get-AzResourceGroup -ErrorAction Stop | Select-Object -First 1
            }
            if ($rgProbe) {
                Add-RangerPermCheck -Name 'Subscription Reader' -Status 'Pass' `
                    -Message 'Can list/read resource groups in target subscription.' -Remediation $null
            }
            else {
                Add-RangerPermCheck -Name 'Subscription Reader' -Status 'Warn' `
                    -Message 'No resource groups returned — subscription may be empty or Reader scope is narrower than sub-wide.' `
                    -Remediation 'Verify Reader role on the subscription or at least the target resource group.'
            }
        }
        catch {
            Add-RangerPermCheck -Name 'Subscription Reader' -Status 'Fail' `
                -Message "Get-AzResourceGroup failed: $($_.Exception.Message)" `
                -Remediation 'Grant Reader role on the subscription (or at least the target resource group).'
        }

        # Check 3 — HCI cluster read
        try {
            $hciArgs = @{ ResourceType = 'microsoft.azurestackhci/clusters'; ErrorAction = 'Stop' }
            if (-not [string]::IsNullOrWhiteSpace($resourceGroup)) { $hciArgs['ResourceGroupName'] = $resourceGroup }
            elseif (-not [string]::IsNullOrWhiteSpace($clusterName)) { $hciArgs['Name'] = $clusterName }
            $hci = @(Get-AzResource @hciArgs)
            if ($hci.Count -gt 0) {
                Add-RangerPermCheck -Name 'HCI cluster read' -Status 'Pass' `
                    -Message "Discovered $($hci.Count) microsoft.azurestackhci/clusters resource(s)." -Remediation $null
            }
            else {
                Add-RangerPermCheck -Name 'HCI cluster read' -Status 'Warn' `
                    -Message 'Query succeeded but returned no clusters in the configured scope.' `
                    -Remediation 'Verify clusterName / resourceGroup; or wait for Arc sync if the cluster was registered recently.'
            }
        }
        catch {
            Add-RangerPermCheck -Name 'HCI cluster read' -Status 'Fail' `
                -Message "Get-AzResource for microsoft.azurestackhci/clusters failed: $($_.Exception.Message)" `
                -Remediation 'Grant Azure Stack HCI Reader or Reader on the cluster resource / resource group.'
        }

        # Check 4 — Arc Connected Machine read
        try {
            $arcArgs = @{ ResourceType = 'Microsoft.HybridCompute/machines'; ErrorAction = 'Stop' }
            if (-not [string]::IsNullOrWhiteSpace($resourceGroup)) { $arcArgs['ResourceGroupName'] = $resourceGroup }
            $arc = @(Get-AzResource @arcArgs | Select-Object -First 5)
            Add-RangerPermCheck -Name 'Arc machine read' -Status 'Pass' `
                -Message "Can read Arc-connected machines (sample: $($arc.Count))." -Remediation $null
        }
        catch {
            Add-RangerPermCheck -Name 'Arc machine read' -Status 'Fail' `
                -Message "Get-AzResource for Microsoft.HybridCompute/machines failed: $($_.Exception.Message)" `
                -Remediation 'Grant Azure Connected Machine Resource Reader on the subscription or target resource group.'
        }

        # Check 5 — Required resource provider registrations
        foreach ($providerId in @('Microsoft.AzureStackHCI', 'Microsoft.HybridCompute')) {
            try {
                $rp = Get-AzResourceProvider -ProviderNamespace $providerId -ErrorAction Stop | Select-Object -First 1
                if ($rp -and $rp.RegistrationState -eq 'Registered') {
                    Add-RangerPermCheck -Name "Provider: $providerId" -Status 'Pass' `
                        -Message 'Registered in target subscription.' -Remediation $null
                }
                else {
                    $state = if ($rp) { [string]$rp.RegistrationState } else { 'Unknown' }
                    Add-RangerPermCheck -Name "Provider: $providerId" -Status 'Warn' `
                        -Message "Registration state: $state" `
                        -Remediation "Register-AzResourceProvider -ProviderNamespace $providerId"
                }
            }
            catch {
                Add-RangerPermCheck -Name "Provider: $providerId" -Status 'Warn' `
                    -Message "Could not determine registration state: $($_.Exception.Message)" `
                    -Remediation "Register-AzResourceProvider -ProviderNamespace $providerId (requires Contributor on subscription)."
            }
        }
    }

    # Check 6 — Key Vault access (only when keyvault:// refs exist)
    $kvRefs = New-Object System.Collections.Generic.List[string]
    foreach ($credName in @('cluster', 'domain', 'bmc', 'firewall', 'switch')) {
        $block = $Config.credentials[$credName]
        if ($block -and $block.passwordRef -is [string] -and $block.passwordRef.StartsWith('keyvault://')) {
            [void]$kvRefs.Add([string]$block.passwordRef)
        }
    }
    if ($Config.credentials.azure -and $Config.credentials.azure.clientSecretRef -is [string] -and $Config.credentials.azure.clientSecretRef.StartsWith('keyvault://')) {
        [void]$kvRefs.Add([string]$Config.credentials.azure.clientSecretRef)
    }

    if ($kvRefs.Count -eq 0) {
        Add-RangerPermCheck -Name 'Key Vault access' -Status 'Skip' `
            -Message 'No keyvault:// references in config.' -Remediation $null
    }
    elseif (-not $hasContext) {
        Add-RangerPermCheck -Name 'Key Vault access' -Status 'Warn' `
            -Message 'Cannot verify — Azure context missing.' `
            -Remediation 'Sign in to Azure; Key Vault uses the same identity.'
    }
    else {
        $kvOk = 0; $kvFail = @()
        foreach ($uri in $kvRefs) {
            $parsed = try { ConvertFrom-RangerKeyVaultUri -Uri $uri } catch { $null }
            if (-not $parsed) { continue }
            try {
                $null = Get-AzKeyVaultSecret -VaultName $parsed.VaultName -Name $parsed.SecretName -ErrorAction Stop
                $kvOk++
            } catch {
                $kvFail += "${uri}: $($_.Exception.Message)"
            }
        }
        if ($kvFail.Count -eq 0) {
            Add-RangerPermCheck -Name 'Key Vault access' -Status 'Pass' `
                -Message "$kvOk of $($kvRefs.Count) Key Vault secret(s) readable." -Remediation $null
        }
        else {
            Add-RangerPermCheck -Name 'Key Vault access' -Status 'Fail' `
                -Message "$($kvFail.Count) of $($kvRefs.Count) Key Vault secrets unreadable. First failure: $($kvFail[0])" `
                -Remediation 'Grant the caller Key Vault Secrets User on each referenced vault and confirm network access (VPN/private endpoint).'
        }
    }

    # Aggregate readiness
    $failCount = @($checks | Where-Object { $_.Status -eq 'Fail' }).Count
    $warnCount = @($checks | Where-Object { $_.Status -eq 'Warn' }).Count
    $overall = if ($failCount -gt 0) { 'Insufficient' } elseif ($warnCount -gt 0) { 'Partial' } else { 'Full' }

    [pscustomobject]@{
        OverallReadiness = $overall
        CallerAccount    = $caller
        Checks           = @($checks)
        Recommendations  = @($recommendations)
        GeneratedAt      = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Format-RangerPermissionAuditConsole {
    param([Parameter(Mandatory = $true)]$Result)

    Write-Host ''
    Write-Host '── Ranger Pre-Run Permission Audit ──────' -ForegroundColor Cyan
    if ($Result.CallerAccount) { Write-Host "  Caller: $($Result.CallerAccount)" -ForegroundColor Gray }
    Write-Host ''
    foreach ($c in $Result.Checks) {
        $pad = $c.Name.PadRight(32)
        switch ($c.Status) {
            'Pass' { Write-Host "  [ OK   ] $pad $($c.Message)" -ForegroundColor Green }
            'Warn' { Write-Host "  [ WARN ] $pad $($c.Message)" -ForegroundColor Yellow }
            'Fail' { Write-Host "  [ FAIL ] $pad $($c.Message)" -ForegroundColor Red }
            'Skip' { Write-Host "  [ SKIP ] $pad $($c.Message)" -ForegroundColor DarkGray }
            default { Write-Host "  [ ???? ] $pad $($c.Message)" }
        }
    }
    Write-Host ''
    $color = switch ($Result.OverallReadiness) {
        'Full'         { 'Green' }
        'Partial'      { 'Yellow' }
        'Insufficient' { 'Red' }
        default        { 'Gray' }
    }
    Write-Host "  Overall readiness: $($Result.OverallReadiness)" -ForegroundColor $color
    if ($Result.Recommendations.Count -gt 0) {
        Write-Host ''
        Write-Host '  Remediation steps:' -ForegroundColor Yellow
        foreach ($r in $Result.Recommendations) { Write-Host "    - $r" -ForegroundColor Gray }
    }
    Write-Host ''
}

function Format-RangerPermissionAuditMarkdown {
    param([Parameter(Mandatory = $true)]$Result)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Ranger Permission Audit')
    $lines.Add('')
    $lines.Add("- **Overall readiness:** $($Result.OverallReadiness)")
    if ($Result.CallerAccount) { $lines.Add("- **Caller:** $($Result.CallerAccount)") }
    $lines.Add("- **Generated:** $($Result.GeneratedAt)")
    $lines.Add('')
    $lines.Add('| Check | Status | Detail |')
    $lines.Add('| --- | --- | --- |')
    foreach ($c in $Result.Checks) {
        $lines.Add("| $($c.Name) | $($c.Status) | $($c.Message) |")
    }
    if ($Result.Recommendations.Count -gt 0) {
        $lines.Add('')
        $lines.Add('## Remediation')
        foreach ($r in $Result.Recommendations) { $lines.Add("- $r") }
    }
    return ($lines -join [Environment]::NewLine)
}
