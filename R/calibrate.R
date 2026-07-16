#' Measure actual field costs against catalog estimates
#'
#' Materializes every authorized field/level of an object's catalog once and
#' reports the measured cost next to the adapter's `estimatedCost`. This is
#' an adapter-authoring aid: `estimatedCost` literals are part of an
#' adapter's identity (they participate in binding signatures and fixture
#' surfaces), so this helper never rewrites a catalog -- it produces the
#' evidence an author needs to recost one deliberately.
#'
#' @param x Source object.
#' @param adapter Optional explicit adapter or adapter ID.
#' @param registry Adapter registry.
#' @param policy Host policy; execution-denied fields are reported as
#'   unauthorized with `NA` measured cost instead of being run.
#' @param tokenizer Optional tokenizer id or [cap_tokenizer()] used for
#'   measurement.
#' @param ... Runtime context such as `label` or fixture metadata.
#' @return A data frame with one row per field/level: `field_id`, `level`,
#'   `timing`, `exec`, `estimated_cost`, `measured_cost`, `tokenizer_id`,
#'   and `authorized`.
#' @export
cap_calibrate_costs <- function(x, adapter = NULL, registry = cap_registry(),
                                policy = cap_policy(), tokenizer = NULL,
                                ...) {
  capr_validate_policy(policy)
  tokenizer <- capr_resolve_tokenizer(tokenizer)
  resolved <- cap_resolve_adapter(
    x,
    adapter = adapter,
    registry = registry,
    allow_fallback = policy$allow_fallback
  )
  context <- list(...)
  context$sensitive_name_patterns <- context$sensitive_name_patterns %||%
    .capr_sensitive_name_patterns
  context$.capr_snapshot_cache <- capr_new_snapshot_cache(x, resolved)
  catalog <- resolved$lifecycle$field_catalog(x, context)
  cap_validate_field_catalog(catalog)

  rows <- list()
  for (field_index in seq_along(catalog$fields)) {
    field <- catalog$fields[[field_index]]
    authorization <- cap_authorize_execution(policy, field$exec)
    for (level in field$levels) {
      measured <- NA_integer_
      if (authorization$allowed) {
        candidate <- list(
          field = field,
          field_index = field_index,
          level = as.integer(level$level),
          estimated_cost = as.integer(level$estimatedCost),
          prior_value = field$selectionHints$priorValue %||% 0,
          intent_adjustment = 0,
          score = field$selectionHints$priorValue %||% 0,
          ratio = 0,
          authorization = authorization,
          selected = TRUE,
          rejected_reason = NULL
        )
        outcome <- capr_materialize_one(
          candidate, resolved, x, policy, context, tokenizer
        )
        if (isTRUE(outcome$ok)) {
          measured <- outcome$actual_cost
        }
      }
      rows[[length(rows) + 1L]] <- data.frame(
        field_id = field$id,
        level = as.integer(level$level),
        timing = field$timing,
        exec = field$exec,
        estimated_cost = as.integer(level$estimatedCost),
        measured_cost = measured,
        tokenizer_id = tokenizer$id,
        authorized = authorization$allowed,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, c(rows, list(make.row.names = FALSE)))
}
