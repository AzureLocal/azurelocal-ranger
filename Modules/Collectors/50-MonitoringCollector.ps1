function Invoke-RangerMonitoringCollector {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory = $true)]
        $CredentialMap,

        [Parameter(Mandatory = $true)]
        [object]$Definition,

        [Parameter(Mandatory = $true)]
        [string]$PackageRoot
    )

    $fixture = Get-RangerCollectorFixtureData -Config $Config -CollectorId $Definition.Id
    if ($fixture) {
        return ConvertTo-RangerHashtable -InputObject $fixture
    }

    $azureResources = @(
        Get-RangerAzureResources -Config $Config
    )

    $healthSnapshots = @(
        Invoke-RangerSafeAction -Label 'Monitoring health snapshot' -DefaultValue @() -ScriptBlock {
            Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -ScriptBlock {
                [ordered]@{
                    node          = $env:COMPUTERNAME
                    healthService = if (Get-Command -Name Get-Service -ErrorAction SilentlyContinue) { Get-Service -Name HealthService -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType } else { $null }
                    diagnostics   = if (Get-Command -Name Get-Service -ErrorAction SilentlyContinue) { Get-Service -Name 'AzureEdgeTelemetryAndDiagnostics*' -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType } else { @() }
                }
            }
        }
    )

    $ama = @($azureResources | Where-Object { $_.Name -match 'AzureMonitor|AMA' -or $_.ResourceType -match 'HybridCompute.*/extensions' })
    $dcr = @($azureResources | Where-Object { $_.ResourceType -match 'dataCollectionRules' })
    $dce = @($azureResources | Where-Object { $_.ResourceType -match 'dataCollectionEndpoints' })
    $telemetry = @($azureResources | Where-Object { $_.Name -match 'Telemetry|Diagnostics|HCIInsights' -or $_.ResourceType -match 'insights|operationalinsights' })
    $alerts = @($azureResources | Where-Object { $_.ResourceType -match 'actionGroups|scheduledQueryRules|alertrules' })
    $updateManager = @($azureResources | Where-Object { $_.ResourceType -match 'maintenance|update' })

    $findings = New-Object System.Collections.ArrayList
    if ($ama.Count -eq 0 -and $dcr.Count -eq 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Minimal Azure monitoring evidence detected' -Description 'The monitoring collector did not find Azure Monitor Agent or Data Collection Rule resources in the configured resource group.' -CurrentState 'monitoring partially configured' -Recommendation 'Review Azure Monitor onboarding, DCR assignments, and resource-group scoping for the Azure Local environment.'))
    }

    return @{
        Status        = if ($findings.Count -gt 0) { 'partial' } else { 'success' }
        Domains       = @{
            monitoring = [ordered]@{
                telemetry = ConvertTo-RangerHashtable -InputObject $telemetry
                ama       = ConvertTo-RangerHashtable -InputObject $ama
                dcr       = ConvertTo-RangerHashtable -InputObject $dcr
                dce       = ConvertTo-RangerHashtable -InputObject $dce
                insights  = ConvertTo-RangerHashtable -InputObject @($azureResources | Where-Object { $_.ResourceType -match 'operationalinsights|insights' })
                alerts    = ConvertTo-RangerHashtable -InputObject $alerts
                health    = ConvertTo-RangerHashtable -InputObject $healthSnapshots
            }
        }
        Findings      = @($findings)
        Relationships = @()
        RawEvidence   = [ordered]@{
            azureResources = ConvertTo-RangerHashtable -InputObject $azureResources
            health         = ConvertTo-RangerHashtable -InputObject $healthSnapshots
            updateManager  = ConvertTo-RangerHashtable -InputObject $updateManager
        }
    }
}