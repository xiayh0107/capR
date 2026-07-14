# Provider-neutral implementations of the agent-facing tools. The aisdk (and
# any future ellmer/MCP) layer wraps these closures; keeping the logic here
# makes every tool testable without any LLM framework installed.
#
# Every mutating tool synthesizes a full cap.contract_response.v1 and pushes
# it through cap_agent_step(), so the complete validate -> gate -> patch ->
# apply path runs regardless of tool granularity. Tool-input mistakes are
# returned to the model as structured error payloads (so a tool loop can
# self-correct); session invariant violations keep failing closed.

capr_require_suggests <- function(package, caller) {
  if (!requireNamespace(package, quietly = TRUE)) {
    capr_abort(
      "capr_dependency_missing",
      sprintf(
        "%s requires the suggested package {%s}; install it first",
        caller, package
      ),
      package = package
    )
  }
  invisible(TRUE)
}

capr_agent_tool_payload <- function(tool, fields) {
  capr_canonical_json(c(
    list(schema = capr_schema("agent_tool_result"), tool = tool),
    fields
  ))
}

capr_agent_tool_error <- function(tool, condition) {
  capr_agent_tool_payload(tool, list(
    ok = FALSE,
    error = list(
      class = class(condition)[[1L]],
      message = conditionMessage(condition)
    )
  ))
}

capr_agent_problem_summaries <- function(problems) {
  lapply(problems, function(problem) {
    list(
      code = problem$code,
      message = problem$message,
      fieldId = problem$fieldId
    )
  })
}

capr_agent_manifest_fields <- function(session, selected) {
  rows <- Filter(
    function(row) {
      if (selected) {
        isTRUE(row$selected)
      } else {
        identical(row$timing, "interactive") && !isTRUE(row$selected)
      }
    },
    session$digest$manifest$fields
  )
  lapply(rows, function(row) {
    list(
      fieldId = row$fieldId,
      level = row$level,
      estimatedCost = row$estimatedCost
    )
  })
}

capr_agent_tool_read_digest <- function(session) {
  capr_validate_agent_session(session)
  session$digest$text
}

# JSON tool arguments may arrive simplified (a data.frame instead of a list
# of records) depending on the calling framework's parser.
capr_agent_tool_records <- function(x) {
  if (is.data.frame(x)) {
    return(lapply(seq_len(nrow(x)), function(index) {
      record <- as.list(x[index, , drop = FALSE])
      lapply(record, function(value) {
        if (is.list(value)) value[[1L]] else value
      })
    }))
  }
  x
}

capr_agent_normalize_tool_requests <- function(requests) {
  requests <- capr_agent_tool_records(requests)
  if (!is.list(requests) || !length(requests)) {
    capr_abort(
      "capr_agent_invalid",
      "`requests` must be a non-empty list of field requests",
      field = "requests"
    )
  }
  lapply(seq_along(requests), function(index) {
    request <- requests[[index]]
    if (!is.list(request)) {
      capr_abort(
        "capr_agent_invalid",
        sprintf("request %d must be a named list", index),
        field = "requests"
      )
    }
    field_id <- request$field_id %||% request$fieldId
    normalized <- list(
      fieldId = capr_assert_scalar_character(
        field_id %||% "", "field_id", condition = "capr_agent_invalid"
      ),
      reason = capr_assert_scalar_character(
        request$reason %||% "", "reason", condition = "capr_agent_invalid"
      )
    )
    if (!is.null(request$level)) {
      normalized$level <- capr_assert_count(
        request$level, "level", condition = "capr_agent_invalid"
      )
    }
    if (!is.null(request$budget)) {
      normalized$budget <- capr_assert_count(
        request$budget, "budget", condition = "capr_agent_invalid"
      )
    }
    normalized
  })
}

capr_agent_tool_request_fields <- function(session, requests) {
  capr_validate_agent_session(session)
  tool <- "capr_request_fields"
  turn <- tryCatch(
    {
      normalized <- capr_agent_normalize_tool_requests(requests)
      cap_agent_step(session, list(
        claims = list(),
        evidence = list(),
        warnings = list(),
        requests = normalized
      ))
    },
    capr_agent_invalid = function(condition) condition
  )
  if (inherits(turn, "condition")) {
    return(capr_agent_tool_error(tool, turn))
  }
  decisions <- lapply(turn$gate$requests %||% list(), function(decision) {
    list(
      fieldId = decision$request$fieldId,
      decision = decision$decision,
      approvedLevel = decision$approvedLevel,
      approvedBudget = decision$approvedBudget,
      problems = capr_agent_problem_summaries(decision$problems)
    )
  })
  capr_agent_tool_payload(tool, list(
    ok = isTRUE(turn$patchApplied),
    outcome = turn$outcome,
    decisions = decisions,
    validationErrors = capr_agent_problem_summaries(
      turn$validation$errors
    ),
    newFieldBlocks = as.list(if (isTRUE(turn$patchApplied)) {
      session$last_delta
    } else {
      character()
    }),
    remainingBudget = turn$followupBudgetRemaining,
    digestChanged = isTRUE(turn$patchApplied)
  ))
}

capr_agent_normalize_tool_claims <- function(claims) {
  claims <- capr_agent_tool_records(claims)
  if (!is.list(claims) || !length(claims)) {
    capr_abort(
      "capr_agent_invalid",
      "`claims` must be a non-empty list of claims",
      field = "claims"
    )
  }
  lapply(seq_along(claims), function(index) {
    claim <- claims[[index]]
    if (!is.list(claim)) {
      capr_abort(
        "capr_agent_invalid",
        sprintf("claim %d must be a named list", index),
        field = "claims"
      )
    }
    evidence <- claim$evidence %||% list()
    if (is.character(evidence)) evidence <- as.list(evidence)
    list(
      id = capr_assert_scalar_character(
        claim$id %||% sprintf("claim-%d", index),
        "id",
        condition = "capr_agent_invalid"
      ),
      text = capr_assert_scalar_character(
        claim$text %||% "", "text", condition = "capr_agent_invalid"
      ),
      evidence = lapply(evidence, function(field_id) {
        capr_assert_scalar_character(
          field_id, "evidence", condition = "capr_agent_invalid"
        )
      })
    )
  })
}

capr_agent_tool_submit_claims <- function(session, claims) {
  capr_validate_agent_session(session)
  tool <- "capr_submit_claims"
  turn <- tryCatch(
    {
      normalized <- capr_agent_normalize_tool_claims(claims)
      cap_agent_step(session, list(
        claims = normalized,
        evidence = list(),
        warnings = list(),
        requests = list()
      ))
    },
    capr_agent_invalid = function(condition) condition
  )
  if (inherits(turn, "condition")) {
    return(capr_agent_tool_error(tool, turn))
  }
  capr_agent_tool_payload(tool, list(
    ok = identical(turn$outcome, "answered"),
    outcome = turn$outcome,
    validationErrors = capr_agent_problem_summaries(
      turn$validation$errors
    )
  ))
}

capr_agent_tool_status <- function(session) {
  capr_validate_agent_session(session)
  capr_agent_tool_payload("capr_session_status", list(
    ok = TRUE,
    sessionId = session$session_id,
    status = session$status,
    stopReason = session$stop_reason,
    turnsUsed = length(session$turns),
    maxTurns = session$max_turns,
    followupBudgetRemaining = as.integer(session$followup_remaining),
    disclosedFields = capr_agent_manifest_fields(session, selected = TRUE),
    requestableFields = capr_agent_manifest_fields(session, selected = FALSE)
  ))
}
