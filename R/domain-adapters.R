.capr_domain_rank_limit <- 64L
.capr_db_schema_limits <- list(
  tables = 200L,
  columns = 500L,
  primary_keys = 200L,
  foreign_keys = 500L
)
.capr_db_schema_integrity_version <- "capr-db-schema-v1"

capr_domain_classes <- function(x) {
  classes <- unname(class(x))
  count <- min(length(classes), 50L)
  as.list(capr_descriptor_bound_string(classes[seq_len(count)]))
}

capr_domain_dimension_vector <- function(x) {
  values <- capr_domain_plain_atomic(x)
  if (!is.numeric(values)) return(NULL)
  if (length(values) > .capr_domain_rank_limit || anyNA(values) ||
      any(!is.finite(values)) || any(values < 0) ||
      any(values != floor(values)) ||
      any(values > .Machine$integer.max)) {
    capr_abort(
      "capr_adapter_invalid",
      "domain dimensions must contain at most 64 finite non-negative integers"
    )
  }
  unname(as.integer(values))
}

capr_domain_plain <- function(x) {
  if (isS4(x) || is.environment(x)) return(NULL)
  value <- if (is.object(x)) {
    tryCatch(unclass(x), error = function(e) NULL)
  } else {
    x
  }
  value
}

capr_domain_plain_atomic <- function(x) {
  value <- capr_domain_plain(x)
  if (is.atomic(value)) value else NULL
}

capr_domain_plain_list <- function(x) {
  value <- capr_domain_plain(x)
  if (is.list(value)) value else NULL
}

capr_domain_slots <- function(x) {
  slots <- methods::slotNames(x)
  if (length(slots) > 100L) {
    capr_abort(
      "capr_adapter_invalid",
      "domain objects with more than 100 slots are not inspected"
    )
  }
  slots
}

capr_domain_names <- function(x, limit = 50L) {
  if (isS4(x)) {
    slots <- capr_domain_slots(x)
    values <- if ("listData" %in% slots) {
      attr(methods::slot(x, "listData"), "names", exact = TRUE)
    } else {
      NULL
    }
  } else {
    values <- attr(capr_domain_plain(x), "names", exact = TRUE)
  }
  values <- capr_domain_plain_atomic(values)
  if (!is.character(values) || !length(values)) return(list())
  count <- min(length(values), limit)
  out <- as.list(capr_descriptor_bound_string(values[seq_len(count)]))
  if (length(values) > count) {
    out[[length(out) + 1L]] <- sprintf(
      "[truncated: %d more]", length(values) - count
    )
  }
  out
}

capr_domain_dimensions <- function(x) {
  if (isS4(x)) {
    slots <- capr_domain_slots(x)
    if ("Dim" %in% slots) {
      dimensions <- capr_domain_dimension_vector(methods::slot(x, "Dim"))
      if (!is.null(dimensions)) return(dimensions)
      return(integer())
    }
    if (all(c("nrows", "listData") %in% slots)) {
      rows <- capr_domain_plain_atomic(methods::slot(x, "nrows"))
      data <- capr_domain_plain_list(methods::slot(x, "listData"))
      if (!is.numeric(rows) || length(rows) != 1L || is.null(data)) {
        return(integer())
      }
      return(c(
        as.integer(rows),
        as.integer(length(data))
      ))
    }
    return(integer())
  }
  plain <- capr_domain_plain(x)
  dimensions <- capr_domain_dimension_vector(
    attr(plain, "dim", exact = TRUE)
  )
  if (!is.null(dimensions)) return(dimensions)
  if (is.list(plain) && any(class(x) %in% c(
    "data.frame", "tbl_df", "tbl_ts", "sf"
  ))) {
    rows <- capr_data_frame_row_count(x)
    return(c(as.integer(rows), as.integer(length(plain))))
  }
  if (inherits(x, "stars") && is.list(plain) && length(plain)) {
    dimensions <- capr_domain_dimension_vector(
      attr(.subset2(plain, 1L), "dim", exact = TRUE)
    )
    if (!is.null(dimensions)) return(dimensions)
  }
  integer()
}

