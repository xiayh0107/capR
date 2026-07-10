test_that("response validation matches positive basic-table fixture", {
  digest <- cap_digest(
    fixture_table("basic-table"),
    budget = 500,
    policy = cap_policy(max_budget = 500)
  )
  fixture <- read_fixture_json(
    "basic-table", "expected-validation.json"
  )
  validation <- cap_validate_response(digest, fixture$response)
  expect_identical(
    capr_canonical_json(unclass(validation)),
    capr_canonical_json(fixture$validation)
  )
  from_json <- cap_validate_response(
    digest,
    jsonlite::toJSON(fixture$response, auto_unbox = TRUE)
  )
  expect_identical(
    capr_canonical_json(unclass(from_json)),
    capr_canonical_json(fixture$validation)
  )
})

test_that("negative validation fixtures produce exact findings", {
  digest <- cap_digest(
    fixture_table("basic-table"),
    budget = 500,
    policy = cap_policy(max_budget = 500)
  )
  negative <- read_fixture_json(
    "basic-table", "negative-validation.json"
  )
  for (case in negative$cases) {
    candidate <- digest
    if (!is.null(case$digestTextFile)) {
      candidate$text <- read_fixture_text(
        "digest-text-negative", "manifest-missing.txt"
      )
    }
    actual <- cap_validate_response(candidate, case$response)
    expect_identical(
      capr_canonical_json(unclass(actual)),
      capr_canonical_json(case$validation),
      info = case$name
    )
  }
})

test_that("malformed responses never reach request execution", {
  digest <- cap_digest(data.frame(a = 1), budget = 500)
  expect_error(
    cap_validate_response(digest, "{broken"),
    class = "capr_artifact_invalid"
  )
  malformed <- cap_validate_response(
    digest,
    list(
      claims = list(),
      evidence = list(),
      warnings = list(),
      requests = list(list(reason = "missing field"))
    )
  )
  expect_false(malformed$ok)
  expect_true(any(vapply(
    malformed$errors,
    function(problem) identical(
      problem$code, "contract_response_invalid"
    ),
    logical(1)
  )))
})

test_that("gate is pure and approves fixture follow-up", {
  table <- fixture_table("followup-basic")
  digest <- cap_digest(
    table,
    budget = 500,
    policy = cap_policy(max_budget = 500)
  )
  request <- read_fixture_json(
    "followup-basic", "request-approved.json"
  )
  validation <- cap_validate_response(digest, request)
  expect_identical(
    capr_canonical_json(unclass(validation)),
    capr_canonical_json(read_fixture_json(
      "followup-basic", "expected-validation-approved.json"
    ))
  )
  touched <- FALSE
  adapter <- digest$adapter
  adapter$bindings$extractors[["capr.table.sample"]] <- function(...) {
    touched <<- TRUE
    stop("gate must not execute this")
  }
  digest$adapter <- adapter
  gate <- cap_gate(
    digest,
    validation,
    policy = cap_policy(
      max_budget = 500,
      max_followup_budget = 500
    ),
    policy_ref = "fixture://basic-table/policy.json"
  )
  expect_false(touched)
  expect_identical(gate$overallDecision, "approved")
  expect_identical(gate$remainingBudget, 200L)
  expect_identical(gate$requests[[1L]]$decision, "approved")
  expect_null(gate$patch)
})

test_that("stale fingerprints and invalid evidence deny follow-up", {
  digest <- cap_digest(
    fixture_table("followup-basic"),
    budget = 500,
    policy = cap_policy(max_budget = 500)
  )
  request <- read_fixture_json(
    "followup-basic", "request-approved.json"
  )
  validation <- cap_validate_response(digest, request)
  stale <- cap_gate(
    digest,
    validation,
    policy = cap_policy(
      max_budget = 500,
      max_followup_budget = 500
    ),
    source = list(fingerprint = "changed"),
    policy_ref = "fixture://basic-table/policy.json"
  )
  expect_identical(stale$overallDecision, "stale_source")
  expect_identical(
    stale$requests[[1L]]$problems[[1L]]$code,
    "gate_stale_source"
  )

  invalid <- validation
  invalid$ok <- FALSE
  denied <- cap_gate(digest, invalid)
  expect_identical(denied$overallDecision, "denied")
  expect_identical(
    denied$requests[[1L]]$problems[[1L]]$code,
    "invalid_evidence"
  )
})

test_that("approved patch matches fixture and applies once", {
  table <- fixture_table("followup-basic")
  digest <- cap_digest(
    table,
    budget = 500,
    policy = cap_policy(max_budget = 500)
  )
  validation <- cap_validate_response(
    digest,
    read_fixture_json("followup-basic", "response.json")
  )
  gate <- cap_gate(
    digest,
    validation,
    policy = cap_policy(
      max_budget = 500,
      max_followup_budget = 340
    )
  )
  patch <- cap_patch(
    digest,
    gate,
    table,
    policy = cap_policy(
      max_budget = 500,
      max_followup_budget = 340
    )
  )
  expect_identical(
    capr_canonical_json(unclass(patch)),
    capr_canonical_json(read_fixture_json(
      "followup-basic", "expected-patch.json"
    ))
  )
  extended <- cap_apply_patch(digest, patch)
  expect_match(
    extended$text,
    '<field id="f1:table@sample#k10"',
    fixed = TRUE
  )
  sample <- Filter(
    function(row) identical(row$fieldId, "f1:table@sample#k10"),
    extended$manifest$fields
  )[[1L]]
  expect_true(sample$selected)
  expect_identical(extended$manifest$budget$used, 340L)
  expect_error(
    cap_apply_patch(extended, patch),
    class = "capr_artifact_invalid"
  )
})

test_that("patch rechecks adapter pin and source fingerprint", {
  table <- fixture_table("followup-basic")
  digest <- cap_digest(table, budget = 500)
  validation <- cap_validate_response(
    digest,
    read_fixture_json("followup-basic", "request-approved.json")
  )
  gate <- cap_gate(digest, validation)
  changed <- table
  attr(changed, "capr_fixture_fingerprint") <- "changed"
  expect_error(
    cap_patch(digest, gate, changed),
    class = "capr_adapter_pin_mismatch"
  )
  drifted <- cap_table_adapter()
  drifted$metadata$provider_version <- "2.0.0"
  expect_error(
    cap_patch(digest, gate, table, adapter = drifted),
    class = "capr_adapter_pin_mismatch"
  )
})
