# Versioning

Azure Local Ranger uses [Semantic Versioning](https://semver.org/) — `MAJOR.MINOR.PATCH`.

---

## What Each Part Means

| Segment | Meaning | Example trigger |
| --- | --- | --- |
| **MAJOR** | Breaking changes — public command removed or renamed, manifest schema key renamed or removed, required config file changes, PowerShell version requirement raised | `1.0.0 → 2.0.0` |
| **MINOR** | New backward-compatible features — new collector, new output format, new public command, new optional config key | `1.0.0 → 1.1.0` |
| **PATCH** | Backward-compatible bug fixes — collector crash fix, report rendering correction, schema validation fix | `1.0.0 → 1.0.1` |

### Ranger-Specific Rules

- Adding a new discovery domain or collector is always a **MINOR** bump.
- Adding a new key to `audit-manifest.json` that is optional and defaults to null is **MINOR**.
- Removing or renaming a key in `audit-manifest.json` in a way that breaks existing manifests is **MAJOR**.
- Changing a `ranger-config.yml` key in a way that requires user action is **MAJOR**.
- Adding a new optional config key is **MINOR**.
- A docs-only or test-only change that ships no module code change gets a **PATCH** if it triggers a release at all; most land as changelog entries with no version bump.

---

## Pre-Release Versions

Versions below `1.0.0` (e.g., `0.5.0`) are pre-release and not published to the PowerShell Gallery. Strict SemVer rules apply **after `1.0.0` ships**. Before that, MINOR bumps may include breaking changes.

---

## Release Automation

Version bumps are automated by [release-please](https://github.com/googleapis/release-please), which reads [Conventional Commits](https://www.conventionalcommits.org/) on `main` and opens a PR that:

- bumps `ModuleVersion` in `AzureLocalRanger.psd1`
- updates `CHANGELOG.md` with categorized entries

Merging that PR creates a GitHub Release and tags the commit.

### Commit Prefix → Version Bump Table

| Prefix | What it signals | Version effect |
| --- | --- | --- |
| `feat:` | New feature | MINOR bump |
| `fix:` | Bug fix | PATCH bump |
| `feat!:` or `BREAKING CHANGE:` footer | Breaking change | MAJOR bump |
| `docs:` | Documentation only | No bump (CHANGELOG entry) |
| `refactor:` | Code restructure, no behavior change | No bump |
| `test:` | Test additions or fixes | No bump |
| `chore:` | Build, config, deps | No bump |
| `ci:` | Workflow or pipeline | No bump |

### Example Commit Messages

```text
feat: add cost analysis collector with AHB tracking
fix: null check in Get-RangerSafeName prevents SVG crash
docs: add drift detection guide to operator docs
feat!: rename domains.network to domains.networking in manifest schema
```

---

## Milestones and Version Alignment

Each GitHub milestone maps to one planned release. An issue assigned to a milestone is committed for that release — it must be closed (or explicitly deferred) before the milestone closes and the version ships.

| Milestone | Target version | Sprint focus |
| --- | --- | --- |
| [v1.0.0 — PSGallery Launch](https://github.com/AzureLocal/azurelocal-ranger/milestone/3) | `1.0.0` | Live-estate validation, PSGallery publish, and final polish |
| [v1.1.0 — Post-Release Sprint](https://github.com/AzureLocal/azurelocal-ranger/milestone/6) | `1.1.0` | Interactive wizard, TUI, Arc Run Command, disconnected mode, WAF, PDF |
| [v2.0.0 — Extended Platform Coverage](https://github.com/AzureLocal/azurelocal-ranger/milestone/4) | `2.0.0` | Switches, firewalls, OEM hardware, multi-rack, cost analysis, PowerPoint |

### When to Create a New Milestone

Create a new milestone when:

- The existing next milestone is already well-scoped and you do not want to inflate it.
- A new feature cluster is clear enough that it needs its own ship target.
- The next intermediate version (e.g., `1.2.0`) has enough issues to warrant tracking.

Use the naming pattern `vX.Y.Z — Short Title` with a one-line sprint description.

---

## How to Check the Current Version

```powershell
# From source — read psd1 directly
(Select-String -Path .\AzureLocalRanger.psd1 -Pattern "ModuleVersion").Line

# After import
(Get-Module AzureLocalRanger).Version
```

---

## Keeping Issues and Versions in Sync

- Every enhancement or bug fix should be tracked as an issue **before** implementation begins.
- Issues are assigned to the milestone for the version they target.
- The [Product Plan Implementation Tracker](https://github.com/AzureLocal/azurelocal-ranger/blob/main/repo-management/reports/product-plan-implementation-tracker.md) provides a human-readable cross-reference between issues, features, and versions separate from GitHub's milestone view.
- Do not merge implementation PRs without a milestone-assigned issue. Commit messages reference `#issue-number` to keep history traceable.

---

## Read Next

- [Roadmap](roadmap.md)
- [Changelog](changelog.md)
- [Contributing](../contributor/contributing.md)
