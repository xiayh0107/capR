# Research Synthesis: capR Build Plan

## Problem

The original planning correctly identified SourceRef, FieldCatalog, budgeted assembly, redaction-before-render, evidence validation, follow-up, and fixture conformance. Its main weakness was an extension model that could still grow as a family of class-specific digest methods.

## Revised conclusion

The core package should know adapters, not every object class.

```text
arbitrary R object
-> one adapter resolution point
-> SourceRef + FieldCatalog + runtime bindings
-> fixed CAP-Digest pipeline
```

S3 remains useful as a bridge, while a deterministic registry supports external packages and local applications.

## Product sequence

1. Freeze documentation and ADRs.
2. Bootstrap an empty valid R package.
3. Implement adapter resolution and contract tests.
4. Vendor CAP-Digest v1.0.
5. Implement one table-family vertical slice.
6. Add validation, gate, patch, and pack hosting.
7. Produce conformance and independent interoperability evidence.
8. Release on GitHub before considering CRAN.

## Why one repository

The same repository contains package source, versioned upstream resources, implementation handbook, architecture decisions, tests, and release evidence. Public behavior, code, and evidence therefore evolve in one review stream.

## Primary risks

Drifting to one method per class; mixing local metadata into canonical artifacts; ambiguous registry behavior; fallback mistaken for semantic support; schema/text drift; R global-state pollution; broadening claims without fixtures; and documentation lagging behind implementation.
