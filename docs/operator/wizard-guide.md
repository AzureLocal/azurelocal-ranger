# Wizard Guide

`Invoke-RangerWizard` is an interactive terminal wizard that builds a Ranger configuration file through prompted questions and optionally launches a run immediately.

It is the fastest way to get a correct configuration without editing YAML by hand.

---

## When to Use the Wizard

| Use the wizard when | Use a config file directly when |
| --- | --- |
| First time running Ranger | Running in automation or CI/CD |
| Exploring a new environment | Using Task Scheduler or GitHub Actions |
| You don't want to edit YAML | Config is already saved and reused across runs |
| You want to launch a run immediately | You need fine-grained control over every key |

---

## Starting the Wizard

```powershell
Invoke-RangerWizard
```

To pre-fill the output path for the saved config file:

```powershell
Invoke-RangerWizard -OutputConfigPath C:\ranger\tplabs.yml
```

To run through all sections and save the config but never launch a run:

```powershell
Invoke-RangerWizard -SkipRun
```

The wizard requires an interactive PowerShell session. It will throw an error if run from a non-interactive host (Task Scheduler, CI agent, etc.).

---

## Section 1 — Environment

```
── Environment ──────────────────────────
Environment name (short label) [prod-azlocal-01]:
Cluster name (CNO / display name) [prod-azlocal-01]:
Cluster FQDN or NetBIOS name (leave blank to skip):
```

| Prompt | What to enter | Example |
| --- | --- | --- |
| Environment name | Short label used in output folder names | `tplabs-prod-01` |
| Cluster name | Display name used in reports | `tplabs-prod-01` |
| Cluster FQDN | Cluster name that resolves on DNS | `tplabs-clus01.contoso.com` |

The environment name appears in every output filename:
`tplabs-prod-01-current-state-20260416T044502Z`

!!! tip
    If you leave Cluster FQDN blank, Ranger will use the node list instead. At least one of FQDN or node FQDNs must be provided.

---

## Section 2 — Cluster Nodes

```
── Cluster Nodes ────────────────────────
Node FQDNs (comma-separated, e.g. node01.lab.local,node02.lab.local):
```

Enter the fully-qualified name of each cluster node, separated by commas.

**Example:**
```
tplabs-01-n01.contoso.com,tplabs-01-n02.contoso.com,tplabs-01-n03.contoso.com,tplabs-01-n04.contoso.com
```

!!! tip
    If your cluster is Arc-registered, Ranger can resolve nodes automatically from Azure. In that case you can leave this blank and rely on Azure resolution — but providing nodes explicitly is more reliable for first runs.

---

## Section 3 — Azure Integration

```
── Azure Integration (optional) ─────────
Subscription ID (GUID, blank to skip):
Tenant ID (GUID, blank to skip):
Resource group name:
```

| Prompt | Where to find it | Example |
| --- | --- | --- |
| Subscription ID | `(Get-AzContext).Subscription.Id` | `00000000-0000-0000-0000-000000000000` |
| Tenant ID | `(Get-AzContext).Tenant.Id` | `11111111-1111-1111-1111-111111111111` |
| Resource group | Azure portal → resource group containing the cluster | `rg-azlocal-prod-01` |

Leave all three blank to skip Azure-side discovery. Ranger will still collect all on-premises data.

---

## Section 4 — Credentials

```
── Credentials ──────────────────────────
  Credential strategy options:
    [1] Use current session context (default)
    [2] Prompt at run time
Credential strategy [1]:
```

**Option 1 — Current session context (recommended for interactive runs)**

Ranger uses your current PowerShell session credentials for WinRM connections. This works when you are already authenticated with a domain account that has access to the cluster.

**Option 2 — Prompt at run time**

Ranger prompts for credentials when the run starts. You will also be asked for usernames now:

```
Cluster WinRM username (DOMAIN\user): CONTOSO\ranger-read
Domain username (DOMAIN\user, blank = same as cluster):
```

!!! note
    Passwords are never stored in the config file. When Option 2 is selected, Ranger prompts for passwords at run time using a secure prompt (`Read-Host -AsSecureString`).

---

## Section 5 — Output

