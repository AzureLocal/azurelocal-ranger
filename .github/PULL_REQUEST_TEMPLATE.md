## Summary

<!-- What does this PR do and why? -->

## Type of change

- [ ] Bug fix (no behavior change for operators)
- [ ] Feature / behavior change (affects how operators use Ranger)
- [ ] Documentation only
- [ ] Tooling / CI / repo hygiene

## Documentation checklist

**Bug fixes** — only check what applies:
- [ ] No operator-visible behavior changed — no doc update needed
- [ ] Bug fix changes documented behavior → updated affected doc page(s)

**Feature / behavior changes** — all that apply must be checked before merge:
- [ ] Operator Guide updated (quickstart, prerequisites, configuration, command-reference, troubleshooting, authentication)
- [ ] Architecture docs updated if the runtime model, manifest, config model, or system overview changed
- [ ] CHANGELOG.md updated
- [ ] Module version bumped in `AzureLocalRanger.psd1`
- [ ] README version line updated if applicable

## Testing

- [ ] `Invoke-Pester -Path ./tests` passes locally (0 failures)
- [ ] `Invoke-ScriptAnalyzer -Path ./Modules -Recurse -Severity Error` returns no errors
- [ ] Tested against a real or fixture-backed run where applicable

## Related issues

Closes #
