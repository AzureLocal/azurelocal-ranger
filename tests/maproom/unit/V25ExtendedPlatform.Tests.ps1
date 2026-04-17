#Requires -Module Pester
<#
.SYNOPSIS
    v2.5.0 Pester coverage for the Extended Platform Coverage milestone:
      #128 Capacity headroom analysis
      #125 Idle / underutilized VM detection
      #126 Storage efficiency analysis
      #127 SQL / Windows Server license inventory
      #129 Multi-cluster estate rollup
      #80  PowerPoint deck output
      #32  Import-RangerManualEvidence
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    Import-Module (Join-Path $RepoRoot 'AzureLocalRanger.psd1') -Force

    $fixturePath = Join-Path $RepoRoot 'tests\maproom\Fixtures\synthetic-manifest.json'
    $script:Manifest = Get-Content -Path $fixturePath -Raw | ConvertFrom-Json -AsHashtable -Depth 50

    # Run the v2.5.0 analyzer pass once and reuse the enriched manifest.
    $script:Enriched = & (Get-Module AzureLocalRanger) {
        param($m) Invoke-RangerV25Analyzers -Manifest $m
    } $script:Manifest
}

Describe 'v2.5.0 #128 capacity headroom analyzer' {
    It 'produces a summary with node / VM / vCPU / memory / storage metrics' {
        $s = $script:Enriched.domains.capacityAnalysis.summary
        $s | Should -Not -BeNullOrEmpty
        $s.nodeCount | Should -BeGreaterThan 0
        $s.totalLogicalCores | Should -BeGreaterThan 0
        $s.vcpuUtilizationPct | Should -BeGreaterOrEqual 0
        $s.memoryUtilizationPct | Should -BeGreaterOrEqual 0
        $s.storageUtilizationPct | Should -BeGreaterOrEqual 0
        $s.vcpuStatus | Should -BeIn @('Healthy','Warning','Critical')
    }

    It 'builds a per-node breakdown matching node count' {
        $script:Enriched.domains.capacityAnalysis.perNode.Count | Should -Be $script:Enriched.domains.capacityAnalysis.summary.nodeCount
    }
}

Describe 'v2.5.0 #125 VM utilization analyzer' {
    It 'classifies at least one VM as idle in the synthetic fixture' {
        $s = $script:Enriched.domains.vmUtilization.summary
        $s.idleCount | Should -BeGreaterOrEqual 1
    }

    It 'classifies at least one VM as underutilized and records potential rightsizing savings' {
        $s = $script:Enriched.domains.vmUtilization.summary
        $s.underutilizedCount | Should -BeGreaterOrEqual 1
        $s.potentialVcpuFreed | Should -BeGreaterOrEqual 1
    }

    It 'emits classification + proposedVcpu on each VM record' {
        $classified = @($script:Enriched.domains.vmUtilization.classifications)
        $classified.Count | Should -BeGreaterThan 0
        ($classified | Where-Object { $_.classification -eq 'idle' }).Count | Should -BeGreaterOrEqual 1
    }
}

Describe 'v2.5.0 #126 storage efficiency analyzer' {
    It 'computes dedup and thin-provisioning coverage percentages' {
        $s = $script:Enriched.domains.storageEfficiency.summary
        $s.dedupCoveragePct | Should -BeGreaterThan 0
        $s.thinCoveragePct  | Should -BeGreaterThan 0
    }

    It 'emits per-volume efficiency records for non-OS volumes' {
        $vols = @($script:Enriched.domains.storageEfficiency.volumes)
        $vols.Count | Should -BeGreaterOrEqual 3
        ($vols | Where-Object { $_.dedupEnabled -eq $true }).Count | Should -BeGreaterOrEqual 1
    }
}

