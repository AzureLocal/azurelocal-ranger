# MAPROOM

This directory contains the offline synthetic and post-discovery testing solution for AzureLocalRanger.

## Contents

- `Fixtures/` — fixture data used by offline and simulation tests
- `unit/` — Pester unit tests
- `integration/` — fixture-backed integration tests
- `scripts/` — synthetic manifest generator and manual render-validation runner
- `docs/` — detailed MAPROOM documentation

## Scope

Everything under `tests/maproom/` is part of offline testing.
It exists so report generation, cached-manifest behavior, and other post-discovery features can be tested without requiring a live discovery run.
