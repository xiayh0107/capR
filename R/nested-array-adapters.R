.capr_nested_limits <- list(
  depth = 4L,
  nodes = 80L,
  children = 20L,
  names = 40L,
  table_columns = 1000L
)
.capr_array_rank_limit <- 64L

capr_nested_classes <- function(x) {
  classes <- unname(class(x))
  count <- min(length(classes), .capr_nested_limits$names)
  as.list(capr_descriptor_bound_string(classes[seq_len(count)]))
}

capr_nested_plain_list <- function(x) {
  if (!is.list(x) || isS4(x) || is.environment(x)) return(NULL)
  value <- if (is.object(x)) {
    tryCatch(unclass(x), error = function(e) NULL)
  } else {
    x
  }
  if (is.list(value)) value else NULL
}

capr_nested_plain_atomic <- function(x) {
  if (!is.atomic(x) || isS4(x)) return(NULL)
  value <- if (is.object(x)) {
    tryCatch(unclass(x), error = function(e) NULL)
  } else {
    x
  }
  if (is.atomic(value)) value else NULL
}

capr_array_slots <- function(x) {
  slots <- methods::slotNames(x)
  if (length(slots) > 100L) {
    capr_abort(
      "capr_adapter_invalid",
      "array objects with more than 100 slots are not inspected"
    )
  }
  slots
}

capr_nested_table_rows <- function(x) {
  capr_data_frame_row_count(x)
}

capr_nested_dimensions <- function(x) {
  dimensions <- if (is.data.frame(x)) {
    c(capr_nested_table_rows(x), length(capr_nested_plain_list(x)))
  } else if (is.atomic(x) || is.list(x)) {
    capr_nested_plain_atomic(attr(x, "dim", exact = TRUE))
  } else {
    NULL
  }
  if (is.null(dimensions)) list() else as.list(as.integer(dimensions))
}

capr_nested_safe_length <- function(x) {
  if (is.null(x)) return(0L)
  if (is.environment(x) || is.function(x) || isS4(x) ||
      typeof(x) %in% c("externalptr", "weakref", "promise") ||
      is.language(x)) {
    return(NA_integer_)
  }
  if (is.atomic(x)) return(as.integer(length(unclass(x))))
  if (is.data.frame(x)) {
    return(as.integer(length(capr_nested_plain_list(x))))
  }
  if (is.list(x) && (identical(unname(class(x)), "list") ||
      inherits(x, "AsIs"))) {
    return(as.integer(length(capr_nested_plain_list(x))))
  }
  NA_integer_
}

capr_nested_container_kind <- function(x) {
  if (is.data.frame(x)) return("data.frame")
  if (is.list(x) && (identical(unname(class(x)), "list") ||
      inherits(x, "AsIs"))) return("list")
  NULL
}

capr_nested_child_names <- function(x, count) {
  source_names <- capr_nested_plain_atomic(
    attr(x, "names", exact = TRUE)
  )
  if (!is.character(source_names) || length(source_names) < count) {
    return(rep("", count))
  }
  source_names <- capr_descriptor_bound_string(
    source_names[seq_len(count)], 80L
  )
  source_names[is.na(source_names)] <- ""
  source_names
}

capr_nested_path <- function(parent, name, index) {
  component <- if (nzchar(name)) {
    paste0("$", capr_descriptor_bound_string(name, 80L))
  } else {
    sprintf("[[%d]]", index)
  }
  paste0(parent, component)
}

