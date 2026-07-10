# Runtime API Draft

> Status: design draft. Signatures may change before package bootstrap is accepted.

## User-facing orchestration

```r
cap_digest(
  x,
  question = NULL,
  budget = 800L,
  policy = cap_policy(),
  adapter = NULL,
  session = NULL,
  registry = cap_registry(),
  ...
)
```

`cap_digest()` is an orchestration function, not the main S3 generic. It resolves one adapter and runs the class-independent pipeline.

Planned supporting functions:

```r
cap_validate_response(digest, response, policy = cap_policy(), ...)
cap_gate(digest, validation, policy = cap_policy(), source = NULL, ...)
cap_patch(digest, gate_result, source, adapter = NULL, ...)
cap_write_artifacts(x, dir, include_sidecars = TRUE, ...)
cap_read_artifacts(dir, validate = TRUE, ...)
cap_run_fixtures(scope = "digest", report = NULL, ...)
cap_conformance_report(results, ...)
```

## Digest orchestration

```r
adapter <- cap_resolve_adapter(x, adapter, registry)
source <- adapter_source_ref(adapter, x, context)
catalog <- adapter_field_catalog(adapter, x, context)
plan <- cap_select_fields(catalog, budget, question, policy)
results <- cap_materialize(plan, adapter, x, policy)
digest <- cap_build_digest(source, plan, results)
manifest <- cap_build_manifest(source, catalog, plan, results)
```

## Policy draft

```r
cap_policy(
  max_budget = 800L,
  max_followup_budget = 300L,
  allow_exec = c("local_cheap", "local_scan"),
  allow_remote = FALSE,
  allow_credentials = FALSE,
  allow_fallback = FALSE,
  require_fingerprint_match = TRUE,
  allow_followup = TRUE
)
```

Exact defaults will be fixture- and security-reviewed before implementation.

## Return objects

Lightweight R classes mirror canonical artifacts without redefining them: `cap_digest`, `cap_manifest`, `cap_validation_result`, `cap_gate_result`, `cap_digest_patch`, and `cap_conformance_report`. Local adapter provenance is attached as implementation metadata or a sidecar.
