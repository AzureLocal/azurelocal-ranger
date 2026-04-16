# First Run

This page gets you from zero to a finished Ranger output package in the shortest possible path.

No options. No branching. Follow these steps in order.

---

## Before You Start

You need three things:

- A Windows machine with PowerShell 7.x (your workstation or a jump box — not a cluster node)
- Network access to the Azure Local cluster's management network
- An account that can authenticate to the cluster over WinRM

---

## Step 1 — Install the Module

Open PowerShell 7 and run:

```powershell
Install-Module AzureLocalRanger -Scope CurrentUser -Force
Import-Module AzureLocalRanger
```

---

## Step 2 — Configure WinRM

If your machine is not domain-joined to the same domain as the cluster, add the cluster node IPs and cluster VIP to your WinRM TrustedHosts list. Run this **once** from an elevated PowerShell session:

```powershell
Start-Service WinRM
Set-Item WSMan:\localhost\Client\TrustedHosts `
  -Value "node01-ip,node02-ip,node03-ip,cluster-vip" -Force
```

Replace the IP addresses with the actual IPs for your environment.

---

## Step 3 — Check Prerequisites

```powershell
Test-AzureLocalRangerPrerequisites
```

Every row should show **Pass** or **Warn**. A **FAIL** on a required check must be resolved before running.

To auto-install missing modules (elevated session required):

```powershell
Test-AzureLocalRangerPrerequisites -InstallPrerequisites
```

---

## Step 4 — Connect to Azure

```powershell
Connect-AzAccount
Set-AzContext -SubscriptionId "your-subscription-id"
```

If you are running in a disconnected environment or do not have Azure access, Ranger will still collect on-premises data — Azure-dependent collectors will be skipped gracefully.

---

## Step 5 — Run the Setup Wizard

```powershell
Invoke-RangerWizard
```

The wizard asks six short sections of questions:

1. **Environment** — a short name for this cluster (used in output filenames)
2. **Cluster Nodes** — the FQDN of the cluster and/or individual node FQDNs
3. **Azure** — subscription ID, tenant ID, and resource group
4. **Credentials** — whether to use your current session or prompt at runtime
5. **Output** — where to save reports (default: `C:\AzureLocalRanger`)
6. **Scope** — which data domains to collect (press Enter to collect everything)

At the end, choose **[B] Both** to save the config file and run immediately.

!!! tip
    Press **Enter** to accept the default shown in `[brackets]` for any prompt.

See [Wizard Guide](wizard-guide.md) for a complete walkthrough with example answers.

---

## Step 6 — Open the Output

When the run completes, Ranger prints the output path. Navigate there and open the HTML report:

```text
C:\AzureLocalRanger\
  <environment>-current-state-<timestamp>\
    reports\
      technical-deep-dive.html   ← start here
      management-summary.html
      executive-summary.html
    diagrams\
      cluster-topology.svg
      ...
    manifest\
      audit-manifest.json
    ranger.log
```

Open `technical-deep-dive.html` in a browser for the full picture. Use `executive-summary.html` for a shareable summary.

See [Understanding Output](understanding-output.md) for a full guide to the output package.

---

## That's It

You've completed your first Ranger run.

For everything beyond the basics:

- [Wizard Guide](wizard-guide.md) — detailed wizard walkthrough
- [Configuration Reference](configuration-reference.md) — every config key explained
- [Command Reference](command-reference.md) — all parameters and common scenarios
- [Understanding Output](understanding-output.md) — how to read your results
- [Quickstart](quickstart.md) — full operator quickstart with all options
- [Prerequisites](../prerequisites.md) — detailed prerequisite checklist
