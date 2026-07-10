# CAP-Digest v1.0 Second Source-Type Decision

> Status: decided - Date: 2026-07-07 - Issue: #101

Decision: CAP-Digest v1.0.0 does not require a second source type.

Rationale: the stable release claim is limited to the fixture-scoped digest
loop and the cross-cutting contracts exercised by the current suite: text
grammar, field anchors, manifest rows, evidence validation, follow-up gates,
digest patches, pack metadata, and safety behavior.

Consequences:

- v1.0.0 may proceed without a second source-type implementation issue;
- release notes must state the source-type limitation;
- future second source-type work should be tracked as post-v1.0 adoption or a
  new CAPP;
- no existing table fixture output changes.
