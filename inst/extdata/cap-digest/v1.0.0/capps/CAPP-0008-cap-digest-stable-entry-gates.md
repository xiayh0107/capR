# CAPP-0008: CAP-Digest Stable Entry Gates

> Status: implemented - Created: 2026-07-07 - Layer: CAP-Digest

## Abstract

This CAPP defines the entry gates for promoting CAP-Digest from the
`0.1.0-alpha` draft track to the fixture-scoped `cap-digest-v1.0.0` stable
track.

## Motivation

Issue #92 tracks CAP-Digest stable work independently from CAP-Core v1.x
maintenance. Stable entry needs Digest-specific evidence instead of borrowing
CAP-Core release status.

## Specification

CAP-Digest may enter the stable release path only after these gates are met:

- frozen v1.0 scope, non-goals, and terminology;
- frozen digest text `text=v1` grammar and `fields=f1` field-id contract;
- frozen `DigestManifest` and evidence-anchor contract;
- frozen follow-up request, gate, and digest patch behavior;
- frozen schema package and compatibility policy;
- positive, negative, pack, follow-up, and safety fixtures;
- documented second source-type decision;
- table-basic pack compatibility rules;
- v1.0 conformance levels and claim language;
- security, privacy, redaction, and guarded extraction requirements;
- validator findings and conformance report shape;
- parser, renderer, and reference behavior baseline;
- release-gate checks in CI or equivalent repository scripts;
- implementer/adoption guidance;
- interoperability evidence and comparison report;
- rc1 package, RC blocker review, stable CAPP, release artifact, maintenance
  policy, status updates, and post-release adoption plan.

## Rationale

The v1.0 release intentionally stabilizes the current executable Digest loop
before adding remote sources, credentials, or a broader source-type matrix.
Stable means compatibility for the documented v1.0 surface, not completeness of
every possible Digest source.

## Compatibility

The entry gates do not change existing alpha fixture outputs. They freeze the
current schema and fixture behavior as v1.0 unless a later CAPP updates a
versioned component.

## Security and Privacy

Security gates require escaping, sensitive-name masking, failed-field recording,
guarded follow-up extraction, budget enforcement, and no CAP-Core runtime or
credential claims.

## Reference Implementation

The reference evidence is `reference/python/`, `fixtures/`, and
`reference/python/scripts/validate_fixtures.py --scope digest`.

## Conformance Fixtures

The v1.0 fixture suite is indexed by `specs/digest/FIXTURES-v1.0.md` and
packaged in `release-artifacts/cap-digest-v1.0.0/`.
