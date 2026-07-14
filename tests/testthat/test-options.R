test_that("options provide defaults and explicit arguments win", {
  old <- options(
    capr.max_budget = 250L,
    capr.max_followup_budget = 120L,
    capr.max_field_seconds = 2,
    capr.default_budget = 90L
  )
  on.exit(options(old), add = TRUE)

  policy <- cap_policy()
  expect_identical(policy$max_budget, 250L)
  expect_identical(policy$max_followup_budget, 120L)
  expect_identical(policy$max_field_seconds, 2)

  explicit <- cap_policy(max_budget = 500L, max_followup_budget = 300L)
  expect_identical(explicit$max_budget, 500L)
  expect_identical(explicit$max_followup_budget, 300L)

  digest <- cap_digest(
    fixture_table("basic-table"),
    policy = cap_policy(max_budget = 500L),
    fingerprint = fixture_fingerprint("basic-table")
  )
  expect_identical(digest$manifest$budget$requested, 90L)
  explicit_digest <- cap_digest(
    fixture_table("basic-table"),
    budget = 130,
    policy = cap_policy(max_budget = 500L),
    fingerprint = fixture_fingerprint("basic-table")
  )
  expect_identical(explicit_digest$manifest$budget$requested, 130L)
})

test_that("invalid option values fail loudly", {
  old <- options(capr.max_budget = "not a number")
  on.exit(options(old), add = TRUE)
  expect_error(cap_policy(), class = "capr_policy_invalid")
})

test_that("extra high-risk classes can only extend fallback refusals", {
  risky <- structure(list(a = 1), class = "host_forbidden_class")
  policy <- cap_policy(allow_fallback = TRUE)
  digest <- cap_digest(risky, policy = policy)
  expect_s3_class(digest, "cap_digest")

  old <- options(capr.extra_high_risk_classes = "host_forbidden_class")
  on.exit(options(old), add = TRUE)
  expect_error(
    cap_digest(risky, policy = policy),
    class = "capr_fallback_disallowed"
  )

  options(capr.extra_high_risk_classes = 42)
  expect_error(
    cap_digest(risky, policy = policy),
    class = "capr_policy_invalid"
  )
})

test_that("conformance fixtures are hermetic against hostile options", {
  old <- options(
    capr.default_budget = 1L,
    capr.max_budget = 1L,
    capr.max_followup_budget = 1L,
    capr.max_field_seconds = 0.000001,
    capr.extra_high_risk_classes = "data.frame"
  )
  on.exit(options(old), add = TRUE)
  report <- cap_run_fixtures()
  expect_true(report$ok)
  expect_identical(report$level, 3L)
})
