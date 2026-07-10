capr_gate_problem <- function(code, message, field_id,
                              retryable = FALSE) {
  list(
    code = code,
    message = message,
    fieldId = field_id,
    retryable = retryable
  )
}

capr_current_fingerprint <- function(digest, source) {
  if (is.null(source)) return(digest$fingerprint)
  if (is.character(source) && length(source) == 1L) return(source)
  if (is.list(source) && !is.null(source$fingerprint)) {
    return(source$fingerprint)
  }
  capr_abort(
    "capr_artifact_invalid",
    "gate source input must be fingerprint metadata, not a live source"
  )
}

#' Decide follow-up requests without materializing fields
#'
#' @param digest Original digest.
#' @param validation Validated response.
#' @param policy Host policy.
#' @param source Optional current fingerprint metadata.
#' @param policy_ref Optional policy artifact reference.
#' @param adapter Optional adapter metadata for pin compatibility checking.
#' @param ... Reserved.
#' @return A canonical `cap.gate_result.v1`.
#' @export
cap_gate <- function(digest, validation, policy = cap_policy(),
                     source = NULL, policy_ref = NULL,
                     adapter = NULL, ...) {
  if (!inherits(digest, "cap_digest") ||
      !inherits(validation, "cap_validation_result")) {
    capr_abort(
      "capr_artifact_invalid",
      "gate requires a digest and validation result"
    )
  }
  capr_validate_policy(policy)
  current_fingerprint <- capr_current_fingerprint(digest, source)
  stale <- policy$require_fingerprint_match &&
    !identical(current_fingerprint, digest$fingerprint)
  pin_problem <- FALSE
  if (!is.null(adapter) && !is.null(digest$adapter_pin)) {
    pin_problem <- inherits(tryCatch(
      {
        cap_check_adapter_pin(adapter, digest$adapter_pin)
        NULL
      },
      error = function(e) e
    ), "condition")
  }
  rows <- digest$manifest$fields
  ids <- vapply(rows, `[[`, character(1), "fieldId")
  names(rows) <- ids
  remaining <- policy$max_followup_budget
  decisions <- list()
  requests <- validation$normalizedResponse$requests

  for (index in seq_along(requests)) {
    request <- requests[[index]]
    field_id <- request$fieldId %||% ""
    row <- rows[[field_id]]
    decision <- "denied"
    approved_level <- NULL
    approved_budget <- NULL
    problems <- list()
    if (!isTRUE(validation$ok)) {
      problems <- list(capr_gate_problem(
        "invalid_evidence",
        "Response evidence did not pass validation.",
        field_id
      ))
    } else if (!policy$allow_followup) {
      problems <- list(capr_gate_problem(
        "followup_disabled",
        "Follow-up is disabled by host policy.",
        field_id
      ))
    } else if (stale) {
      decision <- "stale_source"
      problems <- list(capr_gate_problem(
        "gate_stale_source",
        "Source fingerprint changed.",
        field_id,
        retryable = TRUE
      ))
    } else if (pin_problem) {
      problems <- list(capr_gate_problem(
        "adapter_pin_mismatch",
        "Pinned adapter is unavailable or incompatible.",
        field_id
      ))
    } else if (is.null(row)) {
      decision <- "unknown_field"
      problems <- list(capr_gate_problem(
        "unknown_field",
        "Requested field is unknown.",
        field_id
      ))
    } else if (isTRUE(row$selected)) {
      problems <- list(capr_gate_problem(
        "already_selected",
        "Requested field is already selected.",
        field_id
      ))
    } else if (!identical(row$timing, "interactive")) {
      decision <- "not_available"
      problems <- list(capr_gate_problem(
        "not_requestable",
        "Field is not available through follow-up.",
        field_id
      ))
    } else if (!is.null(request$level) &&
               !identical(as.integer(request$level), as.integer(row$level))) {
      decision <- "unknown_level"
      problems <- list(capr_gate_problem(
        "unknown_level",
        "Requested field level is unavailable.",
        field_id
      ))
    } else {
      authorization <- cap_authorize_execution(policy, row$exec)
      requested_budget <- request$budget %||% row$estimatedCost
      requested_budget <- capr_assert_count(
        requested_budget,
        "request budget",
        condition = "capr_policy_invalid"
      )
      if (!authorization$allowed) {
        decision <- "exec_not_allowed"
        problems <- list(capr_gate_problem(
          "exec_not_allowed",
          "Execution class is denied by host policy.",
          field_id
        ))
      } else if (requested_budget > remaining) {
        decision <- "over_budget"
        problems <- list(capr_gate_problem(
          "budget_exceeded",
          "Requested field exceeds the remaining follow-up budget.",
          field_id
        ))
      } else {
        decision <- "approved"
        approved_level <- request$level %||% row$level
        approved_budget <- requested_budget
        remaining <- remaining - requested_budget
      }
    }
    decisions[[length(decisions) + 1L]] <- list(
      requestIndex = index - 1L,
      request = request,
      decision = decision,
      approvedLevel = approved_level,
      approvedBudget = approved_budget,
      requiresUserConfirmation = FALSE,
      problems = problems
    )
  }
  decision_values <- vapply(
    decisions, `[[`, character(1), "decision"
  )
  overall <- if (any(decision_values == "stale_source")) {
    "stale_source"
  } else if (length(decision_values) &&
             all(decision_values == "approved")) {
    "approved"
  } else if (any(decision_values == "approved")) {
    "approved_with_changes"
  } else {
    "denied"
  }
  structure(
    list(
      schema = "cap.gate_result.v1",
      digestId = digest$manifest$digestId,
      fingerprint = digest$fingerprint,
      overallDecision = overall,
      remainingBudget = if (identical(overall, "stale_source")) {
        NULL
      } else {
        as.integer(remaining)
      },
      policyRef = policy_ref,
      requests = decisions,
      patch = NULL
    ),
    class = c("cap_gate_result", "list")
  )
}
