# Project Charter

## Mission

Build a trustworthy R-hosted CAP-Digest implementation whose behavior is bounded, testable, traceable, and extensible without requiring the core package to know every possible R object class.

## Product statement

capR converts supported R sources into model-readable CAP digest text, machine-readable DigestManifest evidence, validation results, gated follow-up decisions, typed digest patches, and conformance evidence. It does not provide an LLM provider SDK.

## Initial stable scope

The first stable target follows the published CAP-Digest v1.0 table fixture surface: `text=v1`, `fields=f1`, table fields covered by fixtures, selected/rejected/failed manifest rows, evidence validation, follow-up gate and typed patch, `table-basic` metadata hosting, and L0-L3 evidence.

## Non-goals

- all R objects as stable sources;
- arbitrary remote queries;
- credential exchange;
- scientific correctness;
- runtime policy language semantics;
- CAP-Core object semantics;
- model tool execution.

## Design invariants

1. One adapter is resolved once per digest lifecycle.
2. The core pipeline is class-independent after resolution.
3. Host classes and CAP source families are different concepts.
4. Serialized field metadata contains symbolic contracts, not executable code.
5. Registry ambiguity fails closed.
6. Redaction precedes rendering.
7. Rejected and failed fields remain observable.
8. Follow-up uses the same compatible adapter and source fingerprint.
9. Fallback is structural-only and makes no conformance claim.
10. Claims name an exact version, level, fixture suite, and source scope.

## Success criteria

capR succeeds when an independent reviewer can reproduce its table-family artifacts and verify the public conformance claim without relying on hidden process state or undocumented object methods.
