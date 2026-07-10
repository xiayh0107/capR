# ADR-0003: Canonical artifacts and implementation sidecars

- Status: accepted
- Date: 2026-07-10

## Context

capR needs adapter and registry provenance that may not belong in frozen CAP schemas. Mixing local metadata into canonical artifacts can break validation and interoperability.

## Decision

Keep canonical CAP artifacts unchanged. Store capR-specific resolution, registry, run, and diagnostic metadata in clearly named sidecars unless an upstream schema explicitly allows an extension property.

## Consequences

- Canonical artifacts remain independently comparable.
- Adapter provenance remains available for follow-up and debugging.
- Readers must understand canonical versus local files.
- Sidecars cannot be the sole evidence for conformance.

## Rejected alternative

Add arbitrary capR fields directly to every canonical JSON object.

## Review trigger

An upstream CAP schema introduces a stable implementation-provenance extension point.
