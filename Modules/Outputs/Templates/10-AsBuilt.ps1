function New-RangerAsBuiltDocumentControlSection {
    <#
    .SYNOPSIS
        Returns the document control section payload for an as-built report tier.
    .DESCRIPTION
        Appears at the top of each as-built tier. Records the document identity,
        revision, authors, and handoff status so a receiving team can verify
        provenance. Uses deployment past-tense framing.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [string]$Tier
    )

    $summary   = Get-RangerManifestSummary -Manifest $Manifest
    $packageId = '{0}-as-built-{1}' -f (Get-RangerSafeName -Value $summary.ClusterName), (Get-RangerTimestamp)

    [ordered]@{
        heading = 'Document Control'
        type    = 'kv'
        rows    = @(
            @('Document Title',           "Azure Local As-Built Documentation — $($summary.ClusterName)"),
            @('Package ID',               $packageId),
            @('Report Tier',              $Tier),
            @('Revision',                 '1.0 (initial handoff)'),
            @('Classification',           'CONFIDENTIAL — CUSTOMER DELIVERABLE'),
            @('Prepared By',              'Azure Local Ranger v{0}' -f $Manifest.run.toolVersion),
            @('Prepared On',              $Manifest.run.endTimeUtc),
            @('Schema Version',           $Manifest.run.schemaVersion),
            @('Document Status',          'FINAL — AS-BUILT HANDOFF')
        )
    }
}

function New-RangerAsBuiltInstallationRegisterSection {
    <#
    .SYNOPSIS
        Bill-of-materials / installation register with one row per installed node.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $nodes = @($Manifest.domains.clusterNode.nodes)
    $rows  = @(
        foreach ($n in $nodes) {
            $name   = if ($n.name)  { [string]$n.name }  elseif ($n.NodeName) { [string]$n.NodeName } else { '—' }
            $fqdn   = if ($n.fqdn)  { [string]$n.fqdn }  else { '—' }
            $mfr    = if ($n.manufacturer) { [string]$n.manufacturer } else { '—' }
            $model  = if ($n.model) { [string]$n.model } else { '—' }
            $serial = if ($n.serialNumber) { [string]$n.serialNumber } elseif ($n.serial) { [string]$n.serial } else { 'Not recorded' }
            $bios   = if ($n.biosVersion)  { [string]$n.biosVersion }  else { 'Not recorded' }
            $os     = if ($n.osCaption)    { [string]$n.osCaption }    elseif ($n.operatingSystem) { [string]$n.operatingSystem } else { '—' }
            $build  = if ($n.osVersion)    { [string]$n.osVersion }    elseif ($n.osBuildNumber) { [string]$n.osBuildNumber } else { '—' }
            @($name, $fqdn, $mfr, $model, $serial, $bios, $os, $build)
        }
    )

    [ordered]@{
        heading = 'Installation Register (Bill of Materials)'
        type    = 'table'
        headers = @('Hostname', 'FQDN', 'Manufacturer', 'Model', 'Serial', 'BIOS at Deployment', 'OS Installed', 'OS Build')
        rows    = $rows
        caption = 'Each unit listed above was installed and commissioned as part of this deployment. Serial numbers are recorded as discovered at handoff; missing values indicate the collector could not access the field.'
    }
}

function New-RangerAsBuiltNodeConfigurationSection {
    <#
    .SYNOPSIS
        Per-node configuration record (CPU, memory, domain, BIOS) at deployment.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $nodes = @($Manifest.domains.clusterNode.nodes)
    $rows  = @(
        foreach ($n in $nodes) {
            $name = if ($n.name) { [string]$n.name } else { '—' }
            $cpu  = if ($null -ne $n.logicalProcessorCount) { [string]$n.logicalProcessorCount } elseif ($null -ne $n.processorCount) { [string]$n.processorCount } else { '—' }
            $mem  = if ($null -ne $n.totalMemoryGiB) { "{0} GiB" -f [math]::Round([double]$n.totalMemoryGiB, 0) } elseif ($null -ne $n.memoryGiB) { "{0} GiB" -f [math]::Round([double]$n.memoryGiB, 0) } else { '—' }
            $dom  = if ($n.domain) { [string]$n.domain } else { '—' }
            $bios = if ($n.biosVersion) { [string]$n.biosVersion } else { '—' }
            $state = if ($n.state) { [string]$n.state } else { '—' }
            @($name, $state, $cpu, $mem, $dom, $bios)
        }
    )

    [ordered]@{
        heading = 'Per-Node Configuration Record'
        type    = 'table'
        headers = @('Node', 'State at Handoff', 'Logical CPUs', 'Installed Memory', 'Domain Joined', 'BIOS Version')
        rows    = $rows
        caption = 'Each node was configured with the values above at the time of deployment.'
    }
}

