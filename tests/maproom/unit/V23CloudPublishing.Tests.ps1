#Requires -Module Pester
<#
.SYNOPSIS
    v2.3.0 Pester coverage for the Cloud Publishing milestone:
      #244 Azure Blob publisher — Publish-RangerRun + -PublishToStorage
      #245 Catalog + latest-pointer blobs — _catalog/{cluster}/latest.json + _catalog/_index.json
      #247 Log Analytics Workspace sink — RangerRun_CL + RangerFinding_CL
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    Import-Module (Join-Path $RepoRoot 'AzureLocalRanger.psd1') -Force

    $fixturePath = Join-Path $RepoRoot 'tests\maproom\Fixtures\synthetic-manifest-current-state.json'
    $script:Manifest = Get-Content -Path $fixturePath -Raw | ConvertFrom-Json -AsHashtable -Depth 50

    # Build a minimal Ranger package on disk so the publisher can enumerate artifacts.
    $script:PackageDir = Join-Path ([System.IO.Path]::GetTempPath()) ('ranger-pkg-' + (Get-Random))
    New-Item -ItemType Directory -Path $script:PackageDir -Force | Out-Null
    $script:Manifest | ConvertTo-Json -Depth 50 | Set-Content -Path (Join-Path $script:PackageDir 'audit-manifest.json') -Encoding UTF8
    '{"version":"1.0","artifacts":[]}' | Set-Content -Path (Join-Path $script:PackageDir 'package-index.json') -Encoding UTF8
    'log line 1' | Set-Content -Path (Join-Path $script:PackageDir 'ranger.log') -Encoding UTF8
    '{"runId":"test"}' | Set-Content -Path (Join-Path $script:PackageDir 'test-evidence.json') -Encoding UTF8
    New-Item -ItemType Directory -Path (Join-Path $script:PackageDir 'reports') -Force | Out-Null
    '<html/>' | Set-Content -Path (Join-Path $script:PackageDir 'reports\sample.html') -Encoding UTF8
    New-Item -ItemType Directory -Path (Join-Path $script:PackageDir 'powerbi') -Force | Out-Null
    'NodeId,NodeName' | Set-Content -Path (Join-Path $script:PackageDir 'powerbi\nodes.csv') -Encoding UTF8
}

