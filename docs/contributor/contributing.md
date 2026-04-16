# Contributing

Azure Local Ranger is an active implementation repository with a public docs site, module code, tests, and release-management assets.

## Contribution Priorities

Useful contributions right now include:

- tightening wording and scope
- improving documentation structure
- identifying missing discovery requirements
- refining output expectations for diagrams, reports, and as-built packages
- aligning Ranger's public documentation quality with Azure Scout
- fact-checking Azure Local feature claims against current Microsoft documentation when public docs make product assertions
- keeping future-scope work visible in the backlog rather than letting it disappear into one umbrella issue or one architecture paragraph

## Repository Discipline

Because this repo backs both a public MkDocs site and the live PowerShell module, contributors should keep:

- public docs clear and intentional
- internal planning in `repo-management/`
- implementation changes aligned with tests, docs, and the manifest contract

## Docs-First Rule

At the current maturity stage, documentation changes should generally land before implementation changes when:

- the change affects the product boundary
- the change introduces a new domain or output model
- the change depends on a new manifest or orchestration assumption
- the change introduces a new Azure Local operating-mode assumption

## Release Documentation Rule

Feature releases (minor version bumps) require documentation updates before merge if any operator-visible behavior changes. Bug-only releases (patch bumps) may skip documentation if no operator-visible behavior changed.

**Documentation is required when a change:**

- Adds, removes, or renames a public command or parameter
- Adds or removes a configuration key
- Changes the default behavior of any flag or setting
- Introduces a new prerequisite or dependency
- Changes the manifest schema or adds new fields
- Introduces a new deployment variant or transport mechanism
- Adds a new output type or changes the format of an existing one

**Pages to update and when:**

| Page | Update when |
| --- | --- |
| `operator/quickstart.md` | New command, new required parameter, changed default run flow |
| `prerequisites.md` | New dependency, new platform or version requirement |
| `operator/prerequisites.md` | Same as above (installation section) |
| `operator/authentication.md` | New auth mechanism, new RBAC requirement |
| `operator/configuration.md` | Any new or removed config key |
| `operator/command-reference.md` | Any public command or parameter change |
| `operator/troubleshooting.md` | New known failure mode or error message |
| `architecture/system-overview.md` | New transport, new entry point, protocol model change |
| `architecture/how-ranger-works.md` | Runtime flow change, new pre-run step |
| `architecture/audit-manifest.md` | Manifest schema change, new block or field |
| `architecture/configuration-model.md` | Any config key added, removed, or changed |
| `CHANGELOG.md` | Every release — handled by release-please |
| `README.md` | Version line, new top-level commands, install instructions |

The PR template (`.github/PULL_REQUEST_TEMPLATE.md` in the repository root) includes a documentation checklist. All applicable items must be checked before a feature PR is merged.

## Backlog Hygiene

If a requirement is explicitly out of v1, it should stay visible as a roadmap item and preferably as its own issue.

That matters because future-scope work is easy to lose when it exists only as a sentence inside architecture documentation or one umbrella planning issue.

## Read Next

- [Getting Started](getting-started.md)
- [Roadmap](../project/roadmap.md)
- [Documentation Roadmap](../project/documentation-roadmap.md)
