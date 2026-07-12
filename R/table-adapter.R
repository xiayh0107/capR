.capr_sensitive_name_patterns <- c(
  "password", "secret", "token", "api_key", "credential", "private_key"
)

capr_table_label <- function(x, context = list()) {
  label <- context$label %||% attr(x, "capr_label", exact = TRUE) %||% "data.frame"
  capr_assert_scalar_character(
    label, "label", condition = "capr_artifact_invalid"
  )
}

capr_table_uri <- function(x, context = list()) {
  explicit <- context$uri %||% attr(x, "capr_uri", exact = TRUE)
  if (!is.null(explicit)) {
    return(capr_assert_scalar_character(
      explicit, "uri", condition = "capr_artifact_invalid"
    ))
  }
  structure <- list(
    dimensions = unname(dim(x)),
    names = enc2utf8(names(x)),
    classes = lapply(x, function(column) unname(class(column))),
    types = vapply(x, typeof, character(1))
  )
  paste0(
    "r-host://table/",
    capr_sha256(capr_canonical_json(structure))
  )
}

capr_table_fingerprint <- function(x, context = list()) {
  override <- context$fingerprint
  if (!is.null(override)) {
    return(list(
      available = TRUE,
      algorithm = "fixture-declared",
      value = capr_assert_scalar_character(
        override, "fingerprint", condition = "capr_artifact_invalid"
      )
    ))
  }
  structure <- list(
    dimensions = unname(dim(x)),
    names = enc2utf8(names(x)),
    classes = lapply(x, function(column) unname(class(column))),
    types = vapply(x, typeof, character(1)),
    factor_levels = lapply(x, function(column) {
      if (is.factor(column)) enc2utf8(levels(column)) else NULL
    })
  )
  list(
    available = TRUE,
    algorithm = "capr-table-structure-v1-sha256",
    value = paste0(
      "capr_table_structure_v1:",
      capr_sha256(capr_canonical_json(structure))
    )
  )
}

capr_table_type <- function(x) {
  if (inherits(x, "POSIXct")) return("datetime")
  if (inherits(x, "Date")) return("date")
  if (is.factor(x)) return("factor")
  switch(
    typeof(x),
    character = "chr",
    double = "dbl",
    integer = "int",
    logical = "lgl",
    complex = "cplx",
    raw = "raw",
    list = "list",
    typeof(x)
  )
}

capr_scalar_display <- function(x, type = NULL) {
  if (length(x) != 1L) {
    capr_abort(
      "capr_renderer_error",
      "table values must be rendered one scalar at a time"
    )
  }
  if (is.na(x)) return("NA")
  type <- type %||% capr_table_type(x)
  if (identical(type, "dbl")) {
    return(format(
      as.numeric(x),
      scientific = FALSE,
      trim = TRUE,
      digits = 15L,
      nsmall = 1L,
      decimal.mark = "."
    ))
  }
  if (identical(type, "datetime")) {
    return(format(x, "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC", usetz = FALSE))
  }
  if (identical(type, "date")) return(format(x, "%Y-%m-%d"))
  if (identical(type, "cplx")) {
    return(format(x, scientific = FALSE, trim = TRUE, digits = 15L))
  }
  if (identical(type, "raw")) return(as.character(x))
  if (identical(type, "list")) return("[unsupported list value]")
  enc2utf8(as.character(x))
}

capr_table_extract_shape <- function(x, level = 1L, context = list()) {
  list(rows = nrow(x), columns = ncol(x))
}

capr_table_extract_columns <- function(x, level = 1L, context = list()) {
  lapply(seq_along(x), function(index) {
    column <- x[[index]]
    type <- capr_table_type(column)
    unsupported <- identical(type, "list")
    values <- if (unsupported || !length(column)) {
      list()
    } else {
      indices <- seq_len(min(2L, length(column)))
      lapply(indices, function(i) {
        capr_scalar_display(column[i], type)
      })
    }
    list(
      name = enc2utf8(names(x)[[index]]),
      type = type,
      examples = values,
      unsupported = unsupported
    )
  })
}

