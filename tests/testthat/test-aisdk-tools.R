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

# Offline stand-in for an aisdk model, mirroring aisdk's own MockModel test
# helper: an R6 subclass of LanguageModelV1 that replays canned do_generate
# responses and inherits the local token-counting heuristic
# (ceiling(chars / 4) plus a fixed overhead of 8 per message).
aisdk_mock_model <- function(responses = list(), model_id = "Mock Model/v1") {
  generator <- R6::R6Class(
    "CaprAisdkMockModel",
    inherit = aisdk::LanguageModelV1,
    public = list(
      responses = list(),
      initialize = function(responses, model_id) {
        super$initialize(provider = "mock", model_id = model_id)
        self$responses <- responses
      },
      do_generate = function(params) {
        if (!length(self$responses)) {
          stop("aisdk mock model ran out of canned responses", call. = FALSE)
        }
        response <- self$responses[[1L]]
        self$responses <- self$responses[-1L]
        response
      }
    )
  )
  generator$new(responses, model_id)
}

# A canned tool-mode reply carrying `object` as the forced
# cap_contract_response tool call's arguments.
aisdk_contract_tool_call <- function(object) {
  list(
    text = "",
    finish_reason = "tool_calls",
    usage = list(total_tokens = 5L),
    tool_calls = list(list(
      id = "call-1",
      name = "cap_contract_response",
      arguments = object
    ))
  )
}

test_that("cap_aisdk_tokenizer derives a valid id and counts via aisdk", {
  skip_if_not_installed("aisdk")
  tokenizer <- cap_aisdk_tokenizer(aisdk_mock_model())
  expect_s3_class(tokenizer, "capr_tokenizer")
  expect_identical(tokenizer$id, "aisdk-mock-model-v1")
  expect_match(tokenizer$id, "^[a-z0-9][a-z0-9._-]*$")
  expect_identical(tokenizer$provider, "aisdk")
  expect_identical(tokenizer$version, "1.0.0")
  rendered <- "f1:table@shape#base rows=2 cols=2"
  expect_identical(
    tokenizer$count(rendered, "f1:table@shape#base"),
    as.integer(ceiling(nchar(rendered) / 4)) + 8L
  )
})

test_that("cap_aisdk_tokenizer honors id overrides and validates input", {
  skip_if_not_installed("aisdk")
  custom <- cap_aisdk_tokenizer(
    aisdk_mock_model(), id = "anthropic-exact-v2", version = "2.1.0"
  )
  expect_identical(custom$id, "anthropic-exact-v2")
  expect_identical(custom$version, "2.1.0")
  spec <- cap_aisdk_tokenizer("anthropic:claude-sonnet-5")
  expect_identical(spec$id, "aisdk-anthropic-claude-sonnet-5")
  expect_error(
    cap_aisdk_tokenizer(42L),
    class = "capr_tokenizer_invalid"
  )
  expect_error(
    cap_aisdk_tokenizer(aisdk_mock_model(), id = "Bad Id"),
    class = "capr_tokenizer_invalid"
  )
  expect_error(
    cap_aisdk_tokenizer(aisdk_mock_model(model_id = "")),
    class = "capr_tokenizer_invalid"
  )
})

test_that("cap_digest stamps the aisdk tokenizer into budget accounting", {
  skip_if_not_installed("aisdk")
  digest <- cap_digest(
    fixture_table("basic-table"),
    budget = 5000,
    policy = cap_policy(max_budget = 5000),
    fingerprint = fixture_fingerprint("basic-table"),
    tokenizer = cap_aisdk_tokenizer(aisdk_mock_model())
  )
  expect_identical(
    digest$manifest$budget$tokenizer, "aisdk-mock-model-v1"
  )
  header <- strsplit(digest$text, "\n", fixed = TRUE)[[1L]][[1L]]
  expect_match(header, "tokenizer=aisdk-mock-model-v1", fixed = TRUE)
})

test_that("cap_aisdk_ask builds a schema-constrained ask function", {
  skip_if_not_installed("aisdk")
  ask <- cap_aisdk_ask(aisdk_mock_model())
  expect_true(is.function(ask))
  expect_named(formals(ask), "prompt")
  expect_error(cap_aisdk_ask(NULL), class = "capr_agent_invalid")
  expect_error(
    cap_aisdk_ask(aisdk_mock_model(), max_retries = -1L),
    class = "capr_agent_invalid"
  )
  expect_error(cap_aisdk_ask(aisdk_mock_model(), mode = "yaml"))
})

test_that("cap_aisdk_ask drives cap_agent_run through canned tool calls", {
  skip_if_not_installed("aisdk")
  model <- aisdk_mock_model(list(
    aisdk_contract_tool_call(agent_request_response()),
    aisdk_contract_tool_call(
      agent_claims_response(list("f1:table@sample#k10"))
    )
  ))
  session <- agent_fixture_session()
  cap_agent_run(
    session, cap_aisdk_ask(model, mode = "tool", max_retries = 0L)
  )
  expect_identical(session$stop_reason, "completed")
  expect_identical(
    vapply(session$turns, `[[`, character(1), "outcome"),
    c("extended", "answered")
  )
})

test_that("cap_aisdk_ask json mode parses the model text as the contract", {
  skip_if_not_installed("aisdk")
  payload <- agent_claims_response()
  model <- aisdk_mock_model(list(list(
    text = as.character(jsonlite::toJSON(payload, auto_unbox = TRUE)),
    finish_reason = "stop",
    usage = list(total_tokens = 5L)
  )))
  ask <- cap_aisdk_ask(model, mode = "json", max_retries = 0L)
  response <- ask("prompt")
  expect_identical(response$claims[[1L]]$id, "claim-1")
  expect_identical(
    response$claims[[1L]]$evidence, list("f1:table@shape#base")
  )
})

test_that("cap_aisdk_ask returns schema-invalid objects for capR to judge", {
  skip_if_not_installed("aisdk")
  broken <- list(claims = list(list(id = "claim-1")))
  model <- aisdk_mock_model(list(aisdk_contract_tool_call(broken)))
  ask <- cap_aisdk_ask(model, mode = "tool", max_retries = 0L)
  response <- ask("prompt")
  expect_identical(response$claims[[1L]]$id, "claim-1")
  session <- agent_fixture_session()
  turn <- cap_agent_step(session, response)
  expect_identical(turn$outcome, "invalid_response")
})
