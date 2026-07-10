# Security Model

## Threats

capR accounts for digest-tag injection, sensitive names and values, side-effectful methods, lazy/remote objects, unbounded traversal, registry poisoning, direct model execution requests, stale sources, and adapter drift.

## Trust and execution

Trust class describes content/instruction risk. Execution class describes operational risk. Host policy evaluates both.

## Guarded pipeline

```text
resolve adapter
-> validate catalog
-> authorize candidate
-> guarded extract
-> redact
-> deterministic render
-> escape
-> record manifest outcome
```

A field error normally becomes an explicit failed field and caveat rather than an unexplained empty digest.

## Default deny

The first stable policy denies remote queries, credential access, unsafe/unknown execution, unreviewed executable pack metadata, fallback semantic claims, and model-direct extractor calls.

## Follow-up checks

The gate checks field existence/requestability, selection state, fingerprint, budget, execution class, privacy policy, pinned adapter compatibility, and required confirmation.

## Security tests

Tests cover injection escaping, sensitive-name masking, renderer failure, unresolved bindings, registry ambiguity, stale fingerprint, and fallback mislabeling.
