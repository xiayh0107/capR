.capr_plot_limits <- list(
  columns = 30L,
  mappings = 12L,
  layers = 20L,
  labels = 12L,
  scales = 12L,
  theme_elements = 30L,
  text = 120L
)

capr_plot_bounded_strings <- function(x, limit = .capr_plot_limits$columns) {
  if (is.object(x) && !isS4(x)) {
    x <- tryCatch(unclass(x), error = function(e) NULL)
  }
  if (is.null(x) || !is.atomic(x)) return(list())
  total <- length(x)
  count <- min(total, limit)
  out <- as.list(capr_descriptor_bound_string(
    x[seq_len(count)], .capr_plot_limits$text
  ))
  if (total > count) {
    out[[length(out) + 1L]] <- sprintf("[truncated: %d more]", total - count)
  }
  out
}

capr_plot_classes <- function(x) {
  capr_plot_bounded_strings(unname(class(x)))
}

capr_plot_unforced_binding <- function(x, name, default = NULL) {
  if (!is.environment(x) || !exists(name, envir = x, inherits = FALSE) ||
      bindingIsActive(name, x)) {
    return(default)
  }
  # `substitute()` returns an ordinary binding without forcing a delayed
  # promise. That lets us read standard ggproto metadata while keeping hostile
  # delayed bindings inert.
  tryCatch(
    do.call(substitute, list(as.name(name), x)),
    error = function(e) default
  )
}

capr_plot_get <- function(x, name, default = NULL) {
  if (is.null(x)) return(default)
  value <- attr(x, name, exact = TRUE)
  if (is.null(value) && is.environment(x)) {
    value <- capr_plot_unforced_binding(x, name, default)
  }
  if (is.null(value) && is.list(x)) {
    plain <- capr_plot_plain_list(x)
    plain_names <- capr_plot_plain_atomic(
      attr(plain, "names", exact = TRUE)
    )
    if (is.character(plain_names) && name %in% plain_names) {
      value <- .subset2(plain, name)
    }
  }
  if (is.null(value)) default else value
}

capr_plot_plain_list <- function(x) {
  if (!is.list(x) || isS4(x) || is.environment(x)) return(NULL)
  value <- if (is.object(x)) {
    tryCatch(unclass(x), error = function(e) NULL)
  } else {
    x
  }
  if (is.list(value)) value else NULL
}

capr_plot_plain_atomic <- function(x) {
  if (!is.atomic(x) || isS4(x)) return(NULL)
  value <- if (is.object(x)) {
    tryCatch(unclass(x), error = function(e) NULL)
  } else {
    x
  }
  if (is.atomic(value)) value else NULL
}

capr_plot_validate_source <- function(x) {
  if (!inherits(x, "ggplot")) {
    capr_abort(
      "capr_adapter_invalid",
      "the ggplot adapter requires an object inheriting from `ggplot`",
      classes = unname(class(x))
    )
  }
  layers <- capr_plot_get(x, "layers", NULL)
  mapping <- capr_plot_get(x, "mapping", NULL)
  facet <- capr_plot_get(x, "facet", NULL)
  coordinates <- capr_plot_get(x, "coordinates", NULL)
  if (!is.list(layers) || !is.list(mapping) ||
      is.null(facet) || is.null(coordinates)) {
    capr_abort(
      "capr_adapter_invalid",
      "the ggplot object is missing required declarative properties",
      classes = unname(class(x))
    )
  }
  invisible(x)
}

capr_plot_class_name <- function(x, default = "none") {
  classes <- unname(class(x))
  if (!length(classes)) default else capr_plot_bound_text(classes[[1L]])
}

capr_plot_bound_text <- function(x, limit = .capr_plot_limits$text) {
  if (is.object(x) && !isS4(x)) {
    x <- tryCatch(unclass(x), error = function(e) "[unsupported]")
  }
  if (!is.atomic(x) || length(x) != 1L) return("[unsupported]")
  capr_descriptor_bound_string(x, limit)[[1L]]
}

