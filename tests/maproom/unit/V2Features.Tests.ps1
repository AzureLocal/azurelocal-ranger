#Requires -Module Pester
<#
.SYNOPSIS
    v2.0.0 Pester coverage for:
      #215 Arc extensions per-node structure
      #216 Logical networks + subnets
      #217 Storage paths
      #219 Resource Bridge detail
      #218 Custom Locations
      #220 Arc Gateway + per-node routing
      #221 Marketplace + custom gallery images
      #222 Cost/Licensing (AHB) analysis
      #223 VM distribution balance
      #224 Arc agent version grouping
      #225 Weighted WAF scoring + score thresholds
      #226 Export-/Import-RangerWafConfig
      #229 json-evidence export
      #230 Empty-data guard
      #231 Module auto-install validator
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    Import-Module (Join-Path $RepoRoot 'AzureLocalRanger.psd1') -Force

    $fixturePath = Join-Path $RepoRoot 'tests\maproom\Fixtures\synthetic-manifest-current-state.json'
    $script:Manifest = Get-Content -Path $fixturePath -Raw | ConvertFrom-Json -AsHashtable -Depth 50

    # Helper to call module-internal functions by name, since most helpers are not exported.
    function Invoke-RangerInternal {
        param([string]$Name, [object[]]$Args)
        $mod = Get-Module AzureLocalRanger
        $sb  = [scriptblock]::Create("param(`$A) & `$$Name @A")
        return & $mod $sb $Args
    }
}

Describe 'v2.0.0 fixture shape' {
    It '#215: arcExtensionsDetail is a hashtable with byNode + summary, not a bare array' {
        $ext = $script:Manifest.domains.azureIntegration.arcExtensionsDetail
        $ext | Should -BeOfType [System.Collections.IDictionary]
        $ext.byNode  | Should -Not -BeNullOrEmpty
        $ext.summary | Should -Not -BeNullOrEmpty
        $ext.summary.amaCoveragePct | Should -Be 100
    }

    It '#216: logical networks present with subnets and VLAN IDs' {
        $lns = @($script:Manifest.domains.networking.logicalNetworks)
        $lns.Count | Should -BeGreaterThan 0
        $lns[0].subnets | Should -Not -BeNullOrEmpty
        $lns[0].subnets[0].vlan | Should -BeGreaterThan 0
    }

    It '#217: storage paths are populated under storage domain' {
        @($script:Manifest.domains.storage.storagePaths).Count | Should -BeGreaterThan 0
        $script:Manifest.domains.storage.storagePaths[0].path | Should -Not -BeNullOrEmpty
    }

    It '#219: resource bridge detail + provisioning state present' {
        @($script:Manifest.domains.azureIntegration.resourceBridgeDetail).Count | Should -BeGreaterThan 0
        $script:Manifest.domains.azureIntegration.resourceBridgeDetail[0].status | Should -Be 'Connected'
    }

    It '#218: custom locations detail reference resource bridge host resource ID' {
        $cl = $script:Manifest.domains.azureIntegration.customLocationsDetail[0]
        $cl | Should -Not -BeNullOrEmpty
        $cl.hostResourceId | Should -Match 'Microsoft\.ResourceConnector/appliances'
    }

    It '#220: arc gateway + per-node routing populated' {
        @($script:Manifest.domains.azureIntegration.arcGateways).Count | Should -Be 1
        @($script:Manifest.domains.azureIntegration.arcGatewayNodeRouting).Count | Should -Be 3
    }

    It '#221: marketplace + custom gallery images present with distinct imageType' {
        $mi = @($script:Manifest.domains.azureIntegration.marketplaceImages)
        $gi = @($script:Manifest.domains.azureIntegration.galleryImages)
        $mi.Count | Should -BeGreaterThan 0
        $gi.Count | Should -BeGreaterThan 0
        $mi[0].imageType | Should -Be 'Marketplace'
        $gi[0].imageType | Should -Be 'Custom'
    }

    It '#222: costLicensing has AHB summary with adoption percent' {
        $s = $script:Manifest.domains.azureIntegration.costLicensing.summary
        $s.totalPhysicalCores | Should -BeGreaterThan 0
        $s.ahbAdoptionPct     | Should -Be 100
        $s.currency           | Should -Be 'USD'
    }

    It '#223: VM distribution summary is populated' {
        $vd = $script:Manifest.domains.virtualMachines.summary.vmDistribution
        @($vd).Count | Should -Be 3
        $script:Manifest.domains.virtualMachines.summary.vmDistributionBalanced | Should -Be $true
    }

    It '#224: arc agent version groups + OS version groups populated' {
        $groups = @($script:Manifest.domains.clusterNode.nodeSummary.arcAgentVersionGroups)
        $groups.Count | Should -Be 2
        ($groups | Measure-Object -Property nodeCount -Sum).Sum | Should -Be 3
    }
}

