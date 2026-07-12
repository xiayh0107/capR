.capr_gs_max_components <- 50L
.capr_gs_rank_limit <- 64L

capr_gs_class <- function(x) {
  classes <- unname(class(x))
  if (!length(classes)) {
    typeof(x)
  } else {
    capr_descriptor_bound_string(classes[[1L]])
  }
}

capr_gs_classes <- function(x) {
  classes <- unname(class(x))
  count <- min(length(classes), .capr_gs_max_components)
  as.list(capr_descriptor_bound_string(classes[seq_len(count)]))
}

capr_gs_attribute_names <- function(x) {
  values <- capr_gs_plain_atomic(
    attr(attributes(x), "names", exact = TRUE)
  )
  if (!is.character(values)) return(character())
  count <- min(length(values), .capr_gs_max_components)
  out <- enc2utf8(values[seq_len(count)])
  if (length(values) > count) {
    out <- c(out, sprintf("[truncated: %d more]", length(values) - count))
  }
  out
}

capr_gs_plain_list <- function(x) {
  if (!is.list(x) || isS4(x) || is.environment(x)) return(NULL)
  value <- if (is.object(x)) {
    tryCatch(unclass(x), error = function(e) NULL)
  } else {
    x
  }
  if (is.list(value)) value else NULL
}

capr_gs_plain_atomic <- function(x) {
  if (!is.atomic(x) || isS4(x)) return(NULL)
  if (is.object(x)) tryCatch(unclass(x), error = function(e) NULL) else x
}

capr_gs_slots <- function(x) {
  slots <- methods::slotNames(x)
  if (length(slots) > 100L) {
    capr_abort(
      "capr_adapter_invalid",
      "scientific metadata objects with more than 100 slots are not inspected"
    )
  }
  slots
}

capr_gs_list_names <- function(x) {
  x <- capr_gs_plain_list(x)
  if (is.null(x)) return(character())
  values <- capr_gs_plain_atomic(attr(x, "names", exact = TRUE))
  if (!is.character(values)) return(character())
  count <- min(length(values), .capr_gs_max_components)
  enc2utf8(values[seq_len(count)])
}

capr_gs_count <- function(x, label) {
  x <- capr_gs_plain_atomic(x)
  if (!is.numeric(x) || length(x) != 1L || is.na(x) ||
      !is.finite(x) || x < 0 || x != floor(x) || x > .Machine$integer.max) {
    capr_abort(
      "capr_adapter_invalid",
      sprintf("invalid %s metadata", label),
      field = label
    )
  }
  as.integer(x)
}

capr_gs_plain_data_frame_schema <- function(x) {
  classes <- unname(class(x))
  if (!is.list(x) || !any(classes %in% c("data.frame", "tbl_df", "tbl"))) {
    return(list(
      kind = "unsupported",
      classes = as.list(classes),
      rows = 0L,
      columns = 0L,
      column_names = list()
    ))
  }
  all_column_names <- capr_gs_plain_atomic(attr(x, "names", exact = TRUE))
  if (!is.character(all_column_names)) all_column_names <- character()
  name_count <- min(length(all_column_names), .capr_gs_max_components)
  column_names <- enc2utf8(all_column_names[seq_len(name_count)])
  rows <- capr_data_frame_row_count(x)
  list(
    kind = if ("tbl_df" %in% classes) "tibble" else "data.frame",
    classes = as.list(enc2utf8(classes)),
    rows = as.integer(rows),
    columns = as.integer(length(all_column_names)),
    column_names = as.list(column_names),
    truncated = length(all_column_names) > name_count
  )
}

capr_gs_dframe_schema <- function(x) {
  if (!isS4(x)) return(capr_gs_plain_data_frame_schema(x))
  slots <- capr_gs_slots(x)
  if (!all(c("nrows", "listData") %in% slots)) {
    return(list(
      kind = "unsupported",
      classes = capr_gs_classes(x),
      rows = 0L,
      columns = 0L,
      column_names = list()
    ))
  }
  rows <- methods::slot(x, "nrows")
  data <- methods::slot(x, "listData")
  data <- capr_gs_plain_list(data)
  if (is.null(data)) {
    capr_abort(
      "capr_adapter_invalid",
      "scientific metadata container has a non-list listData slot"
    )
  }
  column_names <- capr_gs_list_names(data)
  list(
    kind = "DFrame",
    classes = capr_gs_classes(x),
    rows = capr_gs_count(rows, "metadata row count"),
    columns = as.integer(length(data)),
    column_names = as.list(column_names),
    truncated = length(data) > length(column_names)
  )
}

