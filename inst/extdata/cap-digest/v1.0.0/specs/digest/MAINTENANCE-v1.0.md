# CAP-Digest Maintenance Policy v1.0

> Status: stable v1.0 - Normative maintenance policy - Last updated: 2026-07-07

CAP-Digest v1.0.x maintenance may clarify, correct, and package errata without
expanding the v1.0.0 stability claim.

## Allowed v1.0.x Changes

- clarify stable text without changing behavior;
- correct plainly wrong fixture expected output with an errata note;
- add negative fixtures for behavior already forbidden;
- add optional schema fields;
- improve diagnostics while preserving stable code meanings;
- update release packaging or manifest validation.

## Requires New CAPP or Version Bump

- digest text grammar changes old v1.0 readers cannot parse;
- changed field-id grammar;
- changed required manifest fields or meanings;
- changed follow-up gate semantics;
- renamed stable field ids;
- second source type added as a stable requirement;
- remote or credentialed extraction added to default conformance.

## Errata Process

Errata should record:

- affected artifact;
- observed problem;
- compatibility impact;
- fixture or schema evidence;
- whether a patch package is required.

If no open errata require a patch, a maintenance pass may explicitly defer a
patch release.