capr_domain_length <- function(x) {
  if (isS4(x)) {
    slots <- capr_domain_slots(x)
    if ("listData" %in% slots) {
      data <- capr_domain_plain_list(methods::slot(x, "listData"))
      return(if (is.null(data)) 0L else as.integer(length(data)))
    }
    if ("ranges" %in% slots) {
      ranges <- methods::slot(x, "ranges")
      range_slots <- capr_domain_slots(ranges)
      if ("start" %in% range_slots) {
        starts <- capr_domain_plain_atomic(methods::slot(ranges, "start"))
        return(if (is.null(starts)) 0L else as.integer(length(starts)))
      }
    }
    if ("NAMES" %in% slots) {
      values <- capr_domain_plain_atomic(methods::slot(x, "NAMES"))
      return(if (is.null(values)) 0L else as.integer(length(values)))
    }
    return(0L)
  }
  plain <- capr_domain_plain(x)
  if (is.null(plain)) 0L else as.integer(length(plain))
}

capr_domain_s4_slot <- function(x, name) {
  if (!isS4(x) || !name %in% capr_domain_slots(x)) return(NULL)
  methods::slot(x, name)
}

capr_domain_abort_unsupported <- function(x, family, supported) {
  capr_abort(
    "capr_adapter_invalid",
    sprintf("object is not a supported %s host", family),
    source_family = family,
    classes = unname(class(x)),
    supported_classes = supported
  )
}

capr_db_schema_names <- function(x, what, allow_empty = FALSE,
                                 max_items = 500L) {
  x <- capr_domain_plain_atomic(x)
  if (!is.character(x) || length(x) > max_items ||
      (!allow_empty && !length(x))) {
    capr_abort(
      "capr_adapter_invalid",
      sprintf("%s must be unique non-empty character names", what),
      field = what
    )
  }
  prefix <- substr(x, 1L, 161L)
  if (anyNA(prefix) ||
      any(nchar(prefix, type = "chars") > 160L)) {
    capr_abort(
      "capr_adapter_invalid",
      sprintf("%s must be unique non-empty character names", what),
      field = what
    )
  }
  normalized <- capr_descriptor_bound_string(prefix, 160L)
  if (any(!nzchar(normalized)) || anyDuplicated(normalized)) {
    capr_abort(
      "capr_adapter_invalid",
      sprintf("%s must be unique non-empty character names", what),
      field = what
    )
  }
  normalized
}

capr_db_schema_integrity <- function(core) {
  paste0(
    .capr_db_schema_integrity_version,
    ":",
    capr_sha256(capr_canonical_json(core))
  )
}

capr_db_schema_invalid <- function(reason) {
  capr_abort(
    "capr_adapter_invalid",
    paste(
      "capr_db_schema metadata is not canonical or failed integrity",
      "validation"
    ),
    reason = reason
  )
}

capr_db_schema_record <- function(x, fields, reason) {
  value <- capr_domain_plain_list(x)
  if (is.null(value) || length(value) != length(fields)) {
    capr_db_schema_invalid(reason)
  }
  value_names <- capr_domain_plain_atomic(
    attr(value, "names", exact = TRUE)
  )
  if (!is.character(value_names) ||
      !identical(unname(value_names), fields)) {
    capr_db_schema_invalid(reason)
  }
  value
}

capr_db_schema_sequence <- function(x, minimum, maximum, reason) {
  value <- capr_domain_plain_list(x)
  if (is.null(value) || length(value) < minimum ||
      length(value) > maximum ||
      !is.null(attr(value, "names", exact = TRUE))) {
    capr_db_schema_invalid(reason)
  }
  value
}

capr_db_schema_scalar <- function(x, reason) {
  value <- capr_domain_plain_atomic(x)
  if (!is.character(value) || length(value) != 1L || is.na(value)) {
    capr_db_schema_invalid(reason)
  }
  unname(value)
}

capr_db_schema_character_sequence <- function(x, maximum, reason) {
  values <- capr_db_schema_sequence(
    x, minimum = 1L, maximum = maximum, reason = reason
  )
  unname(vapply(values, capr_db_schema_scalar, character(1), reason = reason))
}