capr_table_extract_sample <- function(x, level = 1L, context = list()) {
  declared <- attr(x, "capr_fixture_sample_rows", exact = TRUE)
  if (!is.null(declared)) {
    rows <- lapply(declared, function(row) {
      values <- lapply(row, function(value) {
        if (is.numeric(value)) {
          capr_scalar_display(value, "dbl")
        } else {
          capr_scalar_display(value)
        }
      })
      names(values) <- enc2utf8(names(row))
      values
    })
    return(list(
      rows = rows[seq_len(min(10L, length(rows)))],
      columns = if (length(rows)) enc2utf8(names(rows[[1L]])) else character()
    ))
  }
  count <- min(10L, nrow(x))
  if (!count) return(list(rows = list(), columns = enc2utf8(names(x))))
  rows <- lapply(seq_len(count), function(row_index) {
    values <- lapply(seq_along(x), function(column_index) {
      column <- x[[column_index]]
      type <- capr_table_type(column)
      if (identical(type, "list")) {
        "[unsupported list value]"
      } else {
        capr_scalar_display(column[row_index], type)
      }
    })
    names(values) <- enc2utf8(names(x))
    values
  })
  list(rows = rows, columns = enc2utf8(names(x)))
}

capr_is_sensitive_name <- function(name, patterns) {
  lower <- tolower(enc2utf8(name))
  any(vapply(
    tolower(enc2utf8(patterns)),
    function(pattern) grepl(pattern, lower, fixed = TRUE),
    logical(1)
  ))
}

capr_table_redact <- function(value, field = NULL, context = list()) {
  patterns <- context$sensitive_name_patterns %||%
    .capr_sensitive_name_patterns
  redacted <- FALSE
  warnings <- character()
  caveats <- list()
  field_id <- field$id %||% field$fieldId %||% ""

  if (identical(field_id, "f1:table@columns#compact")) {
    for (index in seq_along(value)) {
      if (capr_is_sensitive_name(value[[index]]$name, patterns)) {
        value[[index]]$examples <- list("[masked: sensitive name]")
        redacted <- TRUE
        warning <- sprintf("values in %s masked", value[[index]]$name)
        warnings <- c(warnings, warning)
        caveats[[length(caveats) + 1L]] <- list(
          code = "cap_caveat_redacted",
          fieldId = field_id,
          message = sprintf(
            'values in "%s" were masked',
            value[[index]]$name
          ),
          rule = "sensitive-name"
        )
      }
    }
  } else if (identical(field_id, "f1:table@sample#k10")) {
    for (row_index in seq_along(value$rows)) {
      for (name in names(value$rows[[row_index]])) {
        if (capr_is_sensitive_name(name, patterns)) {
          value$rows[[row_index]][[name]] <- "[masked: sensitive name]"
          redacted <- TRUE
        }
      }
    }
    if (redacted) {
      warnings <- "sensitive-name columns masked in sample"
      caveats <- list(list(
        code = "cap_caveat_redacted",
        fieldId = field_id,
        message = "sensitive-name columns were masked in sample rows",
        rule = "sensitive-name"
      ))
    }
  }
  list(
    value = value,
    redacted = redacted,
    warnings = unname(warnings),
    caveats = caveats,
    rules = if (redacted) "sensitive-name" else character()
  )
}

capr_escape_data <- function(x) {
  x <- enc2utf8(as.character(x))
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\r", "&#13;", x, fixed = TRUE)
  gsub("[[:cntrl:]]", "", x)
}

capr_table_render_shape <- function(value, field = NULL, context = list()) {
  sprintf("%d rows x %d columns", value$rows, value$columns)
}

capr_table_render_columns <- function(value, field = NULL, context = list()) {
  lines <- vapply(value, function(column) {
    name <- capr_escape_data(column$name)
    type <- capr_escape_data(column$type)
    examples <- if (!length(column$examples)) {
      if (isTRUE(column$unsupported)) "<data>[unsupported]</data>" else ""
    } else {
      paste(
        vapply(
          column$examples,
          function(example) sprintf(
            "<data>%s</data>",
            capr_escape_data(example)
          ),
          character(1)
        ),
        collapse = ", "
      )
    }
    sprintf("%s <%s> e.g. %s", name, type, examples)
  }, character(1))
  paste(lines, collapse = "\n")
}

capr_table_render_sample <- function(value, field = NULL, context = list()) {
  if (!length(value$rows)) return("[no rows]")
  lines <- vapply(seq_along(value$rows), function(index) {
    row <- value$rows[[index]]
    values <- vapply(names(row), function(name) {
      sprintf(
        "%s=<data>%s</data>",
        capr_escape_data(name),
        capr_escape_data(row[[name]])
      )
    }, character(1))
    sprintf("%d. %s", index, paste(values, collapse = ", "))
  }, character(1))
  paste(lines, collapse = "\n")
}

