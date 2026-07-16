.capr_object_component_limit <- 60L

capr_object_bounded_strings <- function(x,
                                        limit = .capr_object_component_limit) {
  if (is.object(x) && !isS4(x)) {
    x <- tryCatch(unclass(x), error = function(e) NULL)
  }
  if (is.null(x) || !is.atomic(x)) return(list())
  total <- length(x)
  count <- min(total, limit)
  out <- as.list(capr_descriptor_bound_string(x[seq_len(count)]))
  if (total > count) {
    out[[length(out) + 1L]] <- sprintf("[truncated: %d more]", total - count)
  }
  out
}

capr_object_classes <- function(x) {
  capr_object_bounded_strings(unname(class(x)))
}

capr_unclass_atomic <- function(x) {
  if (!is.atomic(x) || isS4(x)) return(NULL)
  if (is.object(x)) tryCatch(unclass(x), error = function(e) NULL) else x
}

capr_unclass_list <- function(x) {
  if (isS4(x) || is.environment(x)) return(NULL)
  value <- tryCatch(unclass(x), error = function(e) NULL)
  if (is.list(value)) value else NULL
}

capr_object_slots <- function(x) {
  slots <- methods::slotNames(x)
  if (length(slots) > 100L) {
    capr_abort(
      "capr_adapter_invalid",
      "model or live objects with more than 100 slots are not inspected"
    )
  }
  slots
}

capr_raw_component <- function(x, name, default = NULL) {
  value <- capr_unclass_list(x)
  capr_list_component(value, name, default)
}

capr_list_component <- function(value, name, default = NULL) {
  value_names <- capr_unclass_atomic(attr(value, "names", exact = TRUE))
  if (is.null(value) || !is.character(value_names) ||
      !name %in% value_names) {
    return(default)
  }
  .subset2(value, name)
}

capr_schema_metadata <- function(x, max_columns = 60L) {
  if (!is.data.frame(x)) {
    return(list(rows = NULL, columns = NULL, names = list(), types = list()))
  }
  raw <- capr_unclass_list(x)
  total <- length(raw)
  count <- min(total, max_columns)
  column_names <- capr_unclass_atomic(
    attr(raw, "names", exact = TRUE)
  )
  if (!is.character(column_names) || length(column_names) < total) {
    column_names <- rep("[unnamed]", total)
  }
  list(
    rows = capr_data_frame_row_count(x),
    columns = as.integer(total),
    names = as.list(capr_descriptor_bound_string(
      column_names[seq_len(count)]
    )),
    types = as.list(unname(vapply(raw[seq_len(count)], function(column) {
      classes <- class(column)
      if (length(classes)) classes[[1L]] else typeof(column)
    }, character(1)))),
    truncated = total > count
  )
}

capr_model_schema_name <- function(x) {
  x <- capr_descriptor_bound_string(x, 120L)
  if (grepl("^[A-Za-z.][A-Za-z0-9._]*$", x)) x else "[derived term]"
}

capr_model_schema <- function(x) {
  schema <- capr_schema_metadata(x)
  schema$names <- lapply(schema$names, capr_model_schema_name)
  schema
}

capr_method_free_length <- function(x) {
  if (isS4(x) || is.environment(x)) return(0L)
  value <- if (is.object(x)) {
    tryCatch(unclass(x), error = function(e) NULL)
  } else {
    x
  }
  if (is.null(value)) 0L else as.integer(length(value))
}

capr_s4_slot_or <- function(x, name, default = NULL) {
  if (!isS4(x) || !name %in% capr_object_slots(x)) return(default)
  methods::slot(x, name)
}

capr_model_supported <- function(x) {
  inherits(x, c(
    "lm", "glm", "merMod", "recipe", "workflow", "model_spec",
    "model_fit"
  )) || (isS4(x) && methods::is(x, "merMod"))
}