capr_db_schema_validate <- function(x) {
  classes <- class(x)
  integrity <- capr_domain_plain_atomic(
    attr(x, "capr_db_schema_integrity", exact = TRUE)
  )
  if (length(classes) != 2L ||
      !identical(unname(classes), c("capr_db_schema", "list")) ||
      !is.character(integrity) || length(integrity) != 1L ||
      is.na(integrity)) {
    capr_db_schema_invalid("class or integrity metadata is invalid")
  }

  raw <- capr_db_schema_record(
    x,
    c("tables", "primary_keys", "foreign_keys"),
    "top-level schema fields are invalid"
  )
  tables <- capr_db_schema_sequence(
    .subset2(raw, "tables"),
    minimum = 1L,
    maximum = .capr_db_schema_limits$tables,
    reason = "table declarations are invalid"
  )
  primary_keys <- capr_db_schema_sequence(
    .subset2(raw, "primary_keys"),
    minimum = 0L,
    maximum = .capr_db_schema_limits$primary_keys,
    reason = "primary-key declarations are invalid"
  )
  foreign_keys <- capr_db_schema_sequence(
    .subset2(raw, "foreign_keys"),
    minimum = 0L,
    maximum = .capr_db_schema_limits$foreign_keys,
    reason = "foreign-key declarations are invalid"
  )

  table_input <- vector("list", length(tables))
  table_names <- character(length(tables))
  for (table_index in seq_along(tables)) {
    table <- capr_db_schema_record(
      .subset2(tables, table_index),
      c("name", "columns"),
      "a table declaration is invalid"
    )
    table_names[[table_index]] <- capr_db_schema_scalar(
      .subset2(table, "name"), "a table name is invalid"
    )
    columns <- capr_db_schema_sequence(
      .subset2(table, "columns"),
      minimum = 1L,
      maximum = .capr_db_schema_limits$columns,
      reason = "column declarations are invalid"
    )
    column_names <- character(length(columns))
    column_types <- character(length(columns))
    for (column_index in seq_along(columns)) {
      column <- capr_db_schema_record(
        .subset2(columns, column_index),
        c("name", "type"),
        "a column declaration is invalid"
      )
      column_names[[column_index]] <- capr_db_schema_scalar(
        .subset2(column, "name"), "a column name is invalid"
      )
      column_types[[column_index]] <- capr_db_schema_scalar(
        .subset2(column, "type"), "a column type is invalid"
      )
    }
    names(column_types) <- column_names
    table_input[[table_index]] <- column_types
  }
  names(table_input) <- table_names

  primary_input <- vector("list", length(primary_keys))
  primary_tables <- character(length(primary_keys))
  for (key_index in seq_along(primary_keys)) {
    key <- capr_db_schema_record(
      .subset2(primary_keys, key_index),
      c("table", "columns"),
      "a primary-key declaration is invalid"
    )
    primary_tables[[key_index]] <- capr_db_schema_scalar(
      .subset2(key, "table"), "a primary-key table is invalid"
    )
    primary_input[[key_index]] <- capr_db_schema_character_sequence(
      .subset2(key, "columns"),
      .capr_db_schema_limits$columns,
      "primary-key columns are invalid"
    )
  }
  names(primary_input) <- primary_tables

  foreign_input <- vector("list", length(foreign_keys))
  for (key_index in seq_along(foreign_keys)) {
    key <- capr_db_schema_record(
      .subset2(foreign_keys, key_index),
      c("from_table", "from_columns", "to_table", "to_columns"),
      "a foreign-key declaration is invalid"
    )
    foreign_input[[key_index]] <- list(
      from_table = capr_db_schema_scalar(
        .subset2(key, "from_table"), "a foreign-key table is invalid"
      ),
      from_columns = capr_db_schema_character_sequence(
        .subset2(key, "from_columns"),
        .capr_db_schema_limits$columns,
        "foreign-key source columns are invalid"
      ),
      to_table = capr_db_schema_scalar(
        .subset2(key, "to_table"), "a foreign-key table is invalid"
      ),
      to_columns = capr_db_schema_character_sequence(
        .subset2(key, "to_columns"),
        .capr_db_schema_limits$columns,
        "foreign-key target columns are invalid"
      )
    )
  }

  rebuilt <- tryCatch(
    cap_db_schema(table_input, primary_input, foreign_input),
    error = function(error) {
      capr_db_schema_invalid(
        "schema declarations violate constructor invariants"
      )
    }
  )
  rebuilt_raw <- unclass(rebuilt)
  core <- list(
    tables = tables,
    primary_keys = primary_keys,
    foreign_keys = foreign_keys
  )
  rebuilt_core <- list(
    tables = .subset2(rebuilt_raw, "tables"),
    primary_keys = .subset2(rebuilt_raw, "primary_keys"),
    foreign_keys = .subset2(rebuilt_raw, "foreign_keys")
  )
  expected_integrity <- capr_domain_plain_atomic(attr(
    rebuilt,
    "capr_db_schema_integrity",
    exact = TRUE
  ))
  if (!identical(core, rebuilt_core) ||
      !identical(unname(integrity), unname(expected_integrity))) {
    capr_db_schema_invalid("schema contents or integrity metadata changed")
  }
  rebuilt_core
}

