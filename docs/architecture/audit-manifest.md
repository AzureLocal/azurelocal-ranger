# Audit Manifest

The audit manifest is the central data model for Azure Local Ranger.

It is the object that should unify all discovery domains into one representation of the Azure Local environment.

## Why The Manifest Matters

Ranger is supposed to support both recurring documentation and as-built documentation. That only works if the product has one stable internal representation of the environment.

Without that, the project risks becoming a collection of unrelated collectors and report generators.

## What The Manifest Should Do

The manifest should:

- hold the complete discovered state of the Azure Local deployment
- record partial success and collector failure status
- preserve relationships between local and Azure-side components
- support report generation from cached data
- support diagram generation from cached data
- support rerendering of outputs without requiring a live environment connection

## Planned Sections

At a high level, the manifest should include:

- run metadata
- environment identity
- collector execution status
- discovery-domain payloads
- findings and warnings
- output metadata

## Metadata Section

This should identify the audit itself.

Examples include:

- tool version
- schema version
- collection timestamp
- operator context if appropriate
- target cluster name
- target Azure subscription and resource group context where applicable

## Collector Status Section

Each discovery domain should report its execution result independently.

That should allow values such as:

- success
- partial
- failed
- skipped
- not-applicable

This is important because Ranger should tolerate incomplete visibility without losing the rest of the environment model.

## Discovery Payload Sections

The manifest should reserve clear top-level sections for domains such as:

- cluster and node
- hardware
- storage
- networking
- virtual machines
- identity and security
- Azure integration
- OEM integration
- management tools
- performance baseline

## Relationship Model

The manifest should preserve cross-domain relationships, such as:

- which workloads run on which nodes
- which CSVs and volumes back which workloads
- which logical or Azure-side resources relate to which local platform components
- which Azure resources represent or extend the deployment

Those relationships are essential for diagrams and as-built documentation.

## Findings Model

The manifest should also support findings derived from discovery.

At minimum, the findings model should be able to express:

- informational observations
- warnings
- critical risks
- recommendations

## Why This Needs To Be Defined Early

The manifest is the backbone of the entire product.

If the manifest is poorly shaped, then:

- reports will become inconsistent
- diagrams will need special-case logic
- cached rerendering will be unreliable
- contributors will invent incompatible patterns across collectors

That is why the manifest should be defined before large amounts of PowerShell implementation are added.