# Project Status

> Updated: 2026-07-10

## Current state

| Area | State | Notes |
|---|---|---|
| Repository | initialized | Documentation-first bootstrap |
| Product scope | documented | Digest-first, table-first, fixture-scoped |
| Adapter architecture | draft baseline | Hybrid S3 bridge + deterministic registry |
| Runtime API | draft baseline | No executable implementation yet |
| R package skeleton | not started | Planned for Phase 1 |
| Vendored CAP resources | not started | Planned after package skeleton |
| Tests and CI | planned | No conformance claim yet |
| Release | not applicable | No package release exists |

## Claims

capR currently makes **no CAP conformance claim**.

Any future claim must identify the capR version, CAP-Digest version, conformance level, fixture revision, supported source family, unsupported features, and report locations.

## Active decisions

- [ADR-0001: Digest-first and table-first](docs/decisions/ADR-0001-digest-first-table-first.md)
- [ADR-0002: Hybrid adapter resolution](docs/decisions/ADR-0002-hybrid-adapter-resolution.md)
- [ADR-0003: Canonical artifacts and sidecars](docs/decisions/ADR-0003-canonical-artifacts-and-sidecars.md)
- [ADR-0004: Strict schema validation in CI](docs/decisions/ADR-0004-schema-validation-in-ci.md)

## Immediate next work

1. Review and accept the documentation baseline.
2. Choose the package license and minimum supported R version.
3. Add the standard R package skeleton.
4. Vendor the published CAP-Digest v1.0 resources with provenance.
5. Implement the adapter contract and contract tests before table rendering.
