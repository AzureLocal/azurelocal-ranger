# Repository Setup

Documents how this repository is configured. Use this as the reference when setting up a new repo or auditing existing settings.

---

## Branch Protection

**Protected branch:** `main`

| Setting | Value |
|---------|-------|
| Require pull request before merging | Yes |
| Required approvals | 1 |
| Dismiss stale reviews on new commits | Yes |
| Require status checks to pass | Yes |
| Require branches to be up to date | Yes |
| Restrict force pushes | Yes |
| Allow admins to bypass | Yes |

---

## Labels

Labels are defined in `azurelocal.github.io/.github/labels.yml` — that is the source of truth for all repos. Labels are applied here when they change in the source repo or manually via `workflow_dispatch` on `sync-labels.yml` in `azurelocal.github.io`.

---

## Secrets

| Secret | Used By | Description |
|--------|---------|-------------|
| `GITHUB_TOKEN` | All workflows | Built-in GitHub token. |

This repo has no `ADD_TO_PROJECT_PAT` — it does not use the `add-to-project.yml` workflow.

---

## CODEOWNERS

Defined in `.github/CODEOWNERS`. Review and update if team membership changes.

---

## GitHub Pages

| Setting | Value |
|---------|-------|
| Source | GitHub Actions (uses `actions/deploy-pages`) |
| Build tool | MkDocs Material + mkdocs-drawio |
| Deploy trigger | Push to `main` touching `docs/**` or `mkdocs.yml` |
| HTTPS enforced | Yes |

---

## Release Please Configuration

This repo uses an explicit `config-file` and `manifest-file` in `release-please.yml`, pointing to `release-please-config.json` and `.release-please-manifest.json` at the repo root. Both files must exist for the workflow to function.

---

## Replication Checklist

- [ ] Enable branch protection on `main` per settings above
- [ ] Add `.github/CODEOWNERS`
- [ ] Add `.github/PULL_REQUEST_TEMPLATE.md`
- [ ] Copy `release-please.yml` and create `release-please-config.json` + `.release-please-manifest.json`
- [ ] Copy `deploy-docs.yml`
- [ ] Keep `validate.yml` aligned with docs dependency and module validation standards
- [ ] Enable GitHub Pages (Settings → Pages → Source: GitHub Actions)