capr_plot_bound_lines <- function(lines, limit, marker = "[truncated]") {
  if (!length(lines)) return("")
  kept <- character()
  for (line in enc2utf8(as.character(lines))) {
    candidate <- paste(c(kept, line), collapse = "\n")
    if (nchar(candidate, type = "chars") > limit) {
      if (nchar(paste(c(kept, marker), collapse = "\n"),
        type = "chars"
      ) <= limit) {
        kept <- c(kept, marker)
      }
      break
    }
    kept <- c(kept, line)
  }
  paste(kept, collapse = "\n")
}

capr_plot_value_text <- function(value) {
  if (is.null(value)) return("NULL")
  if (inherits(value, "waiver")) return("[waiver]")
  if (is.function(value)) return("[function: not executed]")
  if (is.environment(value)) return("[environment: not traversed]")
  if (inherits(value, "formula")) {
    # Drop quosure/formula dispatch and its environment before base indexing.
    bare_formula <- value
    attributes(bare_formula) <- NULL
    if (length(bare_formula) == 2L) value <- bare_formula[[2L]]
  }
  if (is.expression(value)) {
    bare_expression <- if (is.object(value)) {
      tryCatch(unclass(value), error = function(e) expression())
    } else {
      value
    }
    if (length(bare_expression) == 1L) {
      value <- .subset2(bare_expression, 1L)
    } else {
      return(sprintf("[expression length=%d]", length(bare_expression)))
    }
  }
  if (is.name(value)) {
    return(capr_plot_bound_text(as.character(value)))
  }
  if (is.call(value)) {
    bare_call <- value
    attributes(bare_call) <- NULL
    operator <- if (length(bare_call)) .subset2(bare_call, 1L) else NULL
    if (is.name(operator)) {
      return(sprintf("[call: %s]", capr_plot_bound_text(
        as.character(operator), 80L
      )))
    }
    return("[call: not expanded]")
  }
  if (is.language(value)) {
    return("[language object: not expanded]")
  }
  if (is.atomic(value)) {
    if (is.object(value)) {
      value <- tryCatch(unclass(value), error = function(e) character())
    }
    if (!length(value)) return(sprintf("[%s length=0]", typeof(value)))
    if (length(value) != 1L || is.na(value)) {
      if (length(value) == 1L && is.na(value)) return("NA")
      return(sprintf("[%s length=%d]", typeof(value), length(value)))
    }
    return(capr_plot_bound_text(as.character(value)))
  }
  sprintf("[%s: not traversed]", capr_plot_class_name(value, typeof(value)))
}

capr_plot_mapping <- function(mapping) {
  mapping <- capr_plot_plain_list(mapping)
  if (is.null(mapping) || !length(mapping)) return(list())
  mapping_names <- capr_plot_plain_atomic(attr(mapping, "names", exact = TRUE))
  if (!is.character(mapping_names)) {
    mapping_names <- rep("[unnamed]", length(mapping))
  }
  count <- min(length(mapping), .capr_plot_limits$mappings)
  out <- lapply(seq_len(count), function(index) {
    list(
      aesthetic = capr_plot_bound_text(mapping_names[[index]]),
      expression = capr_plot_value_text(.subset2(mapping, index))
    )
  })
  if (length(mapping) > count) {
    out[[length(out) + 1L]] <- list(
      aesthetic = "[truncated]",
      expression = sprintf("%d more mappings", length(mapping) - count)
    )
  }
  out
}

capr_plot_data_schema <- function(data, inherited = FALSE) {
  if (is.null(data) || inherits(data, "waiver")) {
    return(list(
      kind = if (inherited) "inherited" else "none",
      classes = list(),
      rows = 0L,
      columns = 0L,
      column_schema = list(),
      truncated = FALSE
    ))
  }
  if (is.function(data)) {
    return(list(
      kind = "function_not_executed",
      classes = capr_plot_classes(data),
      rows = 0L,
      columns = 0L,
      column_schema = list(),
      truncated = FALSE
    ))
  }
  if (!is.data.frame(data)) {
    return(list(
      kind = "unsupported",
      classes = capr_plot_classes(data),
      rows = 0L,
      columns = 0L,
      column_schema = list(),
      truncated = FALSE
    ))
  }
  plain <- capr_plot_plain_list(data)
  column_names <- capr_plot_plain_atomic(
    attr(plain, "names", exact = TRUE)
  ) %||% character()
  if (!is.character(column_names)) column_names <- character()
  rows <- capr_data_frame_row_count(data)
  total <- length(plain)
  count <- min(total, .capr_plot_limits$columns)
  columns <- lapply(seq_len(count), function(index) {
    column <- .subset2(plain, index)
    list(
      name = capr_plot_bound_text(column_names[[index]]),
      type = capr_table_type(column),
      classes = capr_plot_classes(column)
    )
  })
  list(
    kind = if (inherits(data, "tbl_df")) "tibble" else "data.frame",
    classes = capr_plot_classes(data),
    rows = as.integer(rows),
    columns = as.integer(total),
    column_schema = columns,
    truncated = total > count
  )
}

