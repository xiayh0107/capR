#' Construct a pluggable selection planner
#'
#' A planner controls exactly one decision: the ranking of already-eligible
#' field candidates. The runtime keeps candidate construction, eligibility
#' filtering (interactive timing, execution authorization), the budget
#' commit walk, and per-field dedup, so a custom planner cannot select an
#' interactive, execution-denied, or over-budget field. Custom planner ids
#' are stamped into `plan$planner` and the resolution sidecar for audit.
#'
#' @param id Planner id (lowercase letters, digits, `.`, `_`, `-`). The
#'   built-in ids are reserved.
#' @param version Semantic version of the planner.
#' @param rank `function(candidates, question, policy)` receiving a
#'   read-only list of eligible candidate views (each with `field_id`,
#'   `level`, `estimated_cost`, `prior_value`, `intent_adjustment`, `score`,
#'   `ratio`, `timing`, `trust`, `exec`, `label`, `intent_tags`) and
#'   returning an integer permutation of `seq_along(candidates)`, most
#'   preferred first.
#' @param provider Provider label recorded in listings and sidecars.
#' @return A `capr_planner` object.
#' @export
cap_planner <- function(id, version, rank, provider = "host") {
  structure(
    list(
      schema = capr_schema("planner"),
      id = capr_strategy_id(id, "capr_planner_invalid"),
      version = capr_strategy_version(version, "capr_planner_invalid"),
      provider = capr_assert_scalar_character(
        provider, "provider", condition = "capr_planner_invalid"
      ),
      rank = if (is.function(rank) && length(formals(rank)) >= 3L) {
        rank
      } else {
        capr_abort(
          "capr_planner_invalid",
          "`rank` must be a function(candidates, question, policy)",
          field = "rank"
        )
      }
    ),
    class = "capr_planner"
  )
}

capr_validate_planner <- function(planner) {
  if (!inherits(planner, "capr_planner") ||
      !identical(planner$schema, capr_schema("planner")) ||
      !(is.null(planner$rank) || is.function(planner$rank))) {
    capr_abort("capr_planner_invalid", "invalid capR planner object")
  }
  invisible(planner)
}

# The built-in planner keeps rank = NULL: cap_select_fields() executes the
# original ordering statements verbatim when it sees the default id, so the
# fixture-pinned plan bytes cannot drift through re-expression.
capr_builtin_planner <- function() {
  structure(
    list(
      schema = capr_schema("planner"),
      id = .capr_default_planner_id,
      version = "1.0.0",
      provider = "capR",
      rank = NULL
    ),
    class = "capr_planner"
  )
}

capr_resolve_planner <- function(planner) {
  if (is.null(planner)) {
    return(capr_builtin_planner())
  }
  if (inherits(planner, "capr_planner")) {
    capr_validate_planner(planner)
    return(planner)
  }
  if (is.character(planner) && length(planner) == 1L && !is.na(planner)) {
    if (identical(planner, .capr_default_planner_id)) {
      return(capr_builtin_planner())
    }
    entry <- .capr_strategy_registry()$planners[[planner]]
    if (!is.null(entry)) {
      return(entry)
    }
    capr_abort(
      "capr_planner_invalid",
      "planner is not registered",
      planner_id = planner
    )
  }
  capr_abort(
    "capr_planner_invalid",
    "planner must be NULL, a planner id, or a capr_planner object"
  )
}

capr_validate_ranking <- function(ordering, n, planner_id) {
  if (!is.numeric(ordering) || length(ordering) != n || anyNA(ordering) ||
      any(ordering != floor(ordering)) ||
      !setequal(as.integer(ordering), seq_len(n))) {
    capr_abort(
      "capr_planner_invalid",
      "planner `rank` must return a permutation of the candidate indices",
      planner_id = planner_id,
      expected_length = n
    )
  }
  as.integer(ordering)
}

# Read-only candidate views handed to custom rank functions.
capr_planner_views <- function(candidates) {
  lapply(candidates, function(candidate) {
    list(
      field_id = candidate$field$id,
      level = candidate$level,
      estimated_cost = candidate$estimated_cost,
      prior_value = candidate$prior_value,
      intent_adjustment = candidate$intent_adjustment,
      score = candidate$score,
      ratio = candidate$ratio,
      timing = candidate$field$timing,
      trust = candidate$field$trust,
      exec = candidate$field$exec,
      label = candidate$field$label,
      intent_tags = candidate$field$selectionHints$intentTags %||% list()
    )
  })
}

# Sidecar strategies block; NULL (omitted) whenever both strategies are the
# built-ins so default artifacts stay byte-identical.
capr_strategies_sidecar <- function(planner, tokenizer) {
  if (identical(planner$id, .capr_default_planner_id) &&
      identical(tokenizer$id, .capr_default_tokenizer_id)) {
    return(NULL)
  }
  list(
    planner_id = planner$id,
    planner_version = planner$version,
    tokenizer_id = tokenizer$id,
    tokenizer_version = tokenizer$version
  )
}

#' Register, unregister, and list selection planners
#'
#' The planner registry follows the adapter registry contract:
#' re-registering an identical planner is idempotent, registering a
#' different planner under an existing id raises `capr_registry_conflict`,
#' and built-in ids cannot be shadowed.
#'
#' @param planner A `capr_planner` from [cap_planner()].
#' @return `cap_register_planner()` returns the planner invisibly;
#'   `cap_unregister_planner()` returns the removed count invisibly;
#'   `cap_list_planners()` returns a deterministic data frame.
#' @export
cap_register_planner <- function(planner) {
  capr_validate_planner(planner)
  capr_strategy_id(planner$id, "capr_planner_invalid")
  capr_strategy_register(
    "planners", planner, "rank", "capr_planner_invalid"
  )
}

#' @rdname cap_register_planner
#' @param id Planner id to remove; `NULL` clears the registry.
#' @export
cap_unregister_planner <- function(id = NULL) {
  capr_strategy_unregister("planners", id)
}

#' @rdname cap_register_planner
#' @export
cap_list_planners <- function() {
  capr_strategy_list("planners")
}
