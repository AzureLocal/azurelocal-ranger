# Operator Troubleshooting

This page documents the expected failure modes for a Ranger run and how operators should interpret them.

## First Principle

A partial run is still useful.

Ranger should preserve successful domain results even when some targets are unreachable, some credentials are missing, or some optional integrations are not present.

## Collector States

The manifest should clearly distinguish:

- `success` — the domain ran and returned the expected data
- `partial` — the domain ran but some evidence or subtargets were unavailable
- `failed` — the domain should have run but could not complete
- `skipped` — the domain was not run because inputs, credentials, or operator intent excluded it
- `not-applicable` — the domain is not relevant to the detected environment

## Common Problems

### Arc Run Command Transport Fails

Symptoms:

- collectors are attempted via Arc but return non-zero exit codes or empty output
- manifest shows `status: skipped` with a message referencing Arc transport unavailability

Check:

- `Az.ConnectedMachine` module is installed: `Get-Module Az.ConnectedMachine -ListAvailable`
- active Az context exists: `Get-AzContext`
- nodes are registered as Arc-enabled servers in the configured subscription and resource group
- the Az identity has `Microsoft.HybridCompute/machines/runCommands/action` on the machines
- `behavior.transport` is set to `auto` or `arc` in config — `winrm` will not attempt Arc fallback

### Connectivity Matrix Shows Unexpected Posture

Symptoms:

- run reports `disconnected` posture when cluster nodes should be reachable
- collectors are skipped that you expected to run

Check:

- `manifest.run.connectivity.cluster.targets` — confirms which hosts were probed and whether they responded on ports 5985 or 5986
- WinRM TrustedHosts configuration on the runner
- DNS resolution for node FQDNs from the runner
- `behavior.degradationMode` — set to `graceful` (skip) or `strict` (fail) as intended

To inspect the connectivity matrix after a run:

```powershell
$m = Get-Content .\manifest\audit-manifest.json | ConvertFrom-Json
$m.run.connectivity | ConvertTo-Json -Depth 5
```

### Progress Bars Not Showing

Symptoms:

- `-ShowProgress` was passed but no progress display appears

Check:

- `PwshSpectreConsole` is installed: `Get-Module PwshSpectreConsole -ListAvailable`
- the session is interactive — progress is automatically suppressed in CI (`$env:CI`, `$env:GITHUB_ACTIONS`, etc.) and when `-Unattended` is set
- the terminal supports ANSI escape sequences (Windows Terminal, VS Code terminal, or iTerm2 work; classic `cmd.exe` does not)

If `PwshSpectreConsole` is absent, Ranger falls back to `Write-Progress` silently — this is expected.

### WinRM Access Fails

Symptoms:

- cluster, storage, networking, VM, or management-tool domains fail early
- node-level collectors never start

Check:

- credential validity
- WinRM reachability from the jump box
- DNS resolution for node names
- firewall rules on the management path

### Azure Authentication Fails

Symptoms:

- Azure integration, monitoring, policy, update, and backup domains fail or skip

Check:

- current Az context or service principal configuration
- subscription and tenant alignment
- RBAC scope for the selected resource group or Azure Local instance

### Redfish or iDRAC Access Fails

Symptoms:

- hardware or OEM-management domains skip or fail

Check:

- BMC reachability from the workstation
- correct endpoint names or IPs
- credential validity
- certificate or TLS trust posture

### Key Vault Resolution Fails

Symptoms:

- Ranger cannot resolve one or more `keyvault://` references
- local-identity discovery lacks Key Vault-backed detail

Check:

- the Key Vault exists in the correct subscription and resource group
- the secret name and optional version are correct
- the calling identity has the required Key Vault role assignments
- network reachability to the Key Vault endpoint exists

### Local Identity with Key Vault Tooling Confusion

Symptoms:

- an operator expects WAC or SCVMM behavior that does not work in a local-identity deployment

Check:

- whether the environment is AD-backed or local identity with Key Vault
- documented tool support limitations for local-identity deployments

Current Microsoft documentation states that Windows Admin Center is not supported in Azure Key Vault-based identity environments and SCVMM support is limited or unsupported.

### Azure Local VM Management Prerequisites Missing

Symptoms:

- Arc VM or Azure Local VM management resources are absent or unhealthy

Check:

- Arc Resource Bridge exists and is healthy
- Custom Location exists and is healthy
- Azure Local instance, resource bridge, and related resources are in the same supported region
- firewall URL requirements are satisfied

### Disconnected Environment Assumptions Leak Into Connected Docs

Symptoms:

- operators expect public-cloud Azure behavior in a disconnected deployment

Check:

- whether the environment is actually a disconnected-operations deployment
- whether the required local control-plane prerequisites exist
- whether a dedicated management cluster exists where the documented disconnected model requires it

## What To Do With Missing Data

Missing data should not be hidden. Ranger should surface one of these explanations:

- target unreachable
- credential unavailable
- not applicable to current topology
- feature not supported in current release
- skipped by operator configuration

That explanation is part of the artifact quality, not an implementation detail.

## Escalation Path

When a run result is surprising, operators should narrow the problem in this order:

1. validate configuration
2. validate target reachability
3. validate credentials and RBAC
4. rerun only the affected domains
5. review collector status and provenance in the manifest

## Related Pages

- [Operator Prerequisites](prerequisites.md)
- [Operator Authentication](authentication.md)
- [How Ranger Works](../architecture/how-ranger-works.md)
- [Audit Manifest](../architecture/audit-manifest.md)
