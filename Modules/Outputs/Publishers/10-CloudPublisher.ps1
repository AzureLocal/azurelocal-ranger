#Requires -Version 7.0

<#
.SYNOPSIS
    v2.3.0 cloud publishing — Azure Blob publisher (#244), catalog + latest-pointer
    blobs (#245), and Log Analytics Workspace sink (#247). Keeps every Azure SDK
    call behind a small number of testable helpers so fixture-mode and unit tests
    don't require real Azure credentials.
#>

function Resolve-RangerRemoteStorageConfig {
    <#
    .SYNOPSIS
        Pull the v2.3.0 remote-storage config block out of a Ranger config with sane defaults.
    .DESCRIPTION
        Accepts the fully-resolved config hashtable (as produced by ConvertTo-RangerHashtable
        on the config load path) and returns either a normalised remote-storage block or $null
        when blob publishing is disabled.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary]$Config
    )

    $rs = $null
    if ($Config.output -and $Config.output.remoteStorage) { $rs = $Config.output.remoteStorage }
    if (-not $rs) { return $null }
    $type = [string]$rs.type
    if ([string]::IsNullOrWhiteSpace($type) -or $type -eq 'none') { return $null }

    return [ordered]@{
        type                  = $type
        storageAccount        = [string]$rs.storageAccount
        container             = [string]$rs.container
        pathTemplate          = if (-not [string]::IsNullOrWhiteSpace([string]$rs.pathTemplate)) { [string]$rs.pathTemplate } else { '{cluster}/{yyyy-MM-dd}/{runId}' }
        include               = if ($rs.include) { @($rs.include | ForEach-Object { [string]$_ }) } else { @('manifest','evidence','packageIndex','runLog') }
        authMethod            = if (-not [string]::IsNullOrWhiteSpace([string]$rs.authMethod)) { [string]$rs.authMethod } else { 'default' }
        sasRef                = [string]$rs.sasRef
        blobTags              = if ($rs.blobTags) { $rs.blobTags } else { @{} }
        writeHistory          = [bool]$rs.writeHistory
        failRunOnPublishError = [bool]$rs.failRunOnPublishError
    }
}

function Resolve-RangerLogAnalyticsConfig {
    <#
    .SYNOPSIS
        v2.3.0 (#247): Log Analytics sink config resolver.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary]$Config
    )

    $la = $null
    if ($Config.output -and $Config.output.logAnalytics) { $la = $Config.output.logAnalytics }
    if (-not $la) { return $null }
    if (-not $la.enabled) { return $null }

    return [ordered]@{
        enabled                       = [bool]$la.enabled
        dataCollectionEndpoint        = [string]$la.dataCollectionEndpoint
        dataCollectionRuleImmutableId = [string]$la.dataCollectionRuleImmutableId
        streamName                    = if (-not [string]::IsNullOrWhiteSpace([string]$la.streamName)) { [string]$la.streamName } else { 'Custom-RangerRun_CL' }
        findingStreamName             = [string]$la.findingStreamName
        authMethod                    = if (-not [string]::IsNullOrWhiteSpace([string]$la.authMethod)) { [string]$la.authMethod } else { 'default' }
        failRunOnPublishError         = [bool]$la.failRunOnPublishError
    }
}

function Resolve-RangerBlobPath {
    <#
    .SYNOPSIS
        Substitute {cluster} / {runId} / {yyyy-MM-dd} / {yyyy} / {MM} / {dd} tokens in a path template.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Template,
        [Parameter(Mandatory = $true)] [string]$Cluster,
        [Parameter(Mandatory = $true)] [string]$RunId,
        [datetime]$Timestamp = (Get-Date).ToUniversalTime()
    )

    $safeCluster = ($Cluster -replace '[^\w\-\.]', '-').Trim('-')
    $safeRunId   = ($RunId -replace '[^\w\-\.]', '-')
    $s = $Template
    $s = $s -replace '\{cluster\}',    $safeCluster
    $s = $s -replace '\{runId\}',      $safeRunId
    $s = $s -replace '\{yyyy-MM-dd\}', $Timestamp.ToString('yyyy-MM-dd')
    $s = $s -replace '\{yyyy\}',       $Timestamp.ToString('yyyy')
    $s = $s -replace '\{MM\}',         $Timestamp.ToString('MM')
    $s = $s -replace '\{dd\}',         $Timestamp.ToString('dd')
    return ($s -replace '/+', '/').TrimStart('/')
}

