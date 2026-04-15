# Changelog

The primary changelog for the repository lives at the root in `CHANGELOG.md`, but the main milestones are summarised here for docs readers.

## v1.1.0 Highlights

- intelligent remoting credential selection and authorization preflight for non-domain-joined runners
- Key Vault credential fallback via Azure CLI when Az PowerShell secret resolution is unavailable
- automatic BMC endpoint hydration from sibling `variables.yml`
- collector status semantics aligned so advisory findings do not downgrade successful collection to `partial`
- live v1.1.0 milestone validation closed on `tplabs` with all 6 collectors successful

## Root Changelog

This documentation page exists so the public documentation site can link readers to the project history without duplicating version notes across two places.