capr_table_field_catalog <- function(x, context = list()) {
  fields <- list(
    list(
      schema = "cap.field.v1",
      id = "f1:table@shape#base",
      label = "Shape",
      description = "Row and column count for a tabular source.",
      sourceTypes = list("table"),
      timing = "assemble",
      trust = "code",
      exec = "local_cheap",
      contracts = list(
        extractor = "capr.table.shape",
        redactor = "capr.table.default",
        renderer = "capr.table.shape.text_v1"
      ),
      selectionHints = list(
        priorValue = 1.0,
        intentTags = list("structure")
      ),
      levels = list(list(
        level = 1L,
        estimatedCost = 24L,
        description = "Row and column count."
      ))
    ),
    list(
      schema = "cap.field.v1",
      id = "f1:table@columns#compact",
      label = "Columns",
      description = "Compact column names, types, and masked examples.",
      sourceTypes = list("table"),
      timing = "assemble",
      trust = "derived",
      exec = "local_cheap",
      contracts = list(
        extractor = "capr.table.columns",
        redactor = "capr.table.default",
        renderer = "capr.table.columns.text_v1"
      ),
      selectionHints = list(
        priorValue = 1.1,
        intentTags = list("structure", "schema")
      ),
      levels = list(list(
        level = 1L,
        estimatedCost = 120L,
        description = "Names, types, and at most two masked examples."
      ))
    ),
    list(
      schema = "cap.field.v1",
      id = "f1:table@sample#k10",
      label = "Sample rows",
      description = "Up to ten deterministic sample rows.",
      sourceTypes = list("table"),
      timing = "interactive",
      trust = "data",
      exec = "local_scan",
      contracts = list(
        extractor = "capr.table.sample",
        redactor = "capr.table.default",
        renderer = "capr.table.sample.text_v1"
      ),
      selectionHints = list(
        priorValue = 0.8,
        intentTags = list("sample")
      ),
      levels = list(list(
        level = 1L,
        estimatedCost = 300L,
        description = "Up to ten rows through gated follow-up."
      ))
    )
  )
  list(
    schema = "cap.field_catalog.v1",
    catalogId = "org.capr.table.v1",
    sourceType = "table",
    versions = list(
      cap = "2026-07-05-draft",
      fields = "f1",
      catalog = "v1"
    ),
    fields = fields
  )
}

capr_table_source_ref <- function(x, context = list()) {
  list(
    schema = "cap.source_ref.v1",
    uri = capr_table_uri(x, context),
    sourceType = "table",
    label = capr_table_label(x, context),
    identity = list(
      host = "R",
      classes = unname(class(x)),
      rows = nrow(x),
      columns = ncol(x)
    ),
    trust = "host"
  )
}

#' Construct the stable table-family adapter
#'
#' @return A validated built-in adapter for local data frames.
#' @export
cap_table_adapter <- function() {
  cap_new_adapter(
    id = "org.capr.table",
    version = "1.0.0",
    provider = "capR",
    provider_version = .capr_version(),
    source_family = "table",
    maturity = "stable",
    semantic_level = "table",
    conformance_claim = "CAP-Digest v1.0 table fixture scope",
    capabilities = list(
      followup = TRUE,
      remote = FALSE,
      credentials = FALSE,
      deterministic = TRUE
    ),
    source_ref = capr_table_source_ref,
    field_catalog = capr_table_field_catalog,
    fingerprint = capr_table_fingerprint,
    bindings = list(
      extractors = list(
        "capr.table.shape" = capr_table_extract_shape,
        "capr.table.columns" = capr_table_extract_columns,
        "capr.table.sample" = capr_table_extract_sample
      ),
      redactors = list(
        "capr.table.default" = capr_table_redact
      ),
      renderers = list(
        "capr.table.shape.text_v1" = capr_table_render_shape,
        "capr.table.columns.text_v1" = capr_table_render_columns,
        "capr.table.sample.text_v1" = capr_table_render_sample
      )
    )
  )
}

#' @export
cap_adapter.data.frame <- function(x, ...) {
  if (!identical(class(x)[[1L]], "data.frame")) return(NULL)
  cap_table_adapter()
}

capr_reject_remote_table <- function(x) {
  remote <- c(
    "tbl_lazy", "tbl_sql", "arrow_dplyr_query",
    "Dataset", "ArrowTabular"
  )
  matched <- intersect(class(x), remote)
  if (length(matched)) {
    capr_abort(
      "capr_adapter_not_found",
      "lazy or remote table backends are outside the stable local table path",
      classes = matched
    )
  }
  invisible(TRUE)
}

#' @export
cap_adapter.tbl_df <- function(x, ...) {
  capr_reject_remote_table(x)
  cap_table_adapter()
}

#' @export
cap_adapter.data.table <- function(x, ...) {
  capr_reject_remote_table(x)
  cap_table_adapter()
}
