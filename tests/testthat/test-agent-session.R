test_that("agent session runs the fixture round trip to completion", {
  session <- agent_fixture_session()
  expect_s3_class(session, "capr_agent_session")
  expect_identical(session$status, "active")
  expect_identical(session$followup_remaining, 340L)

  ask <- scripted_ask(list(
    read_fixture_json("followup-basic", "response.json"),
    agent_claims_response(list("f1:table@sample#k10"))
  ))
  cap_agent_run(session, ask)

  expect_identical(session$status, "closed")
  expect_identical(session$stop_reason, "completed")
  expect_length(session$turns, 2L)
  expect_identical(session$turns[[1L]]$outcome, "extended")
  expect_true(session$turns[[1L]]$patchApplied)
  expect_identical(session$turns[[2L]]$outcome, "answered")
  expect_match(
    session$digest$text,
    '<field id="f1:table@sample#k10"',
    fixed = TRUE
  )
  expect_identical(session$digest$manifest$budget$used, 340L)
  expect_identical(session$followup_remaining, 40L)
  expect_identical(
    session$turns[[1L]]$followupBudgetRemaining,
    40L
  )
})

test_that("agent prompt carries instructions and patch deltas", {
  session <- agent_fixture_session()
  full <- cap_agent_prompt(session)
  expect_match(full, "cap.contract_response.v1", fixed = TRUE)
  expect_match(full, "cap digest text=v1", fixed = TRUE)
  bare <- cap_agent_prompt(session, instructions = FALSE)
  expect_identical(bare, session$digest$text)
  expect_identical(
    cap_agent_prompt(session, instructions = FALSE, mode = "delta"),
    session$digest$text
  )

  cap_agent_step(
    session,
    read_fixture_json("followup-basic", "response.json")
  )
  delta <- cap_agent_prompt(session, instructions = FALSE, mode = "delta")
  expect_match(delta, '<field id="f1:table@sample#k10"', fixed = TRUE)
  expect_false(grepl('<field id="f1:table@shape#base"', delta, fixed = TRUE))
})

test_that("denied requests close the linear loop as denied", {
  session <- agent_fixture_session()
  ask <- scripted_ask(list(
    agent_request_response("f1:table@shape#base", "Requesting again.")
  ))
  cap_agent_run(session, ask)
  expect_identical(session$stop_reason, "denied")
  expect_identical(session$turns[[1L]]$outcome, "denied_all")
  expect_identical(
    session$turns[[1L]]$gate$requests[[1L]]$problems[[1L]]$code,
    "already_selected"
  )
  expect_false(session$turns[[1L]]$patchApplied)
})

test_that("budget exhaustion is distinguished from other denials", {
  session <- agent_fixture_session(max_followup_budget = 100L)
  cap_agent_run(
    session,
    scripted_ask(list(read_fixture_json("followup-basic", "response.json")))
  )
  expect_identical(session$stop_reason, "budget_exhausted")
  expect_identical(session$turns[[1L]]$outcome, "budget_exhausted")
  expect_identical(
    session$turns[[1L]]$gate$requests[[1L]]$problems[[1L]]$code,
    "budget_exceeded"
  )
})

test_that("stale sources close the session fail-closed", {
  session <- agent_fixture_session()
  session$context$fingerprint <- "changed"
  turn <- cap_agent_step(
    session,
    read_fixture_json("followup-basic", "response.json")
  )
  expect_identical(turn$outcome, "stale_source")
  expect_identical(session$status, "closed")
  expect_identical(session$stop_reason, "stale_source")
  expect_false(turn$patchApplied)
  expect_error(
    cap_agent_step(session, agent_claims_response()),
    class = "capr_agent_invalid"
  )
})

test_that("invalid responses stop the loop without follow-up", {
  session <- agent_fixture_session()
  cap_agent_run(
    session,
    scripted_ask(list(
      agent_claims_response(list("f1:table@nonexistent#field"))
    ))
  )
  expect_identical(session$stop_reason, "invalid_response")
  expect_identical(session$turns[[1L]]$outcome, "invalid_response")
  expect_null(session$turns[[1L]]$gate)
})

test_that("turn limit closes the session as max_turns", {
  session <- agent_fixture_session(max_turns = 1L)
  cap_agent_run(
    session,
    scripted_ask(list(read_fixture_json("followup-basic", "response.json")))
  )
  expect_identical(session$stop_reason, "max_turns")
  expect_length(session$turns, 1L)
  expect_identical(session$turns[[1L]]$outcome, "extended")
})

test_that("session constructor and run validate their inputs", {
  expect_error(
    agent_fixture_session(max_turns = 0L),
    class = "capr_agent_invalid"
  )
  session <- agent_fixture_session()
  expect_error(
    cap_agent_run(session, ask = "not a function"),
    class = "capr_agent_invalid"
  )
  expect_error(
    cap_agent_transcript(structure(list(), class = "capr_agent_session")),
    class = "capr_agent_invalid"
  )
})

test_that("identical runs produce byte-identical transcripts", {
  run_once <- function() {
    session <- agent_fixture_session()
    cap_agent_run(session, scripted_ask(list(
      read_fixture_json("followup-basic", "response.json"),
      agent_claims_response(list("f1:table@sample#k10"))
    )))
    capr_canonical_json(cap_agent_transcript(session))
  }
  first <- run_once()
  second <- run_once()
  expect_identical(first, second)
  expect_match(first, "capr.agent_transcript.v1", fixed = TRUE)
  expect_match(first, "capr-agent-", fixed = TRUE)
})

test_that("artifact_dir publishes per-turn artifacts and a transcript", {
  dir <- file.path(tempfile("capr-agent-artifacts-"))
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  session <- agent_fixture_session(artifact_dir = dir)
  cap_agent_run(session, scripted_ask(list(
    read_fixture_json("followup-basic", "response.json"),
    agent_claims_response(list("f1:table@sample#k10"))
  )))

  initial <- cap_read_artifacts(file.path(dir, "turn-000", "digest"))
  expect_s3_class(initial, "cap_digest")
  extended <- cap_read_artifacts(file.path(dir, "turn-001", "digest"))
  expect_match(
    extended$text,
    '<field id="f1:table@sample#k10"',
    fixed = TRUE
  )
  expect_true(file.exists(
    file.path(dir, "turn-001", "validation", "validation.json")
  ))
  expect_true(file.exists(file.path(dir, "turn-001", "gate", "gate.json")))
  expect_true(file.exists(file.path(dir, "turn-001", "patch", "patch.json")))
  expect_false(dir.exists(file.path(dir, "turn-002", "digest")))
  expect_true(file.exists(
    file.path(dir, "turn-002", "validation", "validation.json")
  ))

  transcript <- jsonlite::fromJSON(
    file.path(dir, "transcript.capr.json"),
    simplifyVector = FALSE
  )
  expect_identical(transcript$schema, "capr.agent_transcript.v1")
  expect_identical(transcript$status, "closed")
  expect_identical(transcript$stopReason, "completed")
  expect_length(transcript$turns, 2L)
  expect_identical(
    capr_canonical_json(transcript),
    capr_canonical_json(cap_agent_transcript(session))
  )
})

test_that("agent session print method summarizes state", {
  session <- agent_fixture_session()
  output <- capture.output(print(session))
  expect_match(output[[1L]], "<capr_agent_session capr-agent-", fixed = TRUE)
  expect_match(output[[2L]], "status: active", fixed = TRUE)
  expect_match(output[[4L]], "340 follow-up remaining", fixed = TRUE)
})