function New-RangerAsBuiltNetworkAllocationSection {
    <#
    .SYNOPSIS
        Cluster network address allocation as configured at deployment.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $networks = @($Manifest.domains.clusterNode.networks)
    $rows = @(
        foreach ($net in $networks) {
            $name   = if ($net.name)         { [string]$net.name } else { '—' }
            $role   = switch ([string]$net.role) {
                '0'       { 'Disabled' }
                '1'       { 'Cluster + Client (Management)' }
                '2'       { 'Cluster Only (Storage)' }
                '3'       { 'Cluster + Client (Workload)' }
                default   { [string]$net.role }
            }
            $addr   = if ($net.address)      { [string]$net.address } else { '—' }
            $mask   = if ($net.addressMask)  { [string]$net.addressMask } else { '—' }
            $metric = if ($net.metric)       { [string]$net.metric } else { '—' }
            $state  = if ($net.state)        { [string]$net.state } else { '—' }
            @($name, $role, $addr, $mask, $metric, $state)
        }
    )

    [ordered]@{
        heading = 'Network Address Allocation Record'
        type    = 'table'
        headers = @('Cluster Network', 'Role', 'Network Address', 'Mask', 'Metric', 'State')
        rows    = $rows
        caption = 'Cluster networks were assigned and configured as recorded above during deployment.'
    }
}

function New-RangerAsBuiltStorageConfigurationSection {
    <#
    .SYNOPSIS
        Storage pools, virtual disks, and CSV layout as deployed.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $pools = @($Manifest.domains.storage.pools)
    $poolRows = @(
        foreach ($p in $pools) {
            $name   = if ($p.friendlyName) { [string]$p.friendlyName } elseif ($p.name) { [string]$p.name } else { '—' }
            $raw    = if ($null -ne $p.rawCapacityGiB)    { '{0} GiB' -f [math]::Round([double]$p.rawCapacityGiB, 0) } elseif ($null -ne $p.size) { '{0} GiB' -f [math]::Round([double]$p.size / 1GB, 0) } else { '—' }
            $usable = if ($null -ne $p.usableCapacityGiB) { '{0} GiB' -f [math]::Round([double]$p.usableCapacityGiB, 0) } else { '—' }
            $health = if ($p.healthStatus)  { [string]$p.healthStatus } else { '—' }
            @($name, $raw, $usable, $health)
        }
    )

    [ordered]@{
        heading = 'Storage Configuration Record'
        type    = 'table'
        headers = @('Storage Pool', 'Raw Capacity', 'Usable Capacity', 'Health at Handoff')
        rows    = $poolRows
        caption = 'Storage pools and their capacities were provisioned at deployment as shown. CSV and virtual-disk details are included in the delivery-registers workbook.'
    }
}

function New-RangerAsBuiltAzureIntegrationSection {
    <#
    .SYNOPSIS
        Azure integration: Arc registration, subscription, RG, extensions.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $az = $Manifest.domains.azureIntegration
    $reg = $Manifest.domains.clusterNode.cluster.registration

    $tenant = if ($reg.tenantId)       { [string]$reg.tenantId }       elseif ($az.context.tenantId)       { [string]$az.context.tenantId }       else { 'Not registered' }
    $sub    = if ($reg.subscriptionId) { [string]$reg.subscriptionId } elseif ($az.context.subscriptionId) { [string]$az.context.subscriptionId } else { 'Not registered' }
    $rg     = if ($reg.resourceGroup)  { [string]$reg.resourceGroup }  elseif ($az.context.resourceGroup)  { [string]$az.context.resourceGroup }  else { 'Not registered' }

    $rows = @(
        ,@('Tenant ID',              $tenant)
        ,@('Subscription ID',        $sub)
        ,@('Resource Group',         $rg)
        ,@('Arc-connected machines', [string](@($az.arcMachineDetail).Count))
        ,@('AKS clusters',           [string](@($az.aksClusters).Count))
        ,@('Azure Monitor Agents',   [string](@($Manifest.domains.monitoring.ama).Count))
        ,@('Backup items',           [string](@($az.backup.items).Count))
        ,@('ASR protected items',    [string](@($az.asr.protectedItems).Count))
    )

    [ordered]@{
        heading = 'Azure Integration Record'
        type    = 'kv'
        rows    = $rows
    }
}

