# Adapter Registry and Resolution

## Resolution order

```text
1. explicit adapter object or adapter ID
2. cap_adapter(x) S3 bridge
3. registry exact-class match
4. registry inherited-class match
5. generic structural fallback, when policy enables it
6. adapter-not-found error
```

The adapter is resolved once and reused through digest, validation context, follow-up gate, and patch materialization.

## Registry entry

A registry entry records matched class, adapter factory, adapter ID/version, provider package/version, source family, priority, registration origin, and capabilities.

## Conflict rules

1. Host-class order is the primary specificity rule.
2. Explicit priority is secondary.
3. Different adapters with equal effective specificity and priority are ambiguous.
4. Ambiguity raises an error.
5. Identical registration is idempotent only when identity, version, provider, and bindings agree.
6. Silent last-writer-wins is forbidden.
7. Resolution diagnostics include selected and rejected candidates.

## Registration

Third-party packages may register adapters from `.onLoad()`, but registration is not authorization. Host policy still controls whether adapter code may run.

```r
cap_register_adapter(
  class = "analysis_result",
  adapter_factory = analysis_result_adapter,
  priority = 0L
)
```

## Pinning

Session pins are stored on in-memory digest objects. Optional project pins are stored in `.cap/registry/registry.lock.json`. The lock contains metadata and decisions, not executable closures.

## Fallback

Fallback is last before error, may be disabled, and is marked `maturity=fallback`, `semantic_level=structural`, and `conformance_claim=none`.