#' Construct a declared database-schema metadata object
#'
#' This helper creates an in-memory schema declaration for the relational
#' adapter. It never connects to a database or calls DBI. `tables` is a named
#' list whose elements are named character vectors mapping column names to
#' declared types. `primary_keys` is a named list mapping table names to one or
#' more column names. Each `foreign_keys` entry is a list with `from_table`,
#' `from_columns`, `to_table`, and `to_columns`.
#'
#' @param tables Named list of named character column-type vectors.
#' @param primary_keys Named list of primary-key column vectors.
#' @param foreign_keys List of declared foreign-key relationships.
#' @return A validated `capr_db_schema` metadata object.
#' @export
cap_db_schema <- function(tables, primary_keys = list(),
                          foreign_keys = list()) {
  tables <- capr_domain_plain_list(tables)
  table_names_raw <- if (is.null(tables)) {
    NULL
  } else {
    capr_domain_plain_atomic(attr(tables, "names", exact = TRUE))
  }
  if (is.null(tables) || is.null(table_names_raw) || !length(tables) ||
      length(tables) > .capr_db_schema_limits$tables) {
    capr_abort(
      "capr_adapter_invalid",
      "`tables` must be a named list containing at most 200 schemas",
      field = "tables"
    )
  }
  table_names <- capr_db_schema_names(
    table_names_raw, "table names", max_items = .capr_db_schema_limits$tables
  )
  table_order <- capr_stable_order(table_names)
  table_names <- table_names[table_order]
  tables <- tables[table_order]
  normalized_tables <- lapply(seq_along(tables), function(index) {
    columns <- capr_domain_plain_atomic(.subset2(tables, index))
    column_names_raw <- if (is.null(columns)) {
      NULL
    } else {
      capr_domain_plain_atomic(attr(columns, "names", exact = TRUE))
    }
    column_types <- if (is.character(columns) &&
        length(columns) <= .capr_db_schema_limits$columns) {
      capr_descriptor_bound_string(columns, 160L)
    } else {
      NULL
    }
    if (is.null(column_types) || is.null(column_names_raw) ||
        !length(column_types) || anyNA(column_types) ||
        any(!nzchar(column_types))) {
      capr_abort(
        "capr_adapter_invalid",
        "each table must be a named character vector of declared types",
        table = table_names[[index]]
      )
    }
    column_names <- capr_db_schema_names(
      column_names_raw,
      sprintf("columns for table `%s`", table_names[[index]]),
      max_items = .capr_db_schema_limits$columns
    )
    order <- capr_stable_order(column_names)
    list(
      name = table_names[[index]],
      columns = lapply(order, function(column_index) {
        list(
          name = capr_descriptor_bound_string(
            column_names[[column_index]], 160L
          ),
          type = capr_descriptor_bound_string(
            .subset2(column_types, column_index), 160L
          )
        )
      })
    )
  })
  names(normalized_tables) <- table_names
  column_map <- lapply(normalized_tables, function(table) {
    vapply(table$columns, `[[`, character(1), "name")
  })

  primary_keys <- capr_domain_plain_list(primary_keys)
  primary_names_raw <- if (is.null(primary_keys)) {
    NULL
  } else {
    capr_domain_plain_atomic(attr(primary_keys, "names", exact = TRUE))
  }
  if (is.null(primary_keys) ||
      length(primary_keys) > .capr_db_schema_limits$primary_keys ||
      (length(primary_keys) && is.null(primary_names_raw))) {
    capr_abort(
      "capr_adapter_invalid",
      "`primary_keys` must be a named list",
      field = "primary_keys"
    )
  }
  primary_table_names <- capr_db_schema_names(
    primary_names_raw %||% character(),
    "primary-key table names",
    allow_empty = TRUE,
    max_items = .capr_db_schema_limits$primary_keys
  )
  if (length(setdiff(primary_table_names, table_names))) {
    capr_abort(
      "capr_adapter_invalid",
      "primary keys reference unknown tables",
      tables = setdiff(primary_table_names, table_names)
    )
  }
  normalized_primary <- lapply(primary_table_names, function(table) {
    columns <- .subset2(primary_keys, match(table, primary_table_names))
    columns <- capr_db_schema_names(
      columns, sprintf("primary key for `%s`", table),
      max_items = .capr_db_schema_limits$columns
    )
    unknown <- setdiff(columns, column_map[[table]])
    if (length(unknown)) {
      capr_abort(
        "capr_adapter_invalid",
        "primary key references unknown columns",
        table = table,
        columns = unknown
      )
    }
    list(table = table, columns = as.list(unname(columns)))
  })
  normalized_primary <- normalized_primary[
    capr_stable_order(primary_table_names)
  ]

  foreign_keys <- capr_domain_plain_list(foreign_keys)
  if (is.null(foreign_keys) ||
      length(foreign_keys) > .capr_db_schema_limits$foreign_keys) {
    capr_abort(
      "capr_adapter_invalid",
      "`foreign_keys` must be a list containing at most 500 relationships",
      field = "foreign_keys"
    )
  }
  normalized_foreign <- lapply(seq_along(foreign_keys), function(index) {
    key <- capr_domain_plain_list(.subset2(foreign_keys, index))
    required <- c("from_table", "from_columns", "to_table", "to_columns")
    key_names <- if (is.null(key)) {
      character()
    } else {
      capr_domain_plain_atomic(attr(key, "names", exact = TRUE)) %||%
        character()
    }
    if (is.null(key) || length(setdiff(required, key_names))) {
      capr_abort(
        "capr_adapter_invalid",
        "foreign-key entries are missing required metadata",
        index = index
      )
    }
    from_table <- .subset2(capr_db_schema_names(
      capr_domain_plain_atomic(.subset2(key, "from_table")),
      "foreign-key source table",
      max_items = 1L
    ), 1L)
    to_table <- .subset2(capr_db_schema_names(
      capr_domain_plain_atomic(.subset2(key, "to_table")),
      "foreign-key target table",
      max_items = 1L
    ), 1L)
    if (!from_table %in% table_names || !to_table %in% table_names) {
      capr_abort(
        "capr_adapter_invalid",
        "foreign key references an unknown table",
        index = index
      )
    }
    from_columns <- capr_db_schema_names(
      capr_domain_plain_atomic(.subset2(key, "from_columns")),
      sprintf("foreign-key source %d", index),
      max_items = .capr_db_schema_limits$columns
    )
    to_columns <- capr_db_schema_names(
      capr_domain_plain_atomic(.subset2(key, "to_columns")),
      sprintf("foreign-key target %d", index),
      max_items = .capr_db_schema_limits$columns
    )
    if (length(from_columns) != length(to_columns) ||
        length(setdiff(from_columns, column_map[[from_table]])) ||
        length(setdiff(to_columns, column_map[[to_table]]))) {
      capr_abort(
        "capr_adapter_invalid",
        "foreign-key columns are unknown or have incompatible arity",
        index = index
      )
    }
    list(
      from_table = from_table,
      from_columns = as.list(unname(from_columns)),
      to_table = to_table,
      to_columns = as.list(unname(to_columns))
    )
  })
  if (length(normalized_foreign)) {
    signatures <- vapply(
      normalized_foreign, capr_canonical_json, character(1)
    )
    normalized_foreign <- normalized_foreign[capr_stable_order(signatures)]
  }

  core <- list(
    tables = unname(normalized_tables),
    primary_keys = unname(normalized_primary),
    foreign_keys = unname(normalized_foreign)
  )
  structure(
    core,
    class = c("capr_db_schema", "list"),
    capr_db_schema_integrity = capr_db_schema_integrity(core)
  )
}

