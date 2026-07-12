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

Generated adapters whose lifecycle closures capture probe or family settings
should pass a JSON-safe `implementation_spec` to `cap_new_adapter()`. The spec,
lifecycle functions, and runtime bindings all participate in registry conflict
checks and adapter pins.

## Experimental bundled adapters

`cap_grouped_table_adapter()` and `cap_ggplot_adapter()` are public opt-in
constructors, but their semantic fields remain experimental. They use
`maturity = "experimental"` and `conformance_claim = "none"`.

- The grouped-table adapter augments inherited table fields with bounded
  grouping mode, variable names, and group count. Pass it explicitly for a
  `grouped_df` or `rowwise_df`; the default inherited `tbl_df` bridge keeps
  ordinary table semantics and omits grouping.
- The ggplot adapter describes bounded, unevaluated plot declarations and data
  schema. Pass it explicitly or register it for class `ggplot`; it does not
  build, compute, or render a plot.

Ten additional public constructors expose bounded, metadata-only descriptors
for complex object families:

```text
cap_nested_adapter()      cap_array_adapter()
cap_relational_adapter()  cap_temporal_adapter()
cap_spatial_adapter()     cap_graph_adapter()
cap_scientific_adapter()  cap_model_adapter()
cap_visual_adapter()      cap_live_adapter()
```

`cap_db_schema()` is the companion constructor for validated, in-memory table,
column-type, primary-key, and foreign-key declarations consumed by
`cap_relational_adapter()`; it never opens a DBI connection.

All ten require explicit semantic opt-in through `adapter =` or a deliberate
registry entry, use three fields named
`overview`, `structure`, and `semantics`, and have
`maturity = "experimental"` plus `conformance_claim = "none"`. They describe
bounded classes, dimensions, schemas, components, slots, or relationships
without emitting payload values or executing object behavior. In particular,
delayed arrays are not materialized, and lazy/live sources are never queried or
collected. Environment, R6, and Arrow frames are not enumerated. The complete
class matrix and per-family non-execution boundary are
documented in [Experimental complex-object families](../adapters/complex-object-families.md).

Experimental field catalogs and rendered wording may evolve in a later minor
release. They do not change the compatibility promise for stable table fields
or the adapter object/registry contract.

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
The grouping-aware adapter and all experimental `nested`, `array`,
`relational`, `temporal`, `spatial`, `graph`, `scientific`, `model`, `plot`,
and `external` descriptors are outside that claim.
