# Configuration Model

Azure Local Ranger needs a configuration model that is explicit enough for operators to use safely and stable enough that implementation does not hard-code assumptions prematurely.

This page defines the intended public configuration shape.

## Goals

The configuration model should let an operator:

- identify the Azure Local instance and any optional external targets
- provide separate credentials per target type
- choose which discovery domains to run or skip
- select current-state versus as-built output behavior
- direct Ranger where to write artifacts
- use Key Vault references instead of storing secrets inline

## Recommended Format

YAML is the preferred configuration format because it is readable for operators and works well for nested target, credential, and output settings.

JSON support is acceptable if needed later, but YAML should be the primary documented example format.

## Top-Level Structure

A configuration file should be organized around these blocks:

| Section | Purpose |
|---|---|
| `environment` | Human-readable identifiers for the target deployment |
| `targets` | Cluster, BMC, Azure, and optional network-device targets |
| `credentials` | Per-target credential references |
| `domains` | Include/exclude behavior and optional feature switches |
| `output` | Current-state vs as-built, formats, paths, branding, and package settings |
| `behavior` | Timeouts, retry posture, strictness, and logging preferences |

## Representative Example

```yaml
environment:
  name: prod-azlocal-01
  clusterName: azlocal-prod-01
  description: Primary production Azure Local instance

targets:
  cluster:
    fqdn: azlocal-prod-01.contoso.com
    nodes:
      - azl-node-01.contoso.com
      - azl-node-02.contoso.com
  azure:
    subscriptionId: 00000000-0000-0000-0000-000000000000
    resourceGroup: rg-azlocal-prod-01
    tenantId: 11111111-1111-1111-1111-111111111111
  bmc:
    endpoints:
      - host: idrac-node-01.contoso.com
      - host: idrac-node-02.contoso.com
  switches: []
  firewalls: []

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
  exclude: []

output:
  mode: current-state
  formats:
    - html
    - markdown
    - json
  rootPath: ./artifacts
  diagramFormat: svg
  keepRawEvidence: true

behavior:
  promptForMissingCredentials: true
  skipUnavailableOptionalDomains: true
  failOnSchemaViolation: true
  logLevel: info
```

## Credential References

Ranger should support three ways to supply credentials:

1. explicit parameters
2. config-file values or Key Vault references
3. interactive prompt

The documented Key Vault reference format is:

```text
keyvault://<vault-name>/<secret-name>[/<version>]
```

Secrets should not be stored inline in committed configuration files.

## Domain Selection

The configuration model should support both `include` and `exclude` lists.

The rules are:

- if `include` is present, only those domains are considered
- if `exclude` is present, those domains are removed from the candidate set
- if neither is present, Ranger runs all domains for which it has the required targets and credentials
- optional future domains remain skipped unless explicitly configured and supported

## Variant-Specific Settings

Most variant behavior should be detected, not hard-coded in config. However, the model should allow explicit hints when the environment requires them.

Examples:

```yaml
domains:
  hints:
    topology: multi-rack
    identityMode: local-key-vault
    controlPlaneMode: disconnected
```

Hints should guide collector selection or validation wording, but they should not silently override observed facts.

## Output Settings

The output block should control:

- `mode`: `current-state` or `as-built`
- output root path
- format list (`json`, `html`, `markdown`, `svg`)
- whether raw evidence exports are retained
- whether executive-only subsets are generated
- package naming and timestamp behavior

## Behavior Settings

The behavior block should capture operator intent that is not itself discovery data.

Examples include:

- retry counts and timeout posture
- whether to prompt interactively for missing credentials
- whether schema validation warnings fail the run
- log verbosity
- whether to stop after collection or continue into rendering

## Configuration Validation

Before discovery begins, Ranger should validate:

- required fields for the selected domains
- obvious conflicts such as the same domain in both include and exclude lists
- malformed Key Vault references
- unsupported combinations for the current release
- missing Azure region alignment for Azure Local VM management dependencies when those domains are selected

Invalid configuration should fail early with a specific message.

## Relationship To Operator Docs

This page defines the shape of the model. Practical usage guidance belongs in:

- [Operator Configuration](../operator/configuration.md)
- [Operator Authentication](../operator/authentication.md)
- [Operator Troubleshooting](../operator/troubleshooting.md)
