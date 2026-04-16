# Platform Intelligence — Reference Platform Analysis & Feature Roadmap

**Milestone:** Platform Intelligence — Auth, Discovery & Output  
**Date:** 2026-04-16  
**Author:** Ranger Product Team  
**Status:** Planning

---

## Purpose

This document captures a structured analysis of five reference repositories identified as architectural peers or inspiration sources for AzureLocalRanger. For each repo, authentication patterns, documentation generation approaches, discovery mechanisms, and notable features were inventoried. The resulting feature recommendations are organized into a GitHub milestone and individual issues.

---

## Reference Repositories Analyzed

| Repo | Publisher | Focus |
|---|---|---|
| [documenter-azure-local](https://github.com/GetToThe-Cloud/documenter-azure-local) | GetToTheCloud | Azure Local ARM-plane inventory, HTML dashboard |
| [documenter-azure-azurevirtualdesktop](https://github.com/GetToThe-Cloud/documenter-azure-azurevirtualdesktop) | GetToTheCloud | AVD inventory, WAF rule engine, jsPDF |
| [documenter-azure-landingzone](https://github.com/GetToThe-Cloud/documenter-azure-landingzone) | GetToTheCloud | Landing zone CAF/WAF compliance, background runspace |
| [azure-scout](https://github.com/thisismydemo/azure-scout) | thisismydemo | ARI fork — multi-auth, Resource Graph, ImportExcel |
| [azurelocal-s2d-cartographer](https://github.com/AzureLocal/azurelocal-s2d-cartographer) | AzureLocal | On-prem S2D, OOXML Word, headless PDF, preflight probe |

---

## 1. Authentication

### 1.1 GetToTheCloud Tools (all three)

All three GetToTheCloud tools share an identical authentication architecture:

- On startup, `Test-AzureConnection` calls `Get-AzContext`. If a valid context exists (prior `Connect-AzAccount`, SPN via environment variables, managed identity), the server proceeds immediately.
- If no context exists, a `POST /api/auth/login` call triggers `Connect-AzAccount -UseDeviceAuthentication`. The device code and URL appear in the terminal.
- The landingzone variant adds `Save-AzContext -Path $tempFile` on login completion, then `Import-AzContext` inside the background collection runspace. This is the cleanest approach for passing Azure credentials to background PS runspaces — runspaces do not inherit the caller's Az context automatically.
- All three auto-install and auto-update their required Az modules via `Install-Module`/`Update-Module -Force -Scope CurrentUser` on startup.
- **None** implement Key Vault, SPN+secret, certificate, managed identity explicitly, or on-prem auth. Azure-plane only.

**Ranger relevance:** The `Save-AzContext`/`Import-AzContext` background runspace pattern is directly applicable to Ranger's async collection pipeline.

### 1.2 azure-scout

The most complete authentication model in the set. Five-method priority chain in `Connect-AZSCLoginSession`:

| Priority | Method | Trigger |
|---|---|---|
| 1 | Managed Identity | `-Automation` flag |
| 2 | SPN + Certificate | `-AppId` + `-CertificatePath` |
| 3 | SPN + Client Secret | `-AppId` + `-Secret` |
| 4 | Device Code | `-DeviceLogin` switch |
| 5 | Existing context / interactive | Default; reuses `Get-AzContext` if tenant matches |

- Sovereign cloud support: `AzureCloud`, `AzureUSGovernment`, `AzureChinaCloud`, `AzureGermanCloud`.
- Pre-run permission audit (`Invoke-AZTIPermissionAudit`) checks RBAC roles, resource provider registrations, and Graph permissions. Returns `OverallReadiness`: `FullARM`, `FullARMAndEntra`, `Partial`, `Insufficient`. Color-coded console output. Optional JSON/Markdown file.

### 1.3 azurelocal-s2d-cartographer

The only tool with on-prem credential management comparable to Ranger:

- Five `Connect-S2DCluster` parameter sets: ByName+PSCredential, ByExistingCimSession, ByExistingPSSession, Local (no remoting), ByKeyVault.
- Key Vault path: `Get-AzKeyVaultSecret`; username from secret's `ContentType` tag (`domain\user` convention); falls back to explicit `-Username`.
- Auth method defaults to `Negotiate` (Kerberos/NTLM auto-select).
- Module-scoped `$Script:S2DSession` hashtable holds credentials for the run lifetime. Collectors receive no individual credential parameters.
- **Preflight fan-out probe:** after cluster connect, opens a test `CimSession` to a sample node before any collection starts. On failure: detects domain-join state, emits numbered remediation list including the exact `Set-Item WSMan:\localhost\Client\TrustedHosts` command with the resolved FQDN pre-filled.

---

## 2. Discovery

### 2.1 documenter-azure-local

Most directly relevant to Ranger's open discovery issues:

- `Get-AzSubscription` iterates all enabled subscriptions — zero user input.
- HCI cluster search: `Get-AzResource -ResourceType "Microsoft.AzureStackHCI/clusters"` with **no `-ResourceGroupName`** filter. Directly answers Ranger issue #196.
- VM-to-cluster mapping: since ARM does not carry a direct cluster property on Arc VMs, resolves cluster membership by matching VM logical network subnets against each cluster's logical network subnets.
- Cross-subscription: `Set-AzContext` per subscription mid-loop for Arc machine extension queries, then restores original context.
- FQDNs and resource groups read from ARM resource properties — operator supplies nothing.

### 2.2 documenter-azure-azurevirtualdesktop

- VM lookup fallback: `Get-AzVM -Name $vmName -ResourceGroupName $hpRG` — on failure, falls back to `Get-AzVM` (all VMs in subscription) filtered by name. Emits console warning per cross-RG VM. Applicable to Ranger's node discovery when VMs are not in the cluster's resource group.
- Image source tracking: `StorageProfile.ImageReference.Id` vs `.Offer` distinguishes gallery vs. marketplace images.
- No Resource Graph — all individual Az cmdlet calls. Identified as an improvement opportunity.

### 2.3 documenter-azure-landingzone

- Eleven-step sequential collection in a background runspace. Each step writes progress to a temp JSON file; the HTTP server polls it.
- `Invoke-AzRestMethod` used for ARM resource types without dedicated cmdlets (Virtual WAN hub properties, private endpoint NIC IPs). Clean pattern for any ARM types Ranger may need without a PS cmdlet.
- Error handling: every subscription-level block wrapped in `try/catch`; connectivity errors cause `continue` (skip sub, don't abort). Graceful degradation on partial permissions is first-class.

### 2.4 azure-scout

- Single Azure Resource Graph query (`Search-AzGraph`) returns all resource types across all subscriptions at once. Orders of magnitude faster than per-type `Get-AzResource` loops in large environments.
- Management group scope supported — full MG hierarchy in one pass.
- Tag and resource group filters narrow scope without changing the collection architecture.
- Entra ID via Microsoft Graph as a separate plane with its own token.

### 2.5 azurelocal-s2d-cartographer

- Entirely on-prem CIM. No Azure ARM discovery.
- **Cluster FQDN resolution** (2-step): (1) scan WinRM `TrustedHosts` for `<shortname>.*` match, (2) DNS `GetHostEntry()` fallback.
- **Node FQDN resolution** (3-step): (1) passthrough if already dotted, (2) extract domain suffix from cluster FQDN and append to short node name, (3) DNS `GetHostEntry()` fallback.
- Node list from CIM: `Get-CimInstance -Namespace root/MSCluster -ClassName MSCluster_Node`. No RSAT needed on the management host.
- These FQDN resolution patterns are directly applicable to Ranger's pre-Arc fallback path for #197.

---

## 3. Documentation & Report Generation

### Format Matrix

| Tool | HTML | PDF | Word | Excel | Markdown | JSON | SVG/Diagram | Other |
|---|---|---|---|---|---|---|---|---|
| documenter-azure-local | Live SPA | jsPDF (browser) | — | — | — | — | — | — |
| documenter-azure-avd | Live SPA | jsPDF + html2canvas | — | — | — | Download | vis.js network | — |
| documenter-azure-landingzone | Live SPA | jsPDF (programmatic A4) | — | — | — | Download | vis-network | — |
| azure-scout | — | — | — | ImportExcel | GFM + AsciiDoc | Yes | Draw.io | Power BI CSV + star-schema |
| s2d-cartographer | Self-contained | Headless Edge/Chrome | OOXML ZIP | — | — | Yes | 6x SVG pure PS | CSV |

### PDF — Three Distinct Approaches

1. **jsPDF client-side** (GetToTheCloud tools): generates in the browser. No server-side dependency. Limited fidelity; A4 layout requires manual coordinate math; Unicode requires glyph substitution (`✓` → `[+]`).
2. **jsPDF + html2canvas** (AVD documenter): screenshotting complex rendered elements (vis.js diagrams) and embedding PNG into the jsPDF document. Gets visual fidelity for dynamic content without server rendering.
3. **Headless Edge/Chrome `--print-to-pdf`** (S2D Cartographer): renders the existing HTML report in a real browser engine and saves as PDF. Best fidelity. Falls through a priority list: Edge (bundled Win11/Server 2022) → Chrome → Chromium. **Zero library dependency.** Recommended approach for Ranger.

### Word — OOXML ZIP (S2D Cartographer)

Builds `.docx` as a raw OOXML ZIP package in PowerShell. Hand-crafted XML for cover page, KPI tables, alternating-row data tables, health cards. No Office dependency, no COM automation, no Word interop. Works on Server Core. This is the recommended approach for Ranger's Word output.

### Excel — ImportExcel (azure-scout)

`ImportExcel` PowerShell module. Multi-tab workbooks, charts, pivot tables, conditional formatting. No COM automation, no Office license. Recommended for Ranger's XLSX output.

### Diagrams

- **vis.js / vis-network** (GetToTheCloud): force-directed / hierarchical network graphs in the browser. Color-coded nodes by resource type. Edges show relationships. html2canvas capture for PDF embed. Interactive (zoom, pan, click for detail).
- **Draw.io** (azure-scout): generates `.drawio` XML as a background job. Inherited from Microsoft ARI. Does not block report generation.
- **Pure PowerShell SVG** (S2D Cartographer): six diagram types (waterfall, disk-node map, pool layout, resiliency, health card, cache tier). Zero library dependency. Fully offline. Pure coordinate math in PS string templates.

---

## 4. WAF / Scoring Engines

All three GetToTheCloud tools implement config-driven rule-based assessment engines using external JSON files. No rules are hardcoded.

### AVD Documenter — `waf-config.json`

~700 lines, 40+ rules, 5 pillars. Rule schema highlights:

- `id`, `name`, `points`, `condition` or `calculation` (named aggregate metric reference), `thresholds` array (graduated partial credit), `successMessage`/`warningMessage`/`failureMessage`/`recommendation` with `{value}` and `{count}` placeholder substitution.
- `Edit-WAFConfig` cmdlet: interactive console wizard for rule CRUD without touching JSON.
- Browser hot-swap: upload custom `waf-config.json` via file picker; changes take effect immediately without server restart.

### Landingzone Documenter — `scoring-config.json` + `waf-config.json`

Two files: one for CAF compliance scoring (7 categories), one for WAF alignment (5 pillars). Named variable references (`mgCount`, `policyAssigns`, `vnetCount`) evaluated against the collected inventory hashtable. `waf-config.json` adds `weight` per check and `{variable}` interpolation in message strings.

**Ranger validation:** Ranger's existing `config/waf-rules.json` (v1.4.0) confirms the architectural decision. The AVD tool's graduated threshold scoring and named calculation references are refinements worth adding to Ranger's rule schema.

---

## 5. UX & Architecture Patterns

### Progress Reporting

| Tool | Mechanism | Frontend |
|---|---|---|
| documenter-azure-local | Script-scope variable, `/api/inventory/progress` polled 1s | CSS progress bar in loading overlay |
| documenter-azure-avd | Same pattern | Full-screen overlay, 5 fixed % milestones, 10-min AbortController timeout |
| documenter-azure-landingzone | File write to `$env:TEMP/azlz-inventory-progress.json`, polled 800ms | Full-screen overlay, caps at 95% until complete |
| azure-scout | `Write-Progress`, background job for diagram | Console only |
| s2d-cartographer | Collector-based, `Write-Progress` + Spectre TUI | Console (same as Ranger) |

The **file-based IPC pattern** (landingzone) is most sound for PS background runspaces — no shared memory, no PS remoting between threads, survives runspace isolation.

### Wizard & Pre-Check as Parameters

Currently Ranger exposes `Invoke-RangerWizard` and `Test-AzureLocalRangerPrerequisites` as standalone commands. This creates friction: operators must know to run them separately, in the right order, before `Invoke-AzureLocalRanger`.

**Recommended pattern:**

```powershell
# Wizard inline — collect config interactively, then run
Invoke-AzureLocalRanger -Wizard

# Pre-check runs automatically by default; opt out with -SkipPreCheck
Invoke-AzureLocalRanger -ConfigPath .\ranger.yml
Invoke-AzureLocalRanger -ConfigPath .\ranger.yml -SkipPreCheck

# Standalone commands remain for explicit use
Invoke-RangerWizard
Test-AzureLocalRangerPrerequisites
```

This matches how operators actually think: `Invoke-AzureLocalRanger` is the entry point. The wizard and pre-check are modes of that command, not prerequisites the operator must remember to run first.

---

## 6. Feature Recommendations — Ranked by Ranger Applicability

| # | Feature | Source | Linked Issue | Priority |
|---|---|---|---|---|
| 1 | Subscription-wide HCI cluster search — no RG needed | documenter-azure-local | #196 | High |
| 2 | Cluster FQDN auto-discovery from Azure Arc | S2D Cartographer / ARI | #197 | High |
| 3 | Key Vault DNS failure UX — preflight probe + remediation | S2D Cartographer | #198 | High |
| 4 | Wizard format default fix — `json` invalid, docx/xlsx/pdf missing | — | #195 | High |
| 5 | PDF via headless Edge/Chrome `--print-to-pdf` | S2D Cartographer | #207 | High |
| 6 | Word via OOXML ZIP — no Office, no COM | S2D Cartographer | #208 | High |
| 7 | XLSX via ImportExcel — no COM, multi-tab | azure-scout | #209 | High |
| 8 | `Invoke-AzureLocalRanger -Wizard` inline parameter | Pattern | #211 | High |
| 9 | `Invoke-AzureLocalRanger -SkipPreCheck` / auto pre-check | Pattern | #212 | High |
| 10 | Multi-method Azure auth chain (SPN cert/secret + MI + device + context) | azure-scout | #200 | High |
| 11 | Pre-run RBAC & resource provider permission audit | azure-scout | #202 | High |
| 12 | `Save-AzContext`/`Import-AzContext` for background runspaces | documenter-azure-landingzone | #201 | High |
| 13 | WinRM TrustedHosts + DNS FQDN resolution fallback | S2D Cartographer | #203 | High |
| 14 | Azure Resource Graph single-query discovery | azure-scout | #205 | Medium |
| 15 | Node/VM cross-resource-group fallback lookup | documenter-azure-avd | #204 | Medium |
| 16 | Graceful degradation on partial Azure permissions | documenter-azure-landingzone | #206 | Medium |
| 17 | File-based progress IPC for background runspaces | documenter-azure-landingzone | #213 | Medium |
| 18 | Graduated threshold scoring + named calculations in `waf-rules.json` | documenter-azure-avd | #214 | Medium |
| 19 | Power BI CSV + star-schema manifest export | azure-scout | #210 | Low |

---

## 7. Issues & Milestone

**Milestone:** [Platform Intelligence — Auth, Discovery & Output](https://github.com/AzureLocal/azurelocal-ranger/milestone/18)

All issues listed in the feature table above are filed under this milestone. An epic tracking issue links all child issues.

### Already Filed (reassigned to this milestone)

- #195 — [BUG] Wizard default format list wrong — `json` invalid, `docx`/`xlsx`/`pdf` missing
- #196 — [FEATURE] Auto-discover resource group from subscription + cluster name
- #197 — [FEATURE] Auto-discover cluster FQDN from Azure Arc
- #198 — [BUG] Key Vault DNS failure — hard crash, no fallback, no actionable guidance

---

## 8. Testing Requirements

All issues under this milestone require:

1. **Unit tests** in `tests/maproom/unit/` covering the new code path with fixture data.
2. **Integration smoke** documented in the issue (what to run against a live environment to confirm).
3. **Negative path coverage** — what happens when the feature is unavailable (e.g., Arc unreachable, Edge not installed, Key Vault DNS fails) must be tested explicitly.
4. **No regression** against existing collector output — `Invoke-RangerWizard` and `Test-AzureLocalRangerPrerequisites` remain available as standalone commands and their existing behavior is unchanged.

---

*Generated from reference platform analysis session — 2026-04-16*
