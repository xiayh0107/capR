capr_grouping_info <- function(x) {
  capr_reject_remote_table(x)
  grouped_class <- inherits(x, "grouped_df") || inherits(x, "rowwise_df")
  if (!is.data.frame(x) || !inherits(x, "tbl_df") || !grouped_class) {
    capr_abort(
      "capr_adapter_invalid",
      paste(
        "the grouped-table adapter requires a local grouped_df or",
        "rowwise_df"
      ),
      classes = unname(class(x))
    )
  }
  groups <- attr(x, "groups", exact = TRUE)
  if (!is.data.frame(groups) || !".rows" %in% names(groups)) {
    capr_abort(
      "capr_adapter_invalid",
      "grouped table metadata must contain a data-frame `groups` attribute",
      classes = unname(class(x))
    )
  }
  row_indices <- groups[[".rows"]]
  if (!is.list(row_indices)) {
    capr_abort(
      "capr_adapter_invalid",
      "grouped table `.rows` metadata must be a list",
      classes = unname(class(x))
    )
  }
  kind <- if (inherits(x, "rowwise_df")) "rowwise" else "grouped"
  variables <- setdiff(enc2utf8(names(groups)), ".rows")
  drop <- attr(groups, ".drop", exact = TRUE)
  list(
    kind = kind,
    variables = unname(variables),
    group_count = as.integer(nrow(groups)),
    drop_empty = if (is.logical(drop) && length(drop) == 1L && !is.na(drop)) {
      drop
    } else {
      NULL
    }
  )
}

capr_grouped_table_source_ref <- function(x, context = list()) {
  grouping <- capr_grouping_info(x)
  source_ref <- capr_table_source_ref(x, context)
  source_ref$identity$grouping <- list(
    kind = grouping$kind,
    variables = as.list(grouping$variables),
    groupCount = grouping$group_count
  )
  source_ref
}

capr_grouped_table_fingerprint <- function(x, context = list()) {
  grouping <- capr_grouping_info(x)
  table_fingerprint <- capr_table_fingerprint(x, context)
  payload <- list(
    table = table_fingerprint$value,
    kind = grouping$kind,
    variables = as.list(grouping$variables),
    group_count = grouping$group_count,
    drop_empty = grouping$drop_empty
  )
  list(
    available = TRUE,
    algorithm = "capr-grouped-table-structure-v1-sha256",
    value = paste0(
      "capr_grouped_table_structure_v1:",
      capr_sha256(capr_canonical_json(payload))
    ),
    caveat = "group_keys_and_cell_values_not_hashed"
  )
}

capr_grouped_table_field_catalog <- function(x, context = list()) {
  capr_grouping_info(x)
  catalog <- capr_table_field_catalog(x, context)
  catalog$catalogId <- "org.capr.grouped_table.v1"
  catalog$fields[[length(catalog$fields) + 1L]] <- list(
    schema = "cap.field.v1",
    id = "f1:table@capr_grouping#compact",
    label = "Grouping",
    description = paste(
      "Grouping mode, variables, and group count without group keys or cell",
      "values."
    ),
    sourceTypes = list("table"),
    timing = "assemble",
    trust = "derived",
    exec = "local_cheap",
    contracts = list(
      extractor = "capr.grouped_table.grouping",
      redactor = "capr.grouped_table.identity",
      renderer = "capr.grouped_table.grouping.text_v1"
    ),
    selectionHints = list(
      priorValue = 1.25,
      intentTags = list("group", "grouping", "grouped", "rowwise", "tidy")
    ),
    levels = list(list(
      level = 1L,
      estimatedCost = 64L,
      description = "Grouping mode, variables, and group count."
    ))
  )
  catalog
}

capr_grouped_table_render <- function(value, field = NULL, context = list()) {
  variables <- if (length(value$variables)) {
    paste(
      vapply(value$variables, capr_escape_data, character(1)),
      collapse = ", "
    )
  } else {
    "[none]"
  }
  drop <- if (is.null(value$drop_empty)) {
    "unknown"
  } else if (isTRUE(value$drop_empty)) {
    "true"
  } else {
    "false"
  }
  paste(
    sprintf("kind: %s", capr_escape_data(value$kind)),
    sprintf("variables: %s", variables),
    sprintf("groups: %d", value$group_count),
    sprintf("drop empty groups: %s", drop),
    sep = "\n"
  )
}

#' Construct the experimental grouped-table adapter
#'
#' This adapter preserves the stable table fields for local grouped tibbles and
#' adds bounded grouping metadata. It has no CAP conformance claim and does not
#' disclose group keys or cell values in its grouping field.
#'
#' @return A validated experimental adapter for `grouped_df` and `rowwise_df`
#'   objects.
#' @export
cap_grouped_table_adapter <- function() {
  table <- cap_table_adapter()
  bindings <- table$bindings
  bindings$extractors[["capr.grouped_table.grouping"]] <- function(
    x, level = 1L, context = list()
  ) {
    capr_grouping_info(x)
  }
  bindings$redactors[["capr.grouped_table.identity"]] <- function(
    value, field = NULL, context = list()
  ) {
    caveats <- if (!is.null(field)) {
      list(list(
        code = "capr_caveat_grouping_metadata_only",
        fieldId = field$id,
        message = paste(
          "experimental grouping evidence excludes group keys and cell",
          "values; its fingerprint covers structure, mode, variables, and",
          "group count only"
        ),
        rule = "grouping-metadata-only"
      ))
    } else {
      list()
    }
    list(
      value = value,
      redacted = FALSE,
      warnings = character(),
      caveats = caveats,
      rules = character()
    )
  }
  bindings$renderers[["capr.grouped_table.grouping.text_v1"]] <-
    capr_grouped_table_render

  cap_new_adapter(
    id = "org.capr.grouped_table",
    version = "0.1.0",
    provider = "capR",
    provider_version = .capr_version(),
    source_family = "table",
    maturity = "experimental",
    semantic_level = "table",
    conformance_claim = "none",
    capabilities = list(
      followup = TRUE,
      remote = FALSE,
      credentials = FALSE,
      deterministic = TRUE,
      grouping_keys_disclosed = FALSE
    ),
    source_ref = capr_grouped_table_source_ref,
    field_catalog = capr_grouped_table_field_catalog,
    fingerprint = capr_grouped_table_fingerprint,
    bindings = bindings,
    implementation_spec = capr_builtin_implementation_spec(
      prefixes = c("capr_grouped_", "capr_grouping_")
    )
  )
}
