function New-RangerManifest {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory = $true)]
        [object[]]$SelectedCollectors,

        [string]$ToolVersion = '0.2.0'
    )

    $targetNodes = @($Config.targets.cluster.nodes)
    [ordered]@{
        run = [ordered]@{
            toolVersion          = $ToolVersion
            schemaVersion        = Get-RangerManifestSchemaVersion
            startTimeUtc         = (Get-Date).ToUniversalTime().ToString('o')
            endTimeUtc           = $null
            mode                 = $Config.output.mode
            runner               = $env:COMPUTERNAME
            includeDomains       = @($Config.domains.include)
            excludeDomains       = @($Config.domains.exclude)
            selectedCollectors   = @($SelectedCollectors | ForEach-Object { $_.Id })
        }
        target = [ordered]@{
            environmentLabel = $Config.environment.name
            clusterName      = $Config.environment.clusterName
            clusterFqdn      = $Config.targets.cluster.fqdn
            resourceGroup    = $Config.targets.azure.resourceGroup
            subscriptionId   = $Config.targets.azure.subscriptionId
            tenantId         = $Config.targets.azure.tenantId
            nodeList         = $targetNodes
        }
        topology      = [ordered]@{}
        collectors    = [ordered]@{}
        domains       = Get-RangerReservedDomainPayloads
        relationships = @()
        findings      = @()
        artifacts     = @()
        evidence      = @()
    }
}

function Save-RangerCollectorEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$CollectorResult,

        [Parameter(Mandatory = $true)]
        [string]$EvidenceRoot,

        [Parameter(Mandatory = $true)]
        [ref]$Manifest
    )

    if (-not $CollectorResult.ContainsKey('RawEvidence') -or $null -eq $CollectorResult.RawEvidence) {
        return
    }

    New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
    $fileName = "{0}.json" -f (Get-RangerSafeName -Value $CollectorResult.CollectorId)
    $filePath = Join-Path -Path $EvidenceRoot -ChildPath $fileName
    $CollectorResult.RawEvidence | ConvertTo-Json -Depth 100 | Set-Content -Path $filePath -Encoding UTF8
    $relativePath = [System.IO.Path]::GetRelativePath((Split-Path -Parent $EvidenceRoot), $filePath)
    $Manifest.Value.evidence += @(
        [ordered]@{
            collector = $CollectorResult.CollectorId
            kind      = 'raw-evidence'
            path      = $relativePath
        }
    )
}

function Add-RangerCollectorToManifest {
    param(
        [Parameter(Mandatory = $true)]
        [ref]$Manifest,

        [Parameter(Mandatory = $true)]
        [hashtable]$CollectorResult,

        [string]$EvidenceRoot,
        [bool]$KeepRawEvidence = $false
    )

    $Manifest.Value.collectors[$CollectorResult.CollectorId] = [ordered]@{
        status          = $CollectorResult.Status
        startTimeUtc    = $CollectorResult.StartTimeUtc
        endTimeUtc      = $CollectorResult.EndTimeUtc
        targetScope     = @($CollectorResult.TargetScope)
        credentialScope = $CollectorResult.CredentialScope
        messages        = @($CollectorResult.Messages)
    }

    if ($CollectorResult.ContainsKey('Topology') -and $CollectorResult.Topology) {
        $Manifest.Value.topology = ConvertTo-RangerHashtable -InputObject $CollectorResult.Topology
    }

    if ($CollectorResult.ContainsKey('Domains')) {
        foreach ($domainKey in $CollectorResult.Domains.Keys) {
            $Manifest.Value.domains[$domainKey] = ConvertTo-RangerHashtable -InputObject $CollectorResult.Domains[$domainKey]
        }
    }

    if ($CollectorResult.ContainsKey('Relationships')) {
        $Manifest.Value.relationships += @(ConvertTo-RangerHashtable -InputObject $CollectorResult.Relationships)
    }

    if ($CollectorResult.ContainsKey('Findings')) {
        $Manifest.Value.findings += @(ConvertTo-RangerHashtable -InputObject $CollectorResult.Findings)
    }

    if ($CollectorResult.ContainsKey('Evidence')) {
        $Manifest.Value.evidence += @(ConvertTo-RangerHashtable -InputObject $CollectorResult.Evidence)
    }

    if ($KeepRawEvidence -and $EvidenceRoot) {
        Save-RangerCollectorEvidence -CollectorResult $CollectorResult -EvidenceRoot $EvidenceRoot -Manifest $Manifest
    }
}

function Save-RangerManifest {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $Manifest.run.endTimeUtc = (Get-Date).ToUniversalTime().ToString('o')
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    $Manifest | ConvertTo-Json -Depth 100 | Set-Content -Path $Path -Encoding UTF8
}

function New-RangerPackageIndex {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,

        [Parameter(Mandatory = $true)]
        [string]$PackageRoot
    )

    $index = [ordered]@{
        environment = $Manifest.target.environmentLabel
        clusterName = $Manifest.target.clusterName
        mode        = $Manifest.run.mode
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        manifest    = [System.IO.Path]::GetRelativePath($PackageRoot, $ManifestPath)
        artifacts   = @($Manifest.artifacts)
    }

    $path = Join-Path -Path $PackageRoot -ChildPath 'package-index.json'
    $index | ConvertTo-Json -Depth 50 | Set-Content -Path $path -Encoding UTF8
    return $path
}