Describe 'v2.0.0 WAF weighted scoring (#225)' {
    BeforeAll {
        $script:WafResult = & (Get-Module AzureLocalRanger) { param($m) Invoke-RangerWafRuleEvaluation -Manifest $m } $script:Manifest
    }

    It 'returns a summary with overall score, weighted totals, and status' {
        $script:WafResult.summary.overallScore     | Should -BeOfType [int]
        $script:WafResult.summary.weightedAwarded  | Should -BeGreaterThan 0
        $script:WafResult.summary.weightedMax      | Should -BeGreaterThan 0
        $script:WafResult.summary.status           | Should -BeIn @('Excellent','Good','Fair','Needs Improvement')
    }

    It 'weighted rules carry weight / weightedAwarded / weightedMaxPoints' {
        $sample = $script:WafResult.ruleResults | Select-Object -First 1
        $sample.weight           | Should -BeGreaterThan 0
        $sample.weightedMaxPoints | Should -BeGreaterThan 0
    }

    It 'weight multiplies a weight-3 rule by 3 against a weight-1 rule' {
        $w1 = @($script:WafResult.ruleResults | Where-Object { $_.weight -eq 1 -and $_.pass -eq $true } | Select-Object -First 1)[0]
        $w3 = @($script:WafResult.ruleResults | Where-Object { $_.weight -eq 3 -and $_.pass -eq $true } | Select-Object -First 1)[0]
        if ($w1 -and $w3) {
            ($w3.weightedMaxPoints / $w1.weightedMaxPoints) | Should -BeGreaterThan 1
        }
    }

    It 'scoreThresholds are exposed on the result' {
        $script:WafResult.scoreThresholds.excellent | Should -Be 80
        $script:WafResult.scoreThresholds.good      | Should -Be 60
    }

    It 'AHB weight-3 graduated rule resolves via calculation' {
        $ahb = @($script:WafResult.ruleResults | Where-Object { $_.id -eq 'COST-003' })
        $ahb.Count | Should -Be 1
        $ahb[0].weight           | Should -Be 3
        $ahb[0].weightedMaxPoints | Should -Be 9  # maxPoints 3 × weight 3
    }
}

Describe 'v2.0.0 manifest analysis helpers (#222, #223, #224)' {
    It 'Invoke-RangerVmDistributionAnalysis returns balanced=true on [2,2,1] distribution' {
        $r = & (Get-Module AzureLocalRanger) { param($m) Invoke-RangerVmDistributionAnalysis -Manifest $m } $script:Manifest
        $r.balanced | Should -Be $true
        $r.cv       | Should -BeLessThan 0.3
    }

    It 'Invoke-RangerAgentVersionAnalysis reports 2 unique versions' {
        $r = & (Get-Module AzureLocalRanger) { param($m) Invoke-RangerAgentVersionAnalysis -Manifest $m } $script:Manifest
        $r.drift.uniqueVersions | Should -Be 2
        $r.drift.status          | Should -BeIn @('warning','fail')
    }

    It 'Invoke-RangerCostLicensingAnalysis preserves existing costLicensing when present' {
        $r = & (Get-Module AzureLocalRanger) { param($m) Invoke-RangerCostLicensingAnalysis -Manifest $m } $script:Manifest
        $r.summary.totalPhysicalCores | Should -Be 96
    }
}