capr_model_lm_snapshot <- function(x) {
  raw <- capr_unclass_list(x)
  model <- capr_list_component(raw, "model", data.frame())
  terms <- capr_list_component(raw, "terms")
  coefficients <- capr_list_component(raw, "coefficients", numeric())
  response_value <- capr_unclass_atomic(
    attr(terms, "response", exact = TRUE)
  )
  response_index <- if (is.numeric(response_value) &&
      length(response_value) == 1L && !is.na(response_value) &&
      is.finite(response_value) && response_value >= 0L) {
    as.integer(response_value)
  } else {
    0L
  }
  schema <- capr_model_schema(model)
  response <- if (response_index > 0L &&
    length(schema$names) >= response_index) {
    schema$names[[response_index]]
  } else {
    NULL
  }
  family <- if (inherits(x, "glm")) {
    family_object <- capr_list_component(raw, "family")
    if (is.list(family_object)) {
      family_raw <- unclass(family_object)
      family_value <- capr_list_component(family_raw, "family", "unknown")
      if (is.character(family_value) &&
          capr_method_free_length(family_value) == 1L) {
        unname(unclass(family_value))
      } else {
        "unknown"
      }
    } else {
      "unknown"
    }
  } else {
    "gaussian"
  }
  list(
    overview = list(
      kind = if (inherits(x, "glm")) "glm" else "lm",
      classes = capr_object_classes(x),
      training_rows = schema$rows,
      training_columns = schema$columns,
      coefficient_count = capr_method_free_length(coefficients)
    ),
    structure = list(
      training_schema = schema,
      term_count = capr_method_free_length(
        attr(terms, "term.labels", exact = TRUE)
      ),
      coefficient_names_disclosed = FALSE,
      term_expressions_disclosed = FALSE
    ),
    semantics = list(
      response = response,
      family = family,
      fitted = TRUE,
      summary_called = FALSE,
      predict_called = FALSE,
      training_values_disclosed = FALSE
    )
  )
}

capr_model_mermod_snapshot <- function(x) {
  frame <- capr_s4_slot_or(x, "frame", data.frame())
  beta <- capr_s4_slot_or(x, "beta", numeric())
  cnms <- capr_s4_slot_or(x, "cnms", list())
  flist <- capr_s4_slot_or(x, "flist", list())
  schema <- capr_model_schema(frame)
  flist_plain <- capr_unclass_list(flist) %||% list()
  cnms_plain <- capr_unclass_list(cnms) %||% list()
  list(
    overview = list(
      kind = "merMod",
      classes = capr_object_classes(x),
      training_rows = schema$rows,
      training_columns = schema$columns,
      fixed_effect_count = capr_method_free_length(beta),
      grouping_factor_count = as.integer(length(flist_plain))
    ),
    structure = list(
      training_schema = schema,
      grouping_factors = capr_object_bounded_strings(
        attr(flist_plain, "names", exact = TRUE)
      ),
      random_term_groups = capr_object_bounded_strings(
        attr(cnms_plain, "names", exact = TRUE)
      ),
      slots = capr_object_bounded_strings(capr_object_slots(x))
    ),
    semantics = list(
      fitted = TRUE,
      summary_called = FALSE,
      predict_called = FALSE,
      refit_called = FALSE,
      training_values_disclosed = FALSE
    )
  )
}

capr_model_recipe_snapshot <- function(x) {
  raw <- capr_unclass_list(x)
  var_info <- capr_list_component(raw, "var_info")
  steps <- capr_unclass_list(
    capr_list_component(raw, "steps", list())
  ) %||% list()
  total_steps <- length(steps)
  steps <- steps[seq_len(min(total_steps, .capr_object_component_limit))]
  schema <- if (is.data.frame(var_info)) {
    info <- capr_unclass_list(var_info)
    info_names <- capr_unclass_atomic(
      attr(info, "names", exact = TRUE)
    ) %||% character()
    if (!is.character(info_names)) info_names <- character()
    variables <- if ("variable" %in% info_names) {
      capr_unclass_atomic(.subset2(info, "variable"))
    } else {
      character()
    }
    roles <- if ("role" %in% info_names) {
      capr_unclass_atomic(.subset2(info, "role"))
    } else {
      character()
    }
    variable_count <- min(length(variables), .capr_object_component_limit)
    role_count <- min(length(roles), .capr_object_component_limit)
    list(
      total_variables = as.integer(length(variables)),
      variables = as.list(capr_descriptor_bound_string(
        variables[seq_len(variable_count)]
      )),
      roles = as.list(capr_descriptor_bound_string(
        roles[seq_len(role_count)]
      ))
    )
  } else {
    list(total_variables = 0L, variables = list(), roles = list())
  }
  list(
    overview = list(
      kind = "recipe",
      classes = capr_object_classes(x),
      variable_count = schema$total_variables,
      step_count = as.integer(total_steps)
    ),
    structure = list(
      variables = schema$variables,
      roles = schema$roles,
      step_classes = lapply(steps, capr_object_classes),
      components = capr_object_bounded_strings(
        attr(raw, "names", exact = TRUE)
      )
    ),
    semantics = list(
      preprocessing = TRUE,
      trained = isTRUE(capr_list_component(raw, "trained", FALSE)),
      prep_called = FALSE,
      bake_called = FALSE,
      step_values_disclosed = FALSE
    )
  )
}

