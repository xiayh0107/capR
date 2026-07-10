# capR Implementation Plan

## Strategy

The package will be built in evidence-producing vertical slices. Each phase adds implementation, documentation, tests, and review artifacts together.

## Phase 0 — Documentation system

Deliver project charter, layout, adapter/registry architecture, API drafts, security model, testing/release handbook, ADRs, and templates. Gate: design review completed.

## Phase 1 — Package skeleton

Deliver a valid R package root, minimum R version and dependency policy, testthat edition 3, condition/utilities, R CMD check, and docs workflows. Gate: empty package checks cleanly on Linux, macOS, and Windows.

## Phase 2 — Adapter runtime

Deliver validated adapter object, S3 bridge, registry, deterministic resolution, pinning metadata, bounded fallback, and contract test kit. Gate: all resolution and failure cases are reproducible.

## Phase 3 — Table MVP

Deliver vendored CAP-Digest resources, data.frame adapter, SourceRef/fingerprint, table catalog, planner, guarded materialization, redaction/escaping, text, and manifest. Gate: basic and safety outputs match expected behavior.

## Phase 4 — Follow-up and L3

Deliver response validation, gate, patch, pack metadata loader, conformance report, and independent structural harness. Gate: full declared fixture suite passes.

## Phase 5 — Release

Deliver adoption/security statements, release artifact/manifests, RC review, stable GitHub release, and feedback window.

## Suggested issue sequence

1. Bootstrap R package skeleton.
2. Define condition classes and deterministic helpers.
3. Vendor CAP-Digest v1.0 resources.
4. Implement adapter object validator.
5. Implement registry and resolution.
6. Implement fallback policy.
7. Publish adapter contract test kit.
8. Implement table SourceRef and fingerprint.
9. Implement table field catalog.
10. Implement planner and rejected candidates.
11. Implement guarded extraction and redaction.
12. Implement text renderer and manifest.
13. Match basic and security fixtures.
14. Implement response validation.
15. Implement gate and patch.
16. Implement pack metadata hosting.
17. Emit conformance and interop reports.
18. Prepare RC release evidence.

A conservative estimate is 24–40 person-weeks depending on staffing and interoperability rigor.
