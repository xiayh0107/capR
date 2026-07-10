# CAPP-0009: CAP-Digest v1.0.0 Stable Release

> Status: accepted - Created: 2026-07-07 - Layer: CAP-Digest

## Abstract

This CAPP accepts publication of CAP-Digest v1.0.0 stable with release artifact
`release-artifacts/cap-digest-v1.0.0/` and tag plan `cap-digest-v1.0.0`.

## Motivation

Issues #93-#118 completed the stable-entry, specification freeze, fixture,
schema, reference, interoperability, release-candidate, maintenance, and
adoption gates for the fixture-scoped CAP-Digest v1.0.0 release.

## Specification

Publish CAP-Digest v1.0.0 for the stable surface frozen by:

- `specs/digest/STABLE-SCOPE-v1.0.md`;
- `specs/digest/TEXT-GRAMMAR-v1.0.md`;
- `specs/digest/MANIFEST-EVIDENCE-v1.0.md`;
- `specs/digest/FOLLOWUP-GATE-v1.0.md`;
- `specs/digest/SCHEMA-PACKAGE-v1.0.md`;
- `specs/digest/FIXTURES-v1.0.md`;
- `specs/digest/PACK-COMPATIBILITY-v1.0.md`;
- `specs/digest/CONFORMANCE-v1.0.md`;
- `specs/digest/SECURITY-v1.0.md`;
- `specs/digest/VALIDATOR-CODES-v1.0.md`;
- `specs/digest/REFERENCE-BEHAVIOR-v1.0.md`;
- `specs/digest/RELEASE-GATES-v1.0.md`;
- `specs/digest/INTEROPERABILITY-v1.0.md`;
- `specs/digest/MAINTENANCE-v1.0.md`.

The release includes CAP-Digest schemas, fixtures, the `table-basic` Digest
Pack, conformance and interoperability reports, CAPP records, review records,
release notes, and package manifests.

## Rationale

The stable claim is intentionally narrow: one fixture-backed source family,
stable digest text and manifest semantics, stable follow-up gates, stable pack
metadata rules, and executable conformance checks.

## Compatibility

Compatibility is governed by `SCHEMA-PACKAGE-v1.0.md`,
`CONFORMANCE-v1.0.md`, and `MAINTENANCE-v1.0.md`. v1.0.x updates may clarify
or correct without changing required fields, field-id grammar, digest text
grammar, fixture expected outputs, or validator finding meanings.

## Security and Privacy

Security requirements are defined in `SECURITY-v1.0.md`. v1.0 requires
redaction before rendering, escaped data fences, guarded follow-up extraction,
budget and fingerprint gates, no silent field omission, and no credentialed or
remote extraction by default.

## Reference Implementation

The Python reference implementation emits the v1.0 conformance report and
generates release packages. It remains an executable companion, not the only
valid implementation.

## Conformance Fixtures

Stable fixtures are indexed by `FIXTURES-v1.0.md` and packaged under
`release-artifacts/cap-digest-v1.0.0/`.

## CAP-Core Impact

CAP-Core behavior is unchanged. CAP-Digest v1.0.0 does not define runtime
execution, policy language semantics, credential exchange, or CAP-Core object
semantics.

## Release Plan

- RC artifact: `release-artifacts/cap-digest-v1.0.0-rc1/`
- Stable artifact: `release-artifacts/cap-digest-v1.0.0/`
- Tag plan: `cap-digest-v1.0.0`
- Correction path: `specs/digest/MAINTENANCE-v1.0.md`