capr_gs_dimension_vector <- function(value) {
  value <- capr_gs_plain_atomic(value)
  if (!is.numeric(value) || !length(value) ||
      length(value) > .capr_gs_rank_limit || anyNA(value) ||
      any(!is.finite(value)) || any(value < 0) ||
      any(value != floor(value)) ||
      any(value > .Machine$integer.max)) {
    return(NULL)
  }
  as.integer(value)
}

capr_gs_assay_dimensions <- function(x, depth = 0L) {
  sentinel <- "[dimensions unavailable: payload not inspected]"
  if (depth > 2L || is.null(x) || is.function(x) || is.environment(x) ||
      typeof(x) %in% c("externalptr", "weakref", "promise")) {
    return(sentinel)
  }

  direct <- attr(x, "dim", exact = TRUE)
  direct <- capr_gs_dimension_vector(direct)
  if (!is.null(direct)) return(as.list(direct))

  if (!isS4(x)) return(sentinel)
  slots <- capr_gs_slots(x)
  if ("Dim" %in% slots) {
    direct <- capr_gs_dimension_vector(methods::slot(x, "Dim"))
    if (!is.null(direct)) return(as.list(direct))
  }
  if ("dim" %in% slots && capr_gs_class(x) %in% c(
    "HDF5ArraySeed", "TENxMatrixSeed"
  )) {
    direct <- capr_gs_dimension_vector(methods::slot(x, "dim"))
    if (!is.null(direct)) return(as.list(direct))
  }
  if (".Data" %in% slots) {
    payload <- methods::slot(x, ".Data")
    direct <- capr_gs_dimension_vector(attr(payload, "dim", exact = TRUE))
    if (!is.null(direct)) return(as.list(direct))
  }
  if ("seed" %in% slots && capr_gs_class(x) %in% c(
    "HDF5Array", "HDF5Matrix"
  )) {
    return(capr_gs_assay_dimensions(
      methods::slot(x, "seed"),
      depth = depth + 1L
    ))
  }
  sentinel
}

capr_gs_named_schema <- function(items, fallback_dimensions = NULL) {
  items <- capr_gs_plain_list(items)
  if (is.null(items)) {
    capr_abort(
      "capr_adapter_invalid",
      "component schema requires a plain list"
    )
  }
  total <- length(items)
  count <- min(total, .capr_gs_max_components)
  raw_names <- capr_gs_plain_atomic(attr(items, "names", exact = TRUE))
  item_names <- if (!is.null(raw_names) && length(raw_names) == total) {
    enc2utf8(raw_names[seq_len(count)])
  } else {
    sprintf("unnamed_%d", seq_len(count))
  }
  out <- lapply(seq_len(count), function(index) {
    item <- .subset2(items, index)
    dimensions <- capr_gs_assay_dimensions(item)
    if (is.character(dimensions) && !is.null(fallback_dimensions)) {
      dimensions <- as.list(as.integer(fallback_dimensions))
    }
    list(
      name = item_names[[index]],
      class = capr_gs_class(item),
      dimensions = dimensions
    )
  })
  if (total > count) {
    out[[length(out) + 1L]] <- list(
      name = "[truncated]",
      class = "sentinel",
      dimensions = sprintf("[%d more components not inspected]", total - count)
    )
  }
  out
}

