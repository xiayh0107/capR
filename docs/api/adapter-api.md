# Adapter and Registry API v1

> Status: stable in capR v1.0. Adapter compatibility remains distinct from CAP
> conformance.

## S3 bridge

```r
cap_adapter <- function(x, ...) UseMethod("cap_adapter")
cap_adapter.default <- function(x, ...) NULL
```

A class method returns one adapter object. It does not reimplement digest orchestration.

## Adapter constructor

```r
cap_new_adapter(
  id,
  version,
  provider,
  provider_version,
  source_family,
  maturity,
  semantic_level,
  conformance_claim = "none",
  capabilities = list(),
  source_ref,
  field_catalog,
  fingerprint,
  bindings
)
```

The constructor validates metadata and binding shapes.

## Registry API

```r
cap_register_adapter(class, adapter_factory, priority = 0L, registry = cap_registry())
cap_unregister_adapter(...)
cap_list_adapters(...)
cap_resolve_adapter(x, adapter = NULL, registry = cap_registry(), allow_fallback = FALSE)
cap_registry_snapshot(...)
cap_registry_restore(...)
```

## Symbolic bindings

```r
contracts = list(
  extractor = "org.example.overview",
  redactor = "capr.default",
  renderer = "org.example.overview.text_v1"
)
```

The adapter provides approved local functions under those names.

## Capabilities

Capabilities describe support, not authorization:

```r
list(followup = TRUE, remote = FALSE, credentials = FALSE, deterministic = TRUE)
```

Host policy may deny a capability even when the adapter declares it.

## Maturity

Allowed implementation maturity labels are `stable`, `community`, `experimental`, and `fallback`. Maturity is separate from CAP conformance.
