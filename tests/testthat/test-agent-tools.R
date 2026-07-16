tool_result <- function(payload) {
  jsonlite::fromJSON(payload, simplifyVector = FALSE)
}

test_that("read digest tool returns the raw digest text", {
  session <- agent_fixture_session()
  expect_identical(
    capr_agent_tool_read_digest(session),
    session$digest$text
  )
})

test_that("request tool discloses fields through the gate", {
  session <- agent_fixture_session()
  result <- tool_result(capr_agent_tool_request_fields(
    session,
    list(list(
      field_id = "f1:table@sample#k10",
      reason = "Need sample rows.",
      level = 1,
      budget = 300
    ))
  ))
  expect_identical(result$schema, "capr.agent_tool_result.v1")
  expect_true(result$ok)
  expect_identical(result$outcome, "extended")
  expect_identical(result$decisions[[1L]]$decision, "approved")
  expect_identical(result$remainingBudget, 40L)
  expect_true(result$digestChanged)
  expect_match(
    result$newFieldBlocks[[1L]],
    '<field id="f1:table@sample#k10"',
    fixed = TRUE
  )
  expect_identical(session$status, "active")
})

test_that("denied requests keep the session alive for claims", {
  session <- agent_fixture_session()
  denied <- tool_result(capr_agent_tool_request_fields(
    session,
    list(list(field_id = "f1:table@shape#base", reason = "Again."))
  ))
  expect_false(denied$ok)
  expect_identical(denied$outcome, "denied_all")
  expect_identical(
    denied$decisions[[1L]]$problems[[1L]]$code,
    "already_selected"
  )
  expect_length(denied$newFieldBlocks, 0L)
  expect_identical(session$status, "active")

  answered <- tool_result(capr_agent_tool_submit_claims(
    session,
    list(list(
      id = "claim-1",
      text = "Shape is disclosed.",
      evidence = list("f1:table@shape#base")
    ))
  ))
  expect_true(answered$ok)
  expect_identical(answered$outcome, "answered")
  expect_identical(session$status, "active")
})

test_that("unknown request fields surface validation errors", {
  session <- agent_fixture_session()
  result <- tool_result(capr_agent_tool_request_fields(
    session,
    list(list(field_id = "f1:table@missing#x", reason = "Curious."))
  ))
  expect_false(result$ok)
  expect_identical(result$outcome, "invalid_response")
  expect_length(result$decisions, 0L)
  expect_identical(
    result$validationErrors[[1L]]$code,
    "unknown_request_field"
  )
})

test_that("claims citing undisclosed fields are rejected with errors", {
  session <- agent_fixture_session()
  result <- tool_result(capr_agent_tool_submit_claims(
    session,
    list(list(
      id = "claim-1",
      text = "Sample rows say so.",
      evidence = list("f1:table@sample#k10")
    ))
  ))
  expect_false(result$ok)
  expect_identical(result$outcome, "invalid_response")
  expect_identical(
    result$validationErrors[[1L]]$code,
    "evidence_rejected_field"
  )
})

test_that("malformed tool input returns an error payload, not an R error", {
  session <- agent_fixture_session()
  empty <- tool_result(capr_agent_tool_request_fields(session, list()))
  expect_false(empty$ok)
  expect_identical(empty$error$class, "capr_agent_invalid")

  missing_reason <- tool_result(capr_agent_tool_request_fields(
    session,
    list(list(field_id = "f1:table@sample#k10", reason = ""))
  ))
  expect_false(missing_reason$ok)
  expect_identical(missing_reason$error$class, "capr_agent_invalid")

  bad_claims <- tool_result(capr_agent_tool_submit_claims(session, list()))
  expect_false(bad_claims$ok)
  expect_identical(bad_claims$error$class, "capr_agent_invalid")
  expect_identical(session$status, "active")
  expect_length(session$turns, 0L)
})

test_that("closed sessions answer tool calls with an error payload", {
  session <- agent_fixture_session()
  session$context$fingerprint <- "changed"
  stale <- tool_result(capr_agent_tool_request_fields(
    session,
    list(list(field_id = "f1:table@sample#k10", reason = "Need rows."))
  ))
  expect_identical(stale$outcome, "stale_source")
  expect_identical(session$status, "closed")

  after <- tool_result(capr_agent_tool_submit_claims(
    session,
    list(list(id = "claim-1", text = "x", evidence = list()))
  ))
  expect_false(after$ok)
  expect_identical(after$error$class, "capr_agent_invalid")
})

test_that("status tool reports budgets and field inventories", {
  session <- agent_fixture_session()
  status <- tool_result(capr_agent_tool_status(session))
  expect_identical(status$sessionId, session$session_id)
  expect_identical(status$status, "active")
  expect_identical(status$turnsUsed, 0L)
  expect_identical(status$followupBudgetRemaining, 340L)
  disclosed <- vapply(
    status$disclosedFields, `[[`, character(1), "fieldId"
  )
  requestable <- vapply(
    status$requestableFields, `[[`, character(1), "fieldId"
  )
  expect_true("f1:table@shape#base" %in% disclosed)
  expect_identical(requestable, "f1:table@sample#k10")

  capr_agent_tool_request_fields(
    session,
    list(list(field_id = "f1:table@sample#k10", reason = "Need rows."))
  )
  status <- tool_result(capr_agent_tool_status(session))
  expect_identical(status$turnsUsed, 1L)
  expect_identical(status$followupBudgetRemaining, 40L)
  expect_length(status$requestableFields, 0L)
})

test_that("missing suggested packages fail with a typed condition", {
  expect_error(
    capr_require_suggests(
      "capR.definitely.not.installed", "cap_aisdk_tools()"
    ),
    class = "capr_dependency_missing"
  )
})
