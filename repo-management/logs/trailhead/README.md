# TRAILHEAD Run Logs

This directory contains committed run logs from Operation TRAILHEAD field validation cycles.

Each log file is created by `Start-TrailheadRun.ps1` and committed at the end of a testing session as an auditable record.

## File naming

```
run-YYYYMMDD-HHmm.md
```

## How to start a run

```powershell
# 1. Initialise the run (creates log file + GitHub run-log issue)
.\repo-management\scripts\Start-TrailheadRun.ps1

# 2. Dot-source the helpers into your session
. .\repo-management\scripts\TrailheadLog-Helpers.ps1

# 3. Record results as you go
Write-THPhase "P0 — Preflight"
Write-THPass  "P0.1" "PowerShell 7.6.0"
Write-THPass  "P0.2" "Module loads — 4 exported functions present"
Write-THFail  "P0.8" "ICMP to ndm (10.250.1.39) timed out"
Write-THFix   "P0.8" "Added entry to hosts file; retry passed"
Write-THPass  "P0.8" "ICMP retry passed after hosts fix"

# 4. Close and commit at end of session
Close-THRun -Passed 8 -Failed 0
git add repo-management/logs/trailhead/run-*.md
git commit -m "test(trailhead): run log TRAILHEAD-20260407-1400"
git push origin main
```

## Log entry types

| Function | Icon | Meaning |
|---|---|---|
| `Write-THPass` | ✅ | Check passed |
| `Write-THFail` | ❌ | Check failed |
| `Write-THFix` | 🔧 | Fix applied after failure |
| `Write-THNote` | ℹ️ | Observation or context |
| `Write-THSkip` | ⏭️ | Check skipped with reason |
| `Write-THPhase` | ▶ | Phase boundary marker |

## Committed logs

| Run | Version | Result |
|---|---|---|
| _(none yet — first run pending)_ | | |