capr_plot_facet_spec <- function(facet) {
  facet_class <- capr_plot_class_name(facet)
  params <- capr_plot_get(facet, "params", list())
  mappings <- list()
  for (part in c("facets", "rows", "cols")) {
    current <- capr_plot_mapping(capr_plot_get(params, part, list()))
    if (length(current)) {
      current <- lapply(current, function(entry) {
        entry$aesthetic <- paste0(part, ":", entry$aesthetic)
        entry
      })
      mappings <- c(mappings, current)
    }
  }
  list(class = facet_class, mappings = mappings)
}

capr_plot_label_spec <- function(labels) {
  labels <- capr_plot_plain_list(labels)
  if (is.null(labels) || !length(labels)) return(list())
  label_names <- capr_plot_plain_atomic(attr(labels, "names", exact = TRUE))
  if (!is.character(label_names)) {
    label_names <- rep("[unnamed]", length(labels))
  }
  count <- min(length(labels), .capr_plot_limits$labels)
  out <- lapply(seq_len(count), function(index) {
    list(
      name = capr_plot_bound_text(label_names[[index]]),
      value = capr_plot_value_text(.subset2(labels, index))
    )
  })
  if (length(labels) > count) {
    out[[length(out) + 1L]] <- list(
      name = "[truncated]",
      value = sprintf("%d more labels", length(labels) - count)
    )
  }
  out
}

capr_plot_scale_spec <- function(scales) {
  entries <- capr_plot_plain_list(
    capr_plot_get(scales, "scales", list())
  )
  if (!is.list(entries) || !length(entries)) return(list())
  count <- min(length(entries), .capr_plot_limits$scales)
  out <- lapply(seq_len(count), function(index) {
    scale <- .subset2(entries, index)
    aesthetics <- capr_plot_get(scale, "aesthetics", character())
    list(
      index = as.integer(index),
      class = capr_plot_class_name(scale),
      aesthetics = capr_plot_bounded_strings(
        aesthetics, .capr_plot_limits$mappings
      )
    )
  })
  if (length(entries) > count) {
    out[[length(out) + 1L]] <- list(
      index = as.integer(count + 1L),
      class = "[truncated]",
      aesthetics = list(sprintf("%d more scales", length(entries) - count))
    )
  }
  out
}

capr_plot_theme_spec <- function(theme) {
  if (is.null(theme)) {
    return(list(class = "none", complete = FALSE, elements = list()))
  }
  plain <- capr_plot_plain_list(theme)
  element_names <- capr_plot_plain_atomic(attr(plain, "names", exact = TRUE))
  if (!is.character(element_names)) element_names <- character()
  count <- min(length(element_names), .capr_plot_limits$theme_elements)
  complete <- capr_plot_get(theme, "complete", FALSE)
  list(
    class = capr_plot_class_name(theme),
    complete = isTRUE(complete),
    elements = lapply(
      element_names[seq_len(count)], capr_plot_bound_text
    ),
    truncated = length(element_names) > count
  )
}

