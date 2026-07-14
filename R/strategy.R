# Shared machinery for pluggable selection strategies (planners and
# tokenizers). The seams open ONLY the ordering/accounting decisions;
# eligibility filtering, execution authorization, the budget commit walk,
# redaction ordering, and gate rules stay in the runtime, so a hostile
# strategy cannot express a policy violation.

.capr_strategy_registry <- local({
  env <- NULL
  function() {
    if (is.null(env)) {
      env <<- new.env(parent = emptyenv())
      env$planners <- list()
      env$tokenizers <- list()
    }
    env
  }
})

.capr_reserved_strategy_ids <- c(
  "capr-greedy-value-cost-v1",
  "capr-approved-followup-v1",
  "heuristic_v1"
)

capr_strategy_id <- function(id, condition) {
  id <- capr_assert_scalar_character(id, "id", condition = condition)
  if (!grepl("^[a-z0-9][a-z0-9._-]*$", id)) {
    capr_abort(
      condition,
      "`id` must be lowercase letters, digits, '.', '_' or '-'",
      id = id
    )
  }
  if (id %in% .capr_reserved_strategy_ids) {
    capr_abort(
      condition,
      "`id` is reserved for a built-in capR strategy",
      id = id
    )
  }
  id
}

capr_strategy_version <- function(version, condition) {
  version <- capr_assert_scalar_character(
    version, "version", condition = condition
  )
  if (!grepl(
    "^[0-9]+\\.[0-9]+\\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$",
    version,
    perl = TRUE
  )) {
    capr_abort(
      condition,
      "`version` must be a semantic version",
      version = version
    )
  }
  version
}

capr_strategy_signature <- function(strategy, fn_field) {
  paste(
    strategy$id,
    strategy$version,
    strategy$provider,
    capr_function_source_signature(strategy[[fn_field]]),
    sep = "|"
  )
}

capr_strategy_register <- function(kind, strategy, fn_field, condition) {
  registry <- .capr_strategy_registry()
  existing <- registry[[kind]][[strategy$id]]
  if (!is.null(existing)) {
    if (identical(
      capr_strategy_signature(existing, fn_field),
      capr_strategy_signature(strategy, fn_field)
    )) {
      return(invisible(strategy))
    }
    capr_abort(
      "capr_registry_conflict",
      sprintf("a different %s is already registered under this id", kind),
      id = strategy$id
    )
  }
  entries <- registry[[kind]]
  entries[[strategy$id]] <- strategy
  registry[[kind]] <- entries
  invisible(strategy)
}

capr_strategy_unregister <- function(kind, id) {
  registry <- .capr_strategy_registry()
  entries <- registry[[kind]]
  if (is.null(id)) {
    removed <- length(entries)
    registry[[kind]] <- list()
    return(invisible(removed))
  }
  id <- capr_assert_scalar_character(
    id, "id", condition = "capr_registry_conflict"
  )
  removed <- as.integer(!is.null(entries[[id]]))
  entries[[id]] <- NULL
  registry[[kind]] <- entries
  invisible(removed)
}

capr_strategy_list <- function(kind) {
  entries <- .capr_strategy_registry()[[kind]]
  ids <- capr_stable_sort(names(entries))
  data.frame(
    id = ids,
    version = vapply(
      entries[ids], `[[`, character(1), "version"
    ),
    provider = vapply(
      entries[ids], `[[`, character(1), "provider"
    ),
    row.names = NULL,
    stringsAsFactors = FALSE
  )
}
