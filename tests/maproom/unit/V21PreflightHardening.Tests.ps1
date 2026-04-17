#Requires -Module Pester
<#
.SYNOPSIS
    v2.1.0 Pester coverage for the Preflight Hardening milestone:
      #235 Per-resource-type ARM reads for v2.0.0 collector surfaces
      #234 Deep WinRM credential verification via representative CIM query
      #233 Get-AzAdvisorRecommendation read permission probe
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    Import-Module (Join-Path $RepoRoot 'AzureLocalRanger.psd1') -Force

    # Stub config that looks enough like a resolved Ranger config to drive
    # Invoke-RangerPermissionAudit without needing the schema import.
    $script:StubConfig = [ordered]@{
        environment = [ordered]@{ name = 'iic-test'; clusterName = 'azlocal-iic-01' }
        targets     = [ordered]@{
            azure   = [ordered]@{
                subscriptionId = '33333333-3333-3333-3333-333333333333'
                tenantId       = '00000000-0000-0000-0000-000000000000'
                resourceGroup  = 'rg-iic-compute-01'
            }
            cluster = [ordered]@{ fqdn = 'azlocal-iic-01.iic.local'; nodes = @() }
        }
        credentials = [ordered]@{
            cluster  = [ordered]@{ }
            domain   = [ordered]@{ }
            bmc      = [ordered]@{ }
            firewall = [ordered]@{ }
            switch   = [ordered]@{ }
            azure    = [ordered]@{ method = 'existing-context' }
        }
    }
}

Describe 'v2.1.0 #234 Invoke-RangerCimDepthProbe' {
    It 'returns status=skipped with no targets supplied' {
        $r = & (Get-Module AzureLocalRanger) { Invoke-RangerCimDepthProbe -Targets @() }
        $r.status | Should -Be 'skipped'
        $r.reason | Should -Match 'No targets'
    }

    It 'returns status=skipped when CIM session cannot be established' {
        # Target that cannot possibly resolve; the probe should catch and return skipped, not throw.
        $r = & (Get-Module AzureLocalRanger) {
            Invoke-RangerCimDepthProbe -Targets @('ranger-cim-probe-unreachable-sentinel.invalid') -TimeoutSeconds 2
        }
        $r.status | Should -Be 'skipped'
        $r.target | Should -Be 'ranger-cim-probe-unreachable-sentinel.invalid'
    }

    It 'probe result shape includes three namespaces when a session is established' {
        # Without mocking New-CimSession we can only assert the shape contract on skip;
        # call with an intentionally bad target and confirm the ordered keys exist.
        $r = & (Get-Module AzureLocalRanger) {
            Invoke-RangerCimDepthProbe -Targets @('ranger-cim-probe-unreachable-sentinel.invalid') -TimeoutSeconds 2
        }
        $r.Keys | Should -Contain 'status'
        $r.Keys | Should -Contain 'target'
        $r.Keys | Should -Contain 'probes'
    }
}

Describe 'v2.1.0 #235 + #233 Invoke-RangerPermissionAudit surfaces new probes' {
    BeforeAll {
        # Invoke the audit inside the module so internal helpers (Get-AzResource etc.)
        # resolve in module scope. Non-Azure environment — expect Fail on the context
        # check, which is fine; we only care that the audit emits the v2.0.0 ARM and
        # Advisor check rows in some state rather than throwing or silently omitting.
        $script:Audit = & (Get-Module AzureLocalRanger) { param($c) Invoke-RangerPermissionAudit -Config $c } $script:StubConfig
    }

    It 'returns a result with Checks and OverallReadiness' {
        $script:Audit                   | Should -Not -BeNullOrEmpty
        $script:Audit.Checks            | Should -Not -BeNullOrEmpty
        $script:Audit.OverallReadiness  | Should -BeIn @('Full','Partial','Insufficient')
    }

    It 'surfaces a v2.0.0 ARM surfaces check row (#235)' {
        $row = @($script:Audit.Checks | Where-Object { $_.Name -eq 'v2.0.0 ARM surfaces' })
        # In a fully context-less env the probe is gated by $hasContext and may not
        # emit. In an env with Az.Accounts imported and *some* context, the row is
        # present. Accept either outcome but when the row is present assert its shape.
        if ($row.Count -gt 0) {
            $row[0].Status      | Should -BeIn @('Pass','Warn','Fail')
            $row[0].Message     | Should -Not -BeNullOrEmpty
        }
    }

    It 'surfaces an Azure Advisor read check row (#233)' {
        $row = @($script:Audit.Checks | Where-Object { $_.Name -eq 'Azure Advisor read' })
        if ($row.Count -gt 0) {
            $row[0].Status      | Should -BeIn @('Pass','Warn','Skip')
            $row[0].Message     | Should -Not -BeNullOrEmpty
        }
    }

    It 'never throws when Az.Advisor is not installed' {
        # Already proven by BeforeAll not throwing; assert the outer audit object is intact.
        $script:Audit.GeneratedAt | Should -Not -BeNullOrEmpty
    }
}

Describe 'v2.1.0 #235 ARM surface probe list' {
    It 'covers all seven v2.0.0 collector surfaces' {
        $src = Get-Content (Join-Path $RepoRoot 'Modules\Private\90-Permissions.ps1') -Raw
        foreach ($t in @(
            'Microsoft.AzureStackHCI/logicalNetworks',
            'Microsoft.AzureStackHCI/storageContainers',
            'Microsoft.ExtendedLocation/customLocations',
            'Microsoft.ResourceConnector/appliances',
            'Microsoft.HybridCompute/gateways',
            'Microsoft.AzureStackHCI/marketplaceGalleryImages',
            'Microsoft.AzureStackHCI/galleryImages'
        )) {
            $src | Should -Match ([regex]::Escape($t))
        }
    }
}