capr_nested_list_snapshot <- function(x) {
  is_nested_table <- is.data.frame(x)
  if (is_nested_table) {
    plain <- capr_nested_plain_list(x)
    if (length(plain) > .capr_nested_limits$table_columns) {
      capr_abort(
        "capr_adapter_invalid",
        "nested tables with more than 1000 columns are not inspected",
        columns = length(plain)
      )
    }
    column_names <- capr_nested_plain_atomic(
      attr(plain, "names", exact = TRUE)
    ) %||% character()
    if (!is.character(column_names)) column_names <- character()
    list_columns <- column_names[vapply(plain, is.list, logical(1))]
    if (!length(list_columns)) {
      capr_abort(
        "capr_adapter_invalid",
        "the nested adapter requires at least one list-column for tables",
        classes = unname(class(x))
      )
    }
  } else if (!is.list(x) || !identical(unname(class(x)), "list")) {
    capr_abort(
      "capr_adapter_invalid",
      paste(
        "the nested adapter requires a plain list, a table with a",
        "list-column, or an xml2 document/node"
      ),
      classes = unname(class(x))
    )
  } else {
    list_columns <- character()
  }

  state <- new.env(parent = emptyenv())
  state$nodes <- list()
  state$node_count <- 0L
  state$container_count <- 0L
  state$leaf_count <- 0L
  state$max_depth <- 0L
  state$truncated <- FALSE
  state$leaf_types <- integer()

  record_leaf_type <- function(type) {
    if (!type %in% names(state$leaf_types)) {
      state$leaf_types[[type]] <- 0L
    }
    state$leaf_types[[type]] <- state$leaf_types[[type]] + 1L
  }

  visit <- function(value, path, depth, role = "element") {
    if (state$node_count >= .capr_nested_limits$nodes) {
      state$truncated <- TRUE
      return(invisible(NULL))
    }
    state$node_count <- state$node_count + 1L
    state$max_depth <- max(state$max_depth, as.integer(depth))
    container_kind <- capr_nested_container_kind(value)
    value_type <- typeof(value)
    size <- capr_nested_safe_length(value)
    node <- list(
      path = capr_descriptor_bound_string(path, 240L),
      role = role,
      kind = container_kind %||% "leaf",
      type = value_type,
      classes = capr_nested_classes(value),
      length = if (is.na(size)) NULL else size,
      dimensions = capr_nested_dimensions(value)
    )

    if (is.null(container_kind)) {
      state$leaf_count <- state$leaf_count + 1L
      record_leaf_type(value_type)
      node$traversed <- FALSE
      node$reason <- if (is.environment(value)) {
        "environment_not_traversed"
      } else if (is.function(value)) {
        "function_not_executed"
      } else if (isS4(value)) {
        "s4_object_not_traversed"
      } else if (typeof(value) %in% c("externalptr", "weakref", "promise")) {
        "external_resource_not_traversed"
      } else if (is.language(value)) {
        "language_not_evaluated"
      } else {
        "leaf_value_omitted"
      }
      state$nodes[[length(state$nodes) + 1L]] <- node
      return(invisible(NULL))
    }

    state$container_count <- state$container_count + 1L
    total <- size %||% 0L
    node$children <- total
    node$traversed <- depth < .capr_nested_limits$depth
    if (depth >= .capr_nested_limits$depth) {
      node$reason <- "depth_limit"
      state$truncated <- state$truncated || total > 0L
      state$nodes[[length(state$nodes) + 1L]] <- node
      return(invisible(NULL))
    }

    count <- min(total, .capr_nested_limits$children)
    node$children_captured <- as.integer(count)
    node$children_truncated <- total > count
    if (total > count) state$truncated <- TRUE
    state$nodes[[length(state$nodes) + 1L]] <- node
    if (!count) return(invisible(NULL))

    child_names <- capr_nested_child_names(value, count)
    plain <- capr_nested_plain_list(value)
    if (is.null(plain)) {
      state$truncated <- TRUE
      return(invisible(NULL))
    }
    for (index in seq_len(count)) {
      child <- .subset2(plain, index)
      child_role <- if (is.data.frame(value) && is.list(child)) {
        "list_column"
      } else if (is.data.frame(value)) {
        "column"
      } else {
        "element"
      }
      visit(
        child,
        capr_nested_path(path, child_names[[index]], index),
        depth + 1L,
        child_role
      )
      if (state$node_count >= .capr_nested_limits$nodes) {
        state$truncated <- TRUE
        break
      }
    }
    invisible(NULL)
  }

  visit(x, "$", 0L, if (is_nested_table) "nested_table" else "root")
  leaf_types <- if (length(state$leaf_types)) {
    type_names <- sort(names(state$leaf_types), method = "radix")
    lapply(type_names, function(type) {
      list(type = type, count = as.integer(state$leaf_types[[type]]))
    })
  } else {
    list()
  }

  overview <- if (is_nested_table) {
    list(
      kind = "nested_table",
      classes = capr_nested_classes(x),
      rows = capr_nested_table_rows(x),
      columns = as.integer(length(capr_nested_plain_list(x))),
      list_columns = as.integer(length(list_columns))
    )
  } else {
    list(
      kind = "plain_list",
      classes = capr_nested_classes(x),
      length = as.integer(length(capr_nested_plain_list(x)))
    )
  }
  list(
    overview = overview,
    structure = list(
      nodes = state$nodes,
      node_limit = .capr_nested_limits$nodes,
      depth_limit = .capr_nested_limits$depth,
      child_limit = .capr_nested_limits$children,
      truncated = isTRUE(state$truncated)
    ),
    semantics = list(
      max_depth_observed = as.integer(state$max_depth),
      nodes_captured = as.integer(state$node_count),
      containers = as.integer(state$container_count),
      leaves = as.integer(state$leaf_count),
      leaf_types = leaf_types,
      list_columns = as.list(capr_descriptor_bound_string(
        utils::head(list_columns, .capr_nested_limits$names)
      )),
      payload_values_disclosed = FALSE,
      executable_objects_evaluated = FALSE,
      truncated = isTRUE(state$truncated)
    )
  )
}

