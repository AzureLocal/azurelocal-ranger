function New-RangerAsBuiltDocumentControlSection {
    <#
    .SYNOPSIS
        Returns the document control section payload for an as-built report tier.
    .DESCRIPTION
        The document control block appears at the top of each as-built tier report.
        It records environment identity, package ID, tool version, and handoff status
        so a receiving team can verify the provenance of the document.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [string]$Tier
    )

    $summary = Get-RangerManifestSummary -Manifest $Manifest

    $packageId = '{0}-as-built-{1}' -f (Get-RangerSafeName -Value $summary.ClusterName), (Get-RangerTimestamp)

    [ordered]@{
        heading = 'Document Control'
        type    = 'kv'
        rows    = @(
            @('Environment',              $summary.ClusterName),
            @('Package ID',               $packageId),
            @('Report Tier',              $Tier),
            @('Tool Version',             $Manifest.run.toolVersion),
            @('Discovery Run Completed',  $Manifest.run.endTimeUtc),
            @('Schema Version',           $Manifest.run.schemaVersion),
            @('Document Status',          'FINAL — AS-BUILT HANDOFF')
        )
    }
}

function New-RangerAsBuiltInstallationRegisterSection {
    <#
    .SYNOPSIS
        Returns the installation register section for an as-built report.
    .DESCRIPTION
        The installation register summarises the key platform parameters documented
        during the implementation. This section is intended for technical and management
        tiers and is omitted from executive summaries.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $summary = Get-RangerManifestSummary -Manifest $Manifest
    $clusterNode = $Manifest.domains.clusterNode
    $storage     = $Manifest.domains.storage
    $azureInt    = $Manifest.domains.azureIntegration

    $nodeList = @($clusterNode.nodes | ForEach-Object {
        $n = $_
        $name = if ($n.Name) { $n.Name } elseif ($n.NodeName) { $n.NodeName } else { '(unknown)' }
        $state = if ($n.State) { $n.State } elseif ($n.NodeState) { $n.NodeState } else { '(unknown)' }
        '{0} ({1})' -f $name, $state
    })

    [ordered]@{
        heading = 'Installation Register'
        body    = @(
            "Cluster FQDN: $($clusterNode.cluster.FQDN ?? $clusterNode.cluster.Name ?? '(not recorded)')",
            "Node count: $($summary.NodeCount)",
            "Nodes: $(if ($nodeList.Count -gt 0) { $nodeList -join ', ' } else { '(not recorded)' })",
            "Deployment type: $($summary.DeploymentType)",
            "Identity mode: $($summary.IdentityMode)",
            "Connectivity mode: $($summary.ControlPlaneMode)",
            "Storage architecture: $($Manifest.topology.storageArchitecture)",
            "Network architecture: $($Manifest.topology.networkArchitecture)",
            "Storage pool count: $(@($storage.pools).Count)",
            "Physical disk count: $(@($storage.physicalDisks).Count)",
            "Azure subscription: $($azureInt.context.subscriptionId ?? '(not recorded)')",
            "Azure resource group: $($azureInt.context.resourceGroup ?? '(not recorded)')",
            "VM count: $($summary.VmCount)"
        )
    }
}

function New-RangerAsBuiltSignOffSection {
    <#
    .SYNOPSIS
        Returns the sign-off section for an as-built report.
    .DESCRIPTION
        The sign-off block provides a structured handoff acknowledgment.
        The table is intentionally left empty for human completion after review.
    #>
    [ordered]@{
        heading = 'Sign-Off'
        type    = 'sign-off'
    }
}
