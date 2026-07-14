reversing_planner <- function() {
  cap_planner(
    id = "reverse-greedy-v1",
    version = "1.0.0",
    rank = function(candidates, question, policy) {
      rev(seq_along(candidates))
    }
  )
}

test_that("NULL and the built-in id produce identical plans", {
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
    planner = "capr-greedy-value-cost-v1"
  )
  expect_identical(
    capr_canonical_json(default$artifact),
    capr_canonical_json(explicit$artifact)
  )
  expect_identical(
    default$artifact$plan$planner,
    "capr-greedy-value-cost-v1"
  )
  expect_null(default$provenance$strategies)
})

test_that("a custom planner reorders selection under a tight budget", {
  table <- fixture_table("basic-table")
  default <- cap_digest(
    table,
    budget = 130,
    policy = cap_policy(max_budget = 500),
    fingerprint = fixture_fingerprint("basic-table")
  )
  custom <- cap_digest(
    table,
    budget = 130,
    policy = cap_policy(max_budget = 500),
    fingerprint = fixture_fingerprint("basic-table"),
    planner = reversing_planner()
  )
  selected_ids <- function(digest) {
    vapply(
      Filter(function(row) isTRUE(row$selected), digest$manifest$fields),
      `[[`,
      character(1),
      "fieldId"
    )
  }
  expect_identical(selected_ids(default), "f1:table@shape#base")
  expect_identical(selected_ids(custom), "f1:table@columns#compact")
  expect_identical(custom$artifact$plan$planner, "reverse-greedy-v1")
  expect_identical(
    custom$provenance$strategies$planner_id,
    "reverse-greedy-v1"
  )
  expect_identical(
    custom$provenance$strategies$tokenizer_id,
    "heuristic_v1"
  )
})

test_that("adversarial planners cannot break eligibility or budget", {
  table <- fixture_table("basic-table")
  greedy_expensive <- cap_planner(
    id = "grab-everything-v1",
    version = "1.0.0",
    rank = function(candidates, question, policy) {
      order(
        -vapply(candidates, `[[`, integer(1), "estimated_cost")
      )
    }
  )
  digest <- cap_digest(
    table,
    budget = 130,
    policy = cap_policy(max_budget = 500),
    fingerprint = fixture_fingerprint("basic-table"),
    planner = greedy_expensive
  )
  plan_rows <- digest$artifact$plan$candidates
  interactive_rows <- Filter(
    function(row) identical(row$fieldId, "f1:table@sample#k10"),
    plan_rows
  )
  expect_true(length(interactive_rows) > 0L)
  for (row in interactive_rows) {
    expect_false(isTRUE(row$selected))
    expect_identical(row$rejectedReason, "interactive_only")
  }
  selected_cost <- sum(vapply(
    Filter(function(row) isTRUE(row$selected), plan_rows),
    `[[`,
    integer(1),
    "estimatedCost"
  ))
  expect_lte(selected_cost, 130L)
})

test_that("invalid rankings and unknown planners fail typed", {
  table <- fixture_table("basic-table")
  not_permutation <- cap_planner(
    id = "broken-rank-v1",
    version = "1.0.0",
    rank = function(candidates, question, policy) {
      rep(1L, length(candidates))
    }
  )
  expect_error(
    cap_digest(table, budget = 500, planner = not_permutation),
    class = "capr_planner_invalid"
  )
  wrong_length <- cap_planner(
    id = "short-rank-v1",
    version = "1.0.0",
    rank = function(candidates, question, policy) 1L
  )
  expect_error(
    cap_digest(table, budget = 500, planner = wrong_length),
    class = "capr_planner_invalid"
  )
  expect_error(
    cap_digest(table, budget = 500, planner = "unregistered-v1"),
    class = "capr_planner_invalid"
  )
  expect_error(
    cap_planner(
      id = "capr-approved-followup-v1",
      version = "1.0.0",
      rank = function(candidates, question, policy) seq_along(candidates)
    ),
    class = "capr_planner_invalid"
  )
})

test_that("planner registry registers, resolves, and conflicts", {
  on.exit(cap_unregister_planner("reverse-greedy-v1"), add = TRUE)
  planner <- reversing_planner()
  cap_register_planner(planner)
  cap_register_planner(planner)
  listed <- cap_list_planners()
  expect_identical(listed$id, "reverse-greedy-v1")

  digest <- cap_digest(
    fixture_table("basic-table"),
    budget = 130,
    policy = cap_policy(max_budget = 500),
    fingerprint = fixture_fingerprint("basic-table"),
    planner = "reverse-greedy-v1"
  )
  expect_identical(digest$artifact$plan$planner, "reverse-greedy-v1")

  conflicting <- cap_planner(
    id = "reverse-greedy-v1",
    version = "1.0.0",
    rank = function(candidates, question, policy) seq_along(candidates)
  )
  expect_error(
    cap_register_planner(conflicting),
    class = "capr_registry_conflict"
  )
  expect_identical(cap_unregister_planner("reverse-greedy-v1"), 1L)
  expect_identical(nrow(cap_list_planners()), 0L)
})