capr_nested_xml_api <- function(name) {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    capr_abort(
      "capr_adapter_invalid",
      "xml2 is required to inspect xml_document and xml_node objects",
      package = "xml2"
    )
  }
  getExportedValue("xml2", name)
}

capr_nested_xml_method <- function(generic, class) {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    capr_abort(
      "capr_adapter_invalid",
      "xml2 is required to inspect xml_document and xml_node objects",
      package = "xml2"
    )
  }
  utils::getS3method(generic, class, envir = asNamespace("xml2"))
}

capr_nested_xml_children <- function(node, limit) {
  plain_node <- capr_nested_plain_list(node)
  node_names <- capr_nested_plain_atomic(
    attr(plain_node, "names", exact = TRUE)
  )
  if (!is.list(plain_node) || !is.character(node_names) ||
      !all(c("node", "doc") %in% node_names)) {
    return(NULL)
  }
  node_pointer <- .subset2(plain_node, "node")
  document_pointer <- .subset2(plain_node, "doc")
  if (typeof(node_pointer) != "externalptr" ||
      typeof(document_pointer) != "externalptr") {
    return(NULL)
  }
  find_first <- capr_nested_xml_method("xml_find_first", "xml_node")
  result <- vector("list", limit)
  count <- 0L
  for (index in seq_len(limit)) {
    child <- tryCatch(
      find_first(
        plain_node,
        sprintf("./*[%d]", index),
        ns = character()
      ),
      error = function(e) NULL
    )
    if (is.null(child) || inherits(child, "xml_missing")) break
    count <- count + 1L
    result[[count]] <- child
  }
  result[seq_len(count)]
}

