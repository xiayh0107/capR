# ADR-0002: Hybrid adapter resolution

- Status: accepted
- Date: 2026-07-10

## Context

S3 is idiomatic in R, but one digest method per class does not solve open-ended object growth. Registry-only design is explicit but less natural for R package authors.

## Decision

Use `cap_adapter()` as one lightweight S3 bridge, a host-controlled dynamic registry, explicit adapter injection as the highest-priority path, deterministic fail-closed resolution, and one pinned adapter across the lifecycle. `cap_digest()` remains an orchestration function rather than the primary S3 generic.

## Consequences

- Third parties can add adapters without changing capR.
- R packages may use familiar S3 integration.
- Resolution and provenance are inspectable.
- The implementation must maintain robust ambiguity and version checks.

## Rejected alternatives

Hard-coded class branches; many parallel S3 generics; silent last-registration-wins; registry-only public integration.

## Review trigger

Evidence that the hybrid model cannot support package loading, reproducibility, or adapter versioning safely.
