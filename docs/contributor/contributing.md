# Contributing

Azure Local Ranger is still being shaped at the product-definition and planning level.

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

Because this repo is intended to back a public MkDocs site and a future PowerShell module, contributors should keep:

- public docs clear and intentional
- internal planning in `repo-management/`
- implementation directories empty until the design is mature enough to support real work

## Docs-First Rule

At the current maturity stage, documentation changes should generally land before implementation changes when:

- the change affects the product boundary
- the change introduces a new domain or output model
- the change depends on a new manifest or orchestration assumption
- the change introduces a new Azure Local operating-mode assumption

## Backlog Hygiene

If a requirement is explicitly out of v1, it should stay visible as a roadmap item and preferably as its own issue.

That matters because future-scope work is easy to lose when it exists only as a sentence inside architecture documentation or one umbrella planning issue.

## Read Next

- [Getting Started](getting-started.md)
- [Roadmap](../project/roadmap.md)
- [Documentation Roadmap](../project/documentation-roadmap.md)
