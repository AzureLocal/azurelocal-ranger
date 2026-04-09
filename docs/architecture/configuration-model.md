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
| `output` | Current-state vs as-built, formats, paths, and package settings |
| `behavior` | Timeouts, retry posture, strictness, and logging preferences |

## Target Addressing Model

Targets should be explicit rather than inferred from one overloaded cluster setting.

| Target type | Minimum addressing shape |
|---|---|
| Cluster | cluster FQDN and, optionally, explicit node list |
| Azure | subscription ID, resource group, tenant ID, and where useful the Azure Local instance name |
| BMC | explicit endpoint list by host name or IP |
| Switch or firewall | explicit endpoint list plus protocol metadata when those future domains are enabled |

Switch and firewall targets should remain absent by default. Ranger should not assume that every environment wants direct network-device interrogation.

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

## Key Vault Resolution Rules

Key Vault lookup should follow these rules:

1. if a version is supplied, Ranger resolves that exact secret version
2. if no version is supplied, Ranger resolves the latest enabled version
3. Ranger uses the current Azure authentication context to resolve the secret
4. if Key Vault resolution fails and prompting is allowed, Ranger can prompt for the missing secret interactively
5. if Key Vault resolution fails and prompting is not allowed, dependent domains should fail or skip according to whether the credential was required or optional

Ranger should not introduce a separate Key Vault-only credential model. Secret lookup should rely on the Azure identity already in use for the run.

## Domain Selection

The configuration model should support both `include` and `exclude` lists.

The rules are:

- if `include` is present, only those domains are considered
- if `exclude` is present, those domains are removed from the candidate set
- if neither is present, Ranger runs all domains for which it has the required targets and credentials
- optional future domains remain skipped unless explicitly configured and supported

Domain selection should also respect the domain classes defined in the execution model:

- core domains are candidates by default
- optional domains stay off unless their targets and credentials are configured
- variant-specific domains require detected or explicitly hinted variants
- future-only domains remain unavailable in the current release

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