capr_nested_xml_snapshot <- function(x) {
  if (!inherits(x, "xml_node") && !inherits(x, "xml_document")) {
    capr_abort(
      "capr_adapter_invalid",
      "the XML probe requires an xml_document or xml_node",
      classes = unname(class(x))
    )
  }
  xml_name <- capr_nested_xml_api("xml_name")
  root <- x

  state <- new.env(parent = emptyenv())
  state$nodes <- list()
  state$count <- 0L
  state$max_depth <- 0L
  state$truncated <- FALSE

  visit <- function(node, path, depth) {
    if (state$count >= .capr_nested_limits$nodes) {
      state$truncated <- TRUE
      return(invisible(NULL))
    }
    state$count <- state$count + 1L
    state$max_depth <- max(state$max_depth, as.integer(depth))
    name <- capr_descriptor_bound_string(xml_name(node), 80L)
    children <- capr_nested_xml_children(
      node, .capr_nested_limits$children + 1L
    )
    if (!is.list(children)) {
      capr_abort(
        "capr_adapter_invalid",
        "XML child metadata could not be normalized without dispatch"
      )
    }
    observed <- length(children)
    has_extra <- observed > .capr_nested_limits$children
    count <- if (depth < .capr_nested_limits$depth) {
      min(observed, .capr_nested_limits$children)
    } else {
      0L
    }
    truncated <- has_extra || (depth >= .capr_nested_limits$depth && observed > 0L)
    if (truncated) state$truncated <- TRUE
    state$nodes[[length(state$nodes) + 1L]] <- list(
      path = capr_descriptor_bound_string(path, 240L),
      name = name,
      child_elements_observed = as.integer(observed),
      child_count_exact = !has_extra,
      children_captured = as.integer(count),
      truncated = truncated
    )
    if (!count) return(invisible(NULL))
    child_seen <- list()
    for (index in seq_len(count)) {
      child <- .subset2(children, index)
      child_name <- capr_descriptor_bound_string(xml_name(child), 80L)
      child_seen[[child_name]] <- (child_seen[[child_name]] %||% 0L) + 1L
      visit(
        child,
        sprintf("%s/%s[%d]", path, child_name, child_seen[[child_name]]),
        depth + 1L
      )
      if (state$count >= .capr_nested_limits$nodes) {
        state$truncated <- TRUE
        break
      }
    }
    invisible(NULL)
  }

  root_name <- capr_descriptor_bound_string(xml_name(root), 80L)
  visit(root, paste0("/", root_name, "[1]"), 0L)
  list(
    overview = list(
      kind = if (inherits(x, "xml_document")) "xml_document" else "xml_node",
      classes = capr_nested_classes(x),
      root = root_name,
      elements_captured = as.integer(state$count)
    ),
    structure = list(
      elements = state$nodes,
      node_limit = .capr_nested_limits$nodes,
      depth_limit = .capr_nested_limits$depth,
      child_limit = .capr_nested_limits$children,
      truncated = isTRUE(state$truncated)
    ),
    semantics = list(
      max_depth_observed = as.integer(state$max_depth),
      attribute_names_inspected = FALSE,
      text_values_disclosed = FALSE,
      attribute_values_disclosed = FALSE,
      external_resources_accessed = FALSE,
      truncated = isTRUE(state$truncated)
    )
  )
}

capr_nested_json_snapshot <- function(x) {
  raw <- capr_nested_plain_atomic(x)
  if (!inherits(x, "json") || !is.character(raw) || length(raw) != 1L ||
      is.na(raw)) {
    capr_abort(
      "capr_adapter_invalid",
      "the JSON probe requires one non-missing jsonlite `json` string",
      classes = unname(class(x))
    )
  }
  bytes <- nchar(raw, type = "bytes")
  if (bytes > 1000000L) {
    capr_abort(
      "capr_adapter_invalid",
      "JSON metadata input exceeds the one-megabyte parsing bound",
      bytes = bytes
    )
  }
  literal <- sub("^[[:space:]]+", "", enc2utf8(raw))
  if (!startsWith(literal, "{") && !startsWith(literal, "[")) {
    capr_abort(
      "capr_adapter_invalid",
      "JSON input must be an inline object or array; paths and URLs are denied"
    )
  }
  parsed <- tryCatch(
    jsonlite::fromJSON(literal, simplifyVector = FALSE),
    error = function(e) capr_abort(
      "capr_adapter_invalid",
      "inline JSON could not be parsed within the bounded nested probe",
      parent = e
    )
  )
  snapshot <- capr_nested_list_snapshot(parsed)
  snapshot$overview$kind <- "json"
  snapshot$overview$classes <- capr_nested_classes(x)
  snapshot$overview$encoded_bytes <- as.integer(bytes)
  snapshot$semantics$parsed_inline <- TRUE
  snapshot$semantics$paths_or_urls_opened <- FALSE
  snapshot
}