function New-RangerAsBuiltIdentitySecuritySection {
    <#
    .SYNOPSIS
        Identity and security configuration captured at deployment.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $id = $Manifest.domains.identitySecurity
    $summary = Get-RangerManifestSummary -Manifest $Manifest

    $idMode  = if ($Manifest.topology.identityMode)  { [string]$Manifest.topology.identityMode } else { '—' }
    $adSite  = if ($id.activeDirectory.adSite)       { [string]$id.activeDirectory.adSite } else { 'Not collected' }
    $bl      = if ($id.security.bitlockerEnabled -eq $true) { 'Enabled at deployment' } elseif ($id.security.bitlockerEnabled -eq $false) { 'Disabled at deployment' } else { 'Not collected' }
    $wdac    = if ($id.security.wdacPolicy)          { [string]$id.security.wdacPolicy } else { 'Not collected' }

    $rows = @(
        ,@('Identity mode',                 $idMode)
        ,@('Active Directory site',         $adSite)
        ,@('Secured-Core nodes enrolled',   ("{0} of {1}" -f $id.summary.securedCoreNodes, $summary.NodeCount))
        ,@('BitLocker',                     $bl)
        ,@('WDAC policy',                   $wdac)
        ,@('Certificates tracked',          [string]@($id.posture.certificates).Count)
        ,@('Certificates expiring <90d',    [string]$id.summary.certificateExpiringWithin90Days)
        ,@('RBAC assignments at RG scope',  [string]@($id.rbacAssignments).Count)
    )

    [ordered]@{
        heading = 'Identity and Security Record'
        type    = 'kv'
        rows    = $rows
    }
}

function New-RangerAsBuiltValidationRecordSection {
    <#
    .SYNOPSIS
        Validation record — cluster validation report reference and collector pass/fail.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $summary = Get-RangerManifestSummary -Manifest $Manifest

    # Reference the cluster validation report file when recorded under updatePosture
    $validationFileHint = $null
    try {
        $reportName = $Manifest.domains.clusterNode.updatePosture.clusterAwareUpdating.lastTestClusterReport
        if ($reportName) { $validationFileHint = [string]$reportName }
    } catch { }

    $validationRef = if ($validationFileHint) { $validationFileHint } else { 'See cluster-validation report artifact (Test-Cluster output)' }
    $schemaVal     = if ($Manifest.run.schemaValidation.isValid) { 'Passed' } elseif ($null -eq $Manifest.run.schemaValidation.isValid) { 'Not recorded' } else { 'Failed' }

    $rows = @(
        ,@('Validation report',      $validationRef)
        ,@('Collectors run',         [string]$summary.TotalCollectors)
        ,@('Collectors successful',  [string]$summary.SuccessfulCollectors)
        ,@('Collectors partial',     [string]$summary.PartialCollectors)
        ,@('Collectors failed',      [string]$summary.FailedCollectors)
        ,@('Schema validation',      $schemaVal)
        ,@('Critical findings',      [string]$summary.FindingsBySeverity.critical)
        ,@('Warning findings',       [string]$summary.FindingsBySeverity.warning)
    )

    [ordered]@{
        heading = 'Validation Record'
        type    = 'kv'
        rows    = $rows
    }
}

function New-RangerAsBuiltDeviationsSection {
    <#
    .SYNOPSIS
        Known issues / deviations from design — sourced from critical+warning findings.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $deviations = @($Manifest.findings | Where-Object { $_.severity -in @('critical', 'warning') } | Select-Object -First 20)
    if ($deviations.Count -eq 0) {
        return [ordered]@{
            heading = 'Known Issues and Deviations'
            body    = @('No critical or warning-level deviations were recorded at handoff.')
        }
    }

    $rows = @(
        foreach ($d in $deviations) {
            @(
                [string]$d.severity.ToUpperInvariant(),
                [string]($d.title ?? '—'),
                [string]($d.description ?? '—'),
                [string]($d.recommendation ?? 'Accepted as-built; to be remediated under operations.')
            )
        }
    )

    [ordered]@{
        heading = 'Known Issues and Deviations'
        type    = 'table'
        headers = @('Severity', 'Item', 'Deviation', 'Remediation Path')
        rows    = $rows
        caption = 'Deviations listed below were documented at handoff. Items are accepted as-built unless explicitly marked for follow-up remediation.'
    }
}

function New-RangerAsBuiltSignOffSection {
    [ordered]@{
        heading = 'Acceptance and Sign-Off'
        type    = 'sign-off'
    }
}
