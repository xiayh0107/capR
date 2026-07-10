# ADR-0001: Digest-first, table-first, fixture-scoped

- Status: accepted
- Date: 2026-07-10

## Context

CAP-Digest v1.0 stabilizes a published table fixture surface. It does not require a second source family and does not define a general runtime or scientific correctness.

## Decision

The first stable capR track implements CAP-Digest for the table source family. Non-table adapters remain community or experimental until separate specification and fixture evidence exists.

## Consequences

- Work can be checked against published fixtures.
- Scope remains narrow enough for a credible release.
- Arbitrary object support does not block the stable table path.
- Adoption text must not imply universal R-object conformance.

## Rejected alternative

Build a broad R AI framework before matching the CAP-Digest table surface.

## Review trigger

A published upstream source-family fixture or a formal decision to create a new capR release track.
