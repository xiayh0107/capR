# Adoption and Conformance Claims

## Current claim

No executable capR release exists yet. The repository currently provides a development documentation baseline only.

## Future public claim template

```text
Implementation: capR
Implementation version:
CAP version:
Claimed conformance level:
Published fixture suite and revision:
Stable source families covered:
Community adapters:
Experimental adapters:
Fallback behavior:
Unsupported features:
Security and isolation notes:
Implementation provenance:
Conformance report:
Interoperability report:
```

## Claim layering

| Layer | Meaning |
|---|---|
| Artifact validity | JSON and digest text satisfy applicable checks |
| Internal consistency | text, manifest, evidence, rejection state, gate, and patch agree |
| Adapter compatibility | an adapter passes the capR adapter contract test kit |
| CAP conformance | an implementation passes a published CAP fixture suite for an exact scope |

A community adapter may satisfy the first three layers without inheriting the table-family CAP-Digest conformance claim.

## First stable target

The intended first stable claim is limited to the published CAP-Digest v1.0 table fixture surface. Remote extraction, credentials, a second required source family, scientific correctness, CAP-Core runtime semantics, and arbitrary R-object semantic support remain out of scope by default.
