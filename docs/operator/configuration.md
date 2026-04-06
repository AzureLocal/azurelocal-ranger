# Operator Configuration

This page shows how an operator should think about configuration in practice.

The formal model is defined in [Configuration Model](../architecture/configuration-model.md). This page focuses on how to use it.

## What To Configure

Operators generally configure five things:

1. the Azure Local deployment being targeted
2. the credentials for each target type
3. the domains to include or exclude
4. the output mode and destination
5. any variant hints needed for unusual environments

## Practical Example

```yaml
environment:
  name: prod-azlocal-01
  clusterName: azlocal-prod-01

targets:
  cluster:
    fqdn: azlocal-prod-01.contoso.com
  azure:
    subscriptionId: 00000000-0000-0000-0000-000000000000
    resourceGroup: rg-azlocal-prod-01
  bmc:
    endpoints:
      - host: idrac-node-01.contoso.com
      - host: idrac-node-02.contoso.com

credentials:
  azure:
    method: existing-context
  cluster:
    username: CONTOSO\\ranger-read
    passwordRef: keyvault://kv-ranger/cluster-read
  domain:
    username: CONTOSO\\ranger-read
    passwordRef: keyvault://kv-ranger/domain-read
  bmc:
    username: root
    passwordRef: keyvault://kv-ranger/idrac-root

domains:
  include:
    - topology
    - cluster
    - hardware
    - storage
    - networking
    - virtual-machines
    - identity-security
    - azure-integration
    - management-tools
    - performance

output:
  mode: as-built
  formats: [html, markdown, json, svg]
  rootPath: ./artifacts
```

## Include and Exclude Rules

Use `include` when you want a focused run.

Use `exclude` when you want a broad run with a few domains intentionally skipped.

Good examples:

- quick operational run: `cluster`, `storage`, `networking`, `azure-integration`
- documentation-heavy run: all core domains plus `hardware`, `management-tools`, and `performance`
- limited-permission run: exclude `hardware` when no BMC access exists

## Optional Domains

Optional and future domains should stay off unless you explicitly configure them.

Examples:

- direct switch interrogation
- direct firewall interrogation
- variant-specific future collectors for disconnected or multi-rack deep inspection

## Output Mode

`current-state` is for operational understanding.

`as-built` is for formal handoff output. It should include richer report rendering and diagram selection, but it still renders from the same cached manifest.

## Variant Hints

Variant hints are allowed when the environment shape is known ahead of time or difficult to infer reliably.

Example:

```yaml
domains:
  hints:
    topology: local-key-vault
    controlPlaneMode: disconnected
```

Hints should guide validation and wording, not overwrite observed facts silently.

## What Not To Put In Config

Avoid putting these in a committed configuration file:

- plaintext secrets
- ad-hoc notes that belong in documentation rather than machine-readable settings
- environment-specific assumptions that Ranger can discover directly

## If Something Is Missing

If a required value is missing, the desired behavior is:

- fail early for invalid configuration
- prompt for credentials when interactive prompting is enabled
- skip optional domains when targets or credentials are absent

## Related Pages

- [Operator Prerequisites](prerequisites.md)
- [Operator Authentication](authentication.md)
- [Operator Troubleshooting](troubleshooting.md)
