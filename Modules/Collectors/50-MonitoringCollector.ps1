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
        Get-RangerAzureResources -Config $Config -AzureCredentialSettings $CredentialMap.azure
    )

    $healthSnapshots = @(
        Invoke-RangerSafeAction -Label 'Monitoring health snapshot' -DefaultValue @() -ScriptBlock {
            Invoke-RangerClusterCommand -Config $Config -Credential $CredentialMap.cluster -ScriptBlock {
                $healthServiceObj = if (Get-Command -Name Get-Service -ErrorAction SilentlyContinue) { Get-Service -Name HealthService -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType } else { $null }
                $heathFaults = if (Get-Command -Name Get-HealthFault -ErrorAction SilentlyContinue) {
                    @(Get-HealthFault -ErrorAction SilentlyContinue | Select-Object FaultType, FaultingObjectDescription, PerceivedSeverity, Reason, FaultTime | ForEach-Object {
                        [ordered]@{ faultType = $_.FaultType; faultingObject = $_.FaultingObjectDescription; severity = [string]$_.PerceivedSeverity; reason = $_.Reason; faultTime = $_.FaultTime }
                    })
                } else { @() }
                # Check HealthService event log for recent errors
                $healthEvents = @(try {
                    Get-WinEvent -LogName 'Microsoft-Windows-Health/Operational' -MaxEvents 100 -ErrorAction Stop |
                        Group-Object -Property Id | Sort-Object Count -Descending | Select-Object -First 5 |
                        ForEach-Object { [ordered]@{ eventId = $_.Name; count = $_.Count; level = $_.Group[0].LevelDisplayName; sample = $_.Group[0].Message.Substring(0, [Math]::Min(200, $_.Group[0].Message.Length)) } }
                } catch { @() })
                # Windows Admin Center agent / MAS agent version
                $amaAgentVersion = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\MonitoringAgent\Setup' -Name 'CurrentVersion' -ErrorAction SilentlyContinue)?.CurrentVersion
                $amaService = if (Get-Command -Name Get-Service -ErrorAction SilentlyContinue) { Get-Service -Name 'AzureMonitoringAgent','HealthAndSupportServices' -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType } else { @() }

                [ordered]@{
                    node              = $env:COMPUTERNAME
                    healthService     = $healthServiceObj
                    healthFaults      = @($heathFaults)
                    healthFaultCount  = @($heathFaults).Count
                    criticalFaultCount = @($heathFaults | Where-Object { $_.severity -match 'Critical|Fatal' }).Count
                    diagnostics       = if (Get-Command -Name Get-Service -ErrorAction SilentlyContinue) { @(Get-Service -Name 'AzureEdgeTelemetryAndDiagnostics*' -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType) } else { @() }
                    amaService        = @($amaService)
                    amaAgentVersion   = $amaAgentVersion
                    healthEvents      = @($healthEvents)
                }
            }
        }
    )

    # DCR detail with data sources and destinations
    $dcrDetail = @(
        Invoke-RangerSafeAction -Label 'DCR data source detail' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzDataCollectionRule -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                @(Get-AzDataCollectionRule -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue | ForEach-Object {
                    $rule = $_
                    [ordered]@{
                        name         = $rule.Name
                        id           = $rule.Id
                        location     = $rule.Location
                        dataSourceTypes = @($rule.DataSources.PSObject.Properties.Name)
                        destinationTypes = @($rule.Destinations.PSObject.Properties.Name | Where-Object { $_ -ne 'AzureMonitorMetrics' -or $rule.Destinations.$_.Name })
                        transformKql = $rule.DataFlows | ForEach-Object { $_.TransformKql } | Where-Object { $_ }
                        description  = $rule.Description
                    }
                })
            }
        }
    )

    # Alert rules with severity and last-triggered
    $alertRuleDetail = @(
        Invoke-RangerSafeAction -Label 'Azure alert rule detail' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if ([string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                $results = New-Object System.Collections.ArrayList
                if (Get-Command -Name Get-AzActivityLogAlert -ErrorAction SilentlyContinue) {
                    @(Get-AzActivityLogAlert -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue) | ForEach-Object {
                        [void]$results.Add([ordered]@{ name = $_.Name; type = 'ActivityLog'; enabled = $_.Enabled; scopes = @($_.Scopes) })
                    }
                }
                if (Get-Command -Name Get-AzMetricAlertRuleV2 -ErrorAction SilentlyContinue) {
                    @(Get-AzMetricAlertRuleV2 -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue) | ForEach-Object {
                        [void]$results.Add([ordered]@{ name = $_.Name; type = 'Metric'; severity = $_.Severity; enabled = $_.Enabled; evaluationFrequency = [string]$_.EvaluationFrequency; windowSize = [string]$_.WindowSize; lastModified = $_.LastUpdated })
                    }
                }
                if (Get-Command -Name Get-AzScheduledQueryRule -ErrorAction SilentlyContinue) {
                    @(Get-AzScheduledQueryRule -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue) | ForEach-Object {
                        [void]$results.Add([ordered]@{ name = $_.Name; type = 'ScheduledQuery'; severity = $_.Severity; enabled = $_.Enabled; query = $_.Query })
                    }
                }
                @($results)
            }
        }
    )

    # Azure Update Manager: maintenance configurations and pending assessments
    $updateManagerDetail = @(
        Invoke-RangerSafeAction -Label 'Azure Update Manager configuration detail' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzMaintenanceConfiguration -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                @(Get-AzMaintenanceConfiguration -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue | Select-Object Name, MaintenanceScope, Frequency, StartDateTime, DurationInHours, Timezone, Location)
            }
        }
    )

    # HCI Insights / resource health
    $resourceHealth = @(
        Invoke-RangerSafeAction -Label 'Azure resource health for HCI cluster' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzResourceHealth -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                @(Get-AzResourceHealth -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue | Select-Object ResourceName, ResourceType, AvailabilityState, Summary, ReasonType)
            }
        }
    )

    $ama = @($azureResources | Where-Object { $_.Name -match 'AzureMonitor|AMA' -or $_.ResourceType -match 'HybridCompute.*/extensions' })
    $dcr = @($azureResources | Where-Object { $_.ResourceType -match 'dataCollectionRules' })
    $dce = @($azureResources | Where-Object { $_.ResourceType -match 'dataCollectionEndpoints' })
    $telemetry = @($azureResources | Where-Object { $_.Name -match 'Telemetry|Diagnostics|HCIInsights' -or $_.ResourceType -match 'insights|operationalinsights' })
    $alerts = @($azureResources | Where-Object { $_.ResourceType -match 'actionGroups|scheduledQueryRules|alertrules' })
    $updateManager = @($azureResources | Where-Object { $_.ResourceType -match 'maintenance|update' })
    $monitoringSummary = [ordered]@{
        telemetryCount             = @($telemetry).Count
        amaCount                   = @($ama).Count
        dcrCount                   = @($dcr).Count
        dcrDetailCount             = @($dcrDetail).Count
        dceCount                   = @($dce).Count
        alertCount                 = @($alerts).Count
        alertRuleDetailCount       = @($alertRuleDetail).Count
        updateManagerCount         = @($updateManager).Count
        maintenanceConfigCount     = @($updateManagerDetail).Count
        resourceHealthCount        = @($resourceHealth).Count
        unhealthyResourceCount     = @($resourceHealth | Where-Object { $_.AvailabilityState -ne 'Available' }).Count
        healthServiceRunningNodes  = @($healthSnapshots | Where-Object { $_.healthService.Status -eq 'Running' }).Count
        totalHealthFaults          = (@($healthSnapshots | ForEach-Object { $_.healthFaultCount } | Measure-Object -Sum).Sum)
        criticalHealthFaults       = (@($healthSnapshots | ForEach-Object { $_.criticalFaultCount } | Measure-Object -Sum).Sum)
        nodesWithAmaAgent          = @($healthSnapshots | Where-Object { $null -ne $_.amaAgentVersion }).Count
    }

    $findings = New-Object System.Collections.ArrayList
    if ($ama.Count -eq 0 -and $dcr.Count -eq 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Minimal Azure monitoring evidence detected' -Description 'The monitoring collector did not find Azure Monitor Agent or Data Collection Rule resources in the configured resource group.' -CurrentState 'monitoring partially configured' -Recommendation 'Review Azure Monitor onboarding, DCR assignments, and resource-group scoping for the Azure Local environment.'))
    }

    if ($alerts.Count -eq 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'No alerting artifacts were discovered in the scoped Azure resources' -Description 'The monitoring collector found no Azure Monitor alert rule or action group resources for the configured resource group.' -CurrentState 'alert inventory empty' -Recommendation 'Confirm whether alerting is intentionally managed elsewhere or whether resource-group scoping needs to be widened.'))
    }

    if ($monitoringSummary.criticalHealthFaults -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Active critical Health Service faults detected on cluster nodes' -Description "Health Service fault collection found $($monitoringSummary.criticalHealthFaults) critical or fatal fault(s) across cluster nodes." -CurrentState "$($monitoringSummary.criticalHealthFaults) critical faults; $($monitoringSummary.totalHealthFaults) total faults" -Recommendation 'Review HealthService faults via Get-HealthFault and resolve before handoff. Critical faults may indicate storage, network, or hardware degradation.'))
    }

    if (@($resourceHealth | Where-Object { $_.AvailabilityState -ne 'Available' }).Count -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title 'Azure resource health indicates degraded HCI resources' -Description 'Azure Resource Health returned non-Available states for one or more scoped resources.' -CurrentState "$(@($resourceHealth | Where-Object { $_.AvailabilityState -ne 'Available' }).Count) resources not in Available state" -Recommendation 'Review Azure Resource Health for the HCI cluster and any linked Arc Machine resources before handoff.'))
    }

    return @{
        Status        = if ($findings.Count -gt 0) { 'partial' } else { 'success' }
        Domains       = @{
            monitoring = [ordered]@{
                telemetry       = ConvertTo-RangerHashtable -InputObject $telemetry
                ama             = ConvertTo-RangerHashtable -InputObject $ama
                dcr             = ConvertTo-RangerHashtable -InputObject $dcr
                dcrDetail       = ConvertTo-RangerHashtable -InputObject $dcrDetail
                dce             = ConvertTo-RangerHashtable -InputObject $dce
                insights        = ConvertTo-RangerHashtable -InputObject @($azureResources | Where-Object { $_.ResourceType -match 'operationalinsights|insights' })
                alerts          = ConvertTo-RangerHashtable -InputObject $alerts
                alertRuleDetail = ConvertTo-RangerHashtable -InputObject $alertRuleDetail
                health          = ConvertTo-RangerHashtable -InputObject $healthSnapshots
                healthFaults    = ConvertTo-RangerHashtable -InputObject @($healthSnapshots | ForEach-Object { [ordered]@{ node = $_.node; faults = $_.healthFaults; count = $_.healthFaultCount } })
                updateManager   = ConvertTo-RangerHashtable -InputObject $updateManager
                updateManagerDetail = ConvertTo-RangerHashtable -InputObject $updateManagerDetail
                resourceHealth  = ConvertTo-RangerHashtable -InputObject $resourceHealth
                summary         = $monitoringSummary
            }
        }
        Findings      = @($findings)
        Relationships = @()
        RawEvidence   = [ordered]@{
            azureResources    = ConvertTo-RangerHashtable -InputObject $azureResources
            health            = ConvertTo-RangerHashtable -InputObject $healthSnapshots
            updateManager     = ConvertTo-RangerHashtable -InputObject $updateManager
            dcrDetail         = ConvertTo-RangerHashtable -InputObject $dcrDetail
            alertRuleDetail   = ConvertTo-RangerHashtable -InputObject $alertRuleDetail
            resourceHealth    = ConvertTo-RangerHashtable -InputObject $resourceHealth
        }
    }
}