capr_nested_snapshot <- function(x) {
  if (inherits(x, "json")) {
    capr_nested_json_snapshot(x)
  } else if (inherits(x, "xml_node") || inherits(x, "xml_document")) {
    capr_nested_xml_snapshot(x)
  } else {
    capr_nested_list_snapshot(x)
  }
}

#' Construct the experimental nested-object adapter
#'
#' The adapter describes bounded container topology and leaf types without
#' disclosing leaf, XML text, or XML attribute values. Environments, functions,
#' language objects, and external resources are not traversed or evaluated.
#' Traversal is capped at depth four, 80 nodes, and 20 children per container;
#' inline JSON is capped at one megabyte.
#'
#' @return A validated experimental adapter for plain lists, tables with
#'   list-columns, inline jsonlite JSON, and xml2 document/node objects.
#' @export
cap_nested_adapter <- function() {
  capr_new_descriptor_adapter(
    id = "org.capr.nested",
    family = "nested",
    label = "nested object",
    snapshot_fn = capr_nested_snapshot,
    semantic_level = "structural",
    capabilities = list(
      bounded_depth = .capr_nested_limits$depth,
      bounded_nodes = .capr_nested_limits$nodes,
      leaf_values_disclosed = FALSE,
      xml_text_disclosed = FALSE
    ),
    implementation_spec = capr_builtin_implementation_spec(
      prefixes = "capr_nested_",
      symbols = "capr_data_frame_row_count",
      constants = list(limits = .capr_nested_limits)
    )
  )
}

capr_array_kind <- function(x) {
  if (isS4(x) && methods::is(x, "HDF5Array")) return("hdf5_array")
  if (isS4(x) && methods::is(x, "DelayedArray")) return("delayed_array")
  if (isS4(x) && methods::is(x, "Matrix")) {
    if (methods::is(x, "sparseMatrix")) "sparse_matrix" else "matrix_class"
  } else if (inherits(x, "matrix") && inherits(x, "array")) {
    "base_matrix"
  } else if (inherits(x, "array")) {
    "base_array"
  } else {
    capr_abort(
      "capr_adapter_invalid",
      paste(
        "the array adapter requires a matrix, array, Matrix, DelayedArray,",
        "or HDF5Array object"
      ),
      classes = unname(class(x))
    )
  }
}

capr_array_cached_dimensions <- function(x, depth = 0L) {
  if (depth > 8L) return(NULL)
  if (!isS4(x)) {
    return(capr_nested_plain_atomic(attr(x, "dim", exact = TRUE)))
  }
  slots <- capr_array_slots(x)
  if ("Dim" %in% slots) {
    return(capr_nested_plain_atomic(methods::slot(x, "Dim")))
  }
  first_class <- unname(class(x))[[1L]]
  if ("dim" %in% slots && first_class %in% c(
    "HDF5ArraySeed", "TENxMatrixSeed"
  )) {
    return(capr_nested_plain_atomic(methods::slot(x, "dim")))
  }
  if (".Data" %in% slots) {
    dimensions <- capr_nested_plain_atomic(
      attr(methods::slot(x, ".Data"), "dim", exact = TRUE)
    )
    if (!is.null(dimensions)) return(dimensions)
  }
  if ("seed" %in% slots) {
    return(capr_array_cached_dimensions(
      methods::slot(x, "seed"), depth = depth + 1L
    ))
  }
  if ("seeds" %in% slots) {
    seeds <- capr_nested_plain_list(methods::slot(x, "seeds"))
    if (!is.null(seeds) && length(seeds)) {
      return(capr_array_cached_dimensions(
        .subset2(seeds, 1L), depth = depth + 1L
      ))
    }
  }
  NULL
}

