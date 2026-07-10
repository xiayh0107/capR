# CAP-Digest Implementer and Adoption Guide v1.0

> Status: stable v1.0 - Implementer guidance - Last updated: 2026-07-07

This guide summarizes the stable adoption path for CAP-Digest v1.0.0.

## Start With L0/L1

Implement:

- source reference and fingerprint;
- field catalog;
- deterministic field selection;
- digest text writer;
- `DigestManifest` writer;
- redaction before rendering;
- evidence validation.

Use `fixtures/basic-table/` and `fixtures/security-adversarial/` as the first
compatibility target.

## Add L2 Follow-Up

Only after L0/L1 works, implement contract response validation and the follow-up
gate. Models request fields; implementation code enforces the gate and extracts
approved fields.

## Add L3 Pack Hosting

Load Digest Pack metadata fail-closed. Do not execute pack-provided code as
part of a v1.0 claim.

## Adoption Notes

Adopters should publish:

- claimed CAP-Digest level;
- fixture suite version;
- unsupported features;
- conformance report;
- security notes for redaction and extraction;
- whether the implementation is independent or derived from `reference/python/`.

## Out-of-Scope Integrations

Remote sources, credentials, large-source streaming, and second source-type
fixtures are candidates for post-v1.0 work, not requirements for the v1.0.0
stable claim.