capr_model_container_snapshot <- function(x) {
  raw <- capr_unclass_list(x) %||% list()
  total <- length(raw)
  count <- min(total, .capr_object_component_limit)
  components <- lapply(raw[seq_len(count)], function(component) {
    list(classes = capr_object_classes(component), type = typeof(component))
  })
  kind <- if (inherits(x, "workflow")) {
    "workflow"
  } else if (inherits(x, "model_fit")) {
    "model_fit"
  } else if (inherits(x, "model_spec")) {
    "model_spec"
  } else {
    "model_spec"
  }
  engine <- capr_list_component(raw, "engine")
  mode <- capr_list_component(raw, "mode")
  list(
    overview = list(
      kind = kind,
      classes = capr_object_classes(x),
      component_count = as.integer(total)
    ),
    structure = list(
      component_names = capr_object_bounded_strings(
        attr(raw, "names", exact = TRUE) %||% rep("[unnamed]", total),
        count
      ),
      component_classes = components
    ),
    semantics = list(
      engine = if (is.character(engine) &&
        capr_method_free_length(engine) == 1L) unname(unclass(engine)) else NULL,
      mode = if (is.character(mode) &&
        capr_method_free_length(mode) == 1L) unname(unclass(mode)) else NULL,
      fitted = inherits(x, "model_fit"),
      preprocessing_executed = FALSE,
      fitting_executed = FALSE,
      prediction_executed = FALSE,
      payload_values_disclosed = FALSE
    )
  )
}

capr_model_snapshot <- function(x) {
  if (!capr_model_supported(x)) {
    capr_abort(
      "capr_adapter_invalid",
      "the model adapter requires a supported model or workflow object",
      classes = unname(class(x))
    )
  }
  if (inherits(x, c("glm", "lm"))) return(capr_model_lm_snapshot(x))
  if (inherits(x, "merMod") || (isS4(x) && methods::is(x, "merMod"))) {
    return(capr_model_mermod_snapshot(x))
  }
  if (inherits(x, "recipe")) return(capr_model_recipe_snapshot(x))
  capr_model_container_snapshot(x)
}

#' Construct the experimental model and workflow adapter
#'
#' The adapter reports bounded training schema, term counts, engine, and
#' preprocessing metadata. It never calls `summary()`, `predict()`, `fit()`,
#' `prep()`, `bake()`, or `refit()`, and never emits coefficient names,
#' coefficient values, formula expressions, or training values.
#'
#' @return A validated experimental adapter.
#' @export
cap_model_adapter <- function() {
  capr_new_descriptor_adapter(
    id = "org.capr.model",
    family = "model",
    label = "model or workflow",
    snapshot_fn = capr_model_snapshot,
    capabilities = list(
      fits_model = FALSE,
      predicts = FALSE,
      preprocesses = FALSE,
      training_values_disclosed = FALSE
    ),
    implementation_spec = capr_builtin_implementation_spec(
      prefixes = c("capr_model_", "capr_object_"),
      symbols = c(
        "capr_unclass_atomic", "capr_unclass_list",
        "capr_raw_component", "capr_list_component",
        "capr_schema_metadata", "capr_method_free_length",
        "capr_s4_slot_or", "capr_data_frame_row_count"
      ),
      constants = list(component_limit = .capr_object_component_limit)
    )
  )
}

capr_visual_supported <- function(x) {
  inherits(x, c(
    "ggplot", "patchwork", "grob", "gtable", "htmlwidget"
  ))
}

capr_visual_grob_snapshot <- function(x) {
  raw <- capr_unclass_list(x) %||% list()
  grobs <- capr_list_component(
    raw, "grobs", capr_list_component(raw, "children", list())
  )
  grobs <- capr_unclass_list(grobs) %||% list()
  total_grobs <- length(grobs)
  grobs <- grobs[seq_len(min(total_grobs, .capr_object_component_limit))]
  layout <- capr_list_component(raw, "layout")
  list(
    overview = list(
      kind = if (inherits(x, "gtable")) "gtable" else "grob",
      classes = capr_object_classes(x),
      child_count = as.integer(total_grobs)
    ),
    structure = list(
      component_names = capr_object_bounded_strings(
        attr(raw, "names", exact = TRUE)
      ),
      child_classes = lapply(grobs, capr_object_classes),
      layout = capr_schema_metadata(layout)
    ),
    semantics = list(
      drawn = FALSE,
      rendered = FALSE,
      viewports_entered = FALSE,
      labels_disclosed = FALSE
    )
  )
}

