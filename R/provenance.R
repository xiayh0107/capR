#' Build adapter resolution provenance
#'
#' @param adapter A resolved adapter.
#' @param fingerprint_algorithm Named fingerprint algorithm.
#' @param strategies Optional non-default strategy stamp (planner/tokenizer
#'   ids and versions). Omitted entirely for built-in strategies so default
#'   sidecars stay byte-identical.
#' @return A serializable `resolution.capr.json` sidecar representation.
#' @export
cap_resolution_sidecar <- function(adapter,
                                   fingerprint_algorithm = "unspecified",
                                   strategies = NULL) {
  cap_validate_adapter(adapter)
  fingerprint_algorithm <- capr_assert_scalar_character(
    fingerprint_algorithm,
    "fingerprint_algorithm",
    condition = "capr_sidecar_invalid"
  )
  if (!is.null(strategies) &&
      (!is.list(strategies) || is.null(names(strategies)) ||
         any(!nzchar(names(strategies))))) {
    capr_abort(
      "capr_sidecar_invalid",
      "`strategies` must be NULL or a named list",
      field = "strategies"
    )
  }
  m <- adapter$metadata
  diagnostics <- cap_resolution_diagnostics(adapter)
  payload <- list(
    schema = capr_schema("resolution"),
    adapter_id = m$id,
    adapter_version = m$version,
    provider = m$provider,
    provider_version = m$provider_version,
    source_family = m$source_family,
    maturity = m$maturity,
    semantic_level = m$semantic_level,
    conformance_claim = m$conformance_claim,
    resolution_mode = diagnostics$selected$mode %||% "unknown",
    matched_class = diagnostics$matched_class,
    priority = diagnostics$selected$priority %||% NULL,
    binding_signature = capr_binding_signature(adapter),
    fingerprint_algorithm = fingerprint_algorithm,
    capr_version = .capr_version()
  )
  if (!is.null(strategies)) {
    payload$strategies <- strategies
  }
  structure(
    capr_sort_object(payload),
    class = "capr_resolution_sidecar"
  )
}

#' Pin an adapter lifecycle
#' @param adapter A resolved adapter.
#' @return Serializable pin metadata.
#' @export
cap_adapter_pin <- function(adapter) {
  sidecar <- cap_resolution_sidecar(adapter)
  structure(
    sidecar[c(
      "adapter_id", "adapter_version", "provider", "provider_version",
      "source_family", "binding_signature"
    )],
    schema = capr_schema("adapter_pin"),
    class = "capr_adapter_pin"
  )
}

#' Check adapter compatibility with a lifecycle pin
#' @param adapter A candidate adapter.
#' @param pin A pin from `cap_adapter_pin()`.
#' @return `TRUE`, invisibly, or a structured error.
#' @export
cap_check_adapter_pin <- function(adapter, pin) {
  cap_validate_adapter(adapter)
  if (!inherits(pin, "capr_adapter_pin") ||
      !identical(attr(pin, "schema"), capr_schema("adapter_pin"))) {
    capr_abort("capr_adapter_pin_mismatch", "invalid adapter pin")
  }
  current <- unclass(cap_adapter_pin(adapter))
  expected <- unclass(pin)
  names(current) <- names(cap_adapter_pin(adapter))
  names(expected) <- names(pin)
  differing <- names(expected)[!vapply(
    names(expected),
    function(name) identical(expected[[name]], current[[name]]),
    logical(1)
  )]
  if (length(differing)) {
    capr_abort(
      "capr_adapter_pin_mismatch",
      "resolved adapter is incompatible with the digest lifecycle pin",
      fields = differing,
      expected = expected[differing],
      actual = current[differing]
    )
  }
  invisible(TRUE)
}

#' Write and read resolution sidecars
#' @param sidecar A resolution sidecar.
#' @param path File path.
#' @return The normalized path when writing, or sidecar object when reading.
#' @export
cap_write_resolution_sidecar <- function(sidecar, path) {
  if (!inherits(sidecar, "capr_resolution_sidecar") ||
      !identical(sidecar$schema, capr_schema("resolution"))) {
    capr_abort("capr_sidecar_invalid", "invalid resolution sidecar")
  }
  path <- path.expand(capr_assert_scalar_character(
    path, "path", condition = "capr_sidecar_invalid"
  ))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temp <- tempfile(".resolution-", tmpdir = dirname(path))
  on.exit(unlink(temp), add = TRUE)
  writeLines(capr_canonical_json(unclass(sidecar), pretty = TRUE), temp, useBytes = TRUE)
  if (!file.rename(temp, path)) {
    capr_abort("capr_sidecar_invalid", "could not atomically publish sidecar", path = path)
  }
  invisible(normalizePath(path, mustWork = TRUE))
}

#' @rdname cap_write_resolution_sidecar
#' @export
cap_read_resolution_sidecar <- function(path) {
  path <- path.expand(capr_assert_scalar_character(
    path, "path", condition = "capr_sidecar_invalid"
  ))
  parsed <- tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) capr_abort(
      "capr_sidecar_invalid", "malformed resolution sidecar",
      path = path, parent = e
    )
  )
  required <- c(
    "schema", "adapter_id", "adapter_version", "provider",
    "provider_version", "source_family", "maturity", "semantic_level",
    "conformance_claim", "resolution_mode", "binding_signature",
    "fingerprint_algorithm", "capr_version"
  )
  if (!identical(parsed$schema, capr_schema("resolution")) ||
      length(setdiff(required, names(parsed)))) {
    capr_abort(
      "capr_sidecar_invalid",
      "resolution sidecar is incomplete or has the wrong schema",
      path = path
    )
  }
  structure(parsed, class = "capr_resolution_sidecar")
}
