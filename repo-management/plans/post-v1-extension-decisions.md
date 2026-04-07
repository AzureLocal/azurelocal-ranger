# Post-V1 Extension Decisions

This document captures the explicit product decisions and boundary conditions for the post-v1 Azure Local Ranger backlog.

Its purpose is to close the planning and definition issues for future scope without pulling those features into the v1 implementation baseline.

## Decision Model

- v1 remains a PowerShell 7.x-first, jump-box or management-workstation-driven collection model.
- Post-v1 work may extend transport, evidence sources, and import paths, but it must preserve the manifest-first output contract.
- Any future implementation must stay opt-in when it introduces external device APIs, new trust boundaries, or non-host evidence sources.

## #25 Azure-Hosted Automation Worker Execution Model

Decision:
Azure-hosted execution is a valid post-v1 path, but it remains an alternate runner model rather than the default posture.

Supported future execution shapes worth considering first:

- Azure Automation Hybrid Worker running inside the customer-connected management boundary
- Azure VM or Azure Container Apps job running in a private network with line-of-sight to Azure Local endpoints
- GitHub-hosted orchestration only when a customer-managed relay or worker inside the trusted network performs the actual collection

Required network and identity assumptions:

- WinRM, Redfish, and Azure control-plane access must still be reachable from the hosted worker
- Secrets must resolve through managed identity, service principal, or a secure vault path; interactive prompting is not the preferred hosted model
- Hosted runs must emit the same manifest and package artifacts as workstation runs

Portability rules to preserve now:

- collector logic cannot assume an interactive desktop session
- credential resolution must remain separable from the collector implementations
- output rendering must remain decoupled from live collection

Explicit v1 exclusion:

- no Azure-hosted execution path is implemented in v1

## #26 Azure Arc Run Command Alternate Transport

Decision:
Arc Run Command is a limited-use optional future transport, not a replacement for WinRM and not a required v1 dependency.

Why:

- it depends on Azure registration, Arc agent health, RBAC, and command execution quotas
- it introduces different evidence-fidelity and latency characteristics than WinRM
- it is useful for constrained estates where WinRM is blocked, but only for domains that tolerate command fan-out and output-size limits

Candidate safe-use domains:

- lightweight node inventory
- service and policy posture checks
- selected monitoring and identity posture snapshots

Non-goals:

- not the default transport
- not required for disconnected estates
- not a prerequisite for core report or diagram generation

## #27 Direct Switch Interrogation

Decision:
Direct switch interrogation stays a future optional collector family with a separate opt-in configuration and credential boundary.

First implementation path when prioritized:

- vendor-specific adapters behind one normalized network-fabric evidence contract
- start with one vendor only after a concrete customer or lab target exists

Configuration and merge model:

- switch targets, credentials, and protocol details live in a dedicated config section
- direct switch evidence augments host-side networking evidence; it does not replace it
- reports and diagrams must label direct-fabric evidence separately from host-derived evidence

Explicit v1 exclusion:

- v1 networking stays host-centric

## #28 Direct Firewall Interrogation

Decision:
Direct firewall interrogation stays a future optional collector family with its own trust and safety boundary.

First implementation path when prioritized:

- a single vendor-specific adapter or a structured import path if direct APIs are too estate-specific

Configuration and merge model:

- firewall connection data and credentials stay isolated from host credentials
- firewall evidence complements proxy, DNS, route, and host-firewall posture already collected from Azure Local nodes
- outputs must differentiate host-side validation from direct device evidence

Explicit v1 exclusion:

- v1 does not query perimeter firewalls directly

## #29 Non-Dell OEM Hardware Support

Decision:
Non-Dell OEM support remains a separate future workstream with vendor-specific collectors mapped into the common hardware model.

Priority order when implementation starts:

- HPE
- Lenovo
- DataON and other Azure Local partner-specific variants

Normalization rules:

- shared hardware domains remain vendor-neutral in the manifest
- vendor-specific evidence remains preserved in raw evidence and OEM posture substructures
- no generic wording should imply parity before a vendor path actually exists

Explicit v1 exclusion:

- only Dell-first Redfish and OEM posture are implemented in v1

## #30 Disconnected and Limited-Connectivity Enrichment

Decision:
Disconnected and constrained-connectivity enrichment remains post-v1, but the v1 model must stay compatible with it.

Highest-value future enhancements:

- stronger local identity and PKI evidence
- local monitoring and update posture when Azure-side context is absent
- richer disconnected control-plane diagrams and recommendations
- clearer evidence provenance for missing Azure-side data

Architecture constraints preserved now:

- collectors can already emit partial status and findings without failing the full package
- cached manifest rendering works even when Azure-side enrichment is absent

Explicit v1 exclusion:

- no disconnected-only enrichment beyond the current baseline posture

## #31 Rack-Aware and Management-Cluster Enrichment

Decision:
Rack-aware and management-cluster enrichment stays post-v1 and remains distinct from the v1 variant classifier.

Future enrichments to target:

- richer rack and fault-domain relationship mapping
- management-cluster-specific control-plane and dependency views
- externalized network, storage, and management relationships beyond the current host-derived model

Constraints preserved now:

- v1 can label rack-aware posture when evidence exists
- v1 does not claim full management-cluster modeling

Explicit v1 exclusion:

- no management-cluster-specific collector logic is implemented in v1

## #32 Manual Import Workflows

Decision:
Manual import remains a future feature for externally governed environments where Ranger cannot interrogate every external system directly.

First import scenarios worth supporting:

- rack and cabling data
- firewall export summaries
- switch VLAN and subnet inventories
- support matrices or OEM compliance exports

Rules for future implementation:

