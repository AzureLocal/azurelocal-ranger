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
            unattended           = $false
            runner               = $env:COMPUTERNAME
            includeDomains       = @($Config.domains.include)
            excludeDomains       = @($Config.domains.exclude)
            selectedCollectors   = @($SelectedCollectors | ForEach-Object { $_.Id })
            baselineManifestPath = $null
            drift                = [ordered]@{
                status        = 'not-requested'
                summary       = [ordered]@{}
                skippedReason = $null
            }
            schemaValidation     = [ordered]@{ isValid = $null; errors = @(); warnings = @() }
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

function Get-RangerManifestSchemaContract {
    $schemaPath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\repo-management\contracts\manifest-schema.json'
    $resolvedPath = [System.IO.Path]::GetFullPath($schemaPath)
    if (-not (Test-Path -Path $resolvedPath)) {
        throw "Manifest schema contract file was not found: $resolvedPath"
    }

    return Get-Content -Path $resolvedPath -Raw | ConvertFrom-Json -Depth 50
}

function Test-RangerManifestSchema {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [object[]]$SelectedCollectors
    )

    $errors = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]
    $schemaContract = Get-RangerManifestSchemaContract

    foreach ($requiredKey in @($schemaContract.requiredTopLevelKeys)) {
        if (-not $Manifest.Contains($requiredKey)) {
            $errors.Add("Manifest is missing required top-level key '$requiredKey'.")
        }
    }

    if ($Manifest.run.schemaVersion -ne $schemaContract.schemaVersion) {
        $warnings.Add("Manifest schemaVersion '$($Manifest.run.schemaVersion)' does not match schema contract version '$($schemaContract.schemaVersion)'.")
    }

    foreach ($runKey in @($schemaContract.requiredRunKeys)) {
        if (-not $Manifest.run.Contains($runKey) -or $null -eq $Manifest.run[$runKey] -or [string]::IsNullOrWhiteSpace([string]$Manifest.run[$runKey])) {
            $errors.Add("Manifest.run is missing required value '$runKey'.")
        }
    }

    foreach ($reservedDomain in @($schemaContract.reservedDomains)) {
        if (-not $Manifest.domains.Contains($reservedDomain)) {
            $errors.Add("Manifest.domains is missing reserved payload '$reservedDomain'.")
        }
    }

    foreach ($collectorId in @($Manifest.run.selectedCollectors)) {
        if (-not $Manifest.collectors.Contains($collectorId)) {
            $errors.Add("Manifest.collectors is missing selected collector '$collectorId'.")
        }
    }

    foreach ($collectorEntry in @($Manifest.collectors.GetEnumerator())) {
        if ($collectorEntry.Value.status -notin @($schemaContract.collectorStatuses)) {
            $errors.Add("Collector '$($collectorEntry.Key)' has unsupported status '$($collectorEntry.Value.status)'.")
        }
    }

    $artifactPaths = @($Manifest.artifacts | Where-Object { -not [string]::IsNullOrWhiteSpace($_.relativePath) } | ForEach-Object { $_.relativePath })
    $duplicateArtifacts = @($artifactPaths | Group-Object | Where-Object { $_.Count -gt 1 })
    foreach ($duplicateArtifact in $duplicateArtifacts) {
        $warnings.Add("Manifest.artifacts contains duplicate relativePath '$($duplicateArtifact.Name)'.")
    }

    if ($SelectedCollectors) {
        foreach ($collector in $SelectedCollectors) {
            if ($collector.Id -notin @($Manifest.run.selectedCollectors)) {
                $warnings.Add("Selected collector '$($collector.Id)' was not recorded in manifest.run.selectedCollectors.")
            }
        }
    }

    return [ordered]@{
        IsValid  = $errors.Count -eq 0
        Errors   = @($errors)
        Warnings = @($warnings)
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