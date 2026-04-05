# Cluster and Node

This discovery domain defines the base identity and operational state of an Azure Local deployment.

## Scope

It should capture:

- cluster identity and domain context
- node inventory and node state
- cluster version and release information
- quorum and witness design
- fault domains
- cluster networks and CSV summary
- functional level and upgrade state
- update posture and recent update history
- recent critical and error event summary
- registration and Azure-connected platform state

## Why It Matters

This is the foundation for the rest of the estate model. Almost every other discovery area depends on accurate cluster and node identity.