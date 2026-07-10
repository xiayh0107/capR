# Testing and Conformance

## Test layers

| Layer | Purpose |
|---|---|
| Unit | Function behavior and edge cases |
| Adapter contract | Resolution, metadata, binding, fallback, and pinning |
| Fixture conformance | Published CAP-Digest expected behavior |
| Negative/security | Invalid text, injection, masking, failure rows, stale source |
| Snapshot | Stable text and JSON formatting |
| Independent interop | Validate artifacts without importing capR internals |

## Adapter contract tests

Minimum checks include deterministic resolution, ambiguity failure, adapter identity/version, SourceRef/catalog agreement, valid unique field IDs, symbolic contracts only, exactly one approved binding, captured warnings/errors/time, redaction before rendering, bounded deterministic output, structural-only fallback, provenance across follow-up, incompatible pin failure, and claim separation.

## CAP fixtures

Published resources are vendored by version under `inst/extdata/cap-digest/`. Tests must not modify expected upstream outputs.

## Schema validation

Strict JSON Schema Draft 2020-12 validation is a CI/release gate. Runtime may perform lighter structural checks to avoid a heavy validator on every user path.

## Reports

The fixture runner names implementation/version, CAP version, level, fixture revision, checks, failures, and environment. An independent harness inspects release artifacts without loading internal capR objects.