function Select-RangerPackageArtifacts {
    <#
    .SYNOPSIS
        Build the ordered list of artifacts to upload from a Ranger package on disk.
    .DESCRIPTION
        Applies the include filter (manifest, evidence, packageIndex, runLog, reports,
        powerbi, full). `full` expands to manifest + evidence + packageIndex + runLog +
        reports + powerbi.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$PackagePath,
        [Parameter(Mandatory = $true)] [string[]]$Include
    )

    if (-not (Test-Path -Path $PackagePath -PathType Container)) {
        throw "Ranger package folder not found: $PackagePath"
    }

    $inc = @($Include | ForEach-Object { $_.ToLowerInvariant() })
    if ('full' -in $inc) { $inc = @('manifest','evidence','packageindex','runlog','reports','powerbi') }

    $artifacts = New-Object System.Collections.ArrayList

    $addIfExists = {
        param([string]$rel, [string]$category)
        $full = Join-Path -Path $PackagePath -ChildPath $rel
        if (Test-Path -Path $full -PathType Leaf) {
            [void]$artifacts.Add([ordered]@{
                category     = $category
                fullPath     = (Resolve-Path -Path $full).Path
                relativePath = ($rel -replace '\\','/')
                sizeBytes    = (Get-Item -Path $full).Length
            })
        }
    }

    if ('manifest'     -in $inc) { & $addIfExists 'audit-manifest.json' 'manifest' }
    if ('packageindex' -in $inc) { & $addIfExists 'package-index.json'  'packageIndex' }
    if ('runlog'       -in $inc) { & $addIfExists 'ranger.log'          'runLog' }

    if ('evidence' -in $inc) {
        foreach ($f in @(Get-ChildItem -Path $PackagePath -Filter '*-evidence.json' -File -ErrorAction SilentlyContinue)) {
            [void]$artifacts.Add([ordered]@{ category = 'evidence'; fullPath = $f.FullName; relativePath = $f.Name; sizeBytes = $f.Length })
        }
        foreach ($f in @(Get-ChildItem -Path (Join-Path $PackagePath 'reports') -Filter '*-evidence.json' -File -ErrorAction SilentlyContinue)) {
            [void]$artifacts.Add([ordered]@{ category = 'evidence'; fullPath = $f.FullName; relativePath = "reports/$($f.Name)"; sizeBytes = $f.Length })
        }
    }

    if ('reports' -in $inc) {
        $reportsPath = Join-Path $PackagePath 'reports'
        if (Test-Path -Path $reportsPath -PathType Container) {
            foreach ($f in @(Get-ChildItem -Path $reportsPath -File -Recurse -ErrorAction SilentlyContinue)) {
                if ($f.Name -like '*-evidence.json') { continue }  # already added above
                $rel = [System.IO.Path]::GetRelativePath($PackagePath, $f.FullName) -replace '\\','/'
                [void]$artifacts.Add([ordered]@{ category = 'reports'; fullPath = $f.FullName; relativePath = $rel; sizeBytes = $f.Length })
            }
        }
    }

    if ('powerbi' -in $inc) {
        $pbiPath = Join-Path $PackagePath 'powerbi'
        if (Test-Path -Path $pbiPath -PathType Container) {
            foreach ($f in @(Get-ChildItem -Path $pbiPath -File -ErrorAction SilentlyContinue)) {
                $rel = [System.IO.Path]::GetRelativePath($PackagePath, $f.FullName) -replace '\\','/'
                [void]$artifacts.Add([ordered]@{ category = 'powerbi'; fullPath = $f.FullName; relativePath = $rel; sizeBytes = $f.Length })
            }
        }
    }

    return @($artifacts)
}

function Get-RangerFileSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [string]$Path)
    if (-not (Test-Path -Path $Path -PathType Leaf)) { throw "File not found for hashing: $Path" }
    return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
}

