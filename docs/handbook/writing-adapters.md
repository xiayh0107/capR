# Writing a Source Adapter

## 1. Choose a source family

Do not create a source family from a class name alone. Reuse an existing family when field semantics and evidence meaning are shared.

```text
data.frame ─┐
tbl_df     ─┼─> table
data.table ─┘
```

## 2. Define identity

```text
id: org.example.analysis_result
version: 1.0.0
maturity: community
semantic_level: domain
conformance_claim: none
```

## 3. Define SourceRef and fingerprint

The source reference is cheap and bounded. Document the fingerprint strategy or explicitly mark the source unfingerprintable.

## 4. Define the catalog

Each field requires a valid ID, timing, trust, execution class, levels, cost, and symbolic contracts. Example: `f1:analysis_result@org_example_overview#base`.

Avoid generic third-party field names such as `summary`, `results`, or `metadata`.

## 5. Bind local functions

Keep executable functions out of serialized metadata. Bind symbolic names inside the adapter.

## 6. Declare safety

Document possible I/O, code execution, traversal limits, sensitive data, remote/credential requirements, and follow-up behavior.

## 7. Test

Pass contract tests for resolution, catalog validity, binding completeness, redaction order, deterministic rendering, error capture, and pinning. Adapter tests do not create a CAP conformance claim.

## Packaging options

Adapters may live in capR for the built-in table family, the object-owning package, a separate extension package, or an application-local module.
