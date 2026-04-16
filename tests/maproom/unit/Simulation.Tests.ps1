BeforeAll {
    $script:repoRoot     = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
    $script:fixtureRoot  = Join-Path $script:repoRoot 'tests\maproom\Fixtures'
    $script:manifestPath = Join-Path $script:fixtureRoot 'synthetic-manifest.json'
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
}

Describe 'Azure Local Ranger simulation tests (IIC synthetic manifest)' {

    It 'renders all 3 report tiers from the IIC synthetic manifest' {
        $outputRoot = Join-Path $TestDrive 'sim-all-tiers'
        $null = Export-AzureLocalRangerReport -ManifestPath $manifestPath -OutputPath $outputRoot -Formats @('markdown')

        $mdFiles = @(Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*.md' -ErrorAction SilentlyContinue)
        $mdFiles.Count | Should -Be 3
        (@($mdFiles.Name | Where-Object { $_ -match 'Executive' })).Count   | Should -Be 1
        # v1.5.0 (#194): as-built uses Installation and Configuration Record for the mid-tier
        (@($mdFiles.Name | Where-Object { $_ -match 'Installation' })).Count | Should -Be 1
        (@($mdFiles.Name | Where-Object { $_ -match 'Technical' })).Count   | Should -Be 1
    }

    It 'includes the IIC cluster name in rendered reports' {
        $outputRoot = Join-Path $TestDrive 'sim-cluster-name'
        $null = Export-AzureLocalRangerReport -ManifestPath $manifestPath -OutputPath $outputRoot -Formats @('markdown')

        $anyReport = Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*.md' | Select-Object -First 1
        $content   = Get-Content -Path $anyReport.FullName -Raw
        $content | Should -Match 'azlocal-iic-01'
    }

    It 'surfaces warning findings in the executive and management reports' {
        $outputRoot   = Join-Path $TestDrive 'sim-warnings'
        $null = Export-AzureLocalRangerReport -ManifestPath $manifestPath -OutputPath $outputRoot -Formats @('markdown')

        $execReport = Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*Executive*' | Select-Object -First 1
        # v1.5.0 (#194): synthetic fixture is as-built; mid-tier is Installation and Configuration Record
        $midReport  = Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*Installation*' | Select-Object -First 1

        (Get-Content -Path $execReport.FullName -Raw) | Should -Match '(?i)warning|Priority Recommendations'
        (Get-Content -Path $midReport.FullName -Raw)  | Should -Match '(?i)warning|Priority Recommendations'
    }

    It 'generates at least 5 diagrams in as-built mode' {
        $outputRoot  = Join-Path $TestDrive 'sim-diagrams'
        $null = Export-AzureLocalRangerReport -ManifestPath $manifestPath -OutputPath $outputRoot -Formats @('svg')

        $diagrams = @(Get-ChildItem -Path (Join-Path $outputRoot 'diagrams') -Filter '*.svg' -ErrorAction SilentlyContinue)
        $diagrams.Count | Should -BeGreaterOrEqual 5
    }

    It 'generates the monitoring-telemetry-flow diagram' {
        $outputRoot = Join-Path $TestDrive 'sim-monitoring-diag'
        $result = Export-AzureLocalRangerReport -ManifestPath $manifestPath -OutputPath $outputRoot -Formats @('svg')

        $generated = @($result.Artifacts | Where-Object { $_.status -eq 'generated' -and $_.relativePath -match 'monitoring-telemetry-flow' })
        $generated.Count | Should -BeGreaterThan 0
    }

    It 'generates the workload-family-placement diagram' {
        $outputRoot = Join-Path $TestDrive 'sim-workload-diag'
        $result = Export-AzureLocalRangerReport -ManifestPath $manifestPath -OutputPath $outputRoot -Formats @('svg')

        $generated = @($result.Artifacts | Where-Object { $_.status -eq 'generated' -and $_.relativePath -match 'workload-family-placement' })
        $generated.Count | Should -BeGreaterThan 0
    }

    It 'records no error-state diagram artifacts' {
        $outputRoot = Join-Path $TestDrive 'sim-no-errors'
        $result = Export-AzureLocalRangerReport -ManifestPath $manifestPath -OutputPath $outputRoot -Formats @('svg')

        $errorArtifacts = @($result.Artifacts | Where-Object { $_.status -eq 'error' })
        $errorArtifacts.Count | Should -Be 0
    }

    It 'as-built report includes document control block' {
        $outputRoot = Join-Path $TestDrive 'sim-asbuilt-doccontrol'
        $null = Export-AzureLocalRangerReport -ManifestPath $manifestPath -OutputPath $outputRoot -Formats @('markdown')

        $anyReport = Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*.md' | Select-Object -First 1
        $content   = Get-Content -Path $anyReport.FullName -Raw
        $content | Should -Match '(?i)Document Control'
        $content | Should -Match '(?i)AS-BUILT HANDOFF'
    }

    It 'as-built report includes sign-off section' {
        $outputRoot = Join-Path $TestDrive 'sim-asbuilt-signoff'
        $null = Export-AzureLocalRangerReport -ManifestPath $manifestPath -OutputPath $outputRoot -Formats @('markdown')

        $techReport = Get-ChildItem -Path (Join-Path $outputRoot 'reports') -Filter '*Technical*' | Select-Object -First 1
        $content    = Get-Content -Path $techReport.FullName -Raw
        $content | Should -Match '(?i)sign.?off'
        $content | Should -Match '(?i)Implementation Engineer'
    }
}