function Resolve-RangerBlobAuth {
    <#
    .SYNOPSIS
        v2.3.0 (#244): resolve an auth strategy for Azure Blob according to the
        documented default chain: Managed Identity → Entra RBAC context → SAS from Key Vault.
    .OUTPUTS
        Hashtable with { method: 'managedIdentity'|'entraRbac'|'sasFromKeyVault'|'none';
                         sasToken?; clientId?; reason? }.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [hashtable]$RemoteStorageConfig
    )

    $requested = [string]$RemoteStorageConfig.authMethod
    if ([string]::IsNullOrWhiteSpace($requested)) { $requested = 'default' }

    $resolveSas = {
        if ([string]::IsNullOrWhiteSpace([string]$RemoteStorageConfig.sasRef)) { return $null }
        if (-not (Get-Command -Name 'Resolve-RangerCredentialDefinition' -ErrorAction SilentlyContinue)) { return $null }
        try {
            $sas = Resolve-RangerCredentialDefinition -Reference ([string]$RemoteStorageConfig.sasRef)
            if ($sas) { return [string]$sas }
        } catch { return $null }
        return $null
    }

    if ($requested -eq 'managedIdentity' -or ($requested -eq 'default' -and $env:AZURE_CLIENT_ID)) {
        return @{ method = 'managedIdentity'; clientId = [string]$env:AZURE_CLIENT_ID }
    }

    if ($requested -eq 'sasFromKeyVault') {
        $sas = & $resolveSas
        if ($sas) { return @{ method = 'sasFromKeyVault'; sasToken = $sas } }
        return @{ method = 'none'; reason = "sasFromKeyVault requested but sasRef could not be resolved ($($RemoteStorageConfig.sasRef))" }
    }

    if ($requested -in @('default','entraRbac')) {
        try {
            if (Get-Command -Name 'Get-AzContext' -ErrorAction SilentlyContinue) {
                $ctx = Get-AzContext -ErrorAction SilentlyContinue
                if ($ctx -and $ctx.Account) { return @{ method = 'entraRbac' } }
            }
        } catch { }

        # Last-chance fallback to a Key Vault SAS if one was provided alongside default.
        $sas = & $resolveSas
        if ($sas) { return @{ method = 'sasFromKeyVault'; sasToken = $sas } }
        return @{ method = 'none'; reason = 'No Az.Accounts context and no sasRef configured.' }
    }

    return @{ method = 'none'; reason = "Unknown authMethod '$requested'." }
}

function Invoke-RangerBlobUpload {
    <#
    .SYNOPSIS
        Upload a single file to Azure Blob storage. Idempotent — if the destination
        already exists and the local SHA-256 matches, skip the PUT.
    .NOTES
        Depends on Az.Storage when auth method is managedIdentity / entraRbac, or
        can also accept a raw SAS URL via the sasFromKeyVault path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$StorageAccount,
        [Parameter(Mandatory = $true)] [string]$Container,
        [Parameter(Mandatory = $true)] [string]$BlobName,
        [Parameter(Mandatory = $true)] [string]$LocalPath,
        [Parameter(Mandatory = $true)] [hashtable]$Auth,
        [hashtable]$BlobTags
    )

    if (-not (Test-Path -Path $LocalPath -PathType Leaf)) {
        throw "Local blob source not found: $LocalPath"
    }

    $sha = Get-RangerFileSha256 -Path $LocalPath

    if (-not (Get-Command -Name 'Set-AzStorageBlobContent' -ErrorAction SilentlyContinue)) {
        throw 'Az.Storage module is required for Azure Blob publishing. Install-Module Az.Storage -Scope CurrentUser'
    }

    # Build a storage context appropriate for the auth method.
    $ctx = $null
    switch ($Auth.method) {
        'managedIdentity' {
            $ctx = New-AzStorageContext -StorageAccountName $StorageAccount -UseConnectedAccount -ErrorAction Stop
        }
        'entraRbac' {
            $ctx = New-AzStorageContext -StorageAccountName $StorageAccount -UseConnectedAccount -ErrorAction Stop
        }
        'sasFromKeyVault' {
            $ctx = New-AzStorageContext -StorageAccountName $StorageAccount -SasToken $Auth.sasToken -ErrorAction Stop
        }
        default { throw "Unsupported auth method: $($Auth.method)" }
    }

    # Idempotency — compare remote metadata.x-ranger-sha256 if present.
    $existing = $null
    try { $existing = Get-AzStorageBlob -Container $Container -Blob $BlobName -Context $ctx -ErrorAction SilentlyContinue } catch { }
    if ($existing -and $existing.ICloudBlob -and $existing.ICloudBlob.Metadata) {
        $remoteSha = [string]$existing.ICloudBlob.Metadata['x-ranger-sha256']
        if ($remoteSha -and $remoteSha -eq $sha) {
            return [ordered]@{
                blobUri    = ('https://{0}.blob.core.windows.net/{1}/{2}' -f $StorageAccount, $Container, $BlobName)
                status     = 'skipped-idempotent'
                sha256     = $sha
                sizeBytes  = (Get-Item -Path $LocalPath).Length
            }
        }
    }

    $metadata = @{ 'x-ranger-sha256' = $sha }

    $setParams = @{
        File      = $LocalPath
        Container = $Container
        Blob      = $BlobName
        Context   = $ctx
        Force     = $true
        Metadata  = $metadata
    }
    if ($BlobTags -and $BlobTags.Count -gt 0) { $setParams['Tag'] = $BlobTags }

    $result = Set-AzStorageBlobContent @setParams -ErrorAction Stop

    return [ordered]@{
        blobUri   = ('https://{0}.blob.core.windows.net/{1}/{2}' -f $StorageAccount, $Container, $BlobName)
        status    = 'uploaded'
        sha256    = $sha
        sizeBytes = (Get-Item -Path $LocalPath).Length
    }
}

