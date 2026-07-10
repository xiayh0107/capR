# Error and Finding Model

## Two namespaces

capR distinguishes implementation conditions for R developers from stable CAP finding or gate codes in canonical artifacts. An implementation condition must not reuse a CAP code with a different meaning.

## Planned capR conditions

```text
capr_adapter_not_found
capr_adapter_ambiguous
capr_adapter_invalid
capr_registry_conflict
capr_duplicate_field_id
capr_contract_unbound
capr_adapter_pin_mismatch
capr_fallback_disallowed
capr_extraction_error
capr_renderer_error
capr_sidecar_invalid
```

Conditions should carry structured metadata in addition to a readable message.

## Canonical findings

Validation and gate artifacts use the exact codes defined by the vendored CAP-Digest version. A versioned mapping table translates internal conditions only when semantics match exactly.

## Failure philosophy

- Adapter ambiguity stops assembly.
- A failed field is recorded in the manifest.
- One failed field does not erase successful fields unless policy requires source-level fail-closed behavior.
- Invalid evidence does not become a supported claim.
- Stale fingerprint or adapter pin prevents follow-up.
- Unknown execution classes are denied.

Debug diagnostics may be written to a capR sidecar while canonical code meanings remain unchanged.