capr_plot_layer_spec <- function(layers) {
  layers <- capr_plot_plain_list(layers)
  if (is.null(layers) || !length(layers)) return(list())
  count <- min(length(layers), .capr_plot_limits$layers)
  out <- lapply(seq_len(count), function(index) {
    layer <- .subset2(layers, index)
    data <- capr_plot_data_schema(
      capr_plot_get(layer, "data", NULL),
      inherited = TRUE
    )
    fixed <- capr_plot_plain_atomic(attr(capr_plot_plain_list(
      capr_plot_get(layer, "aes_params", list())
    ), "names", exact = TRUE))
    geom_parameters <- capr_plot_plain_atomic(attr(capr_plot_plain_list(
      capr_plot_get(layer, "geom_params", list())
    ), "names", exact = TRUE)) %||% character()
    stat_parameters <- capr_plot_plain_atomic(attr(capr_plot_plain_list(
      capr_plot_get(layer, "stat_params", list())
    ), "names", exact = TRUE)) %||% character()
    geom_count <- min(length(geom_parameters), .capr_plot_limits$mappings)
    stat_count <- min(length(stat_parameters), .capr_plot_limits$mappings)
    parameters <- unique(c(
      geom_parameters[seq_len(geom_count)],
      stat_parameters[seq_len(stat_count)]
    ))
    list(
      index = as.integer(index),
      geom = capr_plot_class_name(capr_plot_get(layer, "geom", NULL)),
      stat = capr_plot_class_name(capr_plot_get(layer, "stat", NULL)),
      position = capr_plot_class_name(capr_plot_get(layer, "position", NULL)),
      inherit_aes = isTRUE(capr_plot_get(layer, "inherit.aes", FALSE)),
      data_kind = data$kind,
      data_rows = data$rows,
      data_columns = data$columns,
      mapping = capr_plot_mapping(capr_plot_get(layer, "mapping", list())),
      fixed_aesthetics = capr_plot_bounded_strings(
        fixed %||% character(), .capr_plot_limits$mappings
      ),
      parameter_names = capr_plot_bounded_strings(
        parameters %||% character(), .capr_plot_limits$mappings
      )
    )
  })
  if (length(layers) > count) {
    out[[length(out) + 1L]] <- list(
      index = as.integer(count + 1L),
      geom = "[truncated]",
      stat = "none",
      position = "none",
      inherit_aes = FALSE,
      data_kind = "none",
      data_rows = 0L,
      data_columns = 0L,
      mapping = list(),
      fixed_aesthetics = list(),
      parameter_names = list(sprintf("%d more layers", length(layers) - count))
    )
  }
  out
}

capr_plot_snapshot <- function(x) {
  capr_plot_validate_source(x)
  data <- capr_plot_data_schema(capr_plot_get(x, "data", NULL))
  layers <- capr_plot_plain_list(capr_plot_get(x, "layers", list())) %||%
    list()
  mapping <- capr_plot_mapping(capr_plot_get(x, "mapping", list()))
  facet <- capr_plot_facet_spec(capr_plot_get(x, "facet", NULL))
  labels <- capr_plot_label_spec(capr_plot_get(x, "labels", list()))
  scales <- capr_plot_scale_spec(capr_plot_get(x, "scales", NULL))
  theme <- capr_plot_theme_spec(capr_plot_get(x, "theme", NULL))
  list(
    classes = capr_plot_classes(x),
    data = data,
    mapping = mapping,
    layers = capr_plot_layer_spec(layers),
    layer_count = as.integer(length(layers)),
    facet = facet,
    coordinates = capr_plot_class_name(capr_plot_get(x, "coordinates", NULL)),
    labels = labels,
    scales = scales,
    theme = theme
  )
}

capr_plot_label <- function(x, context = list()) {
  label <- context$label %||% attr(x, "capr_label", exact = TRUE) %||%
    "ggplot object"
  capr_assert_scalar_character(
    label, "label", condition = "capr_artifact_invalid"
  )
}

capr_plot_fingerprint <- function(x, context = list()) {
  snapshot <- capr_plot_snapshot(x)
  list(
    available = TRUE,
    algorithm = "capr-ggplot-spec-v1-sha256",
    value = paste0(
      "capr_ggplot_spec_v1:",
      capr_sha256(capr_canonical_json(snapshot))
    ),
    caveat = "bounded_declarations_exclude_cell_and_parameter_values"
  )
}

