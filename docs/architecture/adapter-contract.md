# Source Adapter Contract

## Purpose

The adapter contract lets capR support open-ended R classes without adding a new core orchestration method for each class.

## Conceptual contract

```text
Adapter
  identity() -> AdapterIdentity
  matches(source, context) -> MatchResult
  source_ref(source, context) -> SourceRef
  field_catalog(source, context) -> FieldCatalog
  fingerprint(source, context) -> FingerprintResult
  bind(kind, symbolic_contract, context) -> RuntimeFunction
  capabilities(context) -> AdapterCapabilities
```

The concrete R representation may be a validated list/S3 object. The responsibilities remain stable even if function names evolve before v1.0.

## Serializable metadata

```r
list(
  schema = "capr.adapter.v1",
  id = "org.example.analysis_result",
  version = "1.0.0",
  provider = "examplePackage",
  provider_version = "0.3.0",
  source_family = "analysis_result",
  maturity = "community",
  semantic_level = "domain",
  conformance_claim = "none",
  capabilities = list(followup = TRUE, remote = FALSE, credentials = FALSE)
)
```

## Runtime bindings

Executable functions remain process-local. Serialized `cap.field.v1` metadata contains symbolic contract names only.

```r
list(
  source_ref = function(x, context) ...,
  field_catalog = function(x, context) ...,
  fingerprint = function(x, context) ...,
  extractors = list("org.example.overview" = function(...) ...),
  redactors = list("capr.default" = function(...) ...),
  renderers = list("org.example.overview.text_v1" = function(...) ...)
)
```

## Field catalog requirements

Every field declares a valid `f1:<source-family>@<field-name>#<variant>` ID, timing, trust class, execution class, levels, estimated cost, and symbolic contracts. Third-party fields qualify the field-name segment, for example `f1:analysis_result@org_example_overview#base`.

## Lifecycle pinning

The resolved adapter identity and provider version are pinned for the digest lifecycle. Follow-up must not silently re-resolve to another adapter or fallback.

## Fail-closed cases

Invalid metadata, duplicate field IDs, unresolved contracts, ambiguous matches, incompatible pins, unsupported execution classes, and fingerprint mismatch fail closed. Adapter diagnostics use capR condition codes and do not overload stable CAP finding codes.