capr_visual_htmlwidget_snapshot <- function(x) {
  raw <- capr_unclass_list(x) %||% list()
  payload <- capr_list_component(raw, "x")
  payload_plain <- capr_unclass_list(payload)
  dependencies <- capr_unclass_list(
    capr_list_component(raw, "dependencies", list())
  ) %||% list()
  total_dependencies <- length(dependencies)
  dependencies <- dependencies[
    seq_len(min(total_dependencies, .capr_object_component_limit))
  ]
  dependency_classes <- lapply(dependencies, capr_object_classes)
  list(
    overview = list(
      kind = "htmlwidget",
      classes = capr_object_classes(x),
      payload_field_count = as.integer(if (is.list(payload_plain)) {
        length(payload_plain)
      } else {
        0L
      }),
      dependency_count = as.integer(total_dependencies)
    ),
    structure = list(
      payload_fields = capr_object_bounded_strings(
        if (is.list(payload_plain)) {
          attr(payload_plain, "names", exact = TRUE) %||% character()
        } else {
          character()
        }
      ),
      dependency_classes = dependency_classes,
      component_names = capr_object_bounded_strings(
        attr(raw, "names", exact = TRUE)
      )
    ),
    semantics = list(
      pre_render_hook_present = is.function(capr_list_component(
        raw, "preRenderHook"
      )),
      pre_render_hook_executed = FALSE,
      javascript_executed = FALSE,
      browser_opened = FALSE,
      payload_values_disclosed = FALSE
    )
  )
}

capr_visual_ggplot_snapshot <- function(x) {
  spec <- capr_plot_snapshot(x)
  list(
    overview = list(
      kind = if (inherits(x, "patchwork")) "patchwork" else "ggplot",
      classes = capr_object_classes(x),
      rows = spec$data$rows,
      columns = spec$data$columns,
      layer_count = spec$layer_count
    ),
    structure = list(
      data_kind = spec$data$kind,
      column_names = lapply(spec$data$column_schema, function(column) column$name),
      column_types = lapply(spec$data$column_schema, function(column) column$type),
      geom_classes = lapply(spec$layers, function(layer) layer$geom),
      stat_classes = lapply(spec$layers, function(layer) layer$stat),
      facet_class = spec$facet$class,
      coordinates = spec$coordinates
    ),
    semantics = list(
      built = FALSE,
      rendered = FALSE,
      mappings_evaluated = FALSE,
      layer_data_functions_executed = FALSE,
      labels_disclosed = FALSE,
      parameter_values_disclosed = FALSE
    )
  )
}

capr_visual_snapshot <- function(x) {
  if (!capr_visual_supported(x)) {
    capr_abort(
      "capr_adapter_invalid",
      "the visual adapter requires a supported declarative visual object",
      classes = unname(class(x))
    )
  }
  if (inherits(x, "htmlwidget")) return(capr_visual_htmlwidget_snapshot(x))
  if (inherits(x, c("patchwork", "ggplot"))) {
    return(capr_visual_ggplot_snapshot(x))
  }
  capr_visual_grob_snapshot(x)
}

#' Construct the experimental declarative visual adapter
#'
#' This adapter handles grid grobs, gtables, patchworks, htmlwidgets, and a
#' bounded ggplot overview. It never builds, draws, renders, runs JavaScript,
#' invokes hooks, or opens a browser.
#'
#' @return A validated experimental adapter.
#' @export
cap_visual_adapter <- function() {
  capr_new_descriptor_adapter(
    id = "org.capr.visual",
    family = "plot",
    label = "declarative visual object",
    snapshot_fn = capr_visual_snapshot,
    capabilities = list(
      builds_plot = FALSE,
      renders_pixels = FALSE,
      executes_javascript = FALSE,
      invokes_hooks = FALSE
    ),
    implementation_spec = capr_builtin_implementation_spec(
      prefixes = c("capr_visual_", "capr_plot_", "capr_object_"),
      symbols = c(
        "capr_unclass_atomic", "capr_unclass_list",
        "capr_list_component", "capr_schema_metadata",
        "capr_data_frame_row_count", "capr_table_type"
      ),
      constants = list(
        component_limit = .capr_object_component_limit,
        plot_limits = .capr_plot_limits
      )
    )
  )
}

