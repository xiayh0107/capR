test_that("aisdk tool list mirrors the core tool surface", {
  skip_if_not_installed("aisdk")
  session <- agent_fixture_session()
  tools <- cap_aisdk_tools(session)
  expect_length(tools, 4L)
  expect_identical(
    vapply(tools, function(tool) tool$name, character(1)),
    c(
      "capr_read_digest", "capr_request_fields",
      "capr_submit_claims", "capr_session_status"
    )
  )
  for (tool in tools) {
    expect_s3_class(tool, "Tool")
    expect_true(nzchar(tool$description))
  }
})

test_that("aisdk tools drive the gate-backed round trip without a model", {
  skip_if_not_installed("aisdk")
  session <- agent_fixture_session()
  tools <- cap_aisdk_tools(session)
  names(tools) <- vapply(tools, function(tool) tool$name, character(1))

  digest_text <- tools[["capr_read_digest"]]$run(list())
  expect_identical(digest_text, session$digest$text)
  expect_match(digest_text, "<available_on_request>", fixed = TRUE)

  requested <- jsonlite::fromJSON(
    tools[["capr_request_fields"]]$run(list(
      requests = list(list(
        field_id = "f1:table@sample#k10",
        reason = "Need sample rows for a concrete example."
      ))
    )),
    simplifyVector = FALSE
  )
  expect_true(requested$ok)
  expect_identical(requested$decisions[[1L]]$decision, "approved")
  expect_identical(session$digest$manifest$budget$used, 340L)

  answered <- jsonlite::fromJSON(
    tools[["capr_submit_claims"]]$run(list(
      claims = list(list(
        id = "claim-1",
        text = "The sample rows are disclosed.",
        evidence = list("f1:table@sample#k10")
      ))
    )),
    simplifyVector = FALSE
  )
  expect_true(answered$ok)
  expect_identical(answered$outcome, "answered")

  status <- jsonlite::fromJSON(
    tools[["capr_session_status"]]$run(list()),
    simplifyVector = FALSE
  )
  expect_identical(status$turnsUsed, 2L)
  expect_length(status$requestableFields, 0L)
  expect_identical(session$status, "active")
})

test_that("aisdk tools tolerate data.frame-simplified arguments", {
  skip_if_not_installed("aisdk")
  session <- agent_fixture_session()
  tools <- cap_aisdk_tools(session)
  names(tools) <- vapply(tools, function(tool) tool$name, character(1))
  result <- jsonlite::fromJSON(
    tools[["capr_request_fields"]]$run(list(
      requests = data.frame(
        field_id = "f1:table@sample#k10",
        reason = "Need rows.",
        stringsAsFactors = FALSE
      )
    )),
    simplifyVector = FALSE
  )
  expect_true(result$ok)
  expect_identical(result$decisions[[1L]]$decision, "approved")
})

test_that("cap_aisdk_agent wires instructions and tools together", {
  skip_if_not_installed("aisdk")
  session <- agent_fixture_session()
  agent <- cap_aisdk_agent(session)
  expect_identical(agent$name, "capr-analyst")
  expect_identical(agent$system_prompt, cap_agent_instructions())
  expect_length(agent$tools, 4L)
})

test_that("aisdk entry points validate the session", {
  skip_if_not_installed("aisdk")
  expect_error(
    cap_aisdk_tools(structure(list(), class = "capr_agent_session")),
    class = "capr_agent_invalid"
  )
})
