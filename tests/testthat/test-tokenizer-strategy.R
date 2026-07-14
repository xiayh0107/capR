double_nchar_tokenizer <- function() {
  cap_tokenizer(
    id = "double-nchar-v1",
    version = "1.0.0",
    count = function(rendered, field_id) {
      2L * nchar(rendered, type = "chars")
    }
  )
}

test_that("NULL and the built-in id produce byte-identical digests", {
  table <- fixture_table("basic-table")
  default <- cap_digest(
    table,
    budget = 500,
    policy = cap_policy(max_budget = 500),
    fingerprint = fixture_fingerprint("basic-table")
  )
  explicit <- cap_digest(
    table,
    budget = 500,
    policy = cap_policy(max_budget = 500),
    fingerprint = fixture_fingerprint("basic-table"),
    tokenizer = "heuristic_v1"
  )
  expect_identical(default$text, explicit$text)
  expect_identical(
    capr_canonical_json(default$artifact),
    capr_canonical_json(explicit$artifact)
  )
  expect_identical(default$manifest$budget$tokenizer, "heuristic_v1")
  expect_null(default$provenance$strategies)
})

test_that("custom tokenizers stamp header, manifest, and sidecar", {
  table <- fixture_table("basic-table")
  digest <- cap_digest(
    table,
    budget = 5000,
    policy = cap_policy(max_budget = 5000),
    fingerprint = fixture_fingerprint("basic-table"),
    tokenizer = double_nchar_tokenizer()
  )
  header <- strsplit(digest$text, "\n", fixed = TRUE)[[1L]][[1L]]
  expect_match(header, "tokenizer=double-nchar-v1", fixed = TRUE)
  expect_identical(digest$manifest$budget$tokenizer, "double-nchar-v1")
  rows <- Filter(
    function(row) isTRUE(row$selected),
    digest$manifest$fields
  )
  expect_true(length(rows) > 0L)
  for (row in rows) {
    expect_identical(row$tokenizer, "double-nchar-v1")
  }
  default <- cap_digest(
    table,
    budget = 5000,
    policy = cap_policy(max_budget = 5000),
    fingerprint = fixture_fingerprint("basic-table")
  )
  for (row in rows) {
    outcome <- digest$materialization$outcomes[[row$fieldId]]
    expect_identical(
      row$actualCost,
      2L * nchar(outcome$rendered, type = "chars")
    )
  }
  expect_false(identical(
    digest$manifest$budget$used,
    default$manifest$budget$used
  ))
  expect_identical(
    digest$provenance$strategies$tokenizer_id,
    "double-nchar-v1"
  )
  expect_identical(
    digest$provenance$strategies$planner_id,
    "capr-greedy-value-cost-v1"
  )
})

test_that("tokenizer count violations abort instead of failing open", {
  table <- fixture_table("basic-table")
  bad <- cap_tokenizer(
    id = "broken-v1",
    version = "1.0.0",
    count = function(rendered, field_id) -1L
  )
  expect_error(
    cap_digest(table, budget = 500, tokenizer = bad),
    class = "capr_tokenizer_invalid"
  )
  vector_bad <- cap_tokenizer(
    id = "vector-v1",
    version = "1.0.0",
    count = function(rendered, field_id) c(1L, 2L)
  )
  expect_error(
    cap_digest(table, budget = 500, tokenizer = vector_bad),
    class = "capr_tokenizer_invalid"
  )
})

test_that("patch accounting is pinned to the digest tokenizer", {
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
  expect_error(
    cap_patch(
      digest,
      gate,
      table,
      policy = cap_policy(max_budget = 500, max_followup_budget = 340),
      fingerprint = fixture_fingerprint("followup-basic"),
      tokenizer = double_nchar_tokenizer()
    ),
    class = "capr_tokenizer_invalid"
  )
  patch <- cap_patch(
    digest,
    gate,
    table,
    policy = cap_policy(max_budget = 500, max_followup_budget = 340),
    fingerprint = fixture_fingerprint("followup-basic"),
    tokenizer = "heuristic_v1"
  )
  expect_s3_class(patch, "cap_digest_patch")
})

test_that("reloaded non-default digests demand an explicit tokenizer", {
  dir <- tempfile("capr-tokenizer-artifacts-")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  table <- fixture_table("followup-basic")
  digest <- cap_digest(
    table,
    budget = 5000,
    policy = cap_policy(max_budget = 5000),
    fingerprint = fixture_fingerprint("followup-basic"),
    tokenizer = double_nchar_tokenizer()
  )
  cap_write_artifacts(digest, dir)
  reloaded <- cap_read_artifacts(dir)
  validation <- cap_validate_response(
    reloaded,
    read_fixture_json("followup-basic", "response.json")
  )
  gate <- cap_gate(reloaded, validation)
  expect_error(
    cap_patch(reloaded, gate, table),
    class = "capr_tokenizer_invalid"
  )
  expect_error(
    cap_patch(
      reloaded, gate, table,
      tokenizer = double_nchar_tokenizer()
    ),
    class = "capr_artifact_invalid"
  )
})

test_that("tokenizer registry registers, resolves, and protects ids", {
  on.exit(cap_unregister_tokenizer("double-nchar-v1"), add = TRUE)
  tokenizer <- double_nchar_tokenizer()
  cap_register_tokenizer(tokenizer)
  cap_register_tokenizer(tokenizer)
  listed <- cap_list_tokenizers()
  expect_identical(listed$id, "double-nchar-v1")
  expect_identical(listed$provider, "host")

  digest <- cap_digest(
    fixture_table("basic-table"),
    budget = 5000,
    policy = cap_policy(max_budget = 5000),
    fingerprint = fixture_fingerprint("basic-table"),
    tokenizer = "double-nchar-v1"
  )
  expect_identical(digest$manifest$budget$tokenizer, "double-nchar-v1")

  conflicting <- cap_tokenizer(
    id = "double-nchar-v1",
    version = "1.0.0",
    count = function(rendered, field_id) 1L
  )
  expect_error(
    cap_register_tokenizer(conflicting),
    class = "capr_registry_conflict"
  )
  expect_error(
    cap_tokenizer(
      id = "heuristic_v1",
      version = "1.0.0",
      count = function(rendered, field_id) 1L
    ),
    class = "capr_tokenizer_invalid"
  )
  expect_error(
    cap_digest(fixture_table("basic-table"), tokenizer = "unregistered-v1"),
    class = "capr_tokenizer_invalid"
  )
  expect_identical(cap_unregister_tokenizer("double-nchar-v1"), 1L)
  expect_identical(nrow(cap_list_tokenizers()), 0L)
})