```
── Output ───────────────────────────────
Output root path [C:\AzureLocalRanger]:
Report formats [html,markdown,json,svg]:
```

| Prompt | Default | Notes |
| --- | --- | --- |
| Output root path | `C:\AzureLocalRanger` | Ranger creates a timestamped subfolder here |
| Report formats | `html,markdown,json,svg` | Also available: `docx`, `xlsx`, `pdf`, `drawio` |

Each run creates a new subfolder:
```text
C:\AzureLocalRanger\tplabs-prod-01-current-state-20260416T044502Z\
```

---

## Section 6 — Collection Scope

```
── Collection Scope ─────────────────────
  Available domains: clusterNode, hardware, storage, networking, virtualMachines,
    identitySecurity, azureIntegration, monitoring, managementTools, performance, oemIntegration
Include only these domains (comma-separated, blank = all):
Exclude these domains (comma-separated, blank = none):
```

Press **Enter** on both prompts to collect everything (recommended for first runs).

Use **Include** for a focused run:
```
Include only these domains: cluster,storage,networking
```

Use **Exclude** to skip specific domains:
```
Exclude these domains: hardware,performance
```

!!! tip
    Exclude `hardware` if you don't have BMC/iDRAC credentials. Exclude `performance` for a faster run — it adds significant collection time.

---

## Completing the Wizard

```
── What would you like to do? ───────────
    [S] Save configuration only
    [R] Run immediately (without saving)
    [B] Both — save and run
Choice [B]:
```

| Choice | What happens |
| --- | --- |
| **S** | Saves the YAML config file to the path you specified; no run |
| **R** | Runs immediately using the collected config; config is not saved to disk |
| **B** (recommended) | Saves the config file and then launches a run |

Choose **B** to get both a saved config for future runs and immediate results.

---

## The Generated Config File

The wizard saves a YAML file like this:

```yaml
environment:
  name: tplabs-prod-01
  clusterName: tplabs-prod-01
  description: Generated by Invoke-RangerWizard on 2026-04-16

targets:
  cluster:
    fqdn: tplabs-clus01.contoso.com
    nodes:
      - tplabs-01-n01.contoso.com
      - tplabs-01-n02.contoso.com
      - tplabs-01-n03.contoso.com
      - tplabs-01-n04.contoso.com
  azure:
    subscriptionId: 00000000-0000-0000-0000-000000000000
    tenantId: 11111111-1111-1111-1111-111111111111
    resourceGroup: rg-azlocal-prod-01
  bmc:
    endpoints: []

credentials:
  azure:
    method: existing-context

domains:
  include: []
  exclude: []

output:
  mode: current-state
  formats:
    - html
    - markdown
    - json
    - svg
  rootPath: C:\AzureLocalRanger
  showProgress: true

behavior:
  promptForMissingCredentials: false
  degradationMode: graceful
  transport: auto
```

---

## Re-Using the Saved Config

On subsequent runs, pass the saved config file directly — no wizard needed:

```powershell
Invoke-AzureLocalRanger -ConfigPath C:\ranger\tplabs.yml
```

To override a single value without editing the file:

```powershell
Invoke-AzureLocalRanger -ConfigPath C:\ranger\tplabs.yml -OutputPath D:\ranger-results
```

---

## Common Mistakes

| Mistake | Fix |
| --- | --- |
| WinRM connection fails immediately | Add cluster node IPs to TrustedHosts (see [First Run](first-run.md) Step 2) |
| Azure collectors skipped — no Az context | Run `Connect-AzAccount` before starting the wizard |
| Cluster FQDN not resolving | Use node FQDNs directly instead of the cluster FQDN |
| Wrong subscription context | Run `Set-AzContext -SubscriptionId <id>` before the wizard |
| Config saved but run fails on missing credentials | Use credential strategy [2] so Ranger prompts at runtime |

---

## Read Next

- [First Run](first-run.md) — end-to-end beginner guide
- [Configuration Reference](configuration-reference.md) — every config key explained
- [Command Reference](command-reference.md) — all parameters and scenarios
- [Prerequisites](prerequisites.md) — detailed setup checklist