function Invoke-RangerBlobPublish {
    <#
    .SYNOPSIS
        v2.3.0 (#244 + #245): publish a Ranger package to Azure Blob + update catalog blobs.
    .DESCRIPTION
        Core orchestrator for the blob sink. Iterates the package artifacts, uploads each,
        then writes `_catalog/{cluster}/latest.json` and merges `_catalog/_index.json` so
        downstream consumers can find the latest run without listing.
    .OUTPUTS
        Hashtable recorded on manifest.run.cloudPublish — { status, authMethod, blobUris,
        bytesUploaded, duration, latestBlob, indexBlob, errors }.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary]$Manifest,
        [Parameter(Mandatory = $true)] [string]$PackagePath,
        [Parameter(Mandatory = $true)] [hashtable]$RemoteStorageConfig,
        [switch]$Offline
    )

    $start = Get-Date
    $cluster = [string]($Manifest.topology.clusterName ?? $Manifest.domains.clusterNode.clusterName ?? $Manifest.run.clusterName ?? 'unknown-cluster')
    $rawRunId = [string]$Manifest.run.runId
    $runId    = if ([string]::IsNullOrWhiteSpace($rawRunId)) { (Get-Date -Format 'yyyyMMddHHmmss') } else { $rawRunId }
    $mode    = [string]$Manifest.run.mode
    $tool    = [string]$Manifest.run.toolVersion
    $basePath = Resolve-RangerBlobPath -Template $RemoteStorageConfig.pathTemplate -Cluster $cluster -RunId $runId

    $baseTags = @{ cluster = $cluster; mode = $mode; toolVersion = $tool; runId = $runId }
    if ($RemoteStorageConfig.blobTags) {
        foreach ($k in $RemoteStorageConfig.blobTags.Keys) { $baseTags[[string]$k] = [string]$RemoteStorageConfig.blobTags[$k] }
    }

    $result = [ordered]@{
        status        = 'pending'
        authMethod    = 'unknown'
        basePath      = $basePath
        blobUris      = @()
        bytesUploaded = 0
        durationMs    = 0
        latestBlob    = $null
        indexBlob     = $null
        errors        = @()
    }

    try {
        $artifacts = Select-RangerPackageArtifacts -PackagePath $PackagePath -Include $RemoteStorageConfig.include
        if ($artifacts.Count -eq 0) {
            $result.status = 'skipped'
            $result.errors = @('No artifacts matched the configured include filter.')
            return $result
        }

        if ($Offline) {
            # Offline mode — simulate uploads for tests / fixture runs.
            $result.authMethod = 'offline'
            $blobUris = New-Object System.Collections.ArrayList
            $totalBytes = 0
            foreach ($a in $artifacts) {
                $blobName = "$basePath/$($a.relativePath)"
                [void]$blobUris.Add(('offline://{0}/{1}/{2}' -f $RemoteStorageConfig.storageAccount, $RemoteStorageConfig.container, $blobName))
                $totalBytes += [long]$a.sizeBytes
            }
            $result.blobUris = @($blobUris)
            $result.bytesUploaded = [long]$totalBytes
            $result.status = 'ok'
            $result.latestBlob = "offline://{0}/{1}/_catalog/{2}/latest.json" -f $RemoteStorageConfig.storageAccount, $RemoteStorageConfig.container, $cluster
            $result.indexBlob  = "offline://{0}/{1}/_catalog/_index.json" -f $RemoteStorageConfig.storageAccount, $RemoteStorageConfig.container
            $result.durationMs = [int]((Get-Date) - $start).TotalMilliseconds
            return $result
        }

        $auth = Resolve-RangerBlobAuth -RemoteStorageConfig $RemoteStorageConfig
        $result.authMethod = $auth.method
        if ($auth.method -eq 'none') {
            $result.status = 'failed'
            $result.errors = @("auth: $($auth.reason)")
            return $result
        }

        $blobUris = New-Object System.Collections.ArrayList
        $totalBytes = 0
        $errors = New-Object System.Collections.ArrayList

        foreach ($a in $artifacts) {
            $blobName = "$basePath/$($a.relativePath)"
            try {
                $up = Invoke-RangerBlobUpload -StorageAccount $RemoteStorageConfig.storageAccount -Container $RemoteStorageConfig.container -BlobName $blobName -LocalPath $a.fullPath -Auth $auth -BlobTags $baseTags
                [void]$blobUris.Add($up.blobUri)
                $totalBytes += [long]$up.sizeBytes
            } catch {
                [void]$errors.Add(("{0}: {1}" -f $a.relativePath, $_.Exception.Message))
            }
        }

        $result.blobUris = @($blobUris)
        $result.bytesUploaded = [long]$totalBytes
        $result.errors = @($errors)

        # v2.3.0 (#245): catalog blobs — written regardless of partial upload failures,
        # because downstream consumers need a pointer to whatever did land.
        if (@($blobUris).Count -gt 0) {
            $catalogResult = Update-RangerCloudCatalog -Manifest $Manifest -Auth $auth -RemoteStorageConfig $RemoteStorageConfig -BasePath $basePath
            $result.latestBlob = $catalogResult.latestBlob
            $result.indexBlob  = $catalogResult.indexBlob
            if ($catalogResult.errors) { foreach ($e in $catalogResult.errors) { [void]$result.errors.Add($e) } }
        }

        $result.status = if (@($result.errors).Count -eq 0) { 'ok' } elseif (@($blobUris).Count -gt 0) { 'partial' } else { 'failed' }
    } catch {
        $result.status = 'failed'
        $result.errors = @($_.Exception.Message)
    } finally {
        $result.durationMs = [int]((Get-Date) - $start).TotalMilliseconds
    }

    return $result
}