capr_plot_source_ref <- function(x, context = list()) {
  snapshot <- capr_plot_snapshot(x)
  fingerprint <- capr_plot_fingerprint(x, context)$value
  uri <- context$uri %||% attr(x, "capr_uri", exact = TRUE) %||%
    paste0("r-host://plot/", sub("^.*:", "", fingerprint))
  list(
    schema = "cap.source_ref.v1",
    uri = capr_assert_scalar_character(
      uri, "uri", condition = "capr_artifact_invalid"
    ),
    sourceType = "plot",
    label = capr_plot_label(x, context),
    identity = list(
      host = "R",
      classes = snapshot$classes,
      rows = snapshot$data$rows,
      columns = snapshot$data$columns,
      layers = snapshot$layer_count
    ),
    trust = "host"
  )
}

capr_plot_field_catalog <- function(x, context = list()) {
  field <- function(id, label, description, trust, cost, prior, tags,
                    extractor, renderer) {
    list(
      schema = "cap.field.v1",
      id = id,
      label = label,
      description = description,
      sourceTypes = list("plot"),
      timing = "assemble",
      trust = trust,
      exec = "local_cheap",
      contracts = list(
        extractor = extractor,
        redactor = "capr.ggplot.identity",
        renderer = renderer
      ),
      selectionHints = list(
        priorValue = prior,
        intentTags = as.list(tags)
      ),
      levels = list(list(
        level = 1L,
        estimatedCost = as.integer(cost),
        description = description
      ))
    )
  }
  list(
    schema = "cap.field_catalog.v1",
    catalogId = "org.capr.ggplot.v1",
    sourceType = "plot",
    versions = list(
      cap = "2026-07-05-draft",
      fields = "f1",
      catalog = "v1-experimental"
    ),
    fields = list(
      field(
        "f1:plot@overview#base",
        "Plot overview",
        "Plot class, data shape, layer count, facet, and coordinates.",
        "derived", 80L, 1.30,
        c("plot", "chart", "visualization", "overview"),
        "capr.ggplot.overview", "capr.ggplot.overview.text_v1"
      ),
      field(
        "f1:plot@data_schema#compact",
        "Plot data schema",
        "Bounded plot-level data schema without cell values.",
        "derived", 180L, 1.15,
        c("data", "schema", "columns", "types"),
        "capr.ggplot.data_schema", "capr.ggplot.data_schema.text_v1"
      ),
      field(
        "f1:plot@mapping#declared",
        "Declared plot mapping",
        paste(
          "Unevaluated global/facet mappings, explicit labels, scales,",
          "coordinates, and theme metadata."
        ),
        "data", 220L, 1.05,
        c("mapping", "aesthetic", "labels", "facet", "scale", "theme"),
        "capr.ggplot.mapping", "capr.ggplot.mapping.text_v1"
      ),
      field(
        "f1:plot@layers#compact",
        "Plot layers",
        paste(
          "Bounded geom/stat/position and unevaluated layer declarations;",
          "layer data functions are never called."
        ),
        "derived", 300L, 0.95,
        c("layer", "geom", "stat", "position"),
        "capr.ggplot.layers", "capr.ggplot.layers.text_v1"
      )
    )
  )
}

capr_plot_render_pairs <- function(mapping, limit = 360L) {
  if (!length(mapping)) return("[none]")
  pairs <- vapply(mapping, function(entry) {
    sprintf(
      "%s=<data>%s</data>",
      capr_escape_data(entry$aesthetic),
      capr_escape_data(entry$expression)
    )
  }, character(1))
  kept <- character()
  for (pair in pairs) {
    candidate <- paste(c(kept, pair), collapse = ", ")
    if (nchar(candidate, type = "chars") > limit) {
      marker <- "[truncated]"
      if (nchar(paste(c(kept, marker), collapse = ", "),
        type = "chars"
      ) <= limit) {
        kept <- c(kept, marker)
      }
      break
    }
    kept <- c(kept, pair)
  }
  paste(kept, collapse = ", ")
}