- imported data must be labeled with source, timestamp, and provenance
- imported evidence must remain distinguishable from machine-collected evidence in reports and diagrams
- imported content must validate against an explicit schema before it enters the manifest

Explicit v1 exclusion:

- no manual import workflow is implemented in v1

## #33 Windows PowerShell 5.1 Compatibility

Decision:
Windows PowerShell 5.1 remains unsupported unless a future assessment proves that support can be added without distorting the PowerShell 7.x-first architecture.

Current blockers:

- PowerShell 7-oriented module behavior and modern cmdlet expectations
- inconsistent availability of newer runtime features and remoting behavior
- duplicated test burden and packaging complexity

Recommended support posture:

- continue to require PowerShell 7.x for v1 and near-term post-v1 work
- reassess 5.1 only if a concrete downstream dependency or customer requirement justifies the cost

## Outcome

The post-v1 backlog is now explicitly defined with bounded decisions, non-goals, and preserved architectural constraints.

That means the definition issues can close without implying that the future features themselves have already been implemented.

---

## #75 Interactive Configuration Wizard and Direct Parameter Passthrough

Decision:
The configuration wizard (`Invoke-RangerWizard`) is a post-v1 addition. It must not require a config file on disk and it must not be a GUI window. The correct form is a guided terminal interaction.

Architectural requirements that must be preserved:

- Every field the wizard collects maps 1-to-1 to a parameter on `Invoke-RangerCollect`. No wizard-only input path may exist; all inputs must be addressable headlessly.
- The wizard synthesises an in-memory config object using the same internal representation as a loaded YAML config. No special wizard code paths inside the collectors.
- Presets are filter sets over the six domain keys. They do not change collector internals; they set `domains.enabled` the same way a hand-authored config would.
- WinForms, WPF, and any platform-specific GUI framework are explicitly excluded. The wizard must run inside a standard PowerShell 7.x terminal session on Windows and Linux management workstations.
- The wizard must detect non-interactive execution (redirected stdin, `$CI`, `$env:GITHUB_ACTIONS`) and refuse to run, with a clear error pointing to the parameter-based interface.

Scope presets to support:

| Preset key | Domains enabled |
|---|---|
| `full` | all six |
| `nodes-only` | topology-cluster, hardware, storage-networking, workload-identity-azure |
| `azure-only` | workload-identity-azure, monitoring |
| `networking-only` | storage-networking |
| `no-networking` | topology-cluster, hardware, workload-identity-azure, monitoring, management-performance |
| `custom` | user-selected in wizard screen |

Implementation dependency:

- Rendering engine (Spectre.Console or alternative) should be selected via #77 before #75 is implemented, since the wizard prompts depend on multi-selection capability.
- If the TUI library decision is not yet made, the wizard may use plain `$Host.UI.PromptForChoice` as a temporary implementation with a tracked upgrade issue.

## #76 Spectre.Console TUI Rendering

Decision:
Spectre.Console is the preferred library candidate for both scan progress display and interactive wizard prompts. The decision is pending the alternatives survey (#77).

If the survey confirms Spectre.Console:

- `PwshSpectreConsole` (PSGallery) is the integration path — not raw DLL loading — so that the dependency is installable via `Install-Module` and declared in `AzureLocalRanger.psd1` as a `RequiredModules` entry.
- The TUI rendering layer must be isolated behind a Ranger-internal abstraction (`Write-RangerProgress`, `Invoke-RangerWithStatus`, etc.) so that swapping the underlying library in the future does not require changes to collector or orchestrator code.
- ANSI detection must run at module load time. If ANSI is unsupported or `$env:RANGER_NO_TUI = 'true'` is set, all TUI calls route to plain `Write-Verbose` / `Write-Host` fallbacks. This must be testable via the existing Pester suite without requiring a real ANSI terminal.
- `LiveDisplay` (the in-place updating component) is not thread-safe in Spectre.Console. Collectors running in parallel must post status updates to a main-thread queue; the display loop polls that queue on the main thread. This queue pattern should be designed to work regardless of which library is ultimately chosen.

Spectre.Console capabilities confirmed as sufficient for Ranger's needs:

| Need | Spectre.Console feature |
|---|---|
| Per-collector progress bars | `Progress` display with per-task `AddTask()` |
| Spinner for indeterminate wait | `Status` display with `AnsiConsole.Status().Start()` |
| Per-node status table | `LiveDisplay` with a `Table` widget refreshed per update |
| Multi-select domain selection | `MultiSelectionPrompt<T>` |
| Single-select preset | `SelectionPrompt<T>` |
| Text prompt with validation | `TextPrompt<T>` with `.Validate()` |
| Findings count display | `Markup` in a live-refreshed panel |

Explicit non-goals for this feature:

- No full TUI window manager (Terminal.Gui / gui.cs-style) — Ranger is not a dashboard app; it runs and exits.
- No web-based progress UI.
- No persistent background service.

## #77 Terminal TUI Alternatives Survey

Decision:
This is a research task only. No code is written until the survey is complete and a library recommendation is recorded here.

Evaluation must cover at minimum:

- PwshSpectreConsole (Spectre.Console wrapper)
- Microsoft.PowerShell.ConsoleGuiTools (Out-ConsoleGridView, uses Terminal.Gui)
- Sharprompt (prompt-only .NET library)
- PSWriteColor (lightweight colour output)

The evaluation matrix must score each candidate against:
interactive prompts, progress display, table rendering, PS 7.2+ compatibility, cross-platform support, graceful degradation, maintenance health, PSGallery availability, license, and module weight.

The recommended library becomes the implementation target for #76. If no single library satisfies all criteria, the survey should identify a composition (e.g., Spectre.Console for progress + plain Host.UI for prompts).