AfterAll {
    if ($script:PackageDir -and (Test-Path $script:PackageDir)) {
        Remove-Item -Path $script:PackageDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'v2.3.0 #244 Resolve-RangerBlobPath substitutions' {
    It 'substitutes {cluster}, {runId}, and {yyyy-MM-dd}' {
        $p = & (Get-Module AzureLocalRanger) {
            param($t,$c,$r,$ts) Resolve-RangerBlobPath -Template $t -Cluster $c -RunId $r -Timestamp $ts
        } '{cluster}/{yyyy-MM-dd}/{runId}' 'azlocal-iic-01' '20260417020000' ([datetime]'2026-04-17T02:00:00Z').ToUniversalTime()
        $p | Should -Be 'azlocal-iic-01/2026-04-17/20260417020000'
    }

    It 'sanitises cluster names with illegal characters' {
        $p = & (Get-Module AzureLocalRanger) {
            param($t,$c,$r) Resolve-RangerBlobPath -Template $t -Cluster $c -RunId $r
        } '{cluster}/{runId}' 'bad!name with spaces' 'abc/xyz'
        $p | Should -Not -Match '\s'
        $p | Should -Not -Match '!'
    }
}

Describe 'v2.3.0 #244 Select-RangerPackageArtifacts' {
    It 'returns manifest + evidence + packageIndex + runLog by default' {
        $arts = & (Get-Module AzureLocalRanger) {
            param($p,$i) Select-RangerPackageArtifacts -PackagePath $p -Include $i
        } $script:PackageDir @('manifest','evidence','packageIndex','runLog')
        $arts.Count | Should -BeGreaterOrEqual 4
        ($arts | Where-Object { $_.category -eq 'manifest' }).Count | Should -BeGreaterOrEqual 1
        ($arts | Where-Object { $_.category -eq 'evidence' }).Count | Should -BeGreaterThan 0
    }

    It 'include=full also pulls reports/ and powerbi/' {
        $arts = & (Get-Module AzureLocalRanger) {
            param($p) Select-RangerPackageArtifacts -PackagePath $p -Include @('full')
        } $script:PackageDir
        ($arts | Where-Object { $_.category -eq 'reports' }).Count | Should -BeGreaterThan 0
        ($arts | Where-Object { $_.category -eq 'powerbi' }).Count | Should -BeGreaterThan 0
    }
}

Describe 'v2.3.0 #244 Publish-RangerRun Offline mode' {
    It 'generates a plan with simulated blob URIs when -Offline is set' {
        $result = Publish-RangerRun -PackagePath $script:PackageDir -StorageAccount 'stircompliance' -Container 'ranger-runs' -Include full -Offline
        $result.status | Should -Be 'ok'
        $result.authMethod | Should -Be 'offline'
        @($result.blobUris).Count | Should -BeGreaterThan 0
        $result.blobUris[0] | Should -Match '^offline://'
    }

    It 'writes cloudPublish back into the manifest' {
        Publish-RangerRun -PackagePath $script:PackageDir -StorageAccount 'stircompliance' -Container 'ranger-runs' -Offline | Out-Null
        $m = Get-Content (Join-Path $script:PackageDir 'audit-manifest.json') -Raw | ConvertFrom-Json
        $m.run.cloudPublish | Should -Not -BeNullOrEmpty
        $m.run.cloudPublish.status | Should -Be 'ok'
    }

    It 'fails cleanly when storage account is missing' {
        { Publish-RangerRun -PackagePath $script:PackageDir -Container 'c' -Offline } | Should -Throw
    }
}

Describe 'v2.3.0 #245 catalog blob plan' {
    It 'Offline mode returns projected latestBlob and indexBlob URIs' {
        $result = Publish-RangerRun -PackagePath $script:PackageDir -StorageAccount 'stircompliance' -Container 'ranger-runs' -Offline
        $result.latestBlob | Should -Match '_catalog/.*/latest\.json$'
        $result.indexBlob  | Should -Match '_catalog/_index\.json$'
    }
}

Describe 'v2.3.0 #247 Build-RangerLogAnalyticsPayload' {
    It 'produces a single run row with WAF overall score and pillar dict' {
        $payload = & (Get-Module AzureLocalRanger) {
            param($m) Build-RangerLogAnalyticsPayload -Manifest $m
        } $script:Manifest
        $payload.run | Should -Not -BeNullOrEmpty
        $payload.run.Keys | Should -Contain 'RunId'
        $payload.run.Keys | Should -Contain 'Cluster'
        $payload.run.WafPillarScores | Should -BeOfType [System.Collections.IDictionary]
    }

    It 'returns a findings array (may be empty for a clean fixture)' {
        $payload = & (Get-Module AzureLocalRanger) {
            param($m) Build-RangerLogAnalyticsPayload -Manifest $m
        } $script:Manifest
        ,$payload.findings | Should -BeOfType [System.Collections.IEnumerable]
    }
}

Describe 'v2.3.0 #247 Invoke-RangerLogAnalyticsPublish Offline mode' {
    It 'reports ok-offline and counts simulated rows' {
        $la = @{
            enabled = $true
            dataCollectionEndpoint = 'https://example.ingest.monitor.azure.com'
            dataCollectionRuleImmutableId = 'dcr-0000'
            streamName = 'Custom-RangerRun_CL'
            findingStreamName = 'Custom-RangerFinding_CL'
            authMethod = 'default'
        }
        $r = & (Get-Module AzureLocalRanger) {
            param($m,$la) Invoke-RangerLogAnalyticsPublish -Manifest $m -LogAnalyticsConfig $la -Offline
        } $script:Manifest $la
        $r.status | Should -Be 'ok-offline'
        $r.runRowsPosted | Should -Be 1
    }
}