Describe 'v2.5.0 #127 license inventory analyzer' {
    It 'enumerates SQL instances from guestSoftware data' {
        $lic = $script:Enriched.domains.licenseInventory
        $lic.summary.sqlInstanceCount | Should -BeGreaterOrEqual 1
        ($lic.sqlServer | Where-Object { $_.edition -eq 'Enterprise' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'enumerates Windows Server inventory with core counts' {
        $lic = $script:Enriched.domains.licenseInventory
        $lic.summary.windowsServerCount | Should -BeGreaterThan 0
        $lic.summary.windowsServerCores | Should -BeGreaterThan 0
    }
}

Describe 'v2.5.0 #80 PowerPoint deck generator' {
    It 'writes a valid OOXML .pptx package' {
        $out = Join-Path ([System.IO.Path]::GetTempPath()) ('ranger-pptx-' + (Get-Random) + '.pptx')
        try {
            $r = & (Get-Module AzureLocalRanger) {
                param($m,$o) New-RangerPptxDeck -Manifest $m -OutputPath $o
            } $script:Enriched $out
            $r.status | Should -Be 'ok'
            $r.slideCount | Should -BeGreaterOrEqual 5
            Test-Path $out | Should -BeTrue
            # ZIP magic
            $bytes = [System.IO.File]::ReadAllBytes($out)
            $bytes[0] | Should -Be 0x50
            $bytes[1] | Should -Be 0x4B
        } finally {
            Remove-Item $out -ErrorAction SilentlyContinue
        }
    }
}

Describe 'v2.5.0 #32 Import-RangerManualEvidence' {
    It 'merges an evidence file into a manifest domain with provenance' {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('ranger-import-' + (Get-Random))
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        try {
            $mPath = Join-Path $tempDir 'audit-manifest.json'
            $ePath = Join-Path $tempDir 'firewall-evidence.json'
            $script:Manifest | ConvertTo-Json -Depth 50 | Set-Content -Path $mPath -Encoding UTF8
            $evidence = [ordered]@{
                domain = 'externalNetworking'
                data = @(
                    [ordered]@{ device = 'fw-hq-01'; vendor = 'PaloAlto'; rulesetVersion = '10.2.3' }
                )
                provenance = [ordered]@{ collectedBy = 'NetOps'; collectedOn = '2026-04-17' }
            }
            $evidence | ConvertTo-Json -Depth 10 | Set-Content -Path $ePath -Encoding UTF8

            $r = Import-RangerManualEvidence -ManifestPath $mPath -EvidencePath $ePath -Source 'manual-firewall-inventory'
            $r.status | Should -Be 'ok'

            $out = Get-Content -Path $mPath -Raw | ConvertFrom-Json -AsHashtable -Depth 50
            $out.domains.externalNetworking.manualImport | Should -Not -BeNullOrEmpty
            $out.domains.externalNetworking.manualImport.source | Should -Be 'manual-firewall-inventory'
            $out.run.manualImports.Count | Should -BeGreaterOrEqual 1
        } finally {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'fails cleanly when the evidence file has no domain field' {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('ranger-import-' + (Get-Random))
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        try {
            $mPath = Join-Path $tempDir 'audit-manifest.json'
            $ePath = Join-Path $tempDir 'bad-evidence.json'
            $script:Manifest | ConvertTo-Json -Depth 50 | Set-Content -Path $mPath -Encoding UTF8
            '{"data":[]}' | Set-Content -Path $ePath -Encoding UTF8
            { Import-RangerManualEvidence -ManifestPath $mPath -EvidencePath $ePath -Source 's' } | Should -Throw
        } finally {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'v2.5.0 #129 estate rollup' {
    It 'produces a rollup summary over two synthetic cluster manifests' {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('ranger-estate-' + (Get-Random))
        $c1 = Join-Path $tempDir 'cluster-a'
        $c2 = Join-Path $tempDir 'cluster-b'
        New-Item -ItemType Directory -Path $c1 -Force | Out-Null
        New-Item -ItemType Directory -Path $c2 -Force | Out-Null
        try {
            $script:Enriched | ConvertTo-Json -Depth 50 | Set-Content -Path (Join-Path $c1 'audit-manifest.json') -Encoding UTF8
            $script:Enriched | ConvertTo-Json -Depth 50 | Set-Content -Path (Join-Path $c2 'audit-manifest.json') -Encoding UTF8

            $results = @(
                [ordered]@{ cluster = 'cluster-a'; outputPath = $c1; manifestPath = (Join-Path $c1 'audit-manifest.json'); manifest = (Get-Content (Join-Path $c1 'audit-manifest.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 50) }
                [ordered]@{ cluster = 'cluster-b'; outputPath = $c2; manifestPath = (Join-Path $c2 'audit-manifest.json'); manifest = (Get-Content (Join-Path $c2 'audit-manifest.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 50) }
            )
            $rollup = & (Get-Module AzureLocalRanger) {
                param($r) New-RangerEstateRollup -ClusterResults $r -RunId '20260417000000' -StartTime (Get-Date)
            } $results
            $rollup.clusterCount | Should -Be 2
            $rollup.totalNodes   | Should -BeGreaterThan 0
            @($rollup.clusters).Count | Should -Be 2
        } finally {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
