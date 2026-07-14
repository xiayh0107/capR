test_that("calibration measures authorized fields with the tokenizer", {
  table <- fixture_table("basic-table")
  costs <- cap_calibrate_costs(
    table,
    fingerprint = fixture_fingerprint("basic-table")
  )
  expect_s3_class(costs, "data.frame")
  expect_true(all(
    c(
      "field_id", "level", "timing", "exec", "estimated_cost",
      "measured_cost", "tokenizer_id", "authorized"
    ) %in% names(costs)
  ))
  expect_true(all(costs$tokenizer_id == "heuristic_v1"))
  stable <- c(
    "f1:table@shape#base" = 24L,
    "f1:table@columns#compact" = 136L,
    "f1:table@sample#k10" = 180L
  )
  for (field_id in names(stable)) {
    row <- costs[costs$field_id == field_id, ][1L, ]
    expect_true(row$authorized)
    expect_identical(row$measured_cost, stable[[field_id]])
  }
})

test_that("denied execution classes are reported, not run", {
  table <- fixture_table("basic-table")
  costs <- cap_calibrate_costs(
    table,
    policy = cap_policy(allow_exec = "local_cheap"),
    fingerprint = fixture_fingerprint("basic-table")
  )
  denied <- costs[costs$exec != "local_cheap", ]
  expect_true(nrow(denied) > 0L)
  expect_true(all(!denied$authorized))
  expect_true(all(is.na(denied$measured_cost)))
})

test_that("calibration honors a custom tokenizer", {
  table <- fixture_table("basic-table")
  costs <- cap_calibrate_costs(
    table,
    tokenizer = cap_tokenizer(
      id = "double-nchar-v1",
      version = "1.0.0",
      count = function(rendered, field_id) {
        2L * nchar(rendered, type = "chars")
      }
    ),
    fingerprint = fixture_fingerprint("basic-table")
  )
  expect_true(all(costs$tokenizer_id == "double-nchar-v1"))
  measured <- costs$measured_cost[costs$authorized]
  expect_true(all(measured %% 2L == 0L))
})
