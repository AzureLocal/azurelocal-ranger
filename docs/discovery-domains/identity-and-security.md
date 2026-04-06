# Identity and Security

This domain explains how the environment is trusted, governed, and secured.

It covers both local security posture and the Azure-side governance or identity relationships that directly describe the Azure Local deployment.

## What Ranger Collects

The identity-and-security domain should document:

- Active Directory or workgroup identity posture
- local identity with Azure Key Vault signals when that variant is present
- cluster identity and Arc-related identity context
- certificates, TLS posture, and secret-backup dependencies
- BitLocker, secured-core, WDAC, Defender, and audit-policy posture
- local-administrator and drift-control signals
- Azure RBAC or policy context that directly affects the Azure Local deployment

## Manifest Sub-Domains

The v1 collector writes to these named sections of the `identitySecurity` manifest domain:

| Sub-domain | Content |
|---|---|
| `activeDirectory` | Domain name, forest, domain-functional level, OU placement, CNO/VCO context, and AD health signals |
| `certificates` | Certificate inventory, expiry posture, TLS bindings, and secret-backup dependency signals |
| `keyVault` | Key Vault name, secret-backup extension state, required role assignments, and managed identity binding for local-identity deployments |
| `bitLocker` | Volume encryption state, recovery key backup posture, and compliance signal |
| `defender` | Defender AV status, real-time protection, signature currency, and exclusion posture |
| `auditPolicy` | Relevant audit categories enabled or disabled at the host level |

In AD-backed deployments the `activeDirectory` section is populated from the domain collector.
In local-identity deployments where no AD is present, `activeDirectory` records a `not-applicable` reason and the `keyVault` section carries the primary secret and trust signals.

## Why It Matters

Security and trust posture are part of both operational understanding and handoff-quality documentation. This domain should explain not only what is enabled, but also what identity model the environment actually relies on.

## Connectivity and Credentials

| Requirement | Purpose |
|---|---|
| WinRM / PowerShell remoting | Host security, certificate, and local-policy discovery |
| Cluster credential | Required for host-side collection |
| Domain credential | Required when AD-specific discovery is in scope |
| Azure credential | Required for Azure RBAC, policy, Key Vault, and Arc-side relationships |

## Default Behavior

Run this domain when cluster credentials are available.

AD-specific subcollection should become `skipped` or `not-applicable` in local-identity deployments instead of being reported as missing or broken.

## Variant Behavior

### AD-Backed

Ranger should document domain membership, OU placement, CNO or VCO context where relevant, and other directory-backed trust signals.

### Local Identity with Azure Key Vault

Ranger should document:

- `ADAware` posture
- workgroup status
- Key Vault secret-backup extension state
- required Key Vault role assignments
- local-identity tool compatibility boundaries

### Disconnected Operations

Ranger should distinguish Azure public-cloud RBAC and policy from local disconnected control-plane policy and access surfaces.

### Multi-Rack Preview

Security posture still matters, but the environment may rely more heavily on preview-specific Azure-managed infrastructure layers that should be documented clearly.

## Evidence Boundaries

- **Direct discovery:** host security and identity posture from the nodes
- **Azure-side discovery:** RBAC, policy, Key Vault, and Arc-related governance context
- **Manual/imported evidence:** operator-supplied trust-boundary notes or governance overlays when needed

## v1 and Future Boundaries

v1 should focus on host and deployment-level identity and security posture.

It should not imply a full enterprise IAM review or deep in-guest workload security assessment for every hosted workload type.