# Azure Integration

This discovery domain explains the Azure-side footprint of the Azure Local deployment.

## Scope

It should capture:

- Arc registration and resource identity
- subscription, resource group, region, and custom location context
- resource bridge and extensions
- Azure Monitor, Log Analytics, Update Manager, Backup, ASR, and Policy relationships
- Azure-connected services such as AKS hybrid, AVD, Arc VMs, and Arc Data Services where present

## Why It Matters

This is the key domain that keeps Ranger from becoming a local-only inventory tool. Azure-side deployment resources are part of Ranger's boundary.