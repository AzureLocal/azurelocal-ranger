# System Overview

Azure Local Ranger is planned as a PowerShell module and documentation product for understanding Azure Local as a complete connected system.

## Architectural Principles

### Discovery First

The product should discover and normalize information before it attempts to render diagrams or reports.

### Single Audit Model

All discovery domains should feed a central audit model that describes the Azure Local environment as one coherent estate.

### Decoupled Outputs

Reports and diagrams should consume cached audit data rather than depend on live connectivity every time. That supports repeatable documentation and strong as-built generation.

### Graceful Degradation

Collectors should fail independently. Partial visibility is still valuable and should be preserved rather than hidden behind all-or-nothing execution.

### Read-Only Design

Ranger should document and explain environments. It should not change them.

## Planned Logical Flow

1. establish access to the Azure Local deployment and its Azure-side context
2. collect discovery data by domain
3. normalize that data into a central audit manifest
4. record status and partial failures
5. generate outputs from cached audit data
6. support repeatable rerendering of reports and diagrams

## Why This Model Fits Ranger

This model supports both of Ranger's key outcomes:

- current-state environment documentation
- as-built handoff documentation after deployment

Both require trustworthy data, stable output generation, and the ability to rerun outputs without necessarily repeating every live query.
