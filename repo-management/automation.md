# Automation

Documents every GitHub Actions workflow in this repository.

---

## Workflow Summary

| File | Name | Trigger | Purpose |
|------|------|---------|---------|
| `deploy-docs.yml` | Deploy Documentation | Push to `main` touching `docs/**` or `mkdocs.yml` | Builds MkDocs site and deploys to GitHub Pages |
| `validate.yml` | Validate | Pull requests, non-`main` pushes, manual run | Validates MkDocs and the PowerShell module shell before merge |
| `release-please.yml` | Release Please | Push to `main` | Automates CHANGELOG and releases |

---

## deploy-docs.yml

**Trigger:** Push to `main` touching `docs/**` or `mkdocs.yml`  
**Permissions:** `contents: read`, `pages: write`, `id-token: write`  
**Concurrency group:** `pages` (cancel-in-progress: false)

Two-job pipeline:

**build:**
1. Sets up Python 3.12
2. Installs `mkdocs-material` and `mkdocs-drawio`
3. `mkdocs build --strict` — fails on any warning
4. Uploads `site/` as a pages artifact

**deploy:**
1. Uses `actions/deploy-pages@v4` to publish to GitHub Pages

---

## validate.yml

**Trigger:** Pull requests, pushes to any branch except `main`, or manual run  
**Purpose:** Catch documentation or module shell issues before merge.

Validation steps:

1. Sets up Python 3.12
2. Installs `mkdocs-material` and `mkdocs-drawio`
3. Runs `mkdocs build --strict`
4. Validates `AzureLocalRanger.psd1` with `Test-ModuleManifest`
5. Imports the root module to confirm the shell still loads cleanly

---

## release-please.yml

**Trigger:** Push to `main`  
**Permissions:** `contents: write`, `pull-requests: write`

Uses `googleapis/release-please-action@v4` with explicit config:
- `config-file: release-please-config.json`
- `manifest-file: .release-please-manifest.json`

Both files must exist at the repo root. The workflow maintains an automated release PR that updates `CHANGELOG.md` and bumps the version. Merging it creates the GitHub release and tag.