capr_dm_metadata <- function(x) {
  raw <- capr_domain_plain_list(x)
  raw_names <- if (is.null(raw)) {
    NULL
  } else {
    capr_domain_plain_atomic(attr(raw, "names", exact = TRUE))
  }
  if (is.null(raw) || !is.character(raw_names) || !"def" %in% raw_names) {
    capr_abort(
      "capr_adapter_invalid",
      "dm metadata does not contain the expected bounded definition table"
    )
  }
  definition <- capr_domain_plain_list(
    .subset2(raw, match("def", raw_names))
  )
  definition_names <- if (is.null(definition)) {
    NULL
  } else {
    capr_domain_plain_atomic(attr(definition, "names", exact = TRUE))
  }
  if (is.null(definition) || !is.character(definition_names) ||
      !"table" %in% definition_names) {
    capr_abort(
      "capr_adapter_invalid",
      "dm definition metadata does not expose a table-name column"
    )
  }
  table_names <- capr_domain_plain_atomic(
    .subset2(definition, match("table", definition_names))
  )
  if (!is.character(table_names)) {
    capr_abort(
      "capr_adapter_invalid",
      "dm table-name metadata must be character data"
    )
  }
  total <- length(table_names)
  count <- min(total, 50L)
  captured <- capr_descriptor_bound_string(table_names[seq_len(count)])
  if (total > count) {
    captured <- c(
      captured,
      sprintf("[truncated: %d more tables]", total - count)
    )
  }
  list(
    table_count = as.integer(total),
    table_names = as.list(captured),
    truncated = total > count
  )
}

