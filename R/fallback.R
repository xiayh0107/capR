capr_fallback_high_risk <- function(x) {
  is.environment(x) ||
    inherits(x, "connection") ||
    typeof(x) %in% c("externalptr", "promise", "weakref")
}

capr_bounded_names <- function(x, limit = 50L) {
  values <- names(x)
  if (is.null(values)) return(character())
  values <- enc2utf8(values)
  if (length(values) > limit) {
    c(values[seq_len(limit)], sprintf("... %d more", length(values) - limit))
  } else {
    values
  }
}

#' Construct the bounded structural fallback adapter
#'
#' This adapter is structural-only, non-conformant, and never invokes arbitrary
#' print, summary, or conversion methods.
#'
#' @return A `capr_adapter` with fallback maturity.
#' @export
cap_structural_adapter <- function() {
  source_ref <- function(x, context = list()) {
    if (capr_fallback_high_risk(x)) {
      capr_abort(
        "capr_fallback_disallowed",
        "high-risk objects cannot be structurally traversed",
        type = typeof(x),
        classes = class(x)
      )
    }
    list(
      schema = "cap.source_ref.v1",
      sourceType = "r_object",
      uri = sprintf(
        "r-host://structural/%s",
        capr_sha256(paste(typeof(x), length(x), paste(class(x), collapse = "/")))
      ),
      label = "bounded R object structure",
      identity = list(type = typeof(x), classes = unname(class(x))),
      trust = "host"
    )
  }
  field_catalog <- function(x, context = list()) {
    list(
      schema = "cap.field_catalog.v1",
      catalogId = "org.capr.structural_fallback.v1",
      sourceType = "r_object",
      versions = list(
        cap = "2026-07-05-draft",
        fields = "f1",
        catalog = "v1"
      ),
      fields = list(list(
        schema = "cap.field.v1",
        id = "f1:r_object@capr_structure#base",
        label = "R object structure",
        description = "Bounded shallow structure of an R object.",
        sourceTypes = list("r_object"),
        timing = "assemble",
        trust = "code",
        exec = "local_cheap",
        levels = list(list(
          level = 1L,
          estimatedCost = 80L,
          description = "Type, class, dimensions, and bounded names."
        )),
        selectionHints = list(
          priorValue = 1,
          intentTags = list("structure")
        ),
        contracts = list(
          extractor = "capr.fallback.structure",
          redactor = "capr.fallback.identity",
          renderer = "capr.fallback.structure.text_v1"
        )
      ))
    )
  }
  fingerprint <- function(x, context = list()) {
    if (capr_fallback_high_risk(x)) {
      return(list(
        available = FALSE,
        algorithm = "capr-structural-v1",
        value = NULL,
        caveat = "high_risk_source"
      ))
    }
    payload <- list(
      type = typeof(x),
      classes = unname(class(x)),
      length = length(x),
      dim = unname(dim(x)),
      names = capr_bounded_names(x)
    )
    list(
      available = TRUE,
      algorithm = "capr-structural-v1",
      value = capr_sha256(capr_canonical_json(payload))
    )
  }
  extractor <- function(x, level = "base", context = list()) {
    if (capr_fallback_high_risk(x)) {
      capr_abort(
        "capr_fallback_disallowed",
        "high-risk fallback extraction is denied",
        type = typeof(x)
      )
    }
    list(
      type = typeof(x),
      classes = unname(class(x)),
      length = length(x),
      dim = unname(dim(x)),
      names = capr_bounded_names(x),
      attributes = capr_bounded_names(attributes(x), 25L)
    )
  }
  renderer <- function(value, field = NULL, context = list()) {
    paste(
      utils::capture.output(utils::str(
        value, max.level = 2L, vec.len = 20L
      )),
      collapse = "\n"
    )
  }
  cap_new_adapter(
    id = "org.capr.structural_fallback",
    version = "1.0.0",
    provider = "capR",
    provider_version = .capr_version(),
    source_family = "r_object",
    maturity = "fallback",
    semantic_level = "structural",
    conformance_claim = "none",
    capabilities = list(
      followup = FALSE,
      remote = FALSE,
      credentials = FALSE,
      deterministic = TRUE,
      bounded_depth = 2L
    ),
    source_ref = source_ref,
    field_catalog = field_catalog,
    fingerprint = fingerprint,
    bindings = list(
      extractors = list("capr.fallback.structure" = extractor),
      redactors = list("capr.fallback.identity" = function(value, ...) {
        list(
          value = value,
          redacted = FALSE,
          warnings = character(),
          caveats = list(),
          rules = character()
        )
      }),
      renderers = list("capr.fallback.structure.text_v1" = renderer)
    )
  )
}
