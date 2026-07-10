.capr_maturities <- c("stable", "community", "experimental", "fallback")
.capr_semantic_levels <- c("structural", "table", "domain")
.capr_binding_kinds <- c("extractors", "redactors", "renderers")

capr_validate_bindings <- function(bindings) {
  if (!is.list(bindings) || is.null(names(bindings))) {
    capr_abort("capr_adapter_invalid", "`bindings` must be a named list", field = "bindings")
  }
  unknown <- setdiff(names(bindings), .capr_binding_kinds)
  if (length(unknown)) {
    capr_abort(
      "capr_adapter_invalid",
      "adapter contains unsupported binding kinds",
      binding_kinds = unknown
    )
  }
  out <- stats::setNames(vector("list", length(.capr_binding_kinds)), .capr_binding_kinds)
  for (kind in .capr_binding_kinds) {
    values <- bindings[[kind]] %||% list()
    if (!is.list(values) ||
        (length(values) &&
         (is.null(names(values)) || any(!nzchar(names(values)))))) {
      capr_abort(
        "capr_adapter_invalid",
        sprintf("`bindings$%s` must be a named list", kind),
        binding_kind = kind
      )
    }
    if (anyDuplicated(names(values))) {
      capr_abort(
        "capr_adapter_invalid",
        "binding names must be unique",
        binding_kind = kind
      )
    }
    if (length(values) && !all(vapply(values, is.function, logical(1)))) {
      capr_abort(
        "capr_adapter_invalid",
        "runtime bindings must be functions",
        binding_kind = kind
      )
    }
    out[[kind]] <- values[capr_stable_order(names(values))]
  }
  out
}

#' Construct an adapter
#'
#' An adapter carries serializable identity metadata and process-local runtime
#' functions. It never implements digest orchestration.
#'
#' @param id,version,provider,provider_version Adapter identity fields.
#' @param source_family CAP-Digest source family.
#' @param maturity One of `stable`, `community`,
#'   `experimental`, or `fallback`.
#' @param semantic_level One of `structural`, `table`, or
#'   `domain`.
#' @param conformance_claim A precise claim string, defaulting to `none`.
#' @param capabilities Named descriptive capabilities.
#' @param source_ref,field_catalog,fingerprint Lifecycle functions.
#' @param bindings Named `extractors`, `redactors`, and
#'   `renderers` maps.
#' @return A validated `capr_adapter` object.
#' @export
cap_new_adapter <- function(id, version, provider, provider_version, source_family,
                            maturity, semantic_level, conformance_claim = "none",
                            capabilities = list(), source_ref, field_catalog,
                            fingerprint, bindings) {
  if (!is.character(maturity) || length(maturity) != 1L ||
      is.na(maturity) || !maturity %in% .capr_maturities) {
    capr_abort(
      "capr_adapter_invalid",
      "unsupported adapter maturity",
      field = "maturity",
      value = maturity,
      allowed = .capr_maturities
    )
  }
  if (!is.character(semantic_level) || length(semantic_level) != 1L ||
      is.na(semantic_level) || !semantic_level %in% .capr_semantic_levels) {
    capr_abort(
      "capr_adapter_invalid",
      "unsupported semantic level",
      field = "semantic_level",
      value = semantic_level,
      allowed = .capr_semantic_levels
    )
  }
  metadata <- list(
    schema = "capr.adapter.v1",
    id = capr_assert_scalar_character(id, "id"),
    version = capr_semver(version, "version"),
    provider = capr_assert_scalar_character(provider, "provider"),
    provider_version = capr_semver(provider_version, "provider_version"),
    source_family = capr_assert_scalar_character(source_family, "source_family"),
    maturity = maturity,
    semantic_level = semantic_level,
    conformance_claim = capr_assert_scalar_character(
      conformance_claim, "conformance_claim"
    ),
    capabilities = capabilities
  )
  if (!grepl("^[a-z0-9][a-z0-9._-]*$", metadata$id)) {
    capr_abort(
      "capr_adapter_invalid",
      "adapter `id` has invalid syntax",
      field = "id",
      value = metadata$id
    )
  }
  if (!grepl("^[a-z][a-z0-9_-]*$", metadata$source_family)) {
    capr_abort(
      "capr_adapter_invalid",
      "`source_family` has invalid syntax",
      field = "source_family"
    )
  }
  if (!is.list(capabilities) ||
      (length(capabilities) &&
       (is.null(names(capabilities)) || any(!nzchar(names(capabilities)))))) {
    capr_abort(
      "capr_adapter_invalid",
      "`capabilities` must be a named list",
      field = "capabilities"
    )
  }
  lifecycle <- list(
    source_ref = source_ref,
    field_catalog = field_catalog,
    fingerprint = fingerprint
  )
  if (!all(vapply(lifecycle, is.function, logical(1)))) {
    capr_abort(
      "capr_adapter_invalid",
      "adapter lifecycle entries must be functions",
      field = "lifecycle"
    )
  }
  adapter <- structure(
    list(
      metadata = metadata,
      lifecycle = lifecycle,
      bindings = capr_validate_bindings(bindings)
    ),
    class = "capr_adapter"
  )
  cap_validate_adapter(adapter)
  adapter
}

