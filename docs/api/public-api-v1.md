# capR v1 Public API and Compatibility

## Stable user API

- Digest: `cap_digest()`, `cap_policy()`, `print.cap_digest()`,
  `summary.cap_digest()`.
- Evidence/follow-up: `cap_validate_response()`, `cap_gate()`,
  `cap_patch()`, `cap_apply_patch()`.
- Artifacts: `cap_write_artifacts()`, `cap_read_artifacts()`,
  `cap_parse_digest_text()`, `cap_validate_manifest_text()`.
- Evidence gates: `cap_run_fixtures()`, `cap_conformance_report()`,
  `cap_vendor_info()`, `cap_verify_vendor()`.
- Pack metadata: `cap_load_pack()`, `cap_validate_pack()`,
  `cap_pack_conformance_report()`.

## Stable adapter API

- Adapter objects: `cap_new_adapter()`, `cap_validate_adapter()`,
  `cap_adapter()`, `cap_table_adapter()`, `cap_structural_adapter()`.
- Registry: `cap_registry()`, `cap_register_adapter()`,
  `cap_unregister_adapter()`, `cap_list_adapters()`,
  `cap_resolve_adapter()`, `cap_registry_snapshot()`,
  `cap_registry_restore()`.
- Lifecycle evidence: `cap_resolution_diagnostics()`,
  `cap_resolution_sidecar()`, `cap_adapter_pin()`,
  `cap_check_adapter_pin()`, `cap_test_adapter()`.
- Policy/validation support: `cap_authorize_execution()`,
  `cap_validate_field_catalog()`.

## Developer utilities

`capr_condition()`, `capr_abort()`, `capr_is()`,
`capr_condition_fields()`, and `capr_canonical_json()` are exported for
extension diagnostics and deterministic tests. They use the
`capr.*` implementation namespace and must not be treated as canonical CAP
finding codes or artifacts.

Planner, materializer, renderer, and manifest-builder helpers are internal.
They cannot be called as a public bypass around adapter resolution, host
policy, response validation, or the follow-up gate.

## Versioned surfaces

- Runtime API: capR v1.
- Adapter metadata: `capr.adapter.v1`.
- Resolution sidecar: `capr.resolution.v1`.
- Adapter pin: `capr.adapter_pin.v1`.
- Policy sidecar: `capr.policy.v1`.
- Canonical artifacts: versions defined by pinned CAP-Digest v1.0.0.

Canonical CAP artifacts never gain capR-only properties in closed schemas.
Sidecars are optional for interpreting evidence anchors.

## Semantic versioning

- Patch releases preserve function names, required arguments, return classes,
  condition metadata, adapter contract, sidecar versions, CLI commands, and
  stable fixture behavior. Compatible optional fields may be added only where
  the relevant schema/API is open.
- Minor releases may add APIs, adapters, and opt-in behavior without broadening
  an existing conformance claim.
- Breaking runtime, adapter, sidecar, condition, CLI, or claim changes require
  a major release or a new explicitly versioned surface.

Deprecations warn for at least one minor release when feasible and include a
migration path. A security or upstream erratum that cannot preserve behavior
is documented explicitly with regenerated evidence.

## Stable claim boundary

API stability does not imply CAP conformance for arbitrary adapters. The v1.0
claim remains the published fixture scope for source family `table` and the
local `data.frame`, `tbl_df`, and `data.table` hosts.
