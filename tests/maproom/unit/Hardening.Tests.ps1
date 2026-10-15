BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
}

Describe 'Module health (verifies the roadmap claims about 80-ProgressDisplay.ps1)' {
    It 'every module script parses without a syntax error, including 80-ProgressDisplay.ps1' {
        $errors = foreach ($f in Get-ChildItem -Path (Join-Path $script:repoRoot 'Modules') -Recurse -Filter '*.ps1') {
            $e = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$e)
            foreach ($x in @($e)) { "$($f.Name):$($x.Extent.StartLineNumber) $($x.Message)" }
        }
        $errors | Should -BeNullOrEmpty
        Test-Path (Join-Path $script:repoRoot 'Modules\Private\80-ProgressDisplay.ps1') | Should -BeTrue
    }

    It 'Test-ModuleManifest passes and states PowerShell 7+ (Core) as the only supported edition' {
        $m = Test-ModuleManifest -Path (Join-Path $script:repoRoot 'AzureLocalRanger.psd1')
        $m.PowerShellVersion | Should -Be ([version]'7.0')
        $m.CompatiblePSEditions | Should -Be @('Core')
        $m.ExportedFunctions.Keys.Count | Should -BeGreaterThan 12
    }

    It 'no empty catch block is left in the module (errors are logged at debug level instead)' {
        $empty = foreach ($f in Get-ChildItem -Path (Join-Path $script:repoRoot 'Modules') -Recurse -Filter '*.ps1') {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$null)
            $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CatchClauseAst] -and $n.Body.Statements.Count -eq 0 }, $true) | ForEach-Object { "$($f.Name):$($_.Extent.StartLineNumber)" }
        }
        $empty | Should -BeNullOrEmpty
    }
}

Describe 'ProgressDisplay (non-interactive path; PwshSpectreConsole stays optional)' {
    It 'suppresses the Spectre TUI in CI and falls back to Write-Progress' {
        InModuleScope AzureLocalRanger {
            $old = $env:CI
            try {
                $env:CI = 'true'
                Test-RangerSpectreAvailable | Should -BeFalse
                $ctx = New-RangerProgressContext -Collectors @(@{ Id = 'a' }, @{ Id = 'b' })
                $ctx.Mode | Should -Be 'fallback'
                $ctx.Total | Should -Be 2
            }
            finally { $env:CI = $old }
        }
    }

    It 'counts completed collectors and tolerates every status in fallback mode' {
        InModuleScope AzureLocalRanger {
            $ctx = [ordered]@{ Mode = 'fallback'; Total = 3; Completed = 0; Tasks = [ordered]@{} }
            foreach ($id in 'a', 'b', 'c') {
                { Update-RangerProgressCollectorStart -Context $ctx -CollectorId $id } | Should -Not -Throw
            }
            Update-RangerProgressCollectorDone -Context $ctx -CollectorId 'a' -Status success
            Update-RangerProgressCollectorDone -Context $ctx -CollectorId 'b' -Status skipped
            Update-RangerProgressCollectorDone -Context $ctx -CollectorId 'c' -Status failed
            $ctx.Completed | Should -Be 3
            { Complete-RangerProgressDisplay -Context $ctx } | Should -Not -Throw
        }
    }

    It 'mode none is a no-op but still counts' {
        InModuleScope AzureLocalRanger {
            $ctx = [ordered]@{ Mode = 'none'; Total = 1; Completed = 0; Tasks = @() }
            Update-RangerProgressCollectorStart -Context $ctx -CollectorId 'a'
            Update-RangerProgressCollectorDone -Context $ctx -CollectorId 'a'
            $ctx.Completed | Should -Be 1
        }
    }

    It 'spectre mode updates task rows and prints through Spectre (cmdlets mocked, module not required)' {
        InModuleScope AzureLocalRanger {
            function Write-SpectreHost { param($Message, [switch]$NoNewline) }
            function Write-SpectreRule { param($Title, $Color) }
            Mock Write-SpectreHost {}
            Mock Write-SpectreRule {}
            Mock Test-RangerSpectreAvailable { $true }
            Mock Import-RangerSpectreConsole { $true }
            $ctx = New-RangerProgressContext -Collectors @(@{ Id = 'a' }, @{ Id = 'b' })
            $ctx.Mode | Should -Be 'spectre'
            Update-RangerProgressCollectorStart -Context $ctx -CollectorId 'a'
            ($ctx.Tasks | Where-Object Id -eq 'a').Status | Should -Be 'running'
            Update-RangerProgressCollectorDone -Context $ctx -CollectorId 'a' -Status success
            Update-RangerProgressCollectorDone -Context $ctx -CollectorId 'b' -Status failed
            ($ctx.Tasks | Where-Object Id -eq 'a').Status | Should -Be 'success'
            ($ctx.Tasks | Where-Object Id -eq 'b').Status | Should -Be 'failed'
            Complete-RangerProgressDisplay -Context $ctx
            Should -Invoke Write-SpectreHost -Times 1 -ParameterFilter { $Message -match '1 ok.*1 failed' }
        }
    }

    It 'Write-RangerProgressSummary does not throw outside Spectre (it used to build an invalid path)' {
        InModuleScope AzureLocalRanger {
            $m = [ordered]@{ run = [ordered]@{ connectivity = [ordered]@{ posture = 'connected' } }; findings = @(@{ severity = 'warning' }) }
            { Write-RangerProgressSummary -Manifest $m } | Should -Not -Throw
        }
    }
}