#' Validate an adapter
#' @param adapter An adapter object.
#' @return The adapter, invisibly.
#' @export
cap_validate_adapter <- function(adapter) {
  if (!inherits(adapter, "capr_adapter") || !is.list(adapter) ||
      !all(c("metadata", "lifecycle", "bindings") %in% names(adapter))) {
    capr_abort("capr_adapter_invalid", "object is not a complete capr adapter")
  }
  required <- c(
    "schema", "id", "version", "provider", "provider_version",
    "source_family", "maturity", "semantic_level", "conformance_claim",
    "capabilities"
  )
  missing <- setdiff(required, names(adapter$metadata))
  if (length(missing)) {
    capr_abort(
      "capr_adapter_invalid",
      "adapter metadata is incomplete",
      missing = missing
    )
  }
  if (!identical(adapter$metadata$schema, "capr.adapter.v1")) {
    capr_abort(
      "capr_adapter_invalid",
      "unsupported adapter schema",
      schema = adapter$metadata$schema
    )
  }
  lifecycle <- adapter$lifecycle[c("source_ref", "field_catalog", "fingerprint")]
  if (length(lifecycle) != 3L ||
      !all(vapply(lifecycle, is.function, logical(1)))) {
    capr_abort(
      "capr_adapter_invalid",
      "adapter lifecycle functions are invalid"
    )
  }
  capr_validate_bindings(adapter$bindings)
  invisible(adapter)
}

#' Resolve an adapter through S3
#' @param x An R object.
#' @param ... Reserved for bridge methods.
#' @return An adapter or `NULL`. Methods must not run digest orchestration.
#' @export
cap_adapter <- function(x, ...) UseMethod("cap_adapter")

#' @export
cap_adapter.default <- function(x, ...) NULL

#' @export
print.capr_adapter <- function(x, ...) {
  m <- x$metadata
  cat(sprintf("<capr_adapter %s@%s>\n", m$id, m$version))
  cat(sprintf("  provider: %s@%s\n", m$provider, m$provider_version))
  cat(sprintf(
    "  source: %s; maturity: %s; semantics: %s\n",
    m$source_family, m$maturity, m$semantic_level
  ))
  cat(sprintf("  conformance: %s\n", m$conformance_claim))
  invisible(x)
}

capr_adapter_metadata <- function(adapter) {
  cap_validate_adapter(adapter)
  adapter$metadata
}

capr_binding_signature <- function(adapter) {
  cap_validate_adapter(adapter)
  signatures <- lapply(adapter$bindings, function(kind) {
    lapply(kind, function(binding) {
      list(
        formals = paste(deparse(formals(binding), width.cutoff = 500L), collapse = "\n"),
        body = paste(deparse(body(binding), width.cutoff = 500L), collapse = "\n")
      )
    })
  })
  capr_sha256(capr_canonical_json(signatures))
}

capr_adapter_binding <- function(adapter, kind, contract) {
  cap_validate_adapter(adapter)
  kind <- match.arg(kind, .capr_binding_kinds)
  contract <- capr_assert_scalar_character(contract, "contract")
  binding <- adapter$bindings[[kind]][[contract]]
  if (is.null(binding) || !is.function(binding)) {
    capr_abort(
      "capr_contract_unbound",
      sprintf("contract `%s` has no approved %s binding", contract, kind),
      adapter_id = adapter$metadata$id,
      binding_kind = kind,
      contract = contract
    )
  }
  binding
}
