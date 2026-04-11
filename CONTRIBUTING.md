# Contributing

Thank you for your interest in contributing to Azure Local Ranger. Contributions are welcome — especially around expanding discovery coverage, improving report output, and testing across different Azure Local versions and cluster configurations.

## Before You Start

- Read the [README](README.md) for an overview of the project
- Azure Local Ranger is a read-only tool — all discovery is non-destructive, but **test all changes in a non-production environment**
- Check open issues and pull requests to avoid duplicate work

## How to Contribute

### Reporting Bugs

Use the [bug report issue template](.github/ISSUE_TEMPLATE/bug_report.md). Include:

- Azure Local version (22H2, 23H2, etc.)
- PowerShell version (`$PSVersionTable`)
- Which module or function failed and at which step
- Full error message and relevant log output

### Suggesting Features

Use the [feature request issue template](.github/ISSUE_TEMPLATE/feature_request.md). Describe the use case, not just the solution.

### Documentation Issues

Use the [documentation issue template](.github/ISSUE_TEMPLATE/docs_issue.md) for missing, incorrect, or unclear docs.

### Submitting Pull Requests

1. Fork the repo and create a branch from `main`
2. Name branches using conventional types: `feat/gpu-discovery`, `fix/storage-health-check`, `docs/deployment-guide`
3. Keep changes focused — one logical change per PR
4. Update the README and relevant `docs/` pages if your change affects usage or prerequisites
5. Add an entry to [CHANGELOG.md](CHANGELOG.md) under `[Unreleased]`
6. Test your changes against at least one real Azure Local environment before submitting
7. Fill out the pull request template completely

## Commit Messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>
```

| Type | When |
|------|------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `infra` | CI/CD, workflows, config |
| `chore` | Maintenance |
| `refactor` | Code improvement, no behavior change |
| `test` | Tests |

Examples:

- `feat(discovery): add GPU inventory collection`
- `fix(storage): correct S2D pool health parsing`
- `docs(reference): add cluster registration guide`

## Development Guidelines

### PowerShell Style

- Use approved PowerShell verbs (`Get-`, `Set-`, `New-`, `Remove-`, etc.)
- Include `[CmdletBinding()]` and `param()` blocks on all functions
- Use `Write-Verbose` for diagnostic output, `Write-Warning` for non-fatal issues, `Write-Error` for failures
- All discovery functions must be read-only — no cluster state changes, no writes to remote systems

### Testing

- Run Pester tests before submitting: `Invoke-Pester -Path .\tests\`
- Test against a real Azure Local environment when possible
- Describe your test environment and results in the PR

## Standards

This project follows the **org-wide AzureLocal standards** documented at [azurelocal.cloud/standards](https://azurelocal.cloud/standards/). Key references:

- [Repository Structure](https://azurelocal.cloud/standards/repo-structure) — Required files, directories, labels, branch naming
- [Scripting Standards](https://azurelocal.cloud/standards/scripting/scripting-standards) — PowerShell conventions
- [Documentation Standards](https://azurelocal.cloud/standards/documentation/documentation-standards) — Writing and formatting
- [Variable Management](https://azurelocal.cloud/docs/implementation/04-variable-management-standard) — Config file patterns
- [Fictional Company Policy](https://azurelocal.cloud/standards/fictional-company-policy) — Use IIC, never Contoso

## Working Independently

This repository can be used as a standalone project without the parent multi-root workspace.

### Open Only This Repository

1. Open VS Code
2. File > Open Workspace from File > select `azurelocal-ranger.code-workspace`
3. All recommended extensions will be prompted for installation

### Prerequisites

- Python 3.x and pip (for MkDocs documentation)
- [MkDocs Material](https://squidfunk.github.io/mkdocs-material/): `pip install mkdocs-material`

### Run Documentation Locally

```bash
mkdocs serve
```

Browse to <http://127.0.0.1:8000>

### Build Documentation

```bash
mkdocs build
```

## Code of Conduct

Be respectful and constructive. Keep discussions on-topic and collaborative.
