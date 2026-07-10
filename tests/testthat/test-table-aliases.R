test_that("tbl_df reuses stable table semantics", {
  skip_if_not_installed("tibble")
  base <- data.frame(a = 1:2, b = c("x", "y"))
  tibble <- tibble::as_tibble(base)
  attr(base, "capr_label") <- "alias"
  attr(tibble, "capr_label") <- "alias"
  base_digest <- cap_digest(base, budget = 500)
  tibble_digest <- cap_digest(tibble, budget = 500)
  expect_identical(tibble_digest$text, base_digest$text)
  expect_identical(
    capr_canonical_json(tibble_digest$manifest),
    capr_canonical_json(base_digest$manifest)
  )
  expect_identical(tibble_digest$source$sourceType, "table")
  expect_true(cap_test_adapter(
    cap_adapter(tibble), tibble
  )$ok)
})

test_that("data.table is equivalent and remains unmodified", {
  skip_if_not_installed("data.table")
  base <- data.frame(a = 1:2, b = c("x", "y"))
  table <- data.table::as.data.table(base)
  attr(base, "capr_label") <- "alias"
  attr(table, "capr_label") <- "alias"
  before <- serialize(table, NULL)
  base_digest <- cap_digest(base, budget = 500)
  table_digest <- cap_digest(table, budget = 500)
  expect_identical(serialize(table, NULL), before)
  expect_identical(table_digest$text, base_digest$text)
  expect_identical(
    capr_canonical_json(table_digest$manifest),
    capr_canonical_json(base_digest$manifest)
  )
  expect_identical(table_digest$source$sourceType, "table")
  expect_true(cap_test_adapter(
    cap_adapter(table), table
  )$ok)
})

test_that("lazy table classes fail instead of inheriting local semantics", {
  lazy <- structure(
    list(),
    class = c("tbl_lazy", "tbl_df", "tbl", "data.frame")
  )
  expect_error(
    cap_adapter(lazy),
    class = "capr_adapter_not_found"
  )
})
