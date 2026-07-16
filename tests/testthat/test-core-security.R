test_that("fingerprint overrides require explicit runtime context", {
  source <- data.frame(value = 1:2)
  attr(source, "capr_fixture_fingerprint") <- "object-attribute-spoof"

  derived <- cap_digest(source)
  expect_false(identical(derived$fingerprint, "object-attribute-spoof"))

  explicit <- cap_digest(source, fingerprint = "context-declared")
  expect_identical(explicit$fingerprint, "context-declared")
  expect_identical(
    explicit$provenance$fingerprint_algorithm,
    "fixture-declared"
  )
})

test_that("failed patch manifest rows normalize elapsed time", {
  field <- list(
    id = "f1:table@sample#k10",
    label = "Sample rows",
    timing = "interactive",
    trust = "data",
    exec = "local_scan",
    contracts = list(renderer = "capr.table.sample.text_v1")
  )
  candidate <- list(level = 1L, estimated_cost = 300L, prior_value = 0.8)
  outcome <- list(
    ok = FALSE,
    error_class = "renderer_error",
    elapsed_ms = 9876L
  )
  digest <- list(
    source = list(sourceType = "table"),
    fingerprint = "structure-v1:test",
    manifest = list(budget = list(tokenizer = "cl100k_base"))
  )

  row <- capR:::capr_patch_manifest_row(field, candidate, outcome, digest)
  expect_identical(row$elapsedMs, 0L)
})