capr_graph_igraph_metadata <- function(x, kind) {
  raw <- unclass(x)
  if (!is.list(raw) || length(raw) < 9L) {
    capr_abort(
      "capr_adapter_invalid",
      "igraph metadata does not match the bounded internal layout"
    )
  }
  vertices <- raw[[1L]]
  directed <- capr_gs_plain_atomic(.subset2(raw, 2L))
  from <- capr_gs_plain_atomic(.subset2(raw, 3L))
  to <- capr_gs_plain_atomic(.subset2(raw, 4L))
  attributes <- capr_gs_plain_list(.subset2(raw, 9L))
  if (!is.logical(directed) || length(directed) != 1L || is.na(directed) ||
      !is.atomic(from) || !is.atomic(to) ||
      length(from) != length(to) ||
      is.null(attributes) || length(attributes) < 4L) {
    capr_abort(
      "capr_adapter_invalid",
      "igraph metadata contains unsupported or malformed components"
    )
  }
  list(
    kind = kind,
    vertices = capr_gs_count(vertices, "vertex count"),
    edges = capr_gs_count(length(from), "edge count"),
    directed = directed,
    graph_attributes = capr_gs_list_names(.subset2(attributes, 2L)),
    vertex_attributes = capr_gs_list_names(.subset2(attributes, 3L)),
    edge_attributes = capr_gs_list_names(.subset2(attributes, 4L)),
    component_names = character()
  )
}

capr_graph_phylo_metadata <- function(x, kind = "phylo") {
  if (!identical(capr_gs_class(x), "phylo")) {
    capr_abort(
      "capr_adapter_invalid",
      "tree metadata requires an exact phylo component"
    )
  }
  raw <- unclass(x)
  if (!is.list(raw)) {
    capr_abort("capr_adapter_invalid", "phylo metadata is not list-backed")
  }
  component_names <- capr_gs_list_names(raw)
  edge <- .subset2(raw, "edge")
  edge_dim <- capr_gs_dimension_vector(attr(edge, "dim", exact = TRUE))
  tips <- capr_gs_plain_atomic(.subset2(raw, "tip.label"))
  nodes <- capr_gs_plain_atomic(.subset2(raw, "Nnode"))
  if (is.null(edge_dim) || length(edge_dim) != 2L || edge_dim[[2L]] != 2L ||
      !is.character(tips)) {
    capr_abort(
      "capr_adapter_invalid",
      "phylo metadata contains unsupported edge or tip structures"
    )
  }
  list(
    kind = kind,
    vertices = capr_gs_count(
      length(tips) + capr_gs_count(nodes, "node count"),
      "vertex count"
    ),
    edges = edge_dim[[1L]],
    directed = TRUE,
    tips = capr_gs_count(length(tips), "tip count"),
    internal_nodes = capr_gs_count(nodes, "node count"),
    has_edge_lengths = "edge.length" %in% component_names,
    graph_attributes = character(),
    vertex_attributes = character(),
    edge_attributes = character(),
    component_names = component_names
  )
}

capr_graph_treedata_metadata <- function(x) {
  if (!isS4(x) || !identical(capr_gs_class(x), "treedata")) {
    capr_abort("capr_adapter_invalid", "invalid treedata source")
  }
  slots <- capr_gs_slots(x)
  if (!"phylo" %in% slots) {
    capr_abort("capr_adapter_invalid", "treedata source has no phylo slot")
  }
  out <- capr_graph_phylo_metadata(methods::slot(x, "phylo"), "treedata")
  out$component_names <- capr_descriptor_bound_string(slots)
  out$data_schema <- if ("data" %in% slots) {
    capr_gs_plain_data_frame_schema(methods::slot(x, "data"))
  } else {
    list(kind = "none", rows = 0L, columns = 0L, column_names = list())
  }
  out$extra_info_schema <- if ("extraInfo" %in% slots) {
    capr_gs_plain_data_frame_schema(methods::slot(x, "extraInfo"))
  } else {
    list(kind = "none", rows = 0L, columns = 0L, column_names = list())
  }
  out
}

