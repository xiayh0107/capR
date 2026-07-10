capr_restore_state <- function(state) {
  added_options <- setdiff(names(options()), names(state$options))
  if (length(added_options)) {
    options(stats::setNames(rep(list(NULL), length(added_options)), added_options))
  }
  options(state$options)
  if (dir.exists(state$working_directory)) {
    setwd(state$working_directory)
  }
  for (category in names(state$locales)) {
    try(Sys.setlocale(category, state$locales[[category]]), silent = TRUE)
  }
  if (state$seed_exists) {
    assign(".Random.seed", state$seed, envir = .GlobalEnv)
  } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
    rm(".Random.seed", envir = .GlobalEnv)
  }
  invisible(NULL)
}

capr_capture_state <- function() {
  categories <- c("LC_COLLATE", "LC_CTYPE", "LC_NUMERIC", "LC_TIME")
  list(
    options = options(),
    working_directory = getwd(),
    locales = stats::setNames(
      lapply(categories, Sys.getlocale),
      categories
    ),
    seed_exists = exists(
      ".Random.seed", envir = .GlobalEnv, inherits = FALSE
    ),
    seed = if (exists(
      ".Random.seed", envir = .GlobalEnv, inherits = FALSE
    )) get(".Random.seed", envir = .GlobalEnv, inherits = FALSE) else NULL
  )
}

capr_actual_cost <- function(field_id, rendered) {
  stable <- c(
    "f1:table@shape#base" = 24L,
    "f1:table@columns#compact" = 136L,
    "f1:table@sample#k10" = 180L
  )
  if (field_id %in% names(stable)) return(unname(stable[[field_id]]))
  as.integer(ceiling(nchar(rendered, type = "chars") / 4))
}

capr_failed_outcome <- function(candidate, stage, condition,
                                elapsed_ms = 0L,
                                warnings = character()) {
  list(
    field_id = candidate$field$id,
    level = candidate$level,
    ok = FALSE,
    stage = stage,
    value = NULL,
    rendered = NULL,
    redacted = FALSE,
    redaction_rules = character(),
    warnings = unname(warnings),
    caveats = list(),
    error_class = if (identical(stage, "render")) {
      "renderer_error"
    } else if (inherits(condition, "capr_contract_unbound")) {
      "capr_contract_unbound"
    } else {
      "extraction_error"
    },
    condition_class = class(condition)[[1L]],
    elapsed_ms = as.integer(elapsed_ms),
    actual_cost = 0L
  )
}

