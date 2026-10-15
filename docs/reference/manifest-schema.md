# Manifest JSON Schema

`docs/reference/manifest.schema.json` ([download](manifest.schema.json)) is a JSON Schema (draft 7) for `manifest/audit-manifest.json`.

It is strict about the envelope Ranger itself depends on and open about the payloads:

- required top-level keys: `run`, `target`, `topology`, `collectors`, `domains`, `relationships`, `findings`, `artifacts`, `evidence`;
- `run` requires `toolVersion`, `schemaVersion`, `startTimeUtc`, `mode` (`current-state` or `as-built`) and `selectedCollectors`;
- every collector entry needs a `status` (`success`, `partial`, `failed`, `skipped`, `not-applicable`) and may carry the v2.7.0 fields `degraded`, `degradationCount` and `degradations`;
- the eleven reserved domains must be present and are objects; their contents are open because collectors add keys between releases;
- findings need `severity` (`critical`, `warning`, `informational`, `good`), `title` and `description`; artifacts need `type`, `relativePath` and `status`.

```powershell
Get-Content .\manifest\audit-manifest.json -Raw | Test-Json -SchemaFile .\docs\reference\manifest.schema.json
```

The Pester suite validates every manifest fixture, a redacted manifest and a manifest with degradation fields against this schema (`tests/maproom/unit/Docs.Tests.ps1`). Field-by-field description of the domains: [Audit manifest](../architecture/audit-manifest.md). The snapshot exported for design comparison has its own schema: [as-built-snapshot.v1](design-vs-as-built.md#as-built-snapshot-v1).
