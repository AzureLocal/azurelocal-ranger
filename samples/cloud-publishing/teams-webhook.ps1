#Requires -Version 7.0
<#
.SYNOPSIS
    Post a Ranger WAF summary card to a Teams channel after each run.
.EXAMPLE
    $result = Invoke-AzureLocalRanger -Config ranger-config.json -PublishToStorage
    & samples/cloud-publishing/teams-webhook.ps1 -ManifestPath output/audit-manifest.json -WebhookUrl $env:TEAMS_WEBHOOK_URL
#>
param(
    [Parameter(Mandatory)] [string]$ManifestPath,
    [Parameter(Mandatory)] [string]$WebhookUrl
)

$m = Get-Content $ManifestPath -Raw | ConvertFrom-Json
$cluster = $m.topology.clusterName ?? $m.run.clusterName ?? 'unknown'
$score   = $m.domains.wafAssessment.summary.overallScore ?? 0
$status  = $m.domains.wafAssessment.summary.status ?? 'Unknown'
$failing = $m.domains.wafAssessment.summary.failingRules ?? 0
$ver     = $m.run.toolVersion

$color = switch ($status) {
    'Excellent'        { 'Good' }
    'Good'             { 'Good' }
    'Fair'             { 'Warning' }
    'Needs Improvement'{ 'Attention' }
    default            { 'Default' }
}

$body = @{
    type        = 'message'
    attachments = @(@{
        contentType = 'application/vnd.microsoft.card.adaptive'
        content     = @{
            '$schema' = 'http://adaptivecards.io/schemas/adaptive-card.json'
            type      = 'AdaptiveCard'
            version   = '1.4'
            body      = @(
                @{ type = 'TextBlock'; size = 'Medium'; weight = 'Bolder'; text = "Ranger Run — $cluster" }
                @{ type = 'FactSet'; facts = @(
                    @{ title = 'WAF Score';    value = "$score% ($status)" }
                    @{ title = 'Failing Rules'; value = [string]$failing }
                    @{ title = 'Tool Version'; value = $ver }
                    @{ title = 'Run Time';     value = $m.run.endTimeUtc }
                )}
            )
        }
    })
} | ConvertTo-Json -Depth 20 -Compress

Invoke-RestMethod -Method Post -Uri $WebhookUrl -Body $body -ContentType 'application/json' -ErrorAction Stop
Write-Host "Teams notification sent for $cluster (WAF $score%)"