function Update-RangerCloudCatalog {
    <#
    .SYNOPSIS
        v2.3.0 (#245): write `_catalog/{cluster}/latest.json` and merge `_catalog/_index.json`.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary]$Manifest,
        [Parameter(Mandatory = $true)] [hashtable]$Auth,
        [Parameter(Mandatory = $true)] [hashtable]$RemoteStorageConfig,
        [Parameter(Mandatory = $true)] [string]$BasePath
    )

    $cluster = [string]($Manifest.topology.clusterName ?? $Manifest.domains.clusterNode.clusterName ?? $Manifest.run.clusterName ?? 'unknown-cluster')
    $runId   = [string]$Manifest.run.runId
    $errors  = New-Object System.Collections.ArrayList

    $scoreBlock = [ordered]@{
        overall = [int]($Manifest.domains.wafAssessment.summary.overallScore ?? 0)
        status  = [string]($Manifest.domains.wafAssessment.summary.status ?? '')
        pillars = @{}
    }
    if ($Manifest.domains.wafAssessment.pillarScores) {
        foreach ($p in @($Manifest.domains.wafAssessment.pillarScores)) {
            $scoreBlock.pillars[[string]$p.pillar] = [int]$p.score
        }
    }

    $latest = [ordered]@{
        schemaVersion  = '1.0'
        cluster        = $cluster
        lastUpdatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        run = [ordered]@{
            runId          = $runId
            mode           = [string]$Manifest.run.mode
            toolVersion    = [string]$Manifest.run.toolVersion
            generatedAtUtc = [string]$Manifest.run.endTimeUtc
            basePath       = $BasePath
            artifacts      = [ordered]@{
                manifest     = "$BasePath/audit-manifest.json"
                evidence     = "$BasePath/$runId-evidence.json"
                packageIndex = "$BasePath/package-index.json"
            }
            score = $scoreBlock
        }
    }

    $tempDir = [System.IO.Path]::GetTempPath()
    $latestTemp = Join-Path $tempDir "ranger-latest-$([guid]::NewGuid().ToString()).json"
    $latest | ConvertTo-Json -Depth 10 | Set-Content -Path $latestTemp -Encoding UTF8

    $latestBlob = "_catalog/$cluster/latest.json"
    $latestUri  = $null
    try {
        $up = Invoke-RangerBlobUpload -StorageAccount $RemoteStorageConfig.storageAccount -Container $RemoteStorageConfig.container -BlobName $latestBlob -LocalPath $latestTemp -Auth $Auth -BlobTags @{ cluster = $cluster; kind = 'latest' }
        $latestUri = $up.blobUri
    } catch {
        [void]$errors.Add("latest.json: $($_.Exception.Message)")
    } finally {
        Remove-Item -Path $latestTemp -ErrorAction SilentlyContinue
    }

    # _index.json — read-modify-write with ETag; if read fails we create a fresh one.
    $indexEntry = [ordered]@{
        cluster       = $cluster
        latestRunId   = $runId
        latestAtUtc   = $latest.lastUpdatedUtc
        latestScore   = $scoreBlock.overall
        latestStatus  = $scoreBlock.status
        catalogBlob   = $latestBlob
    }
    $ctx = $null
    try {
        switch ($Auth.method) {
            'managedIdentity' { $ctx = New-AzStorageContext -StorageAccountName $RemoteStorageConfig.storageAccount -UseConnectedAccount -ErrorAction Stop }
            'entraRbac'       { $ctx = New-AzStorageContext -StorageAccountName $RemoteStorageConfig.storageAccount -UseConnectedAccount -ErrorAction Stop }
            'sasFromKeyVault' { $ctx = New-AzStorageContext -StorageAccountName $RemoteStorageConfig.storageAccount -SasToken $Auth.sasToken -ErrorAction Stop }
        }
    } catch { [void]$errors.Add("_index context: $($_.Exception.Message)") }

    $indexBlob = '_catalog/_index.json'
    $indexUri  = $null
    if ($ctx) {
        $existing = $null
        try { $existing = Get-AzStorageBlob -Container $RemoteStorageConfig.container -Blob $indexBlob -Context $ctx -ErrorAction SilentlyContinue } catch { }
        $doc = $null
        if ($existing) {
            try {
                $tmpDl = Join-Path $tempDir "ranger-index-$([guid]::NewGuid().ToString()).json"
                $null = Get-AzStorageBlobContent -Container $RemoteStorageConfig.container -Blob $indexBlob -Destination $tmpDl -Context $ctx -Force -ErrorAction Stop
                $doc = Get-Content -Path $tmpDl -Raw | ConvertFrom-Json -AsHashtable -Depth 20
                Remove-Item -Path $tmpDl -ErrorAction SilentlyContinue
            } catch { $doc = $null }
        }
        if (-not $doc) {
            $doc = [ordered]@{ schemaVersion = '1.0'; lastUpdatedUtc = $latest.lastUpdatedUtc; clusters = @() }
        }
        $clusters = @($doc.clusters | Where-Object { $_.cluster -ne $cluster })
        $clusters += $indexEntry
        $doc.clusters = @($clusters)
        $doc.lastUpdatedUtc = $latest.lastUpdatedUtc

        $indexTemp = Join-Path $tempDir "ranger-indexwrite-$([guid]::NewGuid().ToString()).json"
        $doc | ConvertTo-Json -Depth 20 | Set-Content -Path $indexTemp -Encoding UTF8
        try {
            $up2 = Invoke-RangerBlobUpload -StorageAccount $RemoteStorageConfig.storageAccount -Container $RemoteStorageConfig.container -BlobName $indexBlob -LocalPath $indexTemp -Auth $Auth -BlobTags @{ kind = 'index' }
            $indexUri = $up2.blobUri
        } catch {
            [void]$errors.Add("_index.json: $($_.Exception.Message)")
        } finally {
            Remove-Item -Path $indexTemp -ErrorAction SilentlyContinue
        }
    }

    # Optional per-run history — one JSONL line appended.
    if ($RemoteStorageConfig.writeHistory -and $ctx) {
        $historyBlob = "_catalog/$cluster/history.jsonl"
        $histLine = ($indexEntry | ConvertTo-Json -Depth 5 -Compress)
        $histTemp = Join-Path $tempDir "ranger-history-$([guid]::NewGuid().ToString()).jsonl"
        # Try to download existing then append.
        $existingHist = $null
        try {
            $null = Get-AzStorageBlobContent -Container $RemoteStorageConfig.container -Blob $historyBlob -Destination $histTemp -Context $ctx -Force -ErrorAction Stop
        } catch { New-Item -Path $histTemp -ItemType File -Force | Out-Null }
        Add-Content -Path $histTemp -Value $histLine
        try {
            $null = Invoke-RangerBlobUpload -StorageAccount $RemoteStorageConfig.storageAccount -Container $RemoteStorageConfig.container -BlobName $historyBlob -LocalPath $histTemp -Auth $Auth -BlobTags @{ cluster = $cluster; kind = 'history' }
        } catch {
            [void]$errors.Add("history.jsonl: $($_.Exception.Message)")
        } finally {
            Remove-Item -Path $histTemp -ErrorAction SilentlyContinue
        }
    }

    return [ordered]@{
        latestBlob = $latestUri
        indexBlob  = $indexUri
        errors     = @($errors)
    }
}

