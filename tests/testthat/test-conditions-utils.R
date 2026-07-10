test_that("structured conditions preserve metadata and parents", {
  parent <- simpleError("root cause")
  condition <- capr_condition(
    "capr_adapter_invalid",
    "invalid adapter",
    field = "id",
    parent = parent
  )
  expect_s3_class(condition, "capr_adapter_invalid")
  expect_true(capr_is(condition))
  expect_identical(capr_condition_fields(condition)$field, "id")
  expect_identical(condition$parent, parent)
  expect_error(
    capr_abort("capr_registry_conflict", "conflict", class = "x"),
    class = "capr_registry_conflict"
  )
})

test_that("deterministic utilities normalize object key order", {
  first <- capr_canonical_json(list(z = 1, a = list(y = 2, b = 3)))
  second <- capr_canonical_json(list(a = list(b = 3, y = 2), z = 1))
  expect_identical(first, second)
  expect_match(first, '^\\{"a":')
})

test_that("implementation conditions remain outside canonical CAP codes", {
  condition_classes <- get(".capr_condition_classes", asNamespace("capR"))
  expect_true(all(grepl("^capr_", condition_classes)))
  expect_false(any(grepl("^CAP_", condition_classes)))
})