capr_graph_snapshot <- function(x) {
  classes <- unname(class(x))
  if (length(classes) > .capr_gs_max_components) {
    capr_abort(
      "capr_adapter_invalid",
      "graph objects with more than 50 classes are not inspected"
    )
  }
  first <- if (length(classes)) classes[[1L]] else ""
  metadata <- if (identical(first, "tbl_graph") && "igraph" %in% classes) {
    capr_graph_igraph_metadata(x, "tbl_graph")
  } else if (identical(first, "igraph")) {
    capr_graph_igraph_metadata(x, "igraph")
  } else if (identical(first, "phylo")) {
    capr_graph_phylo_metadata(x)
  } else if (identical(first, "treedata")) {
    capr_graph_treedata_metadata(x)
  } else {
    capr_abort(
      "capr_adapter_invalid",
      "graph adapter supports only igraph, tbl_graph, phylo, and treedata",
      classes = classes
    )
  }

  list(
    overview = list(
      kind = metadata$kind,
      classes = capr_gs_classes(x),
      vertices = metadata$vertices,
      edges = metadata$edges,
      directed = metadata$directed
    ),
    structure = list(
      object_attribute_names = as.list(capr_gs_attribute_names(x)),
      graph_attribute_names = as.list(metadata$graph_attributes),
      vertex_attribute_names = as.list(metadata$vertex_attributes),
      edge_attribute_names = as.list(metadata$edge_attributes),
      component_names = as.list(metadata$component_names),
      data_schema = metadata$data_schema %||% NULL,
      extra_info_schema = metadata$extra_info_schema %||% NULL
    ),
    semantics = list(
      tips = metadata$tips %||% NULL,
      internal_nodes = metadata$internal_nodes %||% NULL,
      has_edge_lengths = metadata$has_edge_lengths %||% NULL,
      payload = paste(
        "[edge endpoints, tip labels, and attribute values not inspected]"
      )
    )
  )
}

#' Construct the experimental graph and tree metadata adapter
#'
#' The adapter supports explicit `igraph`, `tbl_graph`, `phylo`, and
#' `treedata` sources. It reports only bounded counts, schema names, and
#' attribute names; edge endpoints, tip-label values, attribute values, and
#' executable components are never traversed.
#'
#' @return A metadata-only experimental adapter with no conformance claim.
#' @export
cap_graph_adapter <- function() {
  capr_new_descriptor_adapter(
    id = "org.capr.graph",
    family = "graph",
    label = "Graph and tree",
    snapshot_fn = capr_graph_snapshot,
    capabilities = list(
      topology_values_disclosed = FALSE,
      labels_disclosed = FALSE,
      attribute_values_disclosed = FALSE
    ),
    implementation_spec = capr_builtin_implementation_spec(
      prefixes = c("capr_graph_", "capr_gs_"),
      constants = list(
        component_limit = .capr_gs_max_components,
        rank_limit = .capr_gs_rank_limit
      )
    )
  )
}

capr_scientific_se_assays <- function(x) {
  slots <- capr_gs_slots(x)
  if (!all(c("assays", "colData", "elementMetadata") %in% slots)) {
    capr_abort(
      "capr_adapter_invalid",
      "SummarizedExperiment metadata is missing required slots"
    )
  }
  assays <- methods::slot(x, "assays")
  if (!isS4(assays) || !"data" %in% capr_gs_slots(assays)) {
    capr_abort("capr_adapter_invalid", "unsupported assays container")
  }
  data <- methods::slot(assays, "data")
  if (!isS4(data) || !"listData" %in% capr_gs_slots(data)) {
    capr_abort("capr_adapter_invalid", "unsupported assay list container")
  }
  items <- methods::slot(data, "listData")
  items <- capr_gs_plain_list(items)
  if (is.null(items)) {
    capr_abort("capr_adapter_invalid", "assay payload index is not a list")
  }
  row_schema <- capr_gs_dframe_schema(methods::slot(x, "elementMetadata"))
  column_schema <- capr_gs_dframe_schema(methods::slot(x, "colData"))
  dimensions <- c(row_schema$rows, column_schema$rows)
  list(
    rows = row_schema$rows,
    columns = column_schema$rows,
    assay_count = as.integer(length(items)),
    assays = capr_gs_named_schema(items, dimensions),
    row_schema = row_schema,
    column_schema = column_schema
  )
}

capr_scientific_se_snapshot <- function(x, kind) {
  info <- capr_scientific_se_assays(x)
  slots <- capr_gs_slots(x)
  internal_components <- character()
  if (identical(kind, "SingleCellExperiment")) {
    for (slot_name in c("int_elementMetadata", "int_colData")) {
      if (slot_name %in% slots) {
        schema <- capr_gs_dframe_schema(methods::slot(x, slot_name))
        internal_components <- c(
          internal_components,
          unlist(schema$column_names, use.names = FALSE)
        )
      }
    }
  }
  list(
    overview = list(
      kind = kind,
      classes = capr_gs_classes(x),
      assays = info$assay_count,
      rows = info$rows,
      columns = info$columns
    ),
    structure = list(
      assay_schema = info$assays,
      row_metadata_schema = info$row_schema,
      column_metadata_schema = info$column_schema,
      slot_names = as.list(enc2utf8(slots)),
      object_attribute_names = as.list(capr_gs_attribute_names(x))
    ),
    semantics = list(
      internal_component_names = as.list(unique(internal_components)),
      payload = "[assay cells and metadata values not inspected]"
    )
  )
}