Describe 'Non-fatal errors are logged and mark the collector degraded' {
    It 'Write-RangerSwallowedError records the collector, the source and the message' {
        InModuleScope AzureLocalRanger {
            $script:RangerCurrentCollectorId = 'unit'
            $script:RangerCollectorDegradations = New-Object System.Collections.ArrayList
            Mock Write-RangerLog {}
            try { throw 'disk unavailable' } catch { Write-RangerSwallowedError -Source 'Test-Source' -ErrorRecord $_ }
            $script:RangerCollectorDegradations.Count | Should -Be 1
            $script:RangerCollectorDegradations[0].source | Should -Be 'Test-Source'
            $script:RangerCollectorDegradations[0].message | Should -Be 'disk unavailable'
            Should -Invoke Write-RangerLog -Times 1 -ParameterFilter { $Level -eq 'debug' -and $Message -match 'unit.*Test-Source.*disk unavailable' }
        }
    }

    It 'a collector whose reads fail ends up degraded in the manifest, with its status unchanged' {
        InModuleScope AzureLocalRanger {
            function Invoke-RangerFakeDegradedCollector {
                param($Config, $CredentialMap, $Definition, $PackageRoot)
                $null = Invoke-RangerSafeAction -Label 'Optional read' -DefaultValue @() -ScriptBlock { throw 'access denied' }
                @{ Status = 'success'; Domains = @{ hardware = @{ nodes = @() } } }
            }
            Mock Write-RangerLog {}
            $def = @{ Id = 'fake'; FunctionName = 'Invoke-RangerFakeDegradedCollector'; RequiredTargets = @('cluster'); RequiredCredential = 'cluster'; Class = 'optional' }
            $r = Invoke-RangerCollectorExecution -Definition $def -Config @{ behavior = @{} } -CredentialMap @{} -PackageRoot $TestDrive
            $r.Status | Should -Be 'success'
            @($r.Degradations).Count | Should -Be 1

            $manifest = [ordered]@{ collectors = [ordered]@{}; domains = [ordered]@{}; relationships = @(); findings = @(); evidence = @() }
            Add-RangerCollectorToManifest -Manifest ([ref]$manifest) -CollectorResult $r
            $manifest.collectors['fake'].status | Should -Be 'success'
            $manifest.collectors['fake'].degraded | Should -BeTrue
            $manifest.collectors['fake'].degradationCount | Should -Be 1
            $manifest.collectors['fake'].degradations[0].source | Should -Be 'Optional read'
        }
    }

    It 'a collector with no failed reads is not degraded' {
        InModuleScope AzureLocalRanger {
            $manifest = [ordered]@{ collectors = [ordered]@{}; domains = [ordered]@{}; relationships = @(); findings = @(); evidence = @() }
            Add-RangerCollectorToManifest -Manifest ([ref]$manifest) -CollectorResult @{ CollectorId = 'clean'; Status = 'success'; StartTimeUtc = 'a'; EndTimeUtc = 'b'; TargetScope = @(); CredentialScope = 'x'; Messages = @(); Degradations = @() }
            $manifest.collectors['clean'].degraded | Should -BeFalse
            $manifest.collectors['clean'].degradationCount | Should -Be 0
        }
    }
}
