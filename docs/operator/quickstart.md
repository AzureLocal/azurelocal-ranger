# Quickstart

This is the shortest path from a clean workstation to a finished Ranger package.

![Ranger operator journey](../assets/diagrams/ranger-operator-journey.svg)

## Step 1: Check Prerequisites

```powershell
Test-AzureLocalRangerPrerequisites
```

Use `-InstallPrerequisites` in an elevated session if you want Ranger to install missing RSAT and Az dependencies.

## Step 2: Generate a Config Scaffold

```powershell
New-AzureLocalRangerConfig -Path .\ranger.yml
```

The generated YAML is annotated and marks mandatory values with `[REQUIRED]`.

## Step 3: Fill in Required Values

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

You can override structural values at runtime, for example:

```powershell
Invoke-AzureLocalRanger \
  -ConfigPath .\ranger.yml \
  -ClusterFqdn tplabs-clus01.contoso.com \
  -EnvironmentName tplabs-prod-01
```

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

## Read Next

- [Prerequisites](../prerequisites.md)
- [Configuration](configuration.md)
- [Command Reference](command-reference.md)