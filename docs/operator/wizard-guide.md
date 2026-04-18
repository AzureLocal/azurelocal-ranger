# Wizard Guide

`Invoke-AzureLocalRanger -Wizard` is the interactive terminal wizard that builds a Ranger configuration file through prompted questions and optionally launches a run immediately. (The standalone `Invoke-RangerWizard` command is retained and behaves identically — the `-Wizard` switch on the main command simply dispatches to it.)

It is the fastest way to get a correct configuration without editing YAML by hand. **This is the recommended first-run path** — the wizard covers every field most operators need, validates your input inline, and shows a review screen before it commits.

!!! info "Advanced tuning fields"
    The wizard covers the structural fields (environment, cluster, Azure auth, BMC, output mode, scope). It does **not** yet prompt for advanced tuning fields like `behavior.logLevel`, `behavior.retryCount`, `output.diagramFormat`, or `credentials.*.passwordRef`. You can set these by editing the saved YAML file, or by copying the config and extending it. Tracked in issue [#299](https://github.com/AzureLocal/azurelocal-ranger/issues/299).

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
Invoke-AzureLocalRanger -Wizard
```

To pre-fill the output path for the saved config file:

```powershell
Invoke-AzureLocalRanger -Wizard -OutputConfigPath C:\ranger\tplabs.yml
```

To run through all sections and save the config but never launch a run:

```powershell
Invoke-AzureLocalRanger -Wizard -SkipRun
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
  Credential strategies:
    [1] Current session context (uses Connect-AzAccount session)
    [2] Prompt at run time (Get-Credential for cluster + domain)
    [3] Service principal (clientId + clientSecret or keyvault:// ref)
    [4] Managed identity (Azure VM / Arc machine runners)
    [5] Device code (browser-based Entra sign-in)
    [6] Azure CLI (az login session)
Credential strategy [1]:
```

| # | Strategy | `credentials.azure.method` | When to use |
| --- | --- | --- | --- |
| **1** | Current session context | `existing-context` | Interactive runs where you've already run `Connect-AzAccount` |
| **2** | Prompt at run time | `existing-context` (with `promptForMissingCredentials: true`) | First run, or when the current session account doesn't have cluster WinRM access |
| **3** | Service principal | `service-principal` | CI / scheduled runs. Wizard prompts for the client ID and an optional `keyvault://` secret reference. |
| **4** | Managed identity | `managed-identity` | Runners hosted on an Azure VM or an Arc-enabled machine with a system or user-assigned identity |
| **5** | Device code | `device-code` | Runners without a browser, signing in interactively on another device |
| **6** | Azure CLI | `azure-cli` | Cross-platform runners where `az login` is the established auth pattern |

### Strategy 2 — Prompt at run time

The wizard also asks for usernames up front, so the runtime prompt only needs passwords:

```
Cluster WinRM username (DOMAIN\user, blank = prompt at run): CONTOSO\ranger-read
Domain username (DOMAIN\user, blank = same as cluster):
```

### Strategy 3 — Service principal

```
Service principal client ID (GUID): 2c57833c-5fe3-4fa3-9699-04f4168c1c0f
Client secret keyvault:// reference (or leave blank to prompt at run time):
  keyvault://<your-vault>/<secret-name>
```

The client ID is validated as a GUID inline — if you mistype it, the wizard re-prompts. The secret reference is optional; if blank, Ranger prompts for the secret at run time using `Read-Host -AsSecureString`.

!!! note
    Passwords and secrets are **never stored in the config file**. The wizard stores only a `keyvault://` reference or a username; the actual secret is resolved from Key Vault or prompted interactively at run time.

---

## Section 5 — BMC / iDRAC endpoints (optional)

```
── BMC / iDRAC (optional) ───────────────
  Configure BMC endpoints to include the hardware/OEM collector.
Configure BMC endpoints now? (Y/N) [N]:
```

If you answer **Y**, the wizard asks for a BMC username, then loops through an entry loop:

```
BMC username (e.g. idrac_admin, blank = prompt at run): idrac_azl_admin
  Enter BMC hosts one per line. Blank line ends the list.
  BMC host or IP: 192.168.214.11
    Corresponding cluster node FQDN for 192.168.214.11 (optional): tplabs-01-n01.azrl.mgmt
  BMC host or IP: 192.168.214.12
    Corresponding cluster node FQDN for 192.168.214.12 (optional): tplabs-01-n02.azrl.mgmt
  BMC host or IP:
```

Press **Enter** on an empty host prompt to end the list. Each entry lands in `targets.bmc.endpoints[]` with `host` and `node` fields. The BMC username is stored in `credentials.bmc.username`; BMC passwords are never written to the config.

Choose **N** to skip BMC entirely — this saves time and avoids noise in the hardware domain when you don't have OOB network access to the BMCs.

---

## Section 6 — Output

```
── Output ───────────────────────────────
Run mode (C=current-state, A=as-built) [C]:
Output root path [C:\AzureLocalRanger]:
Report formats [html,markdown,docx,xlsx,pdf,svg,drawio]:
```

| Prompt | Default | Notes |
| --- | --- | --- |
| Run mode | `C` (current-state) | `A` switches to as-built handoff packaging |
| Output root path | `C:\AzureLocalRanger` | Ranger creates a timestamped subfolder here |
| Report formats | `html,markdown,docx,xlsx,pdf,svg` | Also available: `drawio`, `pptx`, `json`, `json-evidence` |

Each run creates a new subfolder:

```text
C:\AzureLocalRanger\tplabs-prod-01-current-state-20260416T044502Z\
```

Pick `A` (as-built) when you are running against a freshly deployed cluster and want a customer-handoff package. Pick `C` (current-state) for ongoing assessments of an existing deployment, including workload inventory.

---

## Section 7 — Collection Scope

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

## Review screen

Before the wizard commits to anything, it prints the assembled configuration as YAML and asks for confirmation:

```
── Review configuration ─────────────────
environment:
  name: tplabs-prod-01
  clusterName: tplabs-prod-01
  description: Generated by Invoke-RangerWizard on 2026-04-17
targets:
  cluster:
    fqdn: tplabs-clus01.azrl.mgmt
    nodes:
      - tplabs-01-n01.azrl.mgmt
      - tplabs-01-n02.azrl.mgmt
...

Continue? (Y=yes, N=cancel without saving) [Y]:
```

Review the values. If anything looks wrong, type **N** and press Enter — the wizard exits without saving or running. Re-run the wizard to start over. If the configuration is correct, press **Enter** (or **Y**) to continue to the save/run choice.

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
| **S** | Saves the config file to the path you specified; no run |
| **R** | Runs immediately using the collected config; config is not saved to disk |
| **B** (recommended) | Saves the config file and then launches a run |

Choose **B** to get both a saved config for future runs and immediate results.

### Save path and file format

The wizard writes **YAML by default**. If the save path ends in `.json`, it writes JSON instead. The default filename is `<env-name>-ranger.yml` under `C:\AzureLocalRanger\`.

### Overwrite guard

If the save path already exists, the wizard prints the path and asks before clobbering:

```
File exists: C:\AzureLocalRanger\tplabs-prod-01-ranger.yml — overwrite? (Y/N) [N]:
```

Press **Enter** (or **N**) to cancel the save. If you chose **B** (both), the wizard falls through to running without saving. Type **Y** to overwrite the existing file.

---

## The Generated Config File

The wizard saves a YAML file like this:

```yaml
environment:
  name: tplabs-prod-01
  clusterName: tplabs-prod-01
  description: Generated by Invoke-RangerWizard on 2026-04-17

targets:
  cluster:
    fqdn: tplabs-clus01.azrl.mgmt
    nodes:
      - tplabs-01-n01.azrl.mgmt
      - tplabs-01-n02.azrl.mgmt
      - tplabs-01-n03.azrl.mgmt
      - tplabs-01-n04.azrl.mgmt
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
    - docx
    - xlsx
    - pdf
    - svg
  rootPath: C:\AzureLocalRanger
  showProgress: true

behavior:
  promptForMissingCredentials: false
  degradationMode: graceful
  transport: auto
```

If you chose strategy 3 (service principal) and configured BMC endpoints, the wizard also emits the matching fields:

```yaml
credentials:
  azure:
    method: service-principal
    clientId: 2c57833c-5fe3-4fa3-9699-04f4168c1c0f
    clientSecretRef: keyvault://<your-vault>/<secret-name>
  bmc:
    username: idrac_azl_admin

targets:
  bmc:
    endpoints:
      - host: 192.168.214.11
        node: tplabs-01-n01.azrl.mgmt
      - host: 192.168.214.12
        node: tplabs-01-n02.azrl.mgmt
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
