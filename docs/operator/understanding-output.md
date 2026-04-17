# Understanding Output

After a successful run, Ranger writes a timestamped output package to disk. This page explains what's in it, which file to open first, and how to interpret the results.

---

## Output Directory Structure

Every run creates a new folder under `output.rootPath` (default: `C:\AzureLocalRanger`):

```text
C:\AzureLocalRanger\
  tplabs-prod-01-current-state-20260416T044502Z\
    manifest\
      audit-manifest.json              ← raw discovery data — source of truth
      <runId>-evidence.json            ← if json-evidence in formats (v2.0.0)
    reports\
      executive-summary.html
      executive-summary.md
      executive-summary.pptx           ← if pptx in formats (v2.5.0)
      management-summary.html
      management-summary.md
      technical-deep-dive.html
      technical-deep-dive.md
      inventory-workbook.xlsx          ← if xlsx in formats
      technical-deep-dive.docx         ← if docx in formats
      technical-deep-dive.pdf          ← if pdf in formats
    diagrams\
      cluster-topology.svg
      storage-layout.svg
      network-topology.svg
      vm-placement.svg
      ... (up to 18 diagrams)
    powerbi\                           ← if powerbi in formats (v2.0.0)
      nodes.csv
      volumes.csv
      storage-pools.csv
      network-adapters.csv
      health-checks.csv
      waf-findings.csv
      waf-roadmap.csv
      waf-checklist.csv
      capacity-analysis.csv            ← v2.5.0
      vm-utilization.csv               ← v2.5.0
      storage-efficiency.csv           ← v2.5.0
      license-inventory.csv            ← v2.5.0
      estate-clusters.csv              ← estate runs only (v2.5.0)
      _relationships.json
      _metadata.json
    drift-report.json                  ← only when -BaselineManifestPath used
    package-index.json                 ← machine-readable manifest of all output files
    run-status.json                    ← only in -Unattended mode
    ranger.log                         ← full run log with timing and errors
```

The folder name format is `<environment-name>-<mode>-<timestamp>` in UTC ISO 8601:
```
tplabs-prod-01-current-state-20260416T044502Z
```

---

## What Each File Contains

### `manifest\audit-manifest.json`

The raw discovery data collected from the cluster and Azure. Everything in every report and diagram was rendered from this file. You can re-render any format later using `Export-AzureLocalRangerReport` without reconnecting to the cluster.

This is the most important file in the package — treat it as the source of truth for the run.

### `reports\executive-summary.*`

A high-level summary: cluster identity, health roll-up, key findings, and Azure integration state. Typically 1–3 pages. Suitable for sharing with stakeholders who need a status update without technical detail.

### `reports\management-summary.*`

An operational summary: node inventory, storage and networking health, finding counts by severity, and Azure resource coverage. Suitable for operations managers and team leads.

### `reports\technical-deep-dive.*`

The full technical report: all collected data across every domain, all findings with detail and recommendations, collector status, and run metadata. This is the document engineers and architects work from.

### `reports\inventory-workbook.xlsx`

A multi-sheet Excel workbook with raw inventory tables: nodes, VMs, volumes, network adapters, findings, and Arc resources. Suitable for populating CMDBs, generating compliance evidence, or bulk analysis.

### `diagrams\*.svg`

Vector diagrams rendered from the manifest. Open in a browser, draw.io, or any SVG viewer. Suitable for embedding in documentation or sharing with customers.

### `drift-report.json`

Present only when you ran with `-BaselineManifestPath`. Compares the current manifest against the baseline and lists added, removed, and changed elements. Use this to surface configuration drift between runs.

### `ranger.log`

Full text log of the run: startup configuration, connectivity probe results, per-collector timing and status, any errors, and the final output path. Read this first when troubleshooting a failed or partial run.

### `run-status.json`

Present only in `-Unattended` mode. A compact JSON file with the run outcome, collector status counts, and output path. Designed for Task Scheduler exit-code checks and CI pipeline status gates.

---

## Which Report to Open First

| Your role | Start with | Then |
| --- | --- | --- |
| Executive / customer | `executive-summary.html` | — |
| Operations manager | `management-summary.html` | `diagrams/cluster-topology.svg` |
| Engineer / architect | `technical-deep-dive.html` | `manifest/audit-manifest.json` for raw data |
| Compliance / audit | `inventory-workbook.xlsx` | `technical-deep-dive.html` for findings context |
| Troubleshooting a partial run | `ranger.log` | `manifest/audit-manifest.json` collector status |
| Preparing a handoff package | All reports + all diagrams | `drift-report.json` if comparing to a prior state |

---

## Interpreting Collector Status

Each collector reports a status in `manifest.collectors[*].status`. Here is what each means and what to do:

| Status | Meaning | What to do |
| --- | --- | --- |
| `success` | Collector ran and returned complete data | Nothing — expected outcome |
| `partial` | Collector ran but some sub-collectors failed or returned incomplete data | Check `manifest.collectors[*].messages` for the specific sub-section that failed; run may still be useful |
| `skipped` | Collector was not attempted because its required transport was unavailable | Expected in disconnected or restricted environments; check `manifest.run.connectivity` for posture |
| `failed` | Collector threw an unhandled error | Check `ranger.log` for the full exception; resolve the underlying access or connectivity issue |
| `not-applicable` | Collector determined this domain is not relevant for this cluster | Expected — e.g., Arc collectors when no Az context is available |

To see all collector statuses from a run:

```powershell
$manifest = Get-Content '.\manifest\audit-manifest.json' | ConvertFrom-Json
$manifest.collectors | Select-Object id, status, messages
```

---

## Connectivity Posture

The pre-run connectivity probe result is stored in `manifest.run.connectivity.posture`:

| Posture | Meaning |
| --- | --- |
| `connected` | WinRM reachable; Azure reachable |
| `semi-connected` | WinRM reachable; Azure unreachable |
| `disconnected` | WinRM unreachable from this runner |

When posture is `disconnected` or `semi-connected`, expect `skipped` status on collectors that require the unavailable transport. This is normal and expected — not a bug.

---

## Using the Drift Report

When you run with `-BaselineManifestPath`, Ranger writes `drift-report.json` alongside the manifest. It records:

- **Added** — resources or configuration present in the current run but absent from the baseline
- **Removed** — resources present in the baseline but absent from the current run
- **Changed** — resources present in both runs with differing values

Use this for:
- Change control evidence (what changed between maintenance windows)
- Compliance drift detection (did anyone add a VM, change a network config, etc.)
- Pre/post validation for upgrades or migrations

---

## Re-Rendering Reports

You can generate any report format from an existing manifest without re-running discovery:

```powershell
Export-AzureLocalRangerReport `
  -ManifestPath .\manifest\audit-manifest.json `
  -Formats html,docx,xlsx,pdf,svg
```

This is useful when:
- You need a format you didn't include in the original run
- You want to regenerate reports after a template update
- You are preparing a handoff package from a prior run's data

---

## Related Pages

- [First Run](first-run.md)
- [Quickstart](quickstart.md)
- [Command Reference](command-reference.md)
- [Troubleshooting](troubleshooting.md)