capr_relational_snapshot <- function(x) {
  supported <- c("capr_db_schema", "dm", "MultiAssayExperiment")
  if (inherits(x, "capr_db_schema")) {
    raw <- capr_db_schema_validate(x)
    tables <- .subset2(raw, "tables")
    primary_keys <- .subset2(raw, "primary_keys")
    foreign_keys <- .subset2(raw, "foreign_keys")
    return(list(
      overview = list(
        kind = "database_schema",
        classes = capr_domain_classes(x),
        table_count = as.integer(length(tables)),
        primary_key_count = as.integer(length(primary_keys)),
        foreign_key_count = as.integer(length(foreign_keys))
      ),
      structure = list(
        tables = tables,
        primary_keys = primary_keys,
        foreign_keys = foreign_keys
      ),
      semantics = list(
        declared_metadata_only = TRUE,
        table_values_included = FALSE,
        key_values_included = FALSE,
        database_connection_accessed = FALSE,
        remote_queries_executed = FALSE
      )
    ))
  }
  if (inherits(x, "dm")) {
    metadata <- capr_dm_metadata(x)
    return(list(
      overview = list(
        kind = "dm",
        classes = capr_domain_classes(x),
        table_count = metadata$table_count
      ),
      structure = list(
        table_names = metadata$table_names,
        table_names_truncated = metadata$truncated,
        inspected_metadata = "table names only"
      ),
      semantics = list(
        relationship_metadata = "declared by host; key values not traversed",
        table_values_included = FALSE,
        key_values_included = FALSE,
        remote_queries_executed = FALSE
      )
    ))
  }

  if (inherits(x, "MultiAssayExperiment")) {
    experiments <- capr_domain_s4_slot(x, "ExperimentList")
    col_data <- capr_domain_s4_slot(x, "colData")
    sample_map <- capr_domain_s4_slot(x, "sampleMap")
    experiment_names <- capr_domain_names(experiments)
    col_dimensions <- capr_domain_dimensions(col_data)
    map_dimensions <- capr_domain_dimensions(sample_map)
    return(list(
      overview = list(
        kind = "MultiAssayExperiment",
        classes = capr_domain_classes(x),
        experiment_count = capr_domain_length(experiments)
      ),
      structure = list(
        experiment_names = experiment_names,
        primary_sample_count = if (length(col_dimensions)) {
          col_dimensions[[1L]]
        } else {
          0L
        },
        sample_map_rows = if (length(map_dimensions)) {
          map_dimensions[[1L]]
        } else {
          0L
        },
        sample_map_columns = capr_domain_names(sample_map),
        slot_names = as.list(capr_descriptor_bound_string(
          capr_domain_slots(x)
        ))
      ),
      semantics = list(
        relationship_metadata = "experiment names and mapping shape only",
        table_values_included = FALSE,
        sample_identifiers_included = FALSE,
        assay_values_included = FALSE,
        assays_materialized = FALSE
      )
    ))
  }

  capr_domain_abort_unsupported(x, "relational", supported)
}

