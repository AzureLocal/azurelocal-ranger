---
name: TRAILHEAD Milestone Gate
about: Track end-of-milestone Operation TRAILHEAD validation before closing a release milestone.
title: "[TRAILHEAD GATE] vX.Y.Z — milestone-end validation"
labels: ["type/infra", "priority/high", "solution/ranger"]
assignees: []
---

## Summary

Use this issue to track the Operation TRAILHEAD release gate for a delivery milestone.
Do not close the release milestone until this issue is closed or explicitly waived in a comment.

## Milestone Context

- Release milestone: `vX.Y.Z — <name>`
- Target version: `vX.Y.Z`
- Test environment: `<tplabs-clus01 or other environment>`
- Planned validation date: `YYYY-MM-DD`
- Related TRAILHEAD milestone: `Operation TRAILHEAD — vX.Y.Z Field Validation` or `N/A`
- TRAILHEAD run log: `tests/trailhead/logs/run-YYYYMMDD-HHMM.md`

## Entry Criteria

- [ ] All in-scope milestone issues are closed, deferred, or explicitly waived
- [ ] CHANGELOG.md or release notes draft is updated
- [ ] `Invoke-Pester -Path .\tests` passes cleanly
- [ ] No known blocker bug remains open without an explicit release waiver

## Required TRAILHEAD Scope

Choose one. If not using the full cycle, document the rationale in a comment.

- [ ] Full P0-P7 TRAILHEAD cycle required
- [ ] Targeted TRAILHEAD cycle required for impacted phases only
- [ ] No live cycle required; waiver documented and approved

## Impacted Areas

- [ ] Credentials or authentication
- [ ] Connectivity or remoting
- [ ] Collectors or live discovery
- [ ] Manifest or schema
- [ ] Reports, diagrams, or packaging
- [ ] Docs or help only
- [ ] Release or publish automation

## Execution Checklist

- [ ] Start a TRAILHEAD run log with `tests/trailhead/scripts/Start-TrailheadRun.ps1`
- [ ] Execute all required TRAILHEAD phases
- [ ] File and link any bugs found during validation
- [ ] Record pass, partial, or waived outcome for each executed phase
- [ ] Attach package path, report artifacts, and key findings in a comment
- [ ] Update related release issues if validation changes scope or ship decision

## Exit Criteria

- [ ] All required phases reached a recorded outcome
- [ ] All discovered bugs are linked and triaged into the correct milestone
- [ ] Release owner reviewed the validation result
- [ ] Milestone may be closed

## Notes

- Full P0-P7 is expected for milestones that change collectors, authentication, execution, rendering, packaging, or publishing.
- Docs-only milestones can use Pester plus docs review with a waiver comment for live TRAILHEAD phases.