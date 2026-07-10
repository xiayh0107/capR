.capr_field_id_pattern <- paste0(
  "^f1:[a-z][a-z0-9_]*@",
  "[a-z][a-z0-9_]*(?:[-_][a-z0-9_]+)*",
  "#[a-z0-9]+(?:[-_][a-z0-9]+)*$"
)

#' Validate a field catalog
#'
#' @param catalog A `cap.field_catalog.v1` list.
#' @return The catalog, invisibly.
#' @export
cap_validate_field_catalog <- function(catalog) {
  required <- c("schema", "catalogId", "sourceType", "versions", "fields")
  if (!is.list(catalog) ||
      length(setdiff(required, names(catalog))) ||
      !identical(catalog$schema, "cap.field_catalog.v1") ||
      !is.list(catalog$fields) || !length(catalog$fields)) {
    capr_abort(
      "capr_adapter_invalid",
      "invalid cap.field_catalog.v1 object"
    )
  }
  ids <- vapply(catalog$fields, function(field) {
    field_required <- c(
      "schema", "id", "label", "description", "sourceTypes",
      "timing", "trust", "exec", "levels"
    )
    if (!is.list(field) ||
        length(setdiff(field_required, names(field))) ||
        !identical(field$schema, "cap.field.v1")) {
      capr_abort(
        "capr_adapter_invalid",
        "field catalog contains an invalid cap.field.v1 entry"
      )
    }
    if (!grepl(.capr_field_id_pattern, field$id, perl = TRUE)) {
      capr_abort(
        "capr_adapter_invalid",
        "field ID does not match the v1 grammar",
        field_id = field$id
      )
    }
    source_family <- sub("^f1:([^@]+)@.*$", "\\1", field$id)
    if (!identical(source_family, catalog$sourceType) ||
        !catalog$sourceType %in% unlist(field$sourceTypes, use.names = FALSE)) {
      capr_abort(
        "capr_adapter_invalid",
        "field source type does not match its catalog",
        field_id = field$id,
        source_type = catalog$sourceType
      )
    }
    if (!field$timing %in% c("assemble", "interactive") ||
        !field$trust %in% c("code", "derived", "data") ||
        !field$exec %in% c(
          "local_cheap", "local_scan", "remote_query", "unsafe"
        )) {
      capr_abort(
        "capr_adapter_invalid",
        "field trust, timing, or execution class is unsupported",
        field_id = field$id
      )
    }
    if (!is.list(field$levels) || !length(field$levels)) {
      capr_abort(
        "capr_adapter_invalid",
        "field levels must be a non-empty list",
        field_id = field$id
      )
    }
    levels <- vapply(field$levels, function(level) {
      capr_assert_count(
        level$level, "level", condition = "capr_adapter_invalid"
      )
    }, integer(1))
    if (any(levels < 1L) || anyDuplicated(levels)) {
      capr_abort(
        "capr_adapter_invalid",
        "field levels must be unique positive integers",
        field_id = field$id
      )
    }
    for (level in field$levels) {
      capr_assert_count(
        level$estimatedCost,
        "estimatedCost",
        condition = "capr_adapter_invalid"
      )
      capr_assert_scalar_character(
        level$description,
        "description",
        condition = "capr_adapter_invalid"
      )
    }
    if (!is.null(field$contracts)) {
      capr_contract_symbolic(list(fields = list(field)))
    }
    field$id
  }, character(1))
  if (anyDuplicated(ids)) {
    capr_abort(
      "capr_duplicate_field_id",
      "field catalog contains duplicate IDs",
      field_ids = unique(ids[duplicated(ids)])
    )
  }
  invisible(catalog)
}

capr_question_adjustment <- function(question, field) {
  if (is.null(question) || !nzchar(question)) return(0)
  tags <- unlist(
    field$selectionHints$intentTags %||% list(),
    use.names = FALSE
  )
  if (!length(tags)) return(0)
  lower <- tolower(enc2utf8(question))
  0.25 * sum(vapply(
    tolower(enc2utf8(tags)),
    function(tag) grepl(tag, lower, fixed = TRUE),
    logical(1)
  ))
}