capr_plot_render_data_schema <- function(value, field = NULL,
                                         context = list()) {
  lines <- c(
    sprintf("data kind: %s", capr_escape_data(value$kind)),
    sprintf("shape: %d rows x %d columns", value$rows, value$columns)
  )
  if (length(value$column_schema)) {
    lines <- c(lines, "columns:", vapply(value$column_schema, function(column) {
      sprintf(
        "- <data>%s</data> <%s>",
        capr_escape_data(column$name),
        capr_escape_data(column$type)
      )
    }, character(1)))
  }
  if (isTRUE(value$truncated)) {
    lines <- c(lines, sprintf(
      "- [truncated after %d columns]",
      length(value$column_schema)
    ))
  }
  capr_plot_bound_lines(lines, 720L, "[column schema truncated]")
}

capr_plot_render_overview <- function(value, field = NULL, context = list()) {
  capr_plot_bound_lines(c(
    sprintf("plot class: %s", capr_escape_data(value$plot_class)),
    sprintf("data kind: %s", capr_escape_data(value$data_kind)),
    sprintf("data shape: %d rows x %d columns", value$rows, value$columns),
    sprintf("layers: %d", value$layers),
    sprintf("global mappings: %d", value$mappings),
    sprintf("facet: %s", capr_escape_data(value$facet)),
    sprintf("coordinates: %s", capr_escape_data(value$coordinates)),
    sprintf("declared labels: %d", value$labels),
    sprintf("explicit scales: %d", value$scales)
  ), 400L, "[overview truncated]")
}

capr_plot_render_mapping <- function(value, field = NULL, context = list()) {
  label_text <- if (length(value$labels)) {
    capr_plot_bound_lines(vapply(value$labels, function(label) {
      sprintf(
        "%s=<data>%s</data>",
        capr_escape_data(label$name),
        capr_escape_data(label$value)
      )
    }, character(1)), 320L, "[labels truncated]")
  } else {
    "[none]"
  }
  scale_text <- if (length(value$scales)) {
    capr_plot_bound_lines(vapply(value$scales, function(scale) {
      aesthetics <- unlist(scale$aesthetics, use.names = FALSE)
      sprintf(
        "%d:%s[%s]",
        scale$index,
        capr_escape_data(scale$class),
        paste(vapply(aesthetics, capr_escape_data, character(1)), collapse = ",")
      )
    }, character(1)), 280L, "[scales truncated]")
  } else {
    "[none]"
  }
  theme_elements <- unlist(value$theme$elements, use.names = FALSE)
  theme_text <- if (length(theme_elements)) {
    capr_plot_bound_lines(
      vapply(theme_elements, capr_escape_data, character(1)),
      240L,
      "[theme elements truncated]"
    )
  } else {
    "[none]"
  }
  lines <- c(
    sprintf("global: %s", capr_plot_render_pairs(value$global, 300L)),
    sprintf("facet class: %s", capr_escape_data(value$facet$class)),
    sprintf(
      "facet mappings: %s",
      capr_plot_render_pairs(value$facet$mappings, 220L)
    ),
    sprintf("coordinates: %s", capr_escape_data(value$coordinates)),
    sprintf("declared labels: %s", label_text),
    sprintf("explicit scales: %s", scale_text),
    sprintf(
      "theme: %s complete=%s explicit=%s",
      capr_escape_data(value$theme$class),
      if (isTRUE(value$theme$complete)) "true" else "false",
      theme_text
    )
  )
  capr_plot_bound_lines(lines, 880L, "[mapping metadata truncated]")
}

capr_plot_render_layers <- function(value, field = NULL, context = list()) {
  if (!length(value)) return("[no layers]")
  lines <- vapply(value, function(layer) {
    fixed <- unlist(layer$fixed_aesthetics, use.names = FALSE)
    parameters <- unlist(layer$parameter_names, use.names = FALSE)
    sprintf(
      paste0(
        "%d. geom=%s stat=%s position=%s inherit_aes=%s data=%s[%dx%d] ",
        "mapping={%s} fixed={%s} params={%s}"
      ),
      layer$index,
      capr_escape_data(layer$geom),
      capr_escape_data(layer$stat),
      capr_escape_data(layer$position),
      if (isTRUE(layer$inherit_aes)) "true" else "false",
      capr_escape_data(layer$data_kind),
      layer$data_rows,
      layer$data_columns,
      capr_plot_render_pairs(layer$mapping, 280L),
      if (length(fixed)) {
        paste(vapply(fixed, capr_escape_data, character(1)), collapse = ",")
      } else {
        "none"
      },
      if (length(parameters)) {
        paste(vapply(parameters, capr_escape_data, character(1)), collapse = ",")
      } else {
        "none"
      }
    )
  }, character(1))
  capr_plot_bound_lines(lines, 1200L, "[layer metadata truncated]")
}

