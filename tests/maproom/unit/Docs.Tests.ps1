BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
    $script:fixtureRoot = Join-Path $script:repoRoot 'tests\maproom\Fixtures'
    $script:schema = Join-Path $script:repoRoot 'docs\reference\manifest.schema.json'
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
}

Describe 'Manifest JSON Schema (docs/reference/manifest.schema.json)' {
    It 'accepts every manifest fixture' -ForEach @(
        @{ Name = 'synthetic-manifest.json' }, @{ Name = 'synthetic-manifest-current-state.json' }, @{ Name = 'manifest-sample.json' }
    ) {
        (Get-Content (Join-Path $script:fixtureRoot $Name) -Raw) | Test-Json -SchemaFile $script:schema | Should -BeTrue
    }

    It 'rejects a manifest without run, with an unknown collector status or with an invalid finding severity' {
        $m = Get-Content (Join-Path $script:fixtureRoot 'synthetic-manifest.json') -Raw | ConvertFrom-Json -AsHashtable
        $noRun = $m.Clone(); $noRun.Remove('run')
        ($noRun | ConvertTo-Json -Depth 100) | Test-Json -SchemaFile $script:schema -ErrorAction SilentlyContinue | Should -BeFalse
        $badStatus = Get-Content (Join-Path $script:fixtureRoot 'synthetic-manifest.json') -Raw | ConvertFrom-Json -AsHashtable
        $badStatus.collectors['hardware'].status = 'exploded'
        ($badStatus | ConvertTo-Json -Depth 100) | Test-Json -SchemaFile $script:schema -ErrorAction SilentlyContinue | Should -BeFalse
        $badSeverity = Get-Content (Join-Path $script:fixtureRoot 'synthetic-manifest.json') -Raw | ConvertFrom-Json -AsHashtable
        $badSeverity.findings[0].severity = 'catastrophic'
        ($badSeverity | ConvertTo-Json -Depth 100) | Test-Json -SchemaFile $script:schema -ErrorAction SilentlyContinue | Should -BeFalse
    }

    It 'accepts the redacted manifest and the manifest after the 12.2609 and degradation additions' {
        $m = Get-Content (Join-Path $script:fixtureRoot 'synthetic-manifest.json') -Raw | ConvertFrom-Json -AsHashtable
        $red = InModuleScope AzureLocalRanger -Parameters @{ m = $m } { param($m) $null = Invoke-RangerPlatform2609Analysis -Manifest $m; ConvertTo-RangerRedactedManifest -Manifest $m }
        $red.run.redaction.enabled | Should -BeTrue
        ($red | ConvertTo-Json -Depth 100) | Test-Json -SchemaFile $script:schema | Should -BeTrue
        $m.collectors['hardware'].degraded = $true
        $m.collectors['hardware'].degradationCount = 1
        $m.collectors['hardware'].degradations = @(@{ source = 'x'; message = 'y' })
        ($m | ConvertTo-Json -Depth 100) | Test-Json -SchemaFile $script:schema | Should -BeTrue
    }
}

Describe 'Documentation stays in step with the code' {
    It 'the per-collector reference pages match what the generator produces' {
        $stale = @(& (Join-Path $script:repoRoot 'scripts\docs\New-CollectorReferencePages.ps1') -Check)
        $stale | Should -BeNullOrEmpty -Because 'run scripts/docs/New-CollectorReferencePages.ps1 and commit the result'
    }

    It 'every collector definition has a reference page' {
        $ids = InModuleScope AzureLocalRanger { @((Get-RangerCollectorDefinitions).Keys) }
        foreach ($id in $ids) { Test-Path (Join-Path $script:repoRoot "docs\reference\collectors\$id.md") | Should -BeTrue -Because $id }
    }

    It 'has no broken relative Markdown links' {
        $broken = @(& (Join-Path $script:repoRoot 'scripts\ci\Test-MarkdownLinks.ps1') -Root $script:repoRoot)
        ($broken | ForEach-Object { "$($_.File):$($_.Line) -> $($_.Target)" }) | Should -BeNullOrEmpty
    }

    It 'the generated YAML header and the command help point at azurelocal.cloud, not azurelocal.github.io' {
        $yaml = InModuleScope AzureLocalRanger { Get-RangerAnnotatedConfigYaml }
        $yaml | Should -Match 'azurelocal\.cloud/azurelocal-ranger'
        $yaml | Should -Not -Match 'azurelocal\.github\.io'
        (Get-Content (Join-Path $script:repoRoot 'samples\configs\ranger.yml') -Raw) | Should -Not -Match 'azurelocal\.github\.io'
        (Get-Help Invoke-AzureLocalRanger -Full | Out-String) | Should -Not -Match 'azurelocal\.github\.io'
    }

    It 'the release workflow files exist and every action is pinned to a commit SHA' {
        foreach ($wf in 'ci.yml', 'release-please.yml', 'publish-gallery.yml', 'deploy-docs.yml') {
            $path = Join-Path $script:repoRoot ".github\workflows\$wf"
            Test-Path $path | Should -BeTrue -Because $wf
            $uses = Select-String -Path $path -Pattern '^\s*-?\s*uses:\s*(\S+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
            foreach ($u in $uses) { $u | Should -Match '@[0-9a-f]{40}$' -Because "$wf pins $u" }
        }
    }

    It 'every Pester file is assigned to a CI shard' {
        $ci = Get-Content (Join-Path $script:repoRoot '.github\workflows\ci.yml') -Raw
        foreach ($f in Get-ChildItem (Join-Path $script:repoRoot 'tests') -Recurse -Filter '*.Tests.ps1') { $ci | Should -Match ([regex]::Escape($f.Name)) -Because "$($f.Name) must run in CI" }
    }

    It 'the PSGallery publish job needs an approved environment and a secret, and never prints it' {
        $wf = Get-Content (Join-Path $script:repoRoot '.github\workflows\publish-gallery.yml') -Raw
        $wf | Should -Match 'environment: psgallery'
        $wf | Should -Match 'secrets\.PSGALLERY_API_KEY'
        $wf | Should -Not -Match 'Write-Host\s+\$env:PSGALLERY_API_KEY'
    }
}