#' Plan field selection deterministically
#'
#' @param catalog Valid field catalog.
#' @param budget Non-negative initial budget.
#' @param question Optional user intent.
#' @param policy Host policy.
#' @param include_interactive Internal switch used only after gate approval.
#' @return A complete selected/rejected plan.
#' @keywords internal
cap_select_fields <- function(catalog, budget = 800L, question = NULL,
                              policy = cap_policy(),
                              include_interactive = FALSE) {
  cap_validate_field_catalog(catalog)
  capr_validate_policy(policy)
  budget <- capr_assert_count(
    budget, "budget", condition = "capr_policy_invalid"
  )
  budget <- min(budget, policy$max_budget)
  include_interactive <- capr_assert_flag(
    include_interactive, "include_interactive", "capr_policy_invalid"
  )
  if (!is.null(question)) {
    question <- capr_assert_scalar_character(
      question, "question", allow_empty = TRUE,
      condition = "capr_policy_invalid"
    )
  }

  candidates <- list()
  for (field_index in seq_along(catalog$fields)) {
    field <- catalog$fields[[field_index]]
    prior <- field$selectionHints$priorValue %||% 0
    adjustment <- capr_question_adjustment(question, field)
    for (level_index in seq_along(field$levels)) {
      level <- field$levels[[level_index]]
      authorization <- cap_authorize_execution(
        policy,
        field$exec
      )
      cost <- as.integer(level$estimatedCost)
      score <- as.numeric(prior) + adjustment
      ratio <- if (cost == 0L) Inf else score / cost
      candidates[[length(candidates) + 1L]] <- list(
        field = field,
        field_index = field_index,
        level = as.integer(level$level),
        estimated_cost = cost,
        prior_value = as.numeric(prior),
        intent_adjustment = adjustment,
        score = score,
        ratio = ratio,
        authorization = authorization,
        selected = FALSE,
        rejected_reason = NULL
      )
    }
  }

  eligible <- vapply(candidates, function(candidate) {
    field <- candidate$field
    if (identical(field$timing, "interactive") && !include_interactive) {
      candidate$rejected_reason <- "interactive_only"
      return(FALSE)
    }
    isTRUE(candidate$authorization$allowed)
  }, logical(1))
  for (index in seq_along(candidates)) {
    if (identical(candidates[[index]]$field$timing, "interactive") &&
        !include_interactive) {
      candidates[[index]]$rejected_reason <- "interactive_only"
    } else if (!candidates[[index]]$authorization$allowed) {
      candidates[[index]]$rejected_reason <- "exec_not_allowed"
    }
  }

  eligible_indices <- which(eligible)
  if (length(eligible_indices)) {
    ordering <- order(
      -vapply(candidates[eligible_indices], `[[`, numeric(1), "ratio"),
      -vapply(candidates[eligible_indices], `[[`, numeric(1), "score"),
      vapply(candidates[eligible_indices], `[[`, integer(1), "estimated_cost"),
      vapply(
        candidates[eligible_indices],
        function(candidate) candidate$field$id,
        character(1)
      ),
      -vapply(candidates[eligible_indices], `[[`, integer(1), "level"),
      method = "radix"
    )
    spent <- 0L
    selected_fields <- character()
    for (index in eligible_indices[ordering]) {
      candidate <- candidates[[index]]
      if (candidate$field$id %in% selected_fields) {
        candidates[[index]]$rejected_reason <- "level_superseded"
      } else if (spent + candidate$estimated_cost <= budget) {
        candidates[[index]]$selected <- TRUE
        candidates[[index]]$rejected_reason <- NULL
        selected_fields <- c(selected_fields, candidate$field$id)
        spent <- spent + candidate$estimated_cost
      } else {
        candidates[[index]]$rejected_reason <- "over_budget"
      }
    }
  } else {
    spent <- 0L
  }

  structure(
    list(
      schema = "capr.selection_plan.v1",
      catalog_id = catalog$catalogId,
      budget_requested = budget,
      budget_estimated_selected = as.integer(spent),
      planner = "capr-greedy-value-cost-v1",
      tokenizer = "heuristic_v1",
      question = question,
      candidates = candidates
    ),
    class = "capr_selection_plan"
  )
}
