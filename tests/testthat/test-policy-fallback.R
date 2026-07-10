test_that("policy defaults are fail closed", {
  policy <- cap_policy()
  expect_false(policy$allow_remote)
  expect_false(policy$allow_credentials)
  expect_false(policy$allow_fallback)
  expect_true(policy$allow_followup)
  expect_identical(policy$max_field_seconds, 5)
  expect_true(cap_authorize_execution(policy, "local_cheap")$allowed)
  expect_false(cap_authorize_execution(policy, "remote")$allowed)
  expect_false(cap_authorize_execution(policy, "credentialed")$allowed)
  expect_false(cap_authorize_execution(policy, "unknown")$allowed)
})

test_that("contradictory policy values are rejected", {
  expect_error(
    cap_policy(allow_exec = "remote", allow_remote = FALSE),
    class = "capr_policy_invalid"
  )
  expect_error(
    cap_policy(max_budget = -1),
    class = "capr_policy_invalid"
  )
  expect_error(
    cap_policy(allow_exec = "mystery"),
    class = "capr_policy_invalid"
  )
  expect_error(
    cap_policy(max_field_seconds = 0),
    class = "capr_policy_invalid"
  )
})

test_that("fallback is bounded and visibly non-conformant", {
  adapter <- cap_structural_adapter()
  expect_identical(adapter$metadata$maturity, "fallback")
  expect_identical(adapter$metadata$semantic_level, "structural")
  expect_identical(adapter$metadata$conformance_claim, "none")

  registry <- cap_registry(global = FALSE)
  resolved <- cap_resolve_adapter(list(a = 1), registry = registry, allow_fallback = TRUE)
  expect_identical(cap_resolution_diagnostics(resolved)$selected$mode, "fallback")
  catalog <- resolved$lifecycle$field_catalog(list(a = 1), list())
  expect_lte(length(catalog$fields), 1L)
  expect_error(
    resolved$lifecycle$source_ref(new.env(), list()),
    class = "capr_fallback_disallowed"
  )
})
