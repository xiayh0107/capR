test_that("slow tokenizers fail typed, never as raw simpleError", {
  table <- fixture_table("basic-table")
  sleepy <- cap_tokenizer(
    id = "sleepy-v1",
    version = "1.0.0",
    count = function(rendered, field_id) {
      # Busy loop: elapsed-time limits interrupt R evaluation reliably,
      # while Sys.sleep interruption is platform-dependent.
      start <- proc.time()[["elapsed"]]
      while (proc.time()[["elapsed"]] - start < 0.5) sum(seq_len(1000L))
      1L
    }
  )
  condition <- tryCatch(
    cap_digest(
      table,
      budget = 500,
      policy = cap_policy(max_budget = 500, max_field_seconds = 0.05),
      fingerprint = fixture_fingerprint("basic-table"),
      tokenizer = sleepy
    ),
    condition = function(e) e
  )
  expect_s3_class(condition, "capr_error")
  expect_s3_class(condition, "capr_tokenizer_invalid")
  expect_match(
    conditionMessage(condition),
    "exceeded the field time budget",
    fixed = TRUE
  )
})

test_that("throwing tokenizers surface their cause as the parent", {
  table <- fixture_table("basic-table")
  broken <- cap_tokenizer(
    id = "throws-v1",
    version = "1.0.0",
    count = function(rendered, field_id) stop("provider unreachable")
  )
  condition <- tryCatch(
    cap_digest(table, budget = 500, tokenizer = broken),
    condition = function(e) e
  )
  expect_s3_class(condition, "capr_tokenizer_invalid")
  expect_match(conditionMessage(condition), "failed", fixed = TRUE)
  expect_match(
    conditionMessage(condition$parent),
    "provider unreachable",
    fixed = TRUE
  )
})

test_that("parameterized closures cannot silently collide in the registry", {
  make_tokenizer <- function(weight) {
    cap_tokenizer(
      id = "weighted-v1",
      version = "1.0.0",
      count = function(rendered, field_id) {
        weight * nchar(rendered, type = "chars")
      }
    )
  }
  on.exit(cap_unregister_tokenizer("weighted-v1"), add = TRUE)
  first <- make_tokenizer(1L)
  cap_register_tokenizer(first)
  cap_register_tokenizer(first)
  cap_register_tokenizer(make_tokenizer(1L))
  expect_error(
    cap_register_tokenizer(make_tokenizer(2L)),
    class = "capr_registry_conflict"
  )

  make_planner <- function(weight) {
    cap_planner(
      id = "weighted-rank-v1",
      version = "1.0.0",
      rank = function(candidates, question, policy) {
        order(vapply(candidates, `[[`, numeric(1), "ratio") * weight)
      }
    )
  }
  on.exit(cap_unregister_planner("weighted-rank-v1"), add = TRUE)
  cap_register_planner(make_planner(1))
  cap_register_planner(make_planner(1))
  expect_error(
    cap_register_planner(make_planner(-1)),
    class = "capr_registry_conflict"
  )
})

test_that("a smuggled process-local tokenizer cannot bypass the pin", {
  table <- fixture_table("followup-basic")
  digest <- cap_digest(
    table,
    budget = 500,
    policy = cap_policy(max_budget = 500),
    fingerprint = fixture_fingerprint("followup-basic")
  )
  validation <- cap_validate_response(
    digest,
    read_fixture_json("followup-basic", "response.json")
  )
  gate <- cap_gate(
    digest,
    validation,
    policy = cap_policy(max_budget = 500, max_followup_budget = 340)
  )
  digest$tokenizer <- cap_tokenizer(
    id = "smuggled-v1",
    version = "1.0.0",
    count = function(rendered, field_id) {
      10L * nchar(rendered, type = "chars")
    }
  )
  expect_error(
    cap_patch(
      digest,
      gate,
      table,
      policy = cap_policy(max_budget = 500, max_followup_budget = 340),
      fingerprint = fixture_fingerprint("followup-basic")
    ),
    class = "capr_tokenizer_invalid"
  )
})

test_that("empty strategy listings keep a stable schema", {
  expect_identical(cap_unregister_planner(), 0L)
  expect_identical(cap_unregister_tokenizer(), 0L)
  planners <- cap_list_planners()
  tokenizers <- cap_list_tokenizers()
  expect_identical(names(planners), c("id", "version", "provider"))
  expect_identical(names(tokenizers), c("id", "version", "provider"))
  expect_identical(planners$id, character(0))
  expect_identical(tokenizers$id, character(0))
})
