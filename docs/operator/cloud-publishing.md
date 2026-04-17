# Cloud Publishing

AzureLocalRanger v2.3.0 can push run packages to Azure Blob Storage and stream
WAF telemetry to a Log Analytics Workspace after every run.

---

## Azure Blob Publishing (#244 / #245)

### What gets uploaded

| Include level | Files |
| --- | --- |
| `manifest` | `audit-manifest.json` |
| `evidence` | `*-evidence.json` |
| `packageIndex` | `package-index.json` |
| `runLog` | `ranger.log` |
| `reports` | Everything under `reports/` |
| `powerbi` | Everything under `powerbi/` |
| `full` | All of the above |

Default: `manifest`, `evidence`, `packageIndex`, `runLog`.

### Blob layout

```
{container}/
  {cluster}/{yyyy-MM-dd}/{runId}/
    audit-manifest.json
    {runId}-evidence.json
    package-index.json
    ranger.log
  _catalog/
    {cluster}/latest.json      ← overwritten each run
    _index.json                ← merged across all clusters
```

### RBAC requirements

Assign **Storage Blob Data Contributor** on the target container to the runner identity
(Managed Identity, service principal, or user).

```powershell
$storageId = (Get-AzStorageAccount -ResourceGroupName rg-ranger -Name stircompliance).Id
New-AzRoleAssignment `
    -ObjectId (Get-AzADServicePrincipal -DisplayName 'ranger-runner').Id `
    -RoleDefinitionName 'Storage Blob Data Contributor' `
    -Scope "$storageId/blobServices/default/containers/ranger-runs"
```

### Auth chain

Ranger tries the following in order:

1. **Managed Identity** — if `AZURE_CLIENT_ID` is set or `authMethod: managedIdentity`
2. **Entra RBAC** — active `Get-AzContext` (service principal or interactive login)
3. **SAS from Key Vault** — if `sasRef` is set in config

### Configuration

Add to your `ranger-config.json`:

```json
{
  "output": {
    "remoteStorage": {
      "type": "azureBlob",
      "storageAccount": "stircompliance",
      "container": "ranger-runs",
      "pathTemplate": "{cluster}/{yyyy-MM-dd}/{runId}",
      "include": ["manifest", "evidence", "packageIndex", "runLog"],
      "authMethod": "default",
      "writeHistory": false,
      "failRunOnPublishError": false
    }
  }
}
```

Or pass at run-time:

```powershell
Invoke-AzureLocalRanger -Config ranger-config.json -PublishToStorage
```

### Standalone publish

Publish an existing package without re-running Ranger:

```powershell
Publish-RangerRun `
    -PackagePath C:\RangerOutput\2026-04-17 `
    -StorageAccount stircompliance `
    -Container ranger-runs `
    -Include full
```

Offline (no real Azure calls — useful for testing):

```powershell
Publish-RangerRun -PackagePath . -StorageAccount st -Container c -Offline
```

### Catalog blobs

After each publish:

- `_catalog/{cluster}/latest.json` — run summary with artifact paths and WAF score snapshot
- `_catalog/_index.json` — one entry per cluster, listing the latest run ID and score

Downstream consumers (Event Grid triggers, Logic Apps, Power Automate) can poll
`_index.json` without listing the full container.

---

## Log Analytics Workspace Sink (#247)

### Tables

| Table | Description |
| --- | --- |
| `RangerRun_CL` | One row per run: cluster, runId, WAF score + pillar breakdown, AHB adoption, node/VM counts, cloud-publish status |
| `RangerFinding_CL` | One row per failing WAF rule: ruleId, pillar, severity, weight, message, first remediation step |

### DCE / DCR setup

1. Create a **Data Collection Endpoint** (DCE) in Azure Monitor.
2. Create a **Data Collection Rule** (DCR) with two custom streams:
   - `Custom-RangerRun_CL`
   - `Custom-RangerFinding_CL`
3. Assign **Monitoring Metrics Publisher** on the DCR to the runner identity.

### Configuration

```json
{
  "output": {
    "logAnalytics": {
      "enabled": true,
      "dataCollectionEndpoint": "https://your-dce.ingest.monitor.azure.com",
      "dataCollectionRuleImmutableId": "dcr-00000000000000000000000000000000",
      "streamName": "Custom-RangerRun_CL",
      "findingStreamName": "Custom-RangerFinding_CL",
      "authMethod": "default",
      "failRunOnPublishError": false
    }
  }
}
```

```powershell
Invoke-AzureLocalRanger -Config ranger-config.json -PublishToLogAnalytics
```

### KQL examples

```kql
// Latest WAF score per cluster
RangerRun_CL
| summarize arg_max(TimeGenerated, WafOverallScore, WafStatus) by Cluster

// Top failing rules across all clusters
RangerFinding_CL
| summarize FailCount = count() by RuleId, Pillar, Severity
| order by FailCount desc
```

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `auth: No Az.Accounts context and no sasRef configured` | No active login and no SAS | Run `Connect-AzAccount` or set `sasRef` |
| `Az.Storage module is required` | Module not installed | `Install-Module Az.Storage -Scope CurrentUser` |
| `Cannot bind argument to parameter 'RunId'` | Manifest has no `run.runId` | Upgrade to v2.3.0 (adds automatic runId fallback) |
| Upload skipped (idempotent) | SHA-256 matches remote | Normal — blob unchanged since last run |
| DCE post 403 | Missing Monitoring Metrics Publisher | Assign role on the DCR resource |
