# Quickstart

This is the shortest path from a clean workstation to a finished Ranger package.

![Ranger operator journey](../assets/diagrams/ranger-operator-journey.svg)

## Step 1: Check Prerequisites

```powershell
Test-AzureLocalRangerPrerequisites
```

Use `-InstallPrerequisites` in an elevated session if you want Ranger to install missing RSAT and Az dependencies.

## Step 2: Build a Config (Wizard or Manual)

### Option A — Interactive wizard (recommended for first runs)

```powershell
Invoke-RangerWizard
```

The wizard walks through cluster addressing, Azure IDs, credentials, output path, and domain scope with prompted questions. At the end it can save a YAML config file, launch a run immediately, or both. No manual editing required.

### Option B — Generate a scaffold and edit

```powershell
New-AzureLocalRangerConfig -Path .\ranger.yml
```

The generated YAML is annotated and marks mandatory values with `[REQUIRED]`.

## Step 3: Fill in Required Values (Option B only)

At minimum, update:

- `environment.name`
- `targets.cluster.fqdn` or `targets.cluster.nodes`
- `targets.azure.subscriptionId`
- `targets.azure.tenantId`
- `targets.azure.resourceGroup`
- `credentials.cluster.username`

## Step 4: Run Discovery

```powershell
Invoke-AzureLocalRanger -ConfigPath .\ranger.yml
```

Add `-ShowProgress` for a live per-collector progress display (requires the optional `PwshSpectreConsole` module; automatically suppressed in CI and `-Unattended` mode):

```powershell
Invoke-AzureLocalRanger -ConfigPath .\ranger.yml -ShowProgress
```

You can override structural values at runtime, for example:

```powershell
Invoke-AzureLocalRanger `
  -ConfigPath .\ranger.yml `
  -ClusterFqdn tplabs-clus01.contoso.com `
  -EnvironmentName tplabs-prod-01 `
  -ShowProgress
```

### Running in disconnected or semi-connected environments

Ranger probes all transport surfaces before collectors run. If cluster nodes are unreachable on WinRM ports but are Arc-registered, it automatically falls back to Arc Run Command transport (requires `Az.ConnectedMachine` and an active Az context). Collectors whose transport is confirmed unavailable are skipped with `status: skipped` rather than failing the run.

## Step 5: Open the Output Package

By default Ranger writes to:

```text
C:\AzureLocalRanger\<environment>-<mode>-<timestamp>\
```

Key artifacts are:

- `manifest\audit-manifest.json`
- `package-index.json`
- `ranger.log`
- `reports\*.html`
- `reports\*.docx`
- `reports\*.pdf`
- `reports\*.xlsx`
- `diagrams\*.svg`

## Step 6: Re-Render Without Live Access

```powershell
Export-AzureLocalRangerReport \
  -ManifestPath .\manifest\audit-manifest.json \
  -Formats html,markdown,docx,xlsx,pdf,svg
```

That reuses the saved manifest and does not reconnect to the cluster or Azure.

## Step 7: Schedule an Unattended Run

For recurring runs, use `-Unattended` so Ranger never prompts for input and emits a scheduler-friendly `run-status.json` file.

```powershell
Invoke-AzureLocalRanger \
  -ConfigPath .\ranger.yml \
  -Unattended \
  -OutputPath \\fileserver\AzureLocalRanger \
  -BaselineManifestPath .\baseline\audit-manifest.json
```

Recommended unattended credential posture:

- Azure: service principal, managed identity, or pre-existing Az context
- Secrets: `keyvault://` references instead of inline passwords
- Scheduler templates: see `samples/task-scheduler-azurelocalranger.xml` and `samples/github-actions-scheduled-ranger.yml`

## Read Next

- [Prerequisites](../prerequisites.md)
- [Configuration](configuration.md)
- [Command Reference](command-reference.md)