capr_temporal_kind <- function(x) {
  if (inherits(x, "xts")) return("xts")
  if (inherits(x, "zoo")) return("zoo")
  if (inherits(x, "tbl_ts")) return("tbl_ts")
  if (inherits(x, "ts")) return("ts")
  NULL
}

capr_temporal_series_names <- function(x, kind, dimensions) {
  if (identical(kind, "tbl_ts")) return(capr_domain_names(x))
  if (length(dimensions) < 2L) return(list())
  dimnames <- capr_domain_plain_list(
    attr(capr_domain_plain(x), "dimnames", exact = TRUE)
  )
  values <- if (!is.null(dimnames) && length(dimnames) >= 2L) {
    capr_domain_plain_atomic(.subset2(dimnames, 2L))
  } else {
    NULL
  }
  if (!is.character(values) || !length(values)) return(list())
  count <- min(length(values), 50L)
  as.list(capr_descriptor_bound_string(values[seq_len(count)]))
}

capr_temporal_snapshot <- function(x) {
  supported <- c("ts", "zoo", "xts", "tbl_ts")
  kind <- capr_temporal_kind(x)
  if (is.null(kind)) {
    capr_domain_abort_unsupported(x, "temporal", supported)
  }

  dimensions <- capr_domain_dimensions(x)
  observations <- if (length(dimensions)) {
    dimensions[[1L]]
  } else {
    capr_domain_length(x)
  }
  series <- if (length(dimensions) >= 2L) dimensions[[2L]] else 1L
  frequency <- if (identical(kind, "ts")) {
    tsp <- capr_domain_plain_atomic(attr(x, "tsp", exact = TRUE))
    if (is.numeric(tsp) && length(tsp) == 3L) {
      as.numeric(.subset2(tsp, 3L))
    } else {
      NULL
    }
  } else {
    NULL
  }

  list(
    overview = list(
      kind = kind,
      classes = capr_domain_classes(x),
      observations = as.integer(observations),
      series = as.integer(series)
    ),
    structure = list(
      dimensions = dimensions,
      series_names = capr_temporal_series_names(x, kind, dimensions),
      index_metadata = "not inspected"
    ),
    semantics = list(
      regular = if (identical(kind, "ts")) TRUE else NULL,
      frequency = frequency,
      ordered_index = kind %in% c("zoo", "xts", "tbl_ts"),
      index_values_included = FALSE,
      payload_values_included = FALSE
    )
  )
}

capr_spatial_kind <- function(x) {
  if (inherits(x, "sf")) return("sf")
  if (inherits(x, "sfc")) return("sfc")
  if (inherits(x, "stars")) return("stars")
  if (inherits(x, "GRanges")) return("GRanges")
  NULL
}

capr_spatial_snapshot <- function(x) {
  supported <- c("sf", "sfc", "stars", "GRanges")
  kind <- capr_spatial_kind(x)
  if (is.null(kind)) {
    capr_domain_abort_unsupported(x, "spatial", supported)
  }
  if (inherits(x, "stars_proxy")) {
    capr_abort(
      "capr_adapter_invalid",
      "file-backed stars_proxy sources require an explicit remote policy"
    )
  }

  dimensions <- capr_domain_dimensions(x)
  feature_count <- if (identical(kind, "sfc") ||
      identical(kind, "GRanges")) {
    capr_domain_length(x)
  } else if (length(dimensions)) {
    dimensions[[1L]]
  } else {
    0L
  }
  component_names <- if (kind %in% c("sf", "stars")) {
    capr_domain_names(x)
  } else {
    list()
  }
  geometry_column <- if (identical(kind, "sf")) {
    value <- capr_domain_plain_atomic(attr(x, "sf_column", exact = TRUE))
    if (is.character(value) && length(value) == 1L && !is.na(value)) {
      capr_descriptor_bound_string(value)
    } else {
      NULL
    }
  } else {
    NULL
  }
  slot_names <- if (identical(kind, "GRanges") && isS4(x)) {
    slots <- capr_domain_slots(x)
    count <- min(length(slots), 50L)
    as.list(capr_descriptor_bound_string(slots[seq_len(count)]))
  } else {
    list()
  }

  list(
    overview = list(
      kind = kind,
      classes = capr_domain_classes(x),
      feature_count = as.integer(feature_count)
    ),
    structure = list(
      dimensions = dimensions,
      component_names = component_names,
      geometry_column = geometry_column,
      slot_names = slot_names,
      geometry_metadata = "not inspected"
    ),
    semantics = list(
      coordinate_values_included = FALSE,
      bounding_box_included = FALSE,
      coordinate_reference_values_included = FALSE,
      range_values_included = FALSE,
      table_values_included = FALSE
    )
  )
}

