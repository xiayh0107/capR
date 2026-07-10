# CAPP-0009 Stable Release Decision

> Status: accepted - Date: 2026-07-07 - Issue: #114

CAPP-0009 is accepted. CAP-Digest v1.0.0 stable may be published with release
artifact `release-artifacts/cap-digest-v1.0.0/` and tag plan
`cap-digest-v1.0.0`.

## Accepted Scope

The accepted stable scope is fixture-scoped CAP-Digest behavior for table
sources:

- digest text `text=v1`;
- field ids `fields=f1`;
- `cap.manifest.v1`;
- evidence validation;
- follow-up gates and digest patches;
- `table-basic` Digest Pack metadata;
- v1.0 conformance reports and interoperability comparison reports.

## Exclusions

The stable release does not define remote extraction, credential exchange,
runtime execution, policy language semantics, CAP-Core object semantics, or
scientific correctness.

## Maintenance

v1.0.x maintenance follows `specs/digest/MAINTENANCE-v1.0.md`.
