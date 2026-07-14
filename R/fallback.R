capr_fallback_high_risk <- function(x) {
  high_risk_classes <- c(
    "tbl_lazy", "tbl_sql", "Dataset", "ArrowObject", "R6",
    "ggplot", "patchwork", "grob", "gtable", "htmlwidget",
    "DelayedArray", "DelayedMatrix", "HDF5Array", "HDF5Matrix",
    "DBIConnection", "SummarizedExperiment", "SingleCellExperiment",
    "MultiAssayExperiment", "Seurat", "phyloseq", "GRanges", "stars",
    "sf", "sfc", "igraph", "tbl_graph", "treedata", "recipe",
    "workflow", "model_fit", "merMod", "xml_document", "xml_node"
  )
  # Hosts may only EXTEND the refusal list (fail-closed); an option can
  # never remove a built-in high-risk class.
  extra <- getOption("capr.extra_high_risk_classes", character())
  if (!is.character(extra) || anyNA(extra)) {
    capr_abort(
      "capr_policy_invalid",
      "`capr.extra_high_risk_classes` must be a character vector",
      option = "capr.extra_high_risk_classes"
    )
  }
  high_risk_classes <- c(high_risk_classes, extra)
  isS4(x) ||
    is.environment(x) ||
    inherits(x, "connection") ||
    any(inherits(x, high_risk_classes)) ||
    typeof(x) %in% c("externalptr", "promise", "weakref")
}

capr_bounded_names <- function(x, limit = 50L) {
  values <- attr(x, "names", exact = TRUE)
  if (is.object(values) && !isS4(values)) {
    values <- tryCatch(unclass(values), error = function(e) NULL)
  }
  if (!is.character(values)) return(character())
  total <- length(values)
  count <- min(total, limit)
  kept <- capr_descriptor_bound_string(values[seq_len(count)])
  if (total > count) {
    kept <- c(kept, sprintf("... %d more", total - count))
  }
  kept
}

capr_fallback_snapshot <- function(x, include_attributes = FALSE) {
  if (capr_fallback_high_risk(x)) {
    capr_abort(
      "capr_fallback_disallowed",
      "high-risk objects cannot be structurally traversed",
      type = typeof(x),
      classes = class(x)
    )
  }
  raw <- if (is.object(x)) {
    tryCatch(unclass(x), error = function(e) e)
  } else {
    x
  }
  if (inherits(raw, "condition") || isS4(raw) || is.environment(raw) ||
      typeof(raw) %in% c("externalptr", "promise", "weakref")) {
    capr_abort(
      "capr_fallback_disallowed",
      "the object cannot be stripped to a method-free structural host",
      type = typeof(x),
      classes = class(x)
    )
  }
  classes <- unname(class(x))
  class_count <- min(length(classes), 20L)
  dimensions <- attr(raw, "dim", exact = TRUE)
  if (is.object(dimensions) && !isS4(dimensions)) {
    dimensions <- tryCatch(unclass(dimensions), error = function(e) NULL)
  }
  if (!is.numeric(dimensions)) dimensions <- numeric()
  dimension_count <- min(length(dimensions), 20L)
  snapshot <- list(
    type = typeof(x),
    classes = capr_descriptor_bound_string(
      classes[seq_len(class_count)]
    ),
    length = as.integer(length(raw)),
    dim = unname(as.integer(dimensions[seq_len(dimension_count)])),
    names = capr_bounded_names(raw)
  )
  if (include_attributes) {
    snapshot$attributes <- capr_bounded_names(attributes(x), 25L)
  }
  snapshot
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
    snapshot <- capr_fallback_snapshot(x)
    list(
      schema = capr_schema("source_ref"),
      sourceType = "r_object",
      uri = sprintf(
        "r-host://structural/%s",
        capr_sha256(capr_canonical_json(snapshot))
      ),
      label = "bounded R object structure",
      identity = list(type = typeof(x), classes = snapshot$classes),
      trust = "host"
    )
  }
  field_catalog <- function(x, context = list()) {
    list(
      schema = capr_schema("field_catalog"),
      catalogId = "org.capr.structural_fallback.v1",
      sourceType = "r_object",
      versions = capr_catalog_versions(),
      fields = list(list(
        schema = capr_schema("field"),
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
    payload <- capr_fallback_snapshot(x)
    list(
      available = TRUE,
      algorithm = "capr-structural-v1",
      value = capr_sha256(capr_canonical_json(payload))
    )
  }
  extractor <- function(x, level = "base", context = list()) {
    capr_fallback_snapshot(x, include_attributes = TRUE)
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
