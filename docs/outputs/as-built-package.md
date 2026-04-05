# As-Built Package

The as-built package is one of the defining product outputs for Azure Local Ranger.

Ranger is not only meant to help teams inspect what they currently have. It is also meant to help delivery teams hand off a newly deployed Azure Local environment in a professional, accurate, and repeatable way.

## Purpose

The as-built package should capture what was delivered in a form that another team or customer can use immediately.

This output should be suitable for:

- customer handoff
- internal project closure
- transfer from implementation to operations
- support onboarding
- governance review

## What It Should Contain

The exact format can evolve, but the package should be planned to include:

- an environment summary
- cluster and node overview
- hardware summary
- storage architecture summary
- network architecture summary
- workload inventory and placement view
- Azure integration summary
- management and security posture summary
- architecture diagrams
- technical deep-dive appendix or linked detail

## What Makes It Different From A Raw Report

An as-built package should not feel like an unfiltered property dump.

It should be:

- accurate
- organized
- readable
- diagram-supported
- suitable for formal delivery

## Why It Is A First-Class Requirement

Azure Local deployments are often built by one team and then handed to another. Ranger should reduce the amount of tribal knowledge lost during that transition.

That means the as-built package is not a secondary feature. It is part of the product identity.

## Design Implications

Planning for the as-built package affects:

- the audit manifest shape
- the report structure
- the diagram model
- how discovery domains preserve relationships and context
- how polished the output needs to be for handoff scenarios