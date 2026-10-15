# CI, release and publishing

## What CI runs

`.github/workflows/ci.yml` runs on every push to `main` and every pull request. Nothing in it reaches Azure or a cluster: the Pester suites run on fixtures and mocks.

| Job | What it checks | Same locally |
| --- | --- | --- |
| `analyzer` | PSScriptAnalyzer with `PSScriptAnalyzerSettings.psd1` over `Modules/`, the root module files and `scripts/`, and `tests/PSScriptAnalyzerSettings.psd1` over `tests/`. Any remaining Error or Warning fails the job | `pwsh scripts/ci/Invoke-RangerCi.ps1 -Check Analyzer` |
| `manifest` | `Test-ModuleManifest`, PowerShell 7 and the Core edition are declared, the module imports, exported functions match the manifest, `CHANGELOG.md` has a section for the version | `-Check Manifest` |
| `links` | Relative Markdown links in the top-level Markdown files and `docs/` | `-Check Links` |
| `pester` | Four shards, each running one PowerShell process per test file (about 5 to 8 minutes each on a hosted runner) | `-Check Pester -TestFile Config.Tests.ps1,Runtime.Tests.ps1` |

Actions are pinned to full commit SHAs with the release in a comment. Bump them with Dependabot or by hand.

## Analyzer settings

`PSScriptAnalyzerSettings.psd1` lists each excluded rule with the reason (console output is the design, UTF-8 without BOM is the repository convention, internal helper names are API, collectors share one signature). Credential-map parameters carry a function-level `SuppressMessage` with a justification: they hold PSCredential objects or Key Vault references, never a plain-text secret. Empty `catch` blocks are not allowed; use `Write-RangerSwallowedError` so the error is logged at debug level and the collector is marked degraded in the manifest.

## Releases

1. Merge conventional commits (`feat`, `fix`, `docs`, `infra`, `chore`, `refactor`, `test`) to `main`.
2. `.github/workflows/release-please.yml` keeps a release pull request up to date (version, `CHANGELOG.md`, the `ModuleVersion` line marked `x-release-please-version`). The last released version is recorded in `.release-please-manifest.json`.
3. Merging that pull request creates the tag and the GitHub release.
4. `.github/workflows/publish-gallery.yml` runs on the published release, checks that the tag equals the module version, stages the module files and runs `Publish-Module`.

## PowerShell Gallery secret (placeholder, not configured)

The publish job is deliberately inert until the repository owner sets it up:

1. Create a GitHub environment named `psgallery` and add required reviewers, so a person approves each publish.
2. Add the environment secret `PSGALLERY_API_KEY` with a PowerShell Gallery API key scoped to the `AzureLocalRanger` package.

Without the secret the job fails before anything is uploaded. The key is read from the environment only and is never printed. A manual run (`workflow_dispatch`) defaults to a dry run that validates and stages without publishing.

## Documentation site

`.github/workflows/deploy-docs.yml` builds the VitePress site in `docs/` and deploys it to GitHub Pages. `cleanUrls` is on and every page is also emitted as `<route>/index.html`, so both `/operator/first-run` and `/operator/first-run/` resolve. Build locally with `cd docs; npm install; npm run docs:build`.