function Build-RangerLogAnalyticsPayload {
    <#
    .SYNOPSIS
        v2.3.0 (#247): build the RangerRun_CL + RangerFinding_CL payloads from a manifest.
    .OUTPUTS
        Hashtable with `run` (single record) and `findings` (0..N records).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary]$Manifest,
        [hashtable]$CloudPublish
    )

    $cluster = [string]($Manifest.topology.clusterName ?? $Manifest.domains.clusterNode.clusterName ?? $Manifest.run.clusterName ?? 'unknown-cluster')
    $wafSummary = $Manifest.domains.wafAssessment.summary
    $pillarDict = [ordered]@{}
    foreach ($p in @($Manifest.domains.wafAssessment.pillarScores)) {
        $pillarDict[[string]$p.pillar -replace '\s','_'] = [int]$p.score
    }

    $run = [ordered]@{
        TimeGenerated      = (Get-Date).ToUniversalTime().ToString('o')
        Cluster            = $cluster
        RunId              = [string]$Manifest.run.runId
        Mode               = [string]$Manifest.run.mode
        ToolVersion        = [string]$Manifest.run.toolVersion
        WafOverallScore    = if ($wafSummary.overallScore) { [int]$wafSummary.overallScore } else { 0 }
        WafStatus          = [string]$wafSummary.status
        WafPillarScores    = $pillarDict
        FailingRuleCount   = if ($wafSummary.failingRules) { [int]$wafSummary.failingRules } else { 0 }
        AhbStatus          = [string]($Manifest.domains.azureIntegration.costLicensing.summary.ahbStatus ?? '')
        AhbAdoptionPct     = if ($Manifest.domains.azureIntegration.costLicensing.summary.ahbAdoptionPct) { [double]$Manifest.domains.azureIntegration.costLicensing.summary.ahbAdoptionPct } else { 0 }
        CoresWithAhb       = if ($Manifest.domains.azureIntegration.costLicensing.summary.ahbEnrolledCores) { [int]$Manifest.domains.azureIntegration.costLicensing.summary.ahbEnrolledCores } else { 0 }
        NodeCount          = @($Manifest.domains.clusterNode.nodes).Count
        VmCount            = @($Manifest.domains.virtualMachines.inventory).Count
        StoragePools       = @($Manifest.domains.storage.pools).Count
        CloudPublishStatus = if ($CloudPublish) { [string]$CloudPublish.status } else { 'skipped' }
        CimDepthStatus     = [string]($Manifest.run.remoteExecution.cimDepth.status ?? '')
        ManifestBlobUri    = if ($CloudPublish -and $CloudPublish.blobUris) { @($CloudPublish.blobUris | Where-Object { $_ -like '*audit-manifest.json' }) | Select-Object -First 1 } else { '' }
        EvidenceBlobUri    = if ($CloudPublish -and $CloudPublish.blobUris) { @($CloudPublish.blobUris | Where-Object { $_ -like '*evidence.json' }) | Select-Object -First 1 } else { '' }
    }

    $findings = New-Object System.Collections.ArrayList
    $rules = @($Manifest.domains.wafAssessment.ruleResults)
    if ($rules.Count -eq 0 -and (Get-Command -Name Invoke-RangerWafRuleEvaluation -ErrorAction SilentlyContinue)) {
        try {
            $eval = Invoke-RangerWafRuleEvaluation -Manifest $Manifest
            $rules = @($eval.ruleResults)
        } catch { }
    }
    foreach ($rr in $rules) {
        if ($rr.pass) { continue }
        $rem = $rr.remediation
        [void]$findings.Add([ordered]@{
            TimeGenerated  = $run.TimeGenerated
            Cluster        = $cluster
            RunId          = $run.RunId
            RuleId         = [string]$rr.id
            Pillar         = [string]$rr.pillar
            Severity       = [string]$rr.severity
            Weight         = if ($rr.weight) { [int]$rr.weight } else { 1 }
            Message        = [string]$rr.title
            Recommendation = if ($rem -and $rem.steps -and @($rem.steps).Count -gt 0) { [string]@($rem.steps)[0] } else { [string]$rr.recommendation }
        })
    }

    return @{
        run      = $run
        findings = @($findings)
    }
}