capr_live_kind <- function(x) {
  if (inherits(x, c("tbl_sql", "tbl_lazy"))) return("lazy_query")
  if (isS4(x) && tryCatch(methods::is(x, "DBIConnection"), error = function(e) FALSE)) {
    return("database_connection")
  }
  if (inherits(x, "connection")) return("connection")
  if (typeof(x) == "externalptr") return("external_pointer")
  if (is.environment(x)) {
    if (any(class(x) %in% c("Dataset", "ArrowObject"))) return("arrow_dataset")
    if (inherits(x, "R6")) return("r6")
    return("environment")
  }
  NULL
}

capr_live_snapshot <- function(x) {
  kind <- capr_live_kind(x)
  if (is.null(kind)) {
    capr_abort(
      "capr_adapter_invalid",
      "the live adapter requires a lazy, connection, environment, R6, or external-pointer object",
      classes = unname(class(x)),
      type = typeof(x)
    )
  }

  if (identical(kind, "lazy_query")) {
    raw <- capr_unclass_list(x) %||% list()
    query <- capr_list_component(raw, "lazy_query")
    query_plain <- capr_unclass_list(query)
    source <- capr_list_component(raw, "src")
    return(list(
      overview = list(
        kind = kind,
        classes = capr_object_classes(x),
        query_class = capr_object_classes(query),
        source_class = capr_object_classes(source)
      ),
      structure = list(
        cached_components = capr_object_bounded_strings(
          attr(raw, "names", exact = TRUE)
        ),
        query_components = capr_object_bounded_strings(
          if (is.list(query_plain)) {
            attr(query_plain, "names", exact = TRUE) %||% character()
          } else {
            character()
          }
        )
      ),
      semantics = list(
        query_rendered = FALSE,
        query_executed = FALSE,
        rows_collected = FALSE,
        connection_traversed = FALSE,
        payload_values_disclosed = FALSE
      )
    ))
  }

  if (is.environment(x)) {
    return(list(
      overview = list(
        kind = kind,
        classes = capr_object_classes(x),
        binding_count = NULL,
        active_binding_count = NULL
      ),
      structure = list(
        binding_names = list(),
        active_binding_names = list()
      ),
      semantics = list(
        environment_locked = environmentIsLocked(x),
        binding_names_enumerated = FALSE,
        enumeration_reason = "environment frames are intentionally opaque",
        bindings_read = FALSE,
        active_bindings_evaluated = FALSE,
        methods_called = FALSE,
        external_resources_accessed = FALSE
      )
    ))
  }

  list(
    overview = list(
      kind = kind,
      classes = capr_object_classes(x),
      type = typeof(x)
    ),
    structure = list(
      slots = if (isS4(x)) {
        capr_object_bounded_strings(capr_object_slots(x))
      } else {
        list()
      },
      attributes = capr_object_bounded_strings(
        attr(attributes(x), "names", exact = TRUE)
      )
    ),
    semantics = list(
      connection_checked = FALSE,
      connection_opened = FALSE,
      credentials_read = FALSE,
      remote_accessed = FALSE,
      pointer_dereferenced = FALSE
    )
  )
}

#' Construct the experimental lazy and live-object adapter
#'
#' The adapter inspects cached class/component metadata for lazy queries and
#' slot/attribute names for connection-like objects. Environment, Arrow, and R6
#' frames remain opaque: binding names and values are not enumerated. It never
#' renders or executes a lazy query, collects rows, reads credentials,
#' dereferences external pointers, calls R6 methods, or evaluates active
#' bindings.
#'
#' @return A validated experimental adapter.
#' @export
cap_live_adapter <- function() {
  capr_new_descriptor_adapter(
    id = "org.capr.live",
    family = "external",
    label = "lazy or live R object",
    snapshot_fn = capr_live_snapshot,
    capabilities = list(
      remote = FALSE,
      credentials = FALSE,
      executes_query = FALSE,
      collects_rows = FALSE,
      evaluates_active_bindings = FALSE,
      dereferences_external_pointers = FALSE
    ),
    implementation_spec = capr_builtin_implementation_spec(
      prefixes = c("capr_live_", "capr_object_"),
      symbols = c(
        "capr_unclass_atomic", "capr_unclass_list",
        "capr_list_component"
      ),
      constants = list(component_limit = .capr_object_component_limit)
    )
  )
}
