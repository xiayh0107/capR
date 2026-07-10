test_that("table SourceRef and fingerprint are deterministic and bounded", {
  x <- data.frame(a = 1:2, b = c("x", "y"), check.names = FALSE)
  adapter <- cap_table_adapter()
  first <- adapter$lifecycle$fingerprint(x, list())
  second <- adapter$lifecycle$fingerprint(x, list())
  expect_identical(first, second)
  expect_identical(
    adapter$lifecycle$source_ref(x, list())$sourceType,
    "table"
  )
  changed <- x
  names(changed)[[1L]] <- "changed"
  expect_false(identical(
    first$value,
    adapter$lifecycle$fingerprint(changed, list())$value
  ))
  ref <- adapter$lifecycle$source_ref(x, list())
  expect_false(any(vapply(
    ref,
    function(value) identical(value, x),
    logical(1)
  )))
})

test_that("stable table catalog is symbolic, valid, and deterministic", {
  adapter <- cap_table_adapter()
  x <- data.frame(a = 1)
  first <- adapter$lifecycle$field_catalog(x, list())
  second <- adapter$lifecycle$field_catalog(x, list())
  expect_identical(first, second)
  expect_invisible(cap_validate_field_catalog(first))
  expect_identical(
    vapply(first$fields, `[[`, character(1), "id"),
    c(
      "f1:table@shape#base",
      "f1:table@columns#compact",
      "f1:table@sample#k10"
    )
  )
  expect_false(any(vapply(
    unlist(lapply(first$fields, `[[`, "contracts"), recursive = FALSE),
    is.function,
    logical(1)
  )))
})

test_that("planner records every decision and respects budget", {
  catalog <- cap_table_adapter()$lifecycle$field_catalog(
    data.frame(a = 1),
    list()
  )
  plan <- capR:::cap_select_fields(
    catalog, budget = 500, policy = cap_policy()
  )
  selected <- vapply(plan$candidates, `[[`, logical(1), "selected")
  expect_identical(
    vapply(plan$candidates[selected], function(x) x$field$id, character(1)),
    c("f1:table@shape#base", "f1:table@columns#compact")
  )
  expect_identical(
    plan$candidates[[3L]]$rejected_reason,
    "interactive_only"
  )
  expect_lte(plan$budget_estimated_selected, plan$budget_requested)

  zero <- capR:::cap_select_fields(
    catalog, budget = 0, policy = cap_policy()
  )
  expect_false(any(vapply(zero$candidates, `[[`, logical(1), "selected")))
  expect_true(all(vapply(
    zero$candidates[1:2],
    `[[`,
    character(1),
    "rejected_reason"
  ) == "over_budget"))
})

test_that("basic-table fixture is byte and structurally exact", {
  table <- fixture_table("basic-table")
  digest <- cap_digest(
    table,
    budget = 500,
    policy = cap_policy(max_budget = 500)
  )
  expect_identical(
    digest$text,
    read_fixture_text("basic-table", "expected-digest.txt")
  )
  expected_manifest <- read_fixture_json(
    "basic-table", "expected-manifest.json"
  )
  expect_identical(
    capr_canonical_json(digest$manifest),
    capr_canonical_json(expected_manifest)
  )
  expect_identical(
    cap_validate_manifest_text(digest$text, digest$manifest),
    list()
  )
})

test_that("table extractors cover edge column types explicitly", {
  x <- data.frame(
    factor = factor(c("a", "b")),
    date = as.Date(c("2026-01-01", "2026-01-02")),
    time = as.POSIXct(
      c("2026-01-01", "2026-01-02"),
      tz = "UTC"
    ),
    check.names = FALSE
  )
  x$list <- list(list(a = 1), list(b = 2))
  digest <- cap_digest(x, budget = 500)
  columns <- digest$materialization$outcomes[[
    "f1:table@columns#compact"
  ]]$value
  types <- vapply(columns, `[[`, character(1), "type")
  expect_identical(types, c("factor", "date", "datetime", "list"))
  expect_true(columns[[4L]]$unsupported)
  expect_match(digest$text, "\\[unsupported\\]")
})
