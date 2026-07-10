# CAP-Digest Stable Track

> Status: v1.0 stable track active - Last updated: 2026-07-07

CAP-Digest v1.0.0 is accepted for the fixture-scoped Digest stable surface.
CAP-Core v1.0.0 does not promote, stabilize, or change CAP-Digest behavior.

## Independent Tracker

Digest stable work is tracked separately from CAP-Core v1.0.x maintenance:

- [#92](https://github.com/xiayh0107/cap-docs/issues/92) - Digest stable track:
  plan CAP-Digest stable independently from Core v1.x.

## Stable Entry Gates

The Digest stable proposal provides Digest-specific evidence:

- CAPP-0008 stable entry gates;
- CAPP-0009 stable release decision;
- frozen Digest scope and non-goals;
- stable digest text grammar and DigestManifest contract;
- positive and negative Digest fixture suite;
- follow-up gate and Digest Pack compatibility rules;
- schema package and compatibility policy;
- security, privacy, redaction, and guarded extraction review;
- independent implementation or interoperability evidence for Digest behavior;
- release artifact, tag plan, release notes, and CI gates.

## Non-Goals

Digest stable planning must not:

- use CAP-Core v1.0.0 stability as Digest stable evidence;
- bundle Digest promotion into Core v1.0.x errata or patch releases;
- change Core v1.0.0 object semantics;
- claim runtime execution, policy language, credential exchange, or scientific
  correctness guarantees.

## Current Disposition

CAP-Digest v1.0.0 stable is accepted by CAPP-0009. The release artifact is
`release-artifacts/cap-digest-v1.0.0/` and the repository tag plan is
`cap-digest-v1.0.0`.

The stable claim remains fixture-scoped. It does not require a second source
type and does not define remote extraction, credential exchange, runtime
execution, policy language semantics, CAP-Core object semantics, or scientific
correctness.
