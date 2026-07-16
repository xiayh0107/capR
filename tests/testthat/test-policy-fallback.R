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

test_that("fallback rejects complex objects with dispatch or external state", {
  skip_if_not_installed("DelayedArray")
  delayed <- DelayedArray::DelayedArray(matrix(1:4, nrow = 2L))
  expect_error(
    cap_digest(
      delayed,
      policy = cap_policy(allow_fallback = TRUE)
    ),
    class = "capr_fallback_disallowed"
  )

  skip_if_not_installed("DBI")
  skip_if_not_installed("RSQLite")
  connection <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(connection), add = TRUE)
  expect_error(
    cap_digest(
      connection,
      policy = cap_policy(allow_fallback = TRUE)
    ),
    class = "capr_fallback_disallowed"
  )
  expect_true(DBI::dbIsValid(connection))

  skip_if_not_installed("ggplot2")
  plot <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point()
  expect_error(
    cap_digest(plot, policy = cap_policy(allow_fallback = TRUE)),
    class = "capr_fallback_disallowed"
  )
})

test_that("fallback strips S3 classes before structural introspection", {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  trap <- function(...) {
    state$calls <- state$calls + 1L
    stop("hostile S3 method executed")
  }
  methods <- c(
    "length.capr_hostile_fallback",
    "names.capr_hostile_fallback",
    "dim.capr_hostile_fallback"
  )
  for (name in methods) assign(name, trap, envir = .GlobalEnv)
  on.exit(rm(list = methods, envir = .GlobalEnv), add = TRUE)

  source <- structure(list(alpha = 1L), class = "capr_hostile_fallback")
  digest <- cap_digest(
    source,
    policy = cap_policy(allow_fallback = TRUE)
  )
  expect_identical(state$calls, 0L)
  expect_identical(digest$source$sourceType, "r_object")
})
