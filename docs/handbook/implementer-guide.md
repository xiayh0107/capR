# Implementer Guide

## Implemented build order

1. package skeleton and condition classes;
2. adapter object validation;
3. deterministic registry resolution;
4. adapter contract tests;
5. vendored upstream resources;
6. table SourceRef and fingerprint;
7. table field catalog and planner;
8. guarded extraction, redaction, and rendering;
9. manifest and text consistency;
10. response validation;
11. follow-up gate and patch;
12. pack metadata hosting;
13. conformance and interoperability reports;
14. release packaging.

The v1.0 code follows this order. New work must not add object-specific digest
orchestration methods.

## Core loop

```text
R object
-> resolved adapter
-> SourceRef + FieldCatalog + bindings
-> plan
-> guarded materialization
-> digest + manifest
-> validate
-> gate
-> patch
```

## Determinism checklist

For fixed source, policy, budget, question, adapter version, and seed: class resolution, catalog order, field IDs, tie breakers, sampling, formatting, caveat order, and cost accounting are stable.

## Global state

Extraction code must not leave changes to working directory, options, locale, random state, search path, environment variables, or open connections. Higher-risk operations should be isolated when feasible.

## Definition of done

A feature is complete only when architecture/API documentation agrees, unit and contract tests exist, negative behavior is tested, canonical artifacts remain valid, sidecars are optional, security effects are documented, and conformance claims are unchanged or explicitly reviewed.