#' Construct the experimental ggplot specification adapter
#'
#' The adapter reads only bounded, declarative plot properties: unevaluated
#' aesthetic mappings, data schemas, layer declarations, facets, labels,
#' explicit scales, coordinates, and theme metadata. It never calls
#' `ggplot_build()`, renders pixels, evaluates mappings, runs statistics, or
#' invokes layer data functions. Data-cell and fixed parameter values are not
#' disclosed. It has no CAP conformance claim.
#'
#' @return A validated experimental adapter for `ggplot` objects.
#' @export
cap_ggplot_adapter <- function() {
  snapshot <- function(x) capr_plot_snapshot(x)
  identity_redactor <- function(value, field = NULL, context = list()) {
    caveats <- if (!is.null(field) &&
      identical(field$id, "f1:plot@overview#base")) {
      list(list(
        code = "capr_caveat_plot_spec_only",
        fieldId = field$id,
        message = paste(
          "experimental plot adapter inspected bounded declarations only;",
          "cell and parameter values were excluded, and the plot was not",
          "built or rendered"
        ),
        rule = "plot-spec-only"
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
  cap_new_adapter(
    id = "org.capr.ggplot",
    version = "0.1.0",
    provider = "capR",
    provider_version = .capr_version(),
    source_family = "plot",
    maturity = "experimental",
    semantic_level = "domain",
    conformance_claim = "none",
    capabilities = list(
      followup = FALSE,
      remote = FALSE,
      credentials = FALSE,
      deterministic = TRUE,
      builds_plot = FALSE,
      renders_pixels = FALSE,
      evaluates_mappings = FALSE,
      parameter_values_disclosed = FALSE
    ),
    source_ref = capr_plot_source_ref,
    field_catalog = capr_plot_field_catalog,
    fingerprint = capr_plot_fingerprint,
    bindings = list(
      extractors = list(
        "capr.ggplot.overview" = function(x, level = 1L, context = list()) {
          value <- snapshot(x)
          list(
            plot_class = unlist(value$classes, use.names = FALSE)[[1L]],
            data_kind = value$data$kind,
            rows = value$data$rows,
            columns = value$data$columns,
            layers = value$layer_count,
            mappings = as.integer(length(value$mapping)),
            facet = value$facet$class,
            coordinates = value$coordinates,
            labels = as.integer(length(value$labels)),
            scales = as.integer(length(value$scales))
          )
        },
        "capr.ggplot.data_schema" = function(
          x, level = 1L, context = list()
        ) {
          snapshot(x)$data
        },
        "capr.ggplot.mapping" = function(x, level = 1L, context = list()) {
          value <- snapshot(x)
          list(
            global = value$mapping,
            facet = value$facet,
            coordinates = value$coordinates,
            labels = value$labels,
            scales = value$scales,
            theme = value$theme
          )
        },
        "capr.ggplot.layers" = function(x, level = 1L, context = list()) {
          snapshot(x)$layers
        }
      ),
      redactors = list("capr.ggplot.identity" = identity_redactor),
      renderers = list(
        "capr.ggplot.overview.text_v1" = capr_plot_render_overview,
        "capr.ggplot.data_schema.text_v1" = capr_plot_render_data_schema,
        "capr.ggplot.mapping.text_v1" = capr_plot_render_mapping,
        "capr.ggplot.layers.text_v1" = capr_plot_render_layers
      )
    ),
    implementation_spec = capr_builtin_implementation_spec(
      prefixes = "capr_plot_",
      symbols = c("capr_data_frame_row_count", "capr_table_type"),
      constants = list(plot_limits = .capr_plot_limits)
    )
  )
}
