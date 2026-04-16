<#
.SYNOPSIS
    Creates a new Operation TRAILHEAD field-testing cycle — milestone + 8 phase issues — in the
    AzureLocal/azurelocal-ranger GitHub repository.

.DESCRIPTION
    Run this script to kick off a fresh field-testing cycle for a new AzureLocalRanger version.
    It creates:
      - One GitHub milestone  : "Operation TRAILHEAD — v<Version> Field Validation"
      - Eight phase issues     : P0 Preflight through P7 Regression/Sign-off
      - All issues are labelled and assigned to the milestone automatically.

    The GitHub CLI (gh) must be installed and authenticated before running.

.PARAMETER Version
    The module version being tested (e.g. "0.6.0").  Used in the milestone title and all issue bodies.

.PARAMETER Environment
    Short human-readable description of the test environment (e.g. "tplabs-clus01 (4-node Dell, tplabs)").
    Inserted into every issue body so the context is clear when reviewing issues later.

.PARAMETER DueDate
    Optional. ISO 8601 date (YYYY-MM-DD) for the milestone due date.  Defaults to 30 days from today.

.PARAMETER WhatIf
    Print what would be created without actually calling the GitHub API.

.EXAMPLE
    .\New-RangerFieldTestCycle.ps1 -Version "0.6.0" -Environment "tplabs-clus01 (4-node Dell)"

.EXAMPLE
    .\New-RangerFieldTestCycle.ps1 -Version "1.0.0" -Environment "customer-clus01 (Contoso)" -DueDate "2026-08-01"

.NOTES
    Place this script in tests/trailhead/scripts/.
    See tests/trailhead/field-testing.md for the full testing methodology.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Version,

    [Parameter(Mandatory)]
    [string]$Environment,

    [Parameter()]
    [string]$DueDate = (Get-Date).AddDays(30).ToString("yyyy-MM-dd"),

    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Invoke-Gh {
    param([string[]]$Args)
    if ($WhatIf) {
        Write-Host "[WhatIf] gh $($Args -join ' ')" -ForegroundColor Cyan
        return "0"
    }
    gh @Args
    if ($LASTEXITCODE -ne 0) { throw "gh exited with code $LASTEXITCODE" }
}

$milestoneTitle = "Operation TRAILHEAD — v$Version Field Validation"
$labels         = @("type/infra", "priority/high", "solution/ranger")
$labelArgs      = $labels | ForEach-Object { "--label"; $_ }

Write-Host "`nOperation TRAILHEAD — v$Version" -ForegroundColor Green
Write-Host "Environment : $Environment"
Write-Host "Milestone   : $milestoneTitle"
Write-Host "Due         : $DueDate`n"