capr_scientific_seurat_assay <- function(name, assay) {
  if (!isS4(assay)) {
    return(list(
      name = name,
      class = capr_gs_class(assay),
      layers = list(list(
        name = "[unsupported]",
        class = capr_gs_class(assay),
        dimensions = "[dimensions unavailable: payload not inspected]"
      ))
    ))
  }
  slots <- capr_gs_slots(assay)
  layers <- list()
  if ("layers" %in% slots) {
    values <- methods::slot(assay, "layers")
    if (!is.list(values)) {
      capr_abort("capr_adapter_invalid", "Seurat layers slot is not a list")
    }
    layers <- capr_gs_named_schema(values)
  } else {
    layer_slots <- intersect(c("counts", "data", "scale.data"), slots)
    layers <- lapply(layer_slots, function(slot_name) {
      value <- methods::slot(assay, slot_name)
      list(
        name = slot_name,
        class = capr_gs_class(value),
        dimensions = capr_gs_assay_dimensions(value)
      )
    })
  }
  list(name = name, class = capr_gs_class(assay), layers = layers)
}

capr_scientific_seurat_snapshot <- function(x) {
  slots <- capr_gs_slots(x)
  if (!"assays" %in% slots) {
    capr_abort("capr_adapter_invalid", "Seurat source has no assays slot")
  }
  assays <- methods::slot(x, "assays")
  assays <- capr_gs_plain_list(assays)
  if (is.null(assays)) {
    capr_abort("capr_adapter_invalid", "Seurat assays slot is not a list")
  }
  total_assays <- length(assays)
  count <- min(total_assays, .capr_gs_max_components)
  raw_assay_names <- capr_gs_plain_atomic(
    attr(assays, "names", exact = TRUE)
  )
  assay_names <- if (!is.null(raw_assay_names) &&
      length(raw_assay_names) == total_assays) {
    enc2utf8(raw_assay_names[seq_len(count)])
  } else {
    sprintf("unnamed_%d", seq_len(count))
  }
  schemas <- lapply(seq_len(count), function(index) {
    capr_scientific_seurat_assay(
      assay_names[[index]], .subset2(assays, index)
    )
  })
  if (total_assays > count) {
    schemas[[length(schemas) + 1L]] <- list(
      name = "[truncated]",
      class = "sentinel",
      layers = list(list(
        name = "[truncated]",
        class = "sentinel",
        dimensions = sprintf(
          "[%d more assays not inspected]",
          total_assays - count
        )
      ))
    )
  }
  first_dimensions <- NULL
  if (length(schemas) && length(schemas[[1L]]$layers)) {
    candidate <- schemas[[1L]]$layers[[1L]]$dimensions
    if (is.list(candidate) && length(candidate) >= 2L) {
      first_dimensions <- unlist(candidate, use.names = FALSE)
    }
  }
  metadata_schema <- if ("meta.data" %in% slots) {
    capr_gs_plain_data_frame_schema(methods::slot(x, "meta.data"))
  } else {
    list(kind = "none", rows = 0L, columns = 0L, column_names = list())
  }
  component_slots <- intersect(
    c("graphs", "neighbors", "reductions", "images"),
    slots
  )
  components <- lapply(component_slots, function(slot_name) {
    value <- methods::slot(x, slot_name)
    value_plain <- capr_gs_plain_list(value)
    list(
      name = slot_name,
      count = if (!is.null(value_plain)) {
        as.integer(length(value_plain))
      } else {
        0L
      },
      attribute_names = if (!is.null(value_plain)) {
        as.list(capr_gs_list_names(value_plain))
      } else {
        list()
      }
    )
  })
  rows <- if (!is.null(first_dimensions)) {
    as.integer(first_dimensions[[1L]])
  } else {
    0L
  }
  columns <- if (!is.null(first_dimensions)) {
    as.integer(first_dimensions[[2L]])
  } else {
    metadata_schema$rows
  }
  list(
    overview = list(
      kind = "Seurat",
      classes = capr_gs_classes(x),
      assays = as.integer(total_assays),
      rows = rows,
      columns = columns
    ),
    structure = list(
      assay_schema = schemas,
      column_metadata_schema = metadata_schema,
      slot_names = as.list(enc2utf8(slots)),
      object_attribute_names = as.list(capr_gs_attribute_names(x))
    ),
    semantics = list(
      component_schema = components,
      payload = "[assay cells and metadata values not inspected]"
    )
  )
}

