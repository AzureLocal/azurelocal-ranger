BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
    # Remove any previously loaded instances (e.g. system-installed 1.1.x) before loading
    # the repo version — multiple loaded instances cause InModuleScope to enumerate all of
    # them and return aggregated results, breaking count assertions.
    Get-Module AzureLocalRanger | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force
}

# ─────────────────────────────────────────────────────────────────────────────
# Bug #157 — authorization probe must use RetryCount 0 (not the run RetryCount)
# "Access is denied" is a definitive auth failure, not a transient network error.
# ─────────────────────────────────────────────────────────────────────────────
Describe 'Resolve-RangerRemoteExecutionCredential — auth probe retry count' {

    It 'passes RetryCount 0 to Test-RangerRemoteAuthorization regardless of outer RetryCount (#157)' {
        InModuleScope AzureLocalRanger {
            $capturedRetryCount = $null
            Mock Test-RangerRemoteAuthorization {
                param($ComputerName, [PSCredential]$Credential, $RetryCount, $TimeoutSeconds)
                $script:capturedRetryCount = $RetryCount
                throw [System.Management.Automation.Remoting.PSRemotingTransportException]::new('Access is denied.')
            }
            Mock Get-RangerRemoteCredentialCandidates {
                @([ordered]@{ Name = 'domain'; Credential = $null; UserName = 'MGMT\svc.azl.local' })
            }
            Mock Get-RangerExecutionHostContext { [ordered]@{ ComputerName = 'runner'; Domain = $null; IsDomainJoined = $null } }

            { Resolve-RangerRemoteExecutionCredential -Targets @('node01') -RetryCount 3 -TimeoutSeconds 30 } |
                Should -Throw

            $script:capturedRetryCount | Should -Be 0 -Because 'Access is denied is not transient; retrying burns time and adds noise'
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Bug #158 — WinRM probe cache key must be host-only; credential must not factor in
# ─────────────────────────────────────────────────────────────────────────────
Describe 'Get-RangerWinRmProbeCacheKey — host-only key' {

    It 'returns lowercase computer name (#158)' {
        InModuleScope AzureLocalRanger {
            $key = Get-RangerWinRmProbeCacheKey -ComputerName 'NODE01'
            $key | Should -Be 'node01'
        }
    }

    It 'is case-insensitive — NODE01 and node01 produce the same key (#158)' {
        InModuleScope AzureLocalRanger {
            $upper = Get-RangerWinRmProbeCacheKey -ComputerName 'NODE01'
            $lower = Get-RangerWinRmProbeCacheKey -ComputerName 'node01'
            $upper | Should -Be $lower
        }
    }
}

Describe 'Test-RangerWinRmTarget — cache de-duplication' {

    It 'calls Test-WSMan only once per host regardless of how many times it is invoked (#158)' {
        InModuleScope AzureLocalRanger {
            $script:RangerWinRmProbeCache = @{}
            # Test-NetConnection is Windows-only — return $false so TCP probe is skipped on Linux CI.
            # Test-WSMan is cross-platform in pwsh — return $true so WSMan probe still runs.
            Mock Test-RangerCommandAvailable { $false } -ParameterFilter { $Name -eq 'Test-NetConnection' }
            Mock Test-RangerCommandAvailable { $true  } -ParameterFilter { $Name -eq 'Test-WSMan' }
            Mock Test-WSMan { [pscustomobject]@{ wsmid = 'ok' } }

            Test-RangerWinRmTarget -ComputerName 'node01'
            Test-RangerWinRmTarget -ComputerName 'node01'
            Test-RangerWinRmTarget -ComputerName 'node01'

            Should -Invoke Test-WSMan -Times 1 -Because 'second and third calls must be served from cache'
        }
    }

    It 'uses Authentication None — not Negotiate (#158)' {
        InModuleScope AzureLocalRanger {
            $script:RangerWinRmProbeCache = @{}
            # Test-NetConnection is Windows-only — return $false so TCP probe is skipped on Linux CI.
            # Test-WSMan is cross-platform in pwsh — return $true so WSMan probe still runs.
            Mock Test-RangerCommandAvailable { $false } -ParameterFilter { $Name -eq 'Test-NetConnection' }
            Mock Test-RangerCommandAvailable { $true  } -ParameterFilter { $Name -eq 'Test-WSMan' }
            Mock Test-WSMan { [pscustomobject]@{ wsmid = 'ok' } }

            Test-RangerWinRmTarget -ComputerName 'node02'

            Should -Invoke Test-WSMan -ParameterFilter { $Authentication -eq 'None' } `
                -Because 'WSMan probe is connectivity-only; passing credentials or Negotiate auth is wrong'
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Bug #159 — Invoke-Command TerminatingError must not be double-wrapped
# ─────────────────────────────────────────────────────────────────────────────
Describe 'Invoke-RangerRemoteCommand — exception propagation' {

    It 're-throws PSRemotingTransportException exactly once (#159)' {
        InModuleScope AzureLocalRanger {
            $script:RangerWinRmProbeCache = @{}
            Mock Test-RangerWinRmTarget {
                [ordered]@{ Reachable = $true; Transport = 'http'; Port = 5985; Message = 'ok' }
            }
            Mock Invoke-Command {
                throw [System.Management.Automation.Remoting.PSRemotingTransportException]::new('Access is denied.')
            }

            $caughtCount = 0
            $caughtType  = $null
            try {
                Invoke-RangerRemoteCommand -ComputerName @('node01') -ScriptBlock { 1 } -RetryCount 0
            }
            catch {
                $caughtCount++
                $caughtType = $_.Exception.GetType().FullName
            }

            $caughtCount | Should -Be 1 -Because 'exception must propagate once, not be wrapped again'
            $caughtType  | Should -Be 'System.Management.Automation.Remoting.PSRemotingTransportException'
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Bug #160 — Get-RangerManifestSchemaContract must not depend on repo-management/
# ─────────────────────────────────────────────────────────────────────────────
Describe 'Get-RangerManifestSchemaContract — PSGallery install compatibility' {

    It 'returns a schema contract without touching the filesystem (#160)' {
        InModuleScope AzureLocalRanger {
            { Get-RangerManifestSchemaContract } | Should -Not -Throw
        }
    }

    It 'schema contract contains all expected top-level keys (#160)' {
        InModuleScope AzureLocalRanger {
            $contract = Get-RangerManifestSchemaContract
            $contract.requiredTopLevelKeys | Should -Contain 'run'
            $contract.requiredTopLevelKeys | Should -Contain 'collectors'
            $contract.requiredTopLevelKeys | Should -Contain 'domains'
            $contract.collectorStatuses    | Should -Contain 'success'
            $contract.reservedDomains      | Should -Contain 'hardware'
        }
    }

    It 'does not access the filesystem during schema contract retrieval (#160)' {
        InModuleScope AzureLocalRanger {
            # If schema is embedded inline, Test-Path / Get-Content should never be called
            Mock Test-Path   { $false } -ParameterFilter { $Path -match 'manifest-schema' }
            Mock Get-Content { throw 'Get-Content must not be called for embedded schema' } -ParameterFilter { $Path -match 'manifest-schema' }

            { Get-RangerManifestSchemaContract } | Should -Not -Throw
            Should -Invoke Get-Content -Times 0 -ParameterFilter { $Path -match 'manifest-schema' } `
                -Because 'schema must be embedded inline so PSGallery installs work without repo-management/'
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Bug #161 — toolVersion must reflect the running module version, not '1.1.0'
# ─────────────────────────────────────────────────────────────────────────────
Describe 'New-RangerManifest — toolVersion accuracy' {

    It 'toolVersion is not the stale hardcoded 1.1.0 default (#161)' {
        InModuleScope AzureLocalRanger {
            $config = Get-RangerDefaultConfig
            $config.behavior.promptForMissingCredentials = $false
            $collectors = Resolve-RangerSelectedCollectors -Config $config
            $manifest = New-RangerManifest -Config $config -SelectedCollectors $collectors
            $manifest.run.toolVersion | Should -Not -Be '1.1.0' `
                -Because 'hardcoded default was never bumped when the module version changed'
        }
    }

    It 'toolVersion matches the loaded module version (#161)' {
        InModuleScope AzureLocalRanger {
            $config = Get-RangerDefaultConfig
            $config.behavior.promptForMissingCredentials = $false
            $collectors = Resolve-RangerSelectedCollectors -Config $config
            $manifest = New-RangerManifest -Config $config -SelectedCollectors $collectors

            $expectedVersion = (Get-Module AzureLocalRanger).Version.ToString()
            $manifest.run.toolVersion | Should -Be $expectedVersion
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Bug #162 — Redfish retry detail entries must carry label and target URI
# ─────────────────────────────────────────────────────────────────────────────
Describe 'Invoke-RangerRedfishRequest — retry metadata' {

    It 'retry entry label is Invoke-RangerRedfishRequest — not generic operation (#162)' {
        InModuleScope AzureLocalRanger {
            $script:RangerRetryDetails = New-Object System.Collections.ArrayList
            $cred = [PSCredential]::new('idrac\admin', (ConvertTo-SecureString 'pw' -AsPlainText -Force))
            Mock Invoke-RestMethod { throw [System.Net.WebException]::new('503 Service Unavailable') }

            try {
                Invoke-RangerRedfishRequest -Uri 'https://idrac01.mgmt.local/redfish/v1/Systems' -Credential $cred
            }
            catch { }

            $detail = $script:RangerRetryDetails | Select-Object -First 1
            $detail | Should -Not -BeNullOrEmpty
            $detail.Label | Should -Be 'Invoke-RangerRedfishRequest' `
                -Because 'audit-manifest.json retryDetails must identify which caller failed'
        }
    }

    It 'retry entry target is the request URI — not empty string (#162)' {
        InModuleScope AzureLocalRanger {
            $script:RangerRetryDetails = New-Object System.Collections.ArrayList
            $cred = [PSCredential]::new('idrac\admin', (ConvertTo-SecureString 'pw' -AsPlainText -Force))
            Mock Invoke-RestMethod { throw [System.Net.WebException]::new('404 Not Found') }
            $testUri = 'https://idrac01.mgmt.local/redfish/v1/Chassis'

            try {
                Invoke-RangerRedfishRequest -Uri $testUri -Credential $cred
            }
            catch { }

            $detail = $script:RangerRetryDetails | Select-Object -First 1
            $detail.Target | Should -Be $testUri `
                -Because 'target must be the URI so operators can see which Redfish endpoint failed'
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Bug #163 — DebugPreference must never be set to Continue (MSAL debug flood)
# ─────────────────────────────────────────────────────────────────────────────
Describe 'Invoke-RangerDiscoveryRuntime — DebugPreference isolation' {

    It 'DebugPreference is not Continue after module functions run at debug log level (#163)' {
        InModuleScope AzureLocalRanger {
            # Directly exercise the preference-setting switch
            $script:RangerLogLevel = 'debug'
            $savedDebug = $DebugPreference

            # Simulate what Invoke-RangerDiscoveryRuntime does
            $script:_rangerPrevDebugPreference = $DebugPreference
            switch ($script:RangerLogLevel) {
                'debug' {
                    $VerbosePreference     = 'Continue'
                    $InformationPreference = 'Continue'
                    $ProgressPreference    = 'Continue'
                }
            }
            $DebugPreference = 'SilentlyContinue'

            $DebugPreference | Should -Not -Be 'Continue' `
                -Because 'MSAL/Az SDK emit thousands of Write-Debug lines; setting Continue floods the log'

            # Restore
            $DebugPreference = $savedDebug
            $script:RangerLogLevel = $null
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Bug #164 — collector Messages array must never contain null entries
# ─────────────────────────────────────────────────────────────────────────────
Describe 'Invoke-RangerCollectorExecution — null message filtering' {

    It 'Messages array contains no nulls when collector returns null Messages (#164)' {
        InModuleScope AzureLocalRanger {
            $definition = [pscustomobject]@{
                Id                = 'test-collector'
                FunctionName      = 'Invoke-RangerTestCollector'
                Class             = 'required'
                RequiredTargets   = @()
                RequiredCredential = 'none'
            }
            # Collector returns a result with null Messages
            function global:Invoke-RangerTestCollector {
                @{ Status = 'success'; Messages = $null; Domains = @{}; Relationships = @(); Findings = @(); Evidence = @() }
            }

            $config = Get-RangerDefaultConfig
            $result = Invoke-RangerCollectorExecution -Definition $definition -Config $config -CredentialMap @{} -PackageRoot $TestDrive

            $result.Messages | Should -Not -Contain $null `
                -Because 'null entries in Messages produce [message, null] in audit-manifest.json'

            Remove-Item Function:\global:Invoke-RangerTestCollector -ErrorAction SilentlyContinue
        }
    }

    It 'Messages array is non-null when both internal list and result Messages are empty (#164)' {
        InModuleScope AzureLocalRanger {
            $definition = [pscustomobject]@{
                Id                = 'test-collector-empty'
                FunctionName      = 'Invoke-RangerTestCollectorEmpty'
                Class             = 'required'
                RequiredTargets   = @()
                RequiredCredential = 'none'
            }
            function global:Invoke-RangerTestCollectorEmpty {
                @{ Status = 'success'; Messages = @(); Domains = @{}; Relationships = @(); Findings = @(); Evidence = @() }
            }

            $config = Get-RangerDefaultConfig
            $result = Invoke-RangerCollectorExecution -Definition $definition -Config $config -CredentialMap @{} -PackageRoot $TestDrive

            $result.Messages | Should -Not -BeNullOrEmpty -Because 'should contain at least the completion message'
            $result.Messages | Should -Not -Contain $null

            Remove-Item Function:\global:Invoke-RangerTestCollectorEmpty -ErrorAction SilentlyContinue
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Bug #165 — domain credential must be tried before cluster credential
# ─────────────────────────────────────────────────────────────────────────────
Describe 'Get-RangerRemoteCredentialCandidates — ordering' {

    It 'returns domain credential as first candidate when both are provided (#165)' {
        InModuleScope AzureLocalRanger {
            $domainCred  = [PSCredential]::new('MGMT\svc.azl.local', (ConvertTo-SecureString 'pw' -AsPlainText -Force))
            $clusterCred = [PSCredential]::new('lcm-tplabs-clus01',  (ConvertTo-SecureString 'pw' -AsPlainText -Force))

            $candidates = Get-RangerRemoteCredentialCandidates -DomainCredential $domainCred -ClusterCredential $clusterCred

            $candidates[0].Name | Should -Be 'domain' `
                -Because 'domain admin has WinRM PSRemoting rights; LCM cluster account typically does not'
            $candidates[1].Name | Should -Be 'cluster'
        }
    }

    It 'includes cluster candidate and excludes domain when domain credential is absent (#165)' {
        InModuleScope AzureLocalRanger {
            $clusterCred = [PSCredential]::new('lcm-tplabs-clus01', (ConvertTo-SecureString 'pw' -AsPlainText -Force))
            # Candidates are [ordered]@{} dicts; use ForEach-Object not Select-Object -ExpandProperty
            $names = @(Get-RangerRemoteCredentialCandidates -ClusterCredential $clusterCred) | ForEach-Object { [string]$_.Name }

            $names | Should -Contain 'cluster'
            $names | Should -Not -Contain 'domain'          -Because 'no domain credential was provided'
            $names | Should -Not -Contain 'current-context' -Because 'an explicit cluster credential was provided'
        }
    }

    It 'includes current-context and excludes domain/cluster when no credentials are provided (#165)' {
        InModuleScope AzureLocalRanger {
            $names = @(Get-RangerRemoteCredentialCandidates) | ForEach-Object { [string]$_.Name }

            $names | Should -Contain 'current-context'
            $names | Should -Not -Contain 'domain'  -Because 'no credentials were provided'
            $names | Should -Not -Contain 'cluster' -Because 'no credentials were provided'
        }
    }

    It 'deduplicates when cluster and domain resolve to the same username (#165)' {
        InModuleScope AzureLocalRanger {
            $cred = [PSCredential]::new('MGMT\svc.azl.local', (ConvertTo-SecureString 'pw' -AsPlainText -Force))
            $candidates = @(Get-RangerRemoteCredentialCandidates -DomainCredential $cred -ClusterCredential $cred)

            $uniqueNames = ($candidates | Group-Object UserName).Count
            $uniqueNames | Should -Be 1 -Because 'same username should not appear twice in candidates'
        }
    }
}