# ---------------------------------------------------------------------------
# 1. Milestone
# ---------------------------------------------------------------------------
Write-Host "Creating milestone..." -ForegroundColor Yellow
Invoke-Gh @("api", "repos/AzureLocal/azurelocal-ranger/milestones",
    "--method", "POST",
    "--field", "title=$milestoneTitle",
    "--field", "due_on=${DueDate}T00:00:00Z",
    "--field", "description=Operation TRAILHEAD field-testing cycle for AzureLocalRanger v$Version. See tests/trailhead/field-testing.md for methodology."
) | Out-Null
Write-Host "  Milestone created." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 2. Phase issue definitions
# ---------------------------------------------------------------------------
$phases = @(
    @{
        Title = "[TRAILHEAD P0] Preflight — execution environment and baseline validation"
        Body  = @"
## Operation TRAILHEAD — Phase 0: Preflight

**Version:** $Version
**Environment:** $Environment
**Milestone:** $milestoneTitle

Confirm the execution environment is ready **before any live test touches infrastructure**.
All checks must pass before proceeding to Phase 1.

---

### Checklist

- [ ] P0.1 — PowerShell 7.0+ present: `\$PSVersionTable.PSVersion`
- [ ] P0.2 — Module loads clean: `Import-Module .\AzureLocalRanger.psd1 -Force` — no errors, 4 exported functions present
- [ ] P0.3 — Pester baseline: `Invoke-Pester -Path .\tests -PassThru` — all existing tests pass
- [ ] P0.4 — RSAT ActiveDirectory module present: `Get-Module -ListAvailable ActiveDirectory`
- [ ] P0.5 — Az module present: `Get-Module -ListAvailable Az.Accounts`
- [ ] P0.6 — Azure context valid: `Get-AzContext` returns correct subscription
- [ ] P0.7 — Built-in prereq check passes: `Test-AzureLocalRangerPrerequisites`
- [ ] P0.8 — ICMP reachable: all cluster nodes, iDRACs, DC VMs — no unexpected failures

---

**Pass gate:** All checks must pass before Phase 1.
**Explicitly excluded from all TRAILHEAD phases:** Firewalls, switches, OpenGear (opt-in only via future parameter).
"@
    },
    @{
        Title = "[TRAILHEAD P1] Authentication and credential resolution validation"
        Body  = @"
## Operation TRAILHEAD — Phase 1: Authentication & Credentials

**Version:** $Version
**Environment:** $Environment
**Milestone:** $milestoneTitle
**Depends on:** Phase 0 passing

Confirm every credential path Ranger uses resolves correctly before any collector runs.

---

### Checklist

- [ ] P1.1 — Azure service principal auth resolves via config KV URI
- [ ] P1.2 — `Test-RangerKeyVaultUri` returns `\$true` for a valid KV URI
- [ ] P1.3 — KV secret resolution: local-admin-password returns non-null
- [ ] P1.4 — KV secret resolution: cluster/lcm credential returns non-null
- [ ] P1.5 — KV secret resolution: BMC/iDRAC credential returns non-null
- [ ] P1.6 — `Resolve-RangerCredentialMap` returns map with `cluster`, `bmc`, `azure` keys
- [ ] P1.7 — Cluster PSCredential valid: `Test-WSMan` to first node authenticates
- [ ] P1.8 — BMC credential valid: Redfish GET `/redfish/v1/Systems` returns HTTP 200
- [ ] P1.9 — No plaintext secrets in config file (grep check)

---

**Pass gate:** All KV resolution and cluster/BMC auth tests must pass.
"@
    },
    @{
        Title = "[TRAILHEAD P2] Connectivity and remote execution validation"
        Body  = @"
## Operation TRAILHEAD — Phase 2: Connectivity & Remote Execution

**Version:** $Version
**Environment:** $Environment
**Milestone:** $milestoneTitle
**Depends on:** Phase 1 passing

Confirm every transport Ranger depends on is reachable and functional before running collectors.

---

### Checklist

- [ ] P2.1 — WinRM to n01: `Invoke-RangerRemoteCommand` returns correct hostname
- [ ] P2.2 — WinRM to n02
- [ ] P2.3 — WinRM to n03
- [ ] P2.4 — WinRM to n04
- [ ] P2.5 — WinRM to cluster VIP connects (any node)
- [ ] P2.6 — `Get-RangerClusterTargets` returns all node FQDNs from config
- [ ] P2.7 — Redfish GET `/redfish/v1` to iDRAC-n01 returns ServiceVersion
- [ ] P2.8 — Redfish to iDRAC-n02
- [ ] P2.9 — Redfish to iDRAC-n03
- [ ] P2.10 — Redfish to iDRAC-n04
- [ ] P2.11 — `Invoke-RangerAzureQuery` for subscription returns without error
- [ ] P2.12 — DNS resolves cluster FQDN to correct VIP
- [ ] P2.13 — `Invoke-RangerRetry` retries correct number of times on failure

---

**Pass gate:** All WinRM, at least 2/4 iDRAC, and Azure must pass.
"@
    },
    @{
        Title = "[TRAILHEAD P3] Individual collector live tests — all 7 collectors"
        Body  = @"
## Operation TRAILHEAD — Phase 3: Individual Collector Live Tests

**Version:** $Version
**Environment:** $Environment
**Milestone:** $milestoneTitle
**Depends on:** Phase 2 passing

Run each collector in **live mode** in isolation. Verify it returns the expected domain payload shape.

---

### topology-cluster collector

- [ ] P3.1.1 — Returns without terminating error
- [ ] P3.1.2 — `clusterNode` domain populated
- [ ] P3.1.3 — Node count matches expected (record actual count)
- [ ] P3.1.4 — Cluster name matches config
- [ ] P3.1.5 — CSVs present
- [ ] P3.1.6 — Quorum configuration present

### hardware collector

- [ ] P3.2.1 — Returns without terminating error
- [ ] P3.2.2 — `hardware` domain populated (one entry per node)
- [ ] P3.2.3 — OEM manufacturer field present
- [ ] P3.2.4 — Firmware/BIOS version present per node
- [ ] P3.2.5 — Security settings (SecureBoot/TPM) fields present
- [ ] P3.2.6 — `oemIntegration` domain populated with iDRAC data

### storage-networking collector

- [ ] P3.3.1 — Returns without terminating error
- [ ] P3.3.2 — `storage` domain populated (pool, volumes, disks)
- [ ] P3.3.3 — Volume count >= 1
- [ ] P3.3.4 — `networking` domain populated (vSwitch, adapters, intents)
- [ ] P3.3.5 — Network intents match config
- [ ] P3.3.6 — S2D HealthStatus captured

### workload-identity-azure collector

- [ ] P3.4.1 — Returns without terminating error
- [ ] P3.4.2 — `virtualMachines` domain populated (count may be 0 if none deployed)
- [ ] P3.4.3 — `identitySecurity` populated (BitLocker, WDAC fields)
- [ ] P3.4.4 — `azureIntegration` populated (Arc status per node)

### monitoring-observability collector

- [ ] P3.5.1 — Returns without terminating error
- [ ] P3.5.2 — `monitoring` domain populated
- [ ] P3.5.3 — AMA agent status present per node
- [ ] P3.5.4 — Health faults array present
- [ ] P3.5.5 — Log Analytics workspace reference present

### management-performance collector

- [ ] P3.6.1 — Returns without terminating error
- [ ] P3.6.2 — `managementTools` domain populated
- [ ] P3.6.3 — `performance` domain populated with CPU/memory/storage metrics
- [ ] P3.6.4 — Metric timestamps present

### waf-assessment collector (v1.4.0+)

- [ ] P3.7.1 — Returns without terminating error
- [ ] P3.7.2 — `wafAssessment` domain populated
- [ ] P3.7.3 — Azure Advisor recommendations returned (count >= 0, no crash if 0)
- [ ] P3.7.4 — `byPillar` array contains all 5 WAF pillars (Reliability, Security, Cost Optimization, Operational Excellence, Performance Efficiency)
- [ ] P3.7.5 — `summary.overallScore` is a numeric value 0-100
- [ ] P3.7.6 — `summary.status` is one of: Excellent / Good / Needs Attention / At Risk
- [ ] P3.7.7 — WAF rule engine re-evaluation from saved manifest: `Invoke-RangerWafRuleEvaluation` returns pillarScores without re-collection

---

**Pass gate:** All 7 collectors complete without terminating errors. Partial data is a warning, not a failure.
"@
    },
    @{
        Title = "[TRAILHEAD P4] Data quality and accuracy cross-validation"
        Body  = @"
## Operation TRAILHEAD — Phase 4: Data Quality & Accuracy

**Version:** $Version
**Environment:** $Environment
**Milestone:** $milestoneTitle
**Depends on:** Phase 3 passing

Validate that collected data is **accurate**, not just present. Cross-check against known-good values.

---

### Checklist

- [ ] P4.1 — Node hostnames in manifest match variables.yml exactly
- [ ] P4.2 — Node IPs in manifest match variables.yml
- [ ] P4.3 — Cluster VIP matches expected IP
- [ ] P4.4 — iDRAC IPs match expected values
- [ ] P4.5 — S2D volume sizes are plausible (≥ 1000 GB)
- [ ] P4.6 — VM count consistent with `Get-VM` on a node directly
- [ ] P4.7 — Arc status per node matches `Get-AzConnectedMachine`
- [ ] P4.8 — Every finding in manifest has non-empty `detail` and valid `severity`
- [ ] P4.9 — No orphaned domain payloads (every domain key has a matching collector)
- [ ] P4.10 — Degraded fixture test: run with `management-performance-degraded.json` — findings reflect degraded state

---

**Pass gate:** All cross-validation checks pass or discrepancies are filed as issues.
"@
    },
    @{
        Title = "[TRAILHEAD P5] Reporting and diagram output validation"
        Body  = @"
## Operation TRAILHEAD — Phase 5: Reporting & Diagrams

**Version:** $Version
**Environment:** $Environment
**Milestone:** $milestoneTitle
**Depends on:** Phase 4 passing

Validate all output artifacts render correctly from the live-collected manifest.

---

### Checklist

- [ ] P5.1 — 3 HTML report tiers generated (executive, management, technical)
- [ ] P5.2 — 3 Markdown report tiers generated
- [ ] P5.3 — ≥ 5 SVG diagram files generated
- [ ] P5.4 — ≥ 1 draw.io (.drawio) file generated
- [ ] P5.5 — Traffic light SVGs render correctly in browser
- [ ] P5.6 — Capacity bar SVGs present and show plausible values
- [ ] P5.7 — Package README.md generated and references all artifacts
- [ ] P5.8 — package-index.json valid JSON, file count matches actual
- [ ] P5.9 — Findings from Phase 4 visible in technical HTML report
- [ ] P5.10 — Topology diagram contains correct node count
- [ ] P5.11 — Executive HTML report loads in browser without errors

### as-built mode checks (run with `output.mode: as-built`)

- [ ] P5.12 — Document Control block (kv-grid) present in as-built HTML report: environment name, generated date, package ID
- [ ] P5.13 — Installation Register table (kv-grid) present in as-built management report
- [ ] P5.14 — Sign-Off table present in as-built technical report with Implementation Engineer / Technical Reviewer / Customer Representative rows
- [ ] P5.15 — current-state run has NO document control / sign-off sections

### WAF report checks

- [ ] P5.16 — WAF Assessment Scorecard table present in management-tier HTML report (Pillar / Score / Status / Rules Passing / Top Finding)
- [ ] P5.17 — WAF Findings detail table present in technical-tier HTML report (failing rules only)
- [ ] P5.18 — WAF section absent from executive-tier report
- [ ] P5.19 — WAF Scorecard present in Markdown management report

### PDF output checks

- [ ] P5.20 — PDF cover page present: title, cluster name, mode, version, generated date, confidentiality notice
- [ ] P5.21 — PDF renders table sections as pipe-delimited text (not raw JSON)
- [ ] P5.22 — PDF renders sign-off section as placeholder rows in as-built mode

---

**Pass gate:** All output files generated; no rendering errors.
"@
    },
    @{
        Title = "[TRAILHEAD P6] Full end-to-end scenario testing (7 scenarios)"
        Body  = @"
## Operation TRAILHEAD — Phase 6: Full End-to-End Scenarios

**Version:** $Version
**Environment:** $Environment
**Milestone:** $milestoneTitle
**Depends on:** Phases 0–5 passing
**Explicitly excluded:** Firewalls, switches, OpenGear

Run `Invoke-AzureLocalRanger` as a real user would across 7 distinct configuration scenarios.

---

### Scenario A — Full run, all collectors, all outputs
- [ ] A.1 — All 6 collectors complete without terminating error
- [ ] A.2 — Package directory created at OutputPath
- [ ] A.3 — 3 HTML report tiers generated
- [ ] A.4 — 5+ SVG diagrams generated
- [ ] A.5 — audit-manifest.json present and valid JSON
- [ ] A.6 — package-index.json present and lists all artifacts
- [ ] A.7 — README.md present in package root

### Scenario B — Core collectors only (exclude hardware/BMC)
- [ ] B.1 — hardware and oemIntegration domains absent from manifest
- [ ] B.2 — Remaining collectors complete
- [ ] B.3 — Reports render without hardware sections

### Scenario C — Single domain target (`-IncludeDomain clusterNode`)
- [ ] C.1 — Only topology-cluster collector runs
- [ ] C.2 — Manifest contains only clusterNode domain
- [ ] C.3 — Run completes without errors

### Scenario D — YAML config vs JSON config (format parity)
- [ ] D.1 — Both config formats accepted without validation error
- [ ] D.2 — Collector output structurally identical from both configs

### Scenario E — Re-render existing manifest (no re-collection)
- [ ] E.1 — Reports generated from Scenario A manifest without hitting live targets
- [ ] E.2 — Output matches Scenario A reports

### Scenario F — Deliberately broken credential
- [ ] F.1 — Collector fails with structured finding, not unhandled exception
- [ ] F.2 — Other independent collectors still attempt
- [ ] F.3 — Manifest written with partial data and failure noted

### Scenario G — Partial cluster (one node unreachable)
- [ ] G.1 — n01–n03 data collected
- [ ] G.2 — Unreachable node appears in manifest with finding
- [ ] G.3 — Run does not crash or hang indefinitely
- [ ] G.4 — Retry logic fires before marking node unreachable

### Scenario H — Invoke-RangerWizard generates config and drives run (v1.2.0+ wizard)
- [ ] H.1 — `Invoke-RangerWizard` launches without throwing in VS Code terminal and Windows Terminal
- [ ] H.2 — Wizard completes the full question sequence (cluster, nodes, Azure IDs, credentials, output, scope)
- [ ] H.3 — Generated YAML is valid and passes `Test-AzureLocalRangerPrerequisites`
- [ ] H.4 — Run launched from wizard-generated config completes without terminating errors
- [ ] H.5 — Wizard-saved config matches expected values from variables.yml (cluster FQDN, nodes, subscription)
- [ ] H.6 — Wizard `--save` path is written and readable

### Scenario I — current-state mode vs as-built mode output differentiation
- [ ] I.1 — current-state run: no Document Control or Sign-Off sections in any report tier
- [ ] I.2 — as-built run (same manifest): Document Control present in management report
- [ ] I.3 — as-built run: Sign-Off table present in technical report
- [ ] I.4 — as-built run: Installation Register present in management report
- [ ] I.5 — Both runs produce structurally valid HTML (no unclosed tags)
- [ ] I.6 — Both modes produce PDF with cover page
- [ ] I.7 — Output directory names differ between runs (mode is reflected in package path or README)

---

**Pass gate:** All 9 scenarios reach a recorded outcome.
**Note:** Do not delete Scenario A output — used as baseline for Scenario E.
"@
    },
    @{
        Title = "[TRAILHEAD P7] Regression and edge cases — TRAILHEAD sign-off"
        Body  = @"
## Operation TRAILHEAD — Phase 7: Regression & Sign-off

**Version:** $Version
**Environment:** $Environment
**Milestone:** $milestoneTitle
**Depends on:** All prior phases complete

Final phase. Confirm no regressions were introduced and sign off on the cycle.

---

### Regression Tests

- [ ] P7.1 — Re-run idempotency: run Scenario A twice to same OutputPath — second run completes cleanly
- [ ] P7.2 — All existing Pester tests still pass: `Invoke-Pester -Path .\tests` returns 0 failures
- [ ] P7.3 — Module unload/reload: `Remove-Module AzureLocalRanger; Import-Module` — loads clean, no state leak

### Edge Case Tests

- [ ] P7.4 — Empty IncludeDomain list — no unhandled exception
- [ ] P7.5 — Invalid ConfigPath — clear, actionable error; no stack trace
- [ ] P7.6 — Non-existent OutputPath — directory created automatically or clear error
- [ ] P7.7 — Config with no targets defined — `Test-AzureLocalRangerPrerequisites` surfaces gap
- [ ] P7.8 — `Test-AzureLocalRangerPrerequisites` passes clean on execution host after all phases

### Sign-Off Checklist

- [ ] All phases P0–P6 have a recorded outcome (pass / partial+issue / waived)
- [ ] All bugs found during TRAILHEAD have issues filed and linked to the v$Version release milestone
- [ ] CHANGELOG.md updated with v$Version field validation notes
- [ ] TRAILHEAD gate issue closed
- [ ] v$Version release milestone ready to close (all bugs resolved or deferred)

---

**Pass gate:** TRAILHEAD milestone is complete when this issue is closed.
**Note:** Any failed test gets a separate bug issue filed and linked back here.
"@
    }
)

