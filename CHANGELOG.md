# Changelog

## 1.1.0 - Unreleased

### Documentation

- Added an executable Chinese quickstart vignette covering the complete
  digest, response validation, gated follow-up, patch, artifact I/O, fixture,
  and CLI workflow.
- Added an executable advanced Chinese vignette using a mixed-type,
  multi-center sequencing QC table to demonstrate two-round evidence
  disclosure, redaction, escaping, gated sampling, and artifact round-trips.
- Added an executable cross-object vignette showing the stable plain-tibble
  path, explicit grouped-table semantics, fail-closed ggplot resolution, and
  the bounded declarative plot adapter.
- Added a systematic Chinese complex-object vignette covering the research
  taxonomy, why each family exists, official-source map, selection guide,
  hard limits, executable metadata-only examples, and non-inference rules.
- Added a class matrix and safety guide for ten public complex-object descriptor
  families, including delayed/materialization and lazy/live query boundaries.

### Experimental adapters

- Added public, opt-in adapters for grouped and rowwise tibbles and for bounded
  ggplot specifications. Both are experimental and have
  `conformance_claim = "none"`.
- Added public, explicit descriptor constructors for nested, array, relational,
  temporal, spatial, graph, scientific, model, visual, and lazy/live objects.
  All expose bounded metadata only and have `conformance_claim = "none"`.
- Added `cap_db_schema()` for validated table/type/primary-key/foreign-key
  declarations that can be digested without DBI or database access.

### Runtime

- Canonical manifest `elapsedMs` values are normalized to zero for every
  source family so scheduler timing cannot make otherwise identical artifacts
  differ; measured time remains available in process-local materialization
  outcomes.
- Generated-adapter pins now cover lifecycle functions and an explicit
  implementation spec; descriptor snapshots are normalized once per digest,
  and the adapter contract suite probes every locally authorized field.
- Structural fallback now strips ordinary S3 classes before introspection and
  rejects S4, delayed, declarative-execution, and live/external hosts instead
  of invoking their methods.
- Complex descriptors strip classed metadata before indexing, cap container,
  rank, component, and XML traversal, keep environment/R6 frames opaque,
  and pin snapshot/helper implementations in adapter signatures.
- Declared database schemas now revalidate canonical structure and a
  deterministic consistency seal at Digest time; malformed class spoofs,
  post-construction mutation, and non-semantic key-vector names fail closed or
  are excluded before artifact rendering.

### Scope

- The published stable claim remains limited to the CAP-Digest v1.0 table
  fixtures and the documented local `data.frame`, `tbl_df`, and `data.table`
  hosts; the new experimental adapters do not inherit that claim.
- The ggplot adapter inspects bounded declarations and data schema only. It
  does not build plots, execute statistics or mappings, inspect pixels, or
  establish scientific or visual correctness.
- Complex-object descriptors do not disclose payload values or execute object
  behavior. Delayed/file-backed arrays are not materialized, and live/lazy
  objects are not queried, collected, opened, or dereferenced.
- No canonical schema, CLI, fixture, or stable conformance claim changes.

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
