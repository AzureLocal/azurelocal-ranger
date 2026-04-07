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
                        [void]$results.Add([ordered]@{
                            name                = $_.Name
                            type                = 'Metric'
                            severity            = $_.Severity
                            enabled             = $_.Enabled
                            evaluationFrequency = [string]$_.EvaluationFrequency
                            windowSize          = [string]$_.WindowSize
                            lastModified        = $_.LastUpdated
                            targetResourceType  = $_.TargetResourceType
                            actionGroups        = @($_.Action | ForEach-Object { Split-Path $_.ActionGroupId -Leaf })
                            criteriaTypes       = @(if ($_.Criteria) { @($_.Criteria.PSObject.Properties.Name) } else { @() })
                        })
                    }
                }
                if (Get-Command -Name Get-AzScheduledQueryRule -ErrorAction SilentlyContinue) {
                    @(Get-AzScheduledQueryRule -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue) | ForEach-Object {
                        [void]$results.Add([ordered]@{
                            name         = $_.Name
                            type         = 'ScheduledQuery'
                            severity     = $_.Severity
                            enabled      = $_.Enabled
                            query        = $_.Query
                            actionGroups = @($_.Action | ForEach-Object { Split-Path $_.ActionGroupResourceId -Leaf })
                            windowSize   = [string]$_.WindowSize
                            frequency    = [string]$_.Frequency
                        })
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

    # Issue #67: Log Analytics workspace detail and HCI Insights solutions
    $logAnalyticsWorkspaces = @(
        Invoke-RangerSafeAction -Label 'Log Analytics workspace detail' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzOperationalInsightsWorkspace -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                @(Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue | ForEach-Object {
                    $ws = $_
                    $solutions = @(try { Get-AzOperationalInsightsIntelligencePack -ResourceGroupName $ResourceGroup -WorkspaceName $ws.Name -ErrorAction Stop | Where-Object { $_.Enabled } | Select-Object Name, Enabled } catch { @() })
                    $hciInsightsEnabled = @($solutions | Where-Object { $_.Name -match 'azurelocal|hciinsights|ContainerInsights|AzureActivity' }).Count -gt 0
                    [ordered]@{
                        name             = $ws.Name
                        workspaceId      = $ws.CustomerId
                        resourceGroup    = $ws.ResourceGroupName
                        location         = $ws.Location
                        sku              = [string]$ws.Sku
                        retentionDays    = $ws.RetentionInDays
                        enabledSolutions = @($solutions | ForEach-Object { $_.Name })
                        hciInsightsEnabled = $hciInsightsEnabled
                    }
                })
            }
        }
    )

    # Issue #67: Diagnostic settings on HCI cluster and Arc resources
    $diagnosticSettings = @(
        Invoke-RangerSafeAction -Label 'Diagnostic settings on HCI cluster resource' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzDiagnosticSetting -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($SubscriptionId) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                $hciResources = @(Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.AzureStackHCI/clusters' -ErrorAction SilentlyContinue)
                $diagResult = New-Object System.Collections.ArrayList
                foreach ($res in $hciResources) {
                    $settings = @(Get-AzDiagnosticSetting -ResourceId $res.ResourceId -ErrorAction SilentlyContinue)
                    foreach ($s in $settings) {
                        [void]$diagResult.Add([ordered]@{
                            resourceId       = $res.ResourceId
                            resourceName     = $res.Name
                            name             = $s.Name
                            enabledLogs      = @($s.Log | Where-Object { $_.Enabled } | ForEach-Object { $_.Category })
                            enabledMetrics   = @($s.Metrics | Where-Object { $_.Enabled } | ForEach-Object { $_.Category })
                            workspaceId      = $s.WorkspaceId
                            storageAccountId = $s.StorageAccountId
                        })
                    }
                }
                @($diagResult)
            }
        }
    )

    # Issue #67: Action groups
    $actionGroups = @(
        Invoke-RangerSafeAction -Label 'Azure Monitor action groups' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzActionGroup -ErrorAction SilentlyContinue) -or [string]::IsNullOrWhiteSpace($ResourceGroup)) { return @() }
                @(Get-AzActionGroup -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue | ForEach-Object {
                    [ordered]@{
                        name             = $_.Name
                        groupShortName   = $_.GroupShortName
                        enabled          = $_.Enabled
                        emailReceivers   = @($_.EmailReceiver | ForEach-Object { [ordered]@{ name = $_.Name; address = $_.EmailAddress; useCommonAlert = $_.UseCommonAlertSchema } })
                        webhookReceivers = @($_.WebhookReceiver | ForEach-Object { [ordered]@{ name = $_.Name; serviceUri = $_.ServiceUri } })
                        armRoleReceivers = @($_.ArmRoleReceiver | ForEach-Object { $_.RoleId })
                    }
                })
            }
        }
    )

    $ama = @($azureResources | Where-Object { $_.Name -match 'AzureMonitor|AMA' -or $_.ResourceType -match 'HybridCompute.*/extensions' })
    $dcr = @($azureResources | Where-Object { $_.ResourceType -match 'dataCollectionRules' })
    $dce = @($azureResources | Where-Object { $_.ResourceType -match 'dataCollectionEndpoints' })
    $telemetry = @($azureResources | Where-Object { $_.Name -match 'Telemetry|Diagnostics|HCIInsights' -or $_.ResourceType -match 'insights|operationalinsights' })
    $alerts = @($azureResources | Where-Object { $_.ResourceType -match 'actionGroups|scheduledQueryRules|alertrules' })
    $updateManager = @($azureResources | Where-Object { $_.ResourceType -match 'maintenance|update' })

    # Issue #67: Health fault category grouping (group by FaultType prefix)
    $allFaults = @($healthSnapshots | ForEach-Object { $_.healthFaults })
    $healthFaultsByCategory = @($allFaults | Group-Object -Property { ($_.faultType -split '\.')[0] } | ForEach-Object {
        [ordered]@{
            category     = $_.Name
            count        = $_.Count
            criticalCount = @($_.Group | Where-Object { $_.severity -match 'Critical|Fatal' }).Count
            faults       = @($_.Group | Select-Object -First 3)
        }
    })

    # Issue #67: Telemetry extension detail from arc machine extensions
    $telemetryExtensionDetail = @($azureResources | Where-Object { $_.Name -match 'AzureEdgeTelemetryAndDiagnostics|TelemetryAndDiagnostics' } | ForEach-Object {
        [ordered]@{ name = $_.Name; resourceType = $_.ResourceType; location = $_.Location; id = $_.ResourceId }
    })

    # Issue #67: HCI Insights enablement summary
    $hciInsightsSummary = [ordered]@{
        enabled                  = @($logAnalyticsWorkspaces | Where-Object { $_.hciInsightsEnabled -eq $true }).Count -gt 0
        workspaceCount           = @($logAnalyticsWorkspaces).Count
        workspaceName            = if (@($logAnalyticsWorkspaces).Count -gt 0) { $logAnalyticsWorkspaces[0].name } else { $null }
        workspaceId              = if (@($logAnalyticsWorkspaces).Count -gt 0) { $logAnalyticsWorkspaces[0].workspaceId } else { $null }
        workspaceRegion          = if (@($logAnalyticsWorkspaces).Count -gt 0) { $logAnalyticsWorkspaces[0].location } else { $null }
        diagnosticSettingsCount  = @($diagnosticSettings).Count
        platformMetricsEnabled   = @($diagnosticSettings | Where-Object { @($_.enabledMetrics).Count -gt 0 }).Count -gt 0
    }

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
        logAnalyticsWorkspaceCount = @($logAnalyticsWorkspaces).Count
        diagnosticSettingsCount    = @($diagnosticSettings).Count
        actionGroupCount           = @($actionGroups).Count
        hciInsightsEnabled         = $hciInsightsSummary.enabled
        healthFaultCategoryCount   = @($healthFaultsByCategory).Count
        telemetryExtensionCount    = @($telemetryExtensionDetail).Count
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
                telemetry               = ConvertTo-RangerHashtable -InputObject $telemetry
                ama                     = ConvertTo-RangerHashtable -InputObject $ama
                dcr                     = ConvertTo-RangerHashtable -InputObject $dcr
                dcrDetail               = ConvertTo-RangerHashtable -InputObject $dcrDetail
                dce                     = ConvertTo-RangerHashtable -InputObject $dce
                insights                = ConvertTo-RangerHashtable -InputObject @($azureResources | Where-Object { $_.ResourceType -match 'operationalinsights|insights' })
                logAnalyticsWorkspaces  = ConvertTo-RangerHashtable -InputObject $logAnalyticsWorkspaces
                diagnosticSettings      = ConvertTo-RangerHashtable -InputObject $diagnosticSettings
                actionGroups            = ConvertTo-RangerHashtable -InputObject $actionGroups
                alerts                  = ConvertTo-RangerHashtable -InputObject $alerts
                alertRuleDetail         = ConvertTo-RangerHashtable -InputObject $alertRuleDetail
                health                  = ConvertTo-RangerHashtable -InputObject $healthSnapshots
                healthFaults            = ConvertTo-RangerHashtable -InputObject @($healthSnapshots | ForEach-Object { [ordered]@{ node = $_.node; faults = $_.healthFaults; count = $_.healthFaultCount } })
                healthFaultsByCategory  = ConvertTo-RangerHashtable -InputObject $healthFaultsByCategory
                telemetryExtension      = ConvertTo-RangerHashtable -InputObject $telemetryExtensionDetail
                hciInsights             = $hciInsightsSummary
                updateManager           = ConvertTo-RangerHashtable -InputObject $updateManager
                updateManagerDetail     = ConvertTo-RangerHashtable -InputObject $updateManagerDetail
                resourceHealth          = ConvertTo-RangerHashtable -InputObject $resourceHealth
                summary                 = $monitoringSummary
            }
        }
        Findings      = @($findings)
        Relationships = @()
        RawEvidence   = [ordered]@{
            azureResources         = ConvertTo-RangerHashtable -InputObject $azureResources
            health                 = ConvertTo-RangerHashtable -InputObject $healthSnapshots
            updateManager          = ConvertTo-RangerHashtable -InputObject $updateManager
            dcrDetail              = ConvertTo-RangerHashtable -InputObject $dcrDetail
            alertRuleDetail        = ConvertTo-RangerHashtable -InputObject $alertRuleDetail
            resourceHealth         = ConvertTo-RangerHashtable -InputObject $resourceHealth
            logAnalyticsWorkspaces = ConvertTo-RangerHashtable -InputObject $logAnalyticsWorkspaces
            diagnosticSettings     = ConvertTo-RangerHashtable -InputObject $diagnosticSettings
            actionGroups           = ConvertTo-RangerHashtable -InputObject $actionGroups
        }
    }
}