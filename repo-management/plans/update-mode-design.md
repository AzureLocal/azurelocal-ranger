# Update Mode Design

This document captures the design decision for issue #131: a supported way to refresh an existing Azure Local Ranger package without treating every run as a completely unrelated document set.

## Problem Statement

Ranger's timestamped package model is correct for immutable evidence capture, but it creates friction in two real workflows:

- current-state documentation where teams want one canonical package path that always reflects the latest run
- as-built handoff packages where teams need to refresh generated content after review without rebuilding the entire document set by hand

The hard constraint is that a naive overwrite destroys any manual edits made after the original run. That risk is unacceptable for sign-off narratives, reviewer notes, and hand-authored corrections.

## Decision

Primary approach: manifest-driven re-render into an existing package, with file-level preservation for manual content and drift preview before overwrite.

This is closest to Approach C from the issue, but with an explicit preservation contract:

- Ranger updates only files and directories it owns.
- Operator-authored content lives in reserved override directories that Ranger never overwrites.
- Drift detection from #123 is the safety check before generated content is refreshed.

This keeps the update model compatible with the current manifest-first architecture and avoids the complexity of section-level merge markers in every template.

## Why This Approach

Why not fixed-path overwrite only:

- it solves the current-state path problem
- it does not solve the manual-edit problem

Why not selective section refresh first:

- it requires template marker contracts across every report format
- it introduces merge complexity before there is proof that section-level preservation is needed everywhere

Why not companion addendum only:

- it is safe for as-built packages
- it does not satisfy the single canonical current-state document use case

The chosen design keeps the simple packaging model, preserves manual content safely at file boundaries, and leaves room for later section-level preservation if real usage justifies it.

## Supported Phases

### Phase 1

Support package refresh by re-rendering generated outputs into an existing package path.

Behavior:

- collect a new manifest from a live run or provide one explicitly
- compare it to the package's prior manifest when available
- show a drift summary
- overwrite managed generated assets only
- preserve reserved manual-content directories untouched

This phase supports both current-state and as-built refreshes, with the caveat that inline edits inside generated report files are not preserved.

### Phase 2

Add optional override fragments for common hand-authored content.

Examples:

- executive summary additions
- sign-off and approval blocks
- assumptions and exceptions
- reviewer notes

These fragments live outside generated files and are injected during rendering. Ranger preserves them across updates because it never rewrites the override files themselves.

### Phase 3

Only if needed later, consider template-managed section markers for true in-place preservation inside generated reports.

This is explicitly not required for the first supported update mode.

## Package Ownership Model

Ranger-managed content:

- `manifest/`
- `reports/generated/`
- `diagrams/generated/`
- `metadata/`
- package index files that are explicitly marked as generated

Operator-managed content:

- `overrides/`
- `attachments/`
- `notes/`

Contract:

- update mode may overwrite Ranger-managed files
- update mode must never overwrite operator-managed files
- generated files should include a header noting that they are managed artifacts

## Command and Config Interface

Primary command surface:

```powershell
Invoke-AzureLocalRanger \
    -ConfigPath .\ranger-config.yml \
    -UpdateMode \
    -TargetPackagePath C:\AzureLocalRanger\tplabs-current-state \
    -BaselineManifestPath C:\AzureLocalRanger\tplabs-current-state\manifest\audit-manifest.json
```

Secondary render-only path:

```powershell
Update-AzureLocalRangerPackage \
    -ManifestPath .\new-audit-manifest.json \
    -PackagePath C:\AzureLocalRanger\tplabs-current-state \
    -WhatChanged
```

Recommended config model:

```yaml
output:
  rootPath: C:\AzureLocalRanger
  mode: current-state
  update:
    enabled: false
    targetPackagePath: C:\AzureLocalRanger\tplabs-current-state
    preserveOverrides: true
    createPreUpdateArchive: true
    archiveRootPath: C:\AzureLocalRanger\archive
    requireDriftPreview: true
```

Rules:

- `output.update.enabled` is opt-in
- `targetPackagePath` is required when update mode is enabled
- `preserveOverrides` defaults to `true`
- `createPreUpdateArchive` defaults to `true` for safety
- `requireDriftPreview` defaults to `true` so users can see what changed before overwrite proceeds

## Manual Edit Preservation Strategy

Manual edits are preserved at the file boundary, not by trying to merge arbitrary edits inside generated files.

Supported preservation method:

- move manual content into `overrides/`, `attachments/`, or `notes/`
- renderers optionally consume override fragments from `overrides/` when they exist

Unsupported in Phase 1:

- editing the generated HTML or Markdown files directly and expecting Ranger to preserve those inline edits during update

This needs to be stated clearly in operator documentation. It is the simplest safe contract and avoids false confidence.

## Template Changes Required

Phase 1 template changes:

- generated report headers should clearly mark the file as Ranger-managed
- renderers should emit generated artifacts into `reports/generated/` and `diagrams/generated/`
- package index pages may link both generated outputs and override content

Phase 2 template changes:

- optional include hooks for override fragments such as summary, sign-off, and notes blocks
- rendering logic should skip missing override fragments without error

Section-level marker changes are not required for the initial implementation.

## Relationship to Drift Detection (#123)

Drift detection is the safety layer for update mode.

Expected interaction:

- when update mode targets an existing package, Ranger loads the package's prior manifest as the baseline if one exists
- Ranger generates a drift summary before replacing managed outputs
- Ranger writes `drift-report.json` into the updated package
- report renderers may include an update summary section showing added, removed, and changed items since the previous package state

Update mode should not depend on drift detection to function, but drift detection should be the default preview and audit trail whenever a baseline manifest exists.

## Archive Behavior

Update mode should preserve traceability even when the canonical package path stays fixed.

Default behavior:

- copy the current managed package state to an archive location before overwrite
- stamp the archive with timestamp and run identifier
- preserve operator-managed content in place

This allows a stable current path without giving up historical evidence.

## Explicit Non-Goals

- no arbitrary three-way merge of generated report files
- no preservation promise for inline edits inside generated files in Phase 1
- no requirement to update every historical package in place

## Recommended Next Implementation Steps

1. Implement drift detection (#123) first, because update mode should build on the same manifest comparison path.
2. Add package ownership boundaries and managed output paths.
3. Add `-UpdateMode` and `-TargetPackagePath` to `Invoke-AzureLocalRanger`.
4. Add `Update-AzureLocalRangerPackage` as the render-only entry point.
5. Add override fragment support for the most common hand-authored sections.

## Outcome

Azure Local Ranger should support a canonical package path, but it should do so with explicit ownership boundaries rather than pretending it can safely merge arbitrary manual edits.

That is the lowest-risk path that satisfies both operational current-state refreshes and controlled as-built updates.