capr_array_dimensions <- function(x) {
  dimensions <- capr_nested_plain_atomic(capr_array_cached_dimensions(x))
  if (is.null(dimensions) || !is.numeric(dimensions) ||
      length(dimensions) > .capr_array_rank_limit || anyNA(dimensions) ||
      any(!is.finite(dimensions)) || any(dimensions < 0) ||
      any(dimensions != floor(dimensions)) ||
      any(dimensions > .Machine$integer.max)) {
    capr_abort(
      "capr_adapter_invalid",
      "array metadata must provide at most 64 finite integer dimensions",
      classes = unname(class(x))
    )
  }
  as.integer(unname(dimensions))
}

capr_array_stored_entries <- function(x, kind) {
  if (!identical(kind, "sparse_matrix") || !isS4(x)) return(NULL)
  slots <- capr_array_slots(x)
  index_slot <- if ("i" %in% slots) "i" else if ("j" %in% slots) "j" else NULL
  if (is.null(index_slot)) return(NULL)
  index <- capr_nested_plain_atomic(methods::slot(x, index_slot))
  if (is.null(index)) return(NULL)
  as.integer(length(index))
}

capr_array_dimnames_status <- function(x) {
  if (!isS4(x)) {
    return(if (is.null(attr(x, "dimnames", exact = TRUE))) "absent" else "present")
  }
  if ("Dimnames" %in% capr_array_slots(x)) "available_not_read" else "unknown"
}

capr_array_snapshot <- function(x) {
  kind <- capr_array_kind(x)
  dimensions <- capr_array_dimensions(x)
  is_sparse <- identical(kind, "sparse_matrix")
  is_delayed <- kind %in% c("delayed_array", "hdf5_array")
  is_file_backed <- identical(kind, "hdf5_array")
  axes <- lapply(seq_along(dimensions), function(index) {
    list(index = as.integer(index), size = dimensions[[index]])
  })
  list(
    overview = list(
      kind = kind,
      classes = capr_nested_classes(x),
      rank = as.integer(length(dimensions)),
      dimensions = as.list(dimensions),
      cells = as.numeric(prod(as.double(dimensions)))
    ),
    structure = list(
      axes = axes,
      storage_type = if (isS4(x)) "S4" else typeof(x),
      dimension_names = capr_array_dimnames_status(x),
      sparse = is_sparse,
      delayed = is_delayed,
      file_backed = is_file_backed,
      stored_entries = capr_array_stored_entries(x, kind)
    ),
    semantics = list(
      payload_values_disclosed = FALSE,
      payload_materialized = FALSE,
      delayed_operations_evaluated = FALSE,
      backing_path_disclosed = FALSE,
      dimension_name_values_disclosed = FALSE,
      structural_fingerprint_only = TRUE
    )
  )
}

#' Construct the experimental array adapter
#'
#' The adapter reports bounded shape and storage metadata for base, Matrix, and
#' delayed arrays with at most 64 dimensions. It never indexes array cells,
#' coerces delayed objects, reads HDF5 payload values, or discloses backing
#' paths or dimension-name values.
#'
#' @return A validated experimental adapter for matrix-like and array objects.
#' @export
cap_array_adapter <- function() {
  capr_new_descriptor_adapter(
    id = "org.capr.array",
    family = "array",
    label = "array object",
    snapshot_fn = capr_array_snapshot,
    semantic_level = "structural",
    capabilities = list(
      sparse_metadata = TRUE,
      delayed_metadata = TRUE,
      payload_values_disclosed = FALSE,
      backing_paths_disclosed = FALSE
    ),
    implementation_spec = capr_builtin_implementation_spec(
      prefixes = "capr_array_",
      symbols = c(
        "capr_nested_classes", "capr_nested_plain_atomic",
        "capr_nested_plain_list"
      ),
      constants = list(rank_limit = .capr_array_rank_limit)
    )
  )
}