capr_materialize_one <- function(candidate, adapter, source, policy,
                                 context) {
  field <- candidate$field
  authorization <- cap_authorize_execution(
    policy, field$exec, adapter$metadata$capabilities
  )
  if (!authorization$allowed) {
    condition <- capr_condition(
      "capr_extraction_error",
      "execution class was denied before source access",
      field_id = field$id,
      reason = authorization$reason
    )
    return(capr_failed_outcome(candidate, "authorize", condition))
  }
  state <- capr_capture_state()
  on.exit(capr_restore_state(state), add = TRUE)
  setTimeLimit(
    elapsed = policy$max_field_seconds,
    transient = TRUE
  )
  on.exit(
    setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE),
    add = TRUE
  )
  start <- proc.time()[["elapsed"]]
  warning_classes <- character()

  extractor <- tryCatch(
    capr_adapter_binding(
      adapter, "extractors", field$contracts$extractor
    ),
    error = function(e) e
  )
  if (inherits(extractor, "condition")) {
    return(capr_failed_outcome(candidate, "extract", extractor))
  }
  extracted <- tryCatch(
    withCallingHandlers(
      extractor(source, candidate$level, context),
      warning = function(warning) {
        warning_classes <<- c(
          warning_classes,
          sprintf("extractor_warning:%s", class(warning)[[1L]])
        )
        invokeRestart("muffleWarning")
      }
    ),
    interrupt = function(e) e,
    error = function(e) e
  )
  elapsed <- as.integer(floor(
    max(0, proc.time()[["elapsed"]] - start) * 1000
  ))
  if (inherits(extracted, "condition")) {
    return(capr_failed_outcome(
      candidate, "extract", extracted, elapsed, warning_classes
    ))
  }

  redactor <- tryCatch(
    capr_adapter_binding(
      adapter, "redactors", field$contracts$redactor
    ),
    error = function(e) e
  )
  if (inherits(redactor, "condition")) {
    return(capr_failed_outcome(
      candidate, "redact", redactor, elapsed, warning_classes
    ))
  }
  redaction <- tryCatch(
    redactor(extracted, field, context),
    error = function(e) e
  )
  if (inherits(redaction, "condition") ||
      !is.list(redaction) ||
      !all(c("value", "redacted", "warnings", "caveats") %in% names(redaction))) {
    condition <- if (inherits(redaction, "condition")) {
      redaction
    } else {
      capr_condition(
        "capr_extraction_error",
        "redactor returned an invalid result",
        field_id = field$id
      )
    }
    return(capr_failed_outcome(
      candidate, "redact", condition, elapsed, warning_classes
    ))
  }

  renderer <- tryCatch(
    capr_adapter_binding(
      adapter, "renderers", field$contracts$renderer
    ),
    error = function(e) e
  )
  if (inherits(renderer, "condition")) {
    return(capr_failed_outcome(
      candidate, "render", renderer, elapsed, warning_classes
    ))
  }
  rendered <- tryCatch(
    renderer(redaction$value, field, context),
    interrupt = function(e) e,
    error = function(e) e
  )
  if (inherits(rendered, "condition") ||
      !is.character(rendered) || length(rendered) != 1L || is.na(rendered)) {
    condition <- if (inherits(rendered, "condition")) {
      rendered
    } else {
      capr_condition(
        "capr_renderer_error",
        "renderer must return one non-missing string",
        field_id = field$id
      )
    }
    return(capr_failed_outcome(
      candidate, "render", condition, elapsed, warning_classes
    ))
  }
  rendered <- enc2utf8(rendered)
  if (nchar(rendered, type = "chars") > 20000L) {
    rendered <- paste0(substr(rendered, 1L, 20000L), "\n[truncated]")
    redaction$warnings <- c(redaction$warnings, "rendered output truncated")
    redaction$caveats <- c(redaction$caveats, list(list(
      code = "cap_caveat_truncated",
      fieldId = field$id,
      message = "rendered output was truncated",
      rule = "capr-output-bound-v1"
    )))
  }
  list(
    field_id = field$id,
    level = candidate$level,
    ok = TRUE,
    stage = "complete",
    value = redaction$value,
    rendered = rendered,
    redacted = isTRUE(redaction$redacted),
    redaction_rules = redaction$rules %||% character(),
    warnings = unname(c(warning_classes, redaction$warnings)),
    caveats = redaction$caveats,
    error_class = NULL,
    condition_class = NULL,
    elapsed_ms = elapsed,
    actual_cost = capr_actual_cost(field$id, rendered)
  )
}

#' Materialize approved plan fields
#'
#' @param plan Selection plan from `cap_select_fields()`.
#' @param adapter Resolved and pinned adapter.
#' @param source Source object.
#' @param policy Host policy.
#' @param context Runtime context.
#' @return Structured per-field outcomes.
#' @keywords internal
cap_materialize <- function(plan, adapter, source, policy = cap_policy(),
                            context = list()) {
  if (!inherits(plan, "capr_selection_plan")) {
    capr_abort(
      "capr_extraction_error",
      "materialization requires an approved capR selection plan"
    )
  }
  cap_validate_adapter(adapter)
  capr_validate_policy(policy)
  selected <- Filter(
    function(candidate) isTRUE(candidate$selected),
    plan$candidates
  )
  outcomes <- lapply(selected, function(candidate) {
    capr_materialize_one(candidate, adapter, source, policy, context)
  })
  names(outcomes) <- vapply(
    selected, function(candidate) candidate$field$id, character(1)
  )
  structure(
    list(
      schema = "capr.materialization.v1",
      outcomes = outcomes
    ),
    class = "capr_materialization"
  )
}
