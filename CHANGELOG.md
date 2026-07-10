# Changelog

## 1.0.1 - Unreleased

### Documentation

- Added an executable Chinese quickstart vignette covering the complete
  digest, response validation, gated follow-up, patch, artifact I/O, fixture,
  and CLI workflow.

### Scope

- No public API, schema, CLI, adapter-contract, fixture, or stable conformance
  claim changes.

## 1.0.0 - 2026-07-10

### Added

- Deterministic adapter objects, S3 bridge, registry lifecycle, ambiguity
  failures, provenance pinning, host policy, and bounded structural fallback.
- Stable table-family path for `data.frame`, `tbl_df`, and `data.table`.
- CAP-Digest text=v1 rendering/parsing, canonical manifest and artifact I/O,
  redaction-before-rendering, guarded extraction, and deterministic planning.
- Contract-response validation, pure follow-up gate, typed digest patch
  materialization/application, and fail-closed table-basic Pack hosting.
- Reusable adapter contract suite and offline CAP-Digest v1.0 L0-L3 runner.
- Strict Draft 2020-12 schema harness and independent structural
  interoperability/comparison harness.
- `capr` CLI, user/adapter vignettes, release artifact packager, manifest
  validator, and cross-platform workflows.
- Pinned CAP-Digest `cap-digest-v1.0.0` resources with per-file SHA-256
  provenance.

### Scope

- Conformance is limited to the published v1.0 fixtures and `table` source
  family.
- Remote/credentialed extraction, CAP-Core semantics, arbitrary-object
  conformance, and scientific correctness are not claimed.