# ---------------------------------------------------------------------------
# 3. Create issues and assign to milestone
# ---------------------------------------------------------------------------
$createdIssues = @()

foreach ($phase in $phases) {
    Write-Host "Creating: $($phase.Title)" -ForegroundColor Yellow

    if ($WhatIf) {
        Write-Host "[WhatIf] Would create issue: $($phase.Title)" -ForegroundColor Cyan
        $createdIssues += @{ number = "N/A"; title = $phase.Title }
        continue
    }

    $result = gh issue create `
        --title $phase.Title `
        --body $phase.Body `
        @labelArgs `
        --milestone $milestoneTitle 2>&1

    if ($LASTEXITCODE -ne 0) {
        # Milestone flag may not work on create — assign after
        $result = gh issue create `
            --title $phase.Title `
            --body $phase.Body `
            @labelArgs 2>&1

        $issueNumber = $result | Select-String -Pattern '/issues/(\d+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
        if ($issueNumber) {
            gh issue edit $issueNumber --milestone $milestoneTitle | Out-Null
        }
    } else {
        $issueNumber = $result | Select-String -Pattern '/issues/(\d+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
    }

    $createdIssues += @{ number = $issueNumber; title = $phase.Title }
    Write-Host "  Created #$issueNumber" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 4. Summary
# ---------------------------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Green
Write-Host " Operation TRAILHEAD v$Version — Created" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Milestone : $milestoneTitle"
Write-Host "Issues    :"
foreach ($i in $createdIssues) {
    Write-Host "  #$($i.number)  $($i.title)"
}
Write-Host "`nSee: https://github.com/AzureLocal/azurelocal-ranger/milestone" -ForegroundColor Cyan
