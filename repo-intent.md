# Repo intent — azurelocal-ranger

**Know your ground truth. — read-only discovery, documentation, audit, and reporting for Azure Local.**

## What this repo is

Azure Local Ranger builds a manifest-first view of one deployment: the physical
platform, the cluster fabric, hosted workloads, and the Azure resources that
represent, manage, monitor, or extend that environment. Current release
`2.6.6`, published on PSGallery as `AzureLocalRanger`.

## Shape

- `AzureLocalRanger.psd1`/`.psm1`, `Modules/` — the PowerShell module
- `samples/`, `en-US/` — sample output and localized help
- Docs at `docs/index.md` (MkDocs Material)

## How it relates to other repos

- Complements `azurelocal-s2d-cartographer` (storage-specific inventory) and
  `azurelocal-beacon` (pre-deployment readiness) — Ranger covers the full
  post-deployment ground-truth picture, the others are narrower/earlier-stage
  checks

## Status

Active, published (v2.6.6), MIT licensed.