#' Construct the experimental relational descriptor adapter
#'
#' Supports declared `capr_db_schema`, in-memory `dm`, and
#' `MultiAssayExperiment` objects. Declared schemas expose bounded table,
#' primary-key, and foreign-key metadata; `dm` exposes bounded table names; and
#' multi-assay objects expose experiment/mapping shapes. Table, key, sample-map,
#' and assay values are not read, and remote queries are never executed.
#'
#' @return A validated experimental descriptor adapter.
#' @export
cap_relational_adapter <- function() {
  capr_new_descriptor_adapter(
    id = "org.capr.relational",
    family = "relational",
    label = "Relational object",
    snapshot_fn = capr_relational_snapshot,
    semantic_level = "domain",
    capabilities = list(
      table_values_included = FALSE,
      assay_values_included = FALSE,
      executes_queries = FALSE
    ),
    implementation_spec = capr_builtin_implementation_spec(
      prefixes = c(
        "capr_relational_", "capr_dm_", "capr_domain_", "capr_db_schema_"
      ),
      symbols = "cap_db_schema",
      constants = list(
        rank_limit = .capr_domain_rank_limit,
        db_schema_limits = .capr_db_schema_limits,
        db_schema_integrity_version = .capr_db_schema_integrity_version
      )
    )
  )
}

#' Construct the experimental temporal descriptor adapter
#'
#' Supports `ts`, `zoo`, `xts`, and `tbl_ts` hosts. It records bounded shape and
#' series metadata plus cached regularity/frequency for base `ts`, without
#' reading payload or index values.
#'
#' @return A validated experimental descriptor adapter.
#' @export
cap_temporal_adapter <- function() {
  capr_new_descriptor_adapter(
    id = "org.capr.temporal",
    family = "temporal",
    label = "Temporal object",
    snapshot_fn = capr_temporal_snapshot,
    semantic_level = "domain",
    capabilities = list(
      payload_values_included = FALSE,
      index_values_included = FALSE,
      executes_queries = FALSE
    ),
    implementation_spec = capr_builtin_implementation_spec(
      prefixes = c("capr_temporal_", "capr_domain_"),
      constants = list(rank_limit = .capr_domain_rank_limit)
    )
  )
}

#' Construct the experimental spatial descriptor adapter
#'
#' Supports `sf`, `sfc`, in-memory `stars`, and `GRanges` hosts. File-backed
#' `stars_proxy` inputs are rejected. It records bounded class, shape,
#' component, and slot metadata without disclosing table values or inspecting
#' and disclosing coordinate, bounding-box, coordinate-reference, or genomic-
#' range elements.
#'
#' @return A validated experimental descriptor adapter.
#' @export
cap_spatial_adapter <- function() {
  capr_new_descriptor_adapter(
    id = "org.capr.spatial",
    family = "spatial",
    label = "Spatial object",
    snapshot_fn = capr_spatial_snapshot,
    semantic_level = "domain",
    capabilities = list(
      table_values_included = FALSE,
      coordinate_values_included = FALSE,
      bounding_box_included = FALSE,
      range_values_included = FALSE
    ),
    implementation_spec = capr_builtin_implementation_spec(
      prefixes = c("capr_spatial_", "capr_domain_"),
      constants = list(rank_limit = .capr_domain_rank_limit)
    )
  )
}