function Invoke-RangerLogAnalyticsPublish {
    <#
    .SYNOPSIS
        v2.3.0 (#247): POST the distilled run + findings records to a DCE/DCR pair via Logs Ingestion API.
    .DESCRIPTION
        Non-blocking by default — failures record `manifest.run.logAnalytics.status = 'failed'`
        rather than aborting the run.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary]$Manifest,
        [Parameter(Mandatory = $true)] [hashtable]$LogAnalyticsConfig,
        [hashtable]$CloudPublish,
        [switch]$Offline
    )

    $start = Get-Date
    $result = [ordered]@{
        status         = 'pending'
        authMethod     = [string]$LogAnalyticsConfig.authMethod
        runRowsPosted  = 0
        findingRowsPosted = 0
        durationMs     = 0
        errors         = @()
    }

    try {
        $payload = Build-RangerLogAnalyticsPayload -Manifest $Manifest -CloudPublish $CloudPublish
        if ($Offline) {
            $result.status = 'ok-offline'
            $result.runRowsPosted = 1
            $result.findingRowsPosted = @($payload.findings).Count
            $result.durationMs = [int]((Get-Date) - $start).TotalMilliseconds
            return $result
        }

        $dce = [string]$LogAnalyticsConfig.dataCollectionEndpoint
        $dcr = [string]$LogAnalyticsConfig.dataCollectionRuleImmutableId
        if ([string]::IsNullOrWhiteSpace($dce) -or [string]::IsNullOrWhiteSpace($dcr)) {
            $result.status = 'failed'
            $result.errors = @('dataCollectionEndpoint and dataCollectionRuleImmutableId are required.')
            return $result
        }

        # Acquire token — caller must be logged in via Az.Accounts or be running with an MI.
        $token = $null
        try {
            if (Get-Command -Name Get-AzAccessToken -ErrorAction SilentlyContinue) {
                $token = (Get-AzAccessToken -ResourceUrl 'https://monitor.azure.com/' -ErrorAction Stop).Token
            }
        } catch { $result.errors = @($_.Exception.Message) }
        if (-not $token) {
            $result.status = 'failed'
            $result.errors += 'Could not acquire monitor.azure.com access token. Check Az.Accounts context / MI.'
            return $result
        }

        $headers = @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }

        $runUrl = "$dce/dataCollectionRules/$dcr/streams/$($LogAnalyticsConfig.streamName)?api-version=2023-01-01"
        $body = ConvertTo-Json -InputObject @($payload.run) -Depth 10 -Compress
        try {
            $null = Invoke-RestMethod -Method Post -Uri $runUrl -Headers $headers -Body $body -ErrorAction Stop
            $result.runRowsPosted = 1
        } catch {
            $result.errors += "run post: $($_.Exception.Message)"
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$LogAnalyticsConfig.findingStreamName) -and @($payload.findings).Count -gt 0) {
            $findingUrl = "$dce/dataCollectionRules/$dcr/streams/$($LogAnalyticsConfig.findingStreamName)?api-version=2023-01-01"
            $fbody = ConvertTo-Json -InputObject @($payload.findings) -Depth 10 -Compress
            try {
                $null = Invoke-RestMethod -Method Post -Uri $findingUrl -Headers $headers -Body $fbody -ErrorAction Stop
                $result.findingRowsPosted = @($payload.findings).Count
            } catch {
                $result.errors += "finding post: $($_.Exception.Message)"
            }
        }

        $result.status = if ($result.runRowsPosted -gt 0 -and @($result.errors).Count -eq 0) { 'ok' } elseif ($result.runRowsPosted -gt 0) { 'partial' } else { 'failed' }
    } catch {
        $result.status = 'failed'
        $result.errors = @($_.Exception.Message)
    } finally {
        $result.durationMs = [int]((Get-Date) - $start).TotalMilliseconds
    }

    return $result
}