capr_scientific_phyloseq_snapshot <- function(x) {
  slots <- capr_gs_slots(x)
  component_slots <- intersect(
    c("otu_table", "tax_table", "sam_data", "phy_tree", "refseq"),
    slots
  )
  components <- lapply(component_slots, function(slot_name) {
    value <- methods::slot(x, slot_name)
    list(
      name = slot_name,
      class = capr_gs_class(value),
      dimensions = capr_gs_assay_dimensions(value),
      attribute_names = as.list(capr_gs_attribute_names(value))
    )
  })
  otu <- Filter(function(value) identical(value$name, "otu_table"), components)
  dimensions <- if (length(otu) && is.list(otu[[1L]]$dimensions)) {
    unlist(otu[[1L]]$dimensions, use.names = FALSE)
  } else {
    integer()
  }
  list(
    overview = list(
      kind = "phyloseq",
      classes = capr_gs_classes(x),
      assays = as.integer(length(otu)),
      rows = if (length(dimensions) >= 1L) as.integer(dimensions[[1L]]) else 0L,
      columns = if (length(dimensions) >= 2L) {
        as.integer(dimensions[[2L]])
      } else {
        0L
      }
    ),
    structure = list(
      component_schema = components,
      slot_names = as.list(enc2utf8(slots)),
      object_attribute_names = as.list(capr_gs_attribute_names(x))
    ),
    semantics = list(
      payload = paste(
        "[assay cells, taxon/sample identifiers, and metadata values",
        "not inspected]"
      )
    )
  )
}

capr_scientific_snapshot <- function(x) {
  classes <- unname(class(x))
  first <- if (length(classes)) classes[[1L]] else ""
  if (identical(first, "SingleCellExperiment")) {
    return(capr_scientific_se_snapshot(x, "SingleCellExperiment"))
  }
  if (first %in% c("SummarizedExperiment", "RangedSummarizedExperiment")) {
    return(capr_scientific_se_snapshot(x, "SummarizedExperiment"))
  }
  if (identical(first, "Seurat")) {
    return(capr_scientific_seurat_snapshot(x))
  }
  if (identical(first, "phyloseq")) {
    return(capr_scientific_phyloseq_snapshot(x))
  }
  capr_abort(
    "capr_adapter_invalid",
    paste(
      "scientific adapter supports only SummarizedExperiment,",
      "SingleCellExperiment, Seurat, and phyloseq"
    ),
    classes = classes
  )
}

#' Construct the experimental scientific-container metadata adapter
#'
#' The adapter supports explicit `SummarizedExperiment`,
#' `SingleCellExperiment`, `Seurat`, and `phyloseq` sources. It reports only
#' bounded component names, metadata schemas, and assay dimensions of rank at
#' most 64. Assay cells, row/column/sample/feature identifier values, and
#' metadata values are not disclosed; file-backed payloads are not
#' materialized.
#'
#' @return A metadata-only experimental adapter with no conformance claim.
#' @export
cap_scientific_adapter <- function() {
  capr_new_descriptor_adapter(
    id = "org.capr.scientific",
    family = "scientific",
    label = "Scientific container",
    snapshot_fn = capr_scientific_snapshot,
    capabilities = list(
      assay_values_disclosed = FALSE,
      identifiers_disclosed = FALSE,
      materializes_assays = FALSE
    ),
    implementation_spec = capr_builtin_implementation_spec(
      prefixes = c("capr_scientific_", "capr_gs_"),
      constants = list(
        component_limit = .capr_gs_max_components,
        rank_limit = .capr_gs_rank_limit
      )
    )
  )
}