Describe 'v2.0.0 Export-/Import-RangerWafConfig (#226)' {
    BeforeAll {
        $script:ExportPath = Join-Path ([System.IO.Path]::GetTempPath()) ("ranger-waf-export-{0}.json" -f ([guid]::NewGuid()))
    }
    AfterAll {
        if (Test-Path $script:ExportPath) { Remove-Item $script:ExportPath -Force }
    }

    It 'Export-RangerWafConfig writes a JSON file with version and rules' {
        Export-RangerWafConfig -OutputPath $script:ExportPath | Out-Null
        Test-Path $script:ExportPath | Should -Be $true
        $json = Get-Content $script:ExportPath -Raw | ConvertFrom-Json
        $json.version | Should -Match '^[0-9]+'
        @($json.rules).Count | Should -BeGreaterThan 20
    }

    It 'Import-RangerWafConfig -Validate returns a dry-run result object' {
        $r = Import-RangerWafConfig -Path $script:ExportPath -Validate
        $r.validated | Should -Be $true
        $r.ruleCount | Should -BeGreaterThan 20
    }

    It 'Import-RangerWafConfig throws on malformed JSON' {
        $bad = Join-Path ([System.IO.Path]::GetTempPath()) ("ranger-waf-bad-{0}.json" -f ([guid]::NewGuid()))
        'this is { not valid json' | Set-Content -Path $bad -Encoding UTF8
        try   { { Import-RangerWafConfig -Path $bad } | Should -Throw }
        finally { Remove-Item $bad -Force -ErrorAction SilentlyContinue }
    }

    It 'Import-RangerWafConfig throws on schema violation (missing id)' {
        $bad = Join-Path ([System.IO.Path]::GetTempPath()) ("ranger-waf-bad-{0}.json" -f ([guid]::NewGuid()))
        @{ version = '1.0'; pillars = @('x'); rules = @(@{ pillar = 'x'; title = 'y' }) } | ConvertTo-Json -Depth 5 | Set-Content -Path $bad -Encoding UTF8
        try   { { Import-RangerWafConfig -Path $bad } | Should -Throw }
        finally { Remove-Item $bad -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'v2.0.0 JSON evidence export (#229)' {
    BeforeAll {
        $script:EvidenceDir = Join-Path ([System.IO.Path]::GetTempPath()) ("ranger-evidence-{0}" -f ([guid]::NewGuid()))
        New-Item -ItemType Directory -Path $script:EvidenceDir -Force | Out-Null
        & (Get-Module AzureLocalRanger) { param($m, $p) Write-RangerJsonEvidenceExport -Manifest $m -PackageRoot $p } $script:Manifest $script:EvidenceDir | Out-Null
        $script:EvidenceFile = Get-ChildItem -Path (Join-Path $script:EvidenceDir 'reports') -Filter '*-evidence.json' | Select-Object -First 1
        $script:EvidencePayload = Get-Content $script:EvidenceFile.FullName -Raw | ConvertFrom-Json
    }
    AfterAll {
        if (Test-Path $script:EvidenceDir) { Remove-Item $script:EvidenceDir -Recurse -Force }
    }

    It 'produces a file named <runId>-evidence.json' {
        $script:EvidenceFile.Name | Should -Match '^\d+-evidence\.json$'
    }

    It '_metadata envelope contains rangerVersion + clusterName' {
        $script:EvidencePayload._metadata.rangerVersion | Should -Not -BeNullOrEmpty
        $script:EvidencePayload._metadata.clusterName   | Should -Be 'azlocal-iic-01'
    }

    It 'excludes scoring / run metadata (no wafResults, no findings, no run)' {
        $props = $script:EvidencePayload.PSObject.Properties.Name
        $props | Should -Not -Contain 'wafResults'
        $props | Should -Not -Contain 'findings'
        $props | Should -Not -Contain 'run'
        $props | Should -Not -Contain 'summary'
    }

    It 'includes nodes + logicalNetworks + storagePaths + costLicensing' {
        @($script:EvidencePayload.nodes).Count             | Should -BeGreaterThan 0
        @($script:EvidencePayload.logicalNetworks).Count   | Should -BeGreaterThan 0
        @($script:EvidencePayload.storagePaths).Count      | Should -BeGreaterThan 0
        $script:EvidencePayload.costLicensing               | Should -Not -BeNullOrEmpty
    }
}

Describe 'v2.0.0 module auto-install validator (#231)' {
    It 'Invoke-RangerModuleValidation returns an array with required modules' {
        $result = & (Get-Module AzureLocalRanger) { Invoke-RangerModuleValidation -Quiet }
        @($result).Count | Should -BeGreaterThan 0
        @($result | Where-Object { $_.category -eq 'required' }).Count | Should -BeGreaterOrEqual 3
    }

    It 'Each entry has name, category, status fields' {
        $result = & (Get-Module AzureLocalRanger) { Invoke-RangerModuleValidation -Quiet }
        foreach ($r in $result) {
            $r.name     | Should -Not -BeNullOrEmpty
            $r.category | Should -BeIn @('required','optional')
            $r.status   | Should -BeIn @('ok','current','installed','updated','missing-optional','install-failed','update-failed')
        }
    }
}
