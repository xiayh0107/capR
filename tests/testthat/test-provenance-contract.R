test_that("resolution sidecars round trip and pins detect drift", {
  adapter <- test_adapter()
  resolved <- cap_resolve_adapter(data.frame(x = 1), adapter = adapter)
  sidecar <- cap_resolution_sidecar(resolved, "test-v1")
  path <- tempfile(fileext = ".json")
  cap_write_resolution_sidecar(sidecar, path)
  reread <- cap_read_resolution_sidecar(path)
  expect_identical(unclass(reread), unclass(sidecar))

  pin <- cap_adapter_pin(resolved)
  expect_invisible(cap_check_adapter_pin(resolved, pin))
  drifted <- test_adapter(provider_version = "2.0.0")
  expect_error(
    cap_check_adapter_pin(drifted, pin),
    class = "capr_adapter_pin_mismatch"
  )
})

test_that("the reusable adapter contract distinguishes compatibility", {
  result <- cap_test_adapter(test_adapter(), data.frame(x = 1))
  expect_s3_class(result, "capr_adapter_contract_result")
  expect_true(result$ok)
  expect_match(result$scope, "not CAP conformance")

  broken <- test_adapter(claim = "CAP-Digest v1.0")
  broken$metadata$maturity <- "community"
  result <- cap_test_adapter(broken, data.frame(x = 1))
  expect_false(result$ok)
  failed <- vapply(result$checks, function(x) !x$ok, logical(1))
  expect_true("claim_separation" %in% vapply(
    result$checks[failed], `[[`, character(1), "name"
  ))
})

test_that("contract suite reports precise broken-adapter categories", {
  source <- data.frame(x = 1)
  failed_names <- function(adapter) {
    result <- cap_test_adapter(adapter, source)
    vapply(
      Filter(function(check) !check$ok, result$checks),
      `[[`,
      character(1),
      "name"
    )
  }

  unbound <- test_adapter()
  unbound$bindings$extractors[["test.shape"]] <- NULL
  expect_true("contracts_symbolic_bound" %in% failed_names(unbound))

  nondeterministic <- test_adapter()
  counter <- 0L
  nondeterministic$lifecycle$fingerprint <- function(...) {
    counter <<- counter + 1L
    list(
      available = TRUE,
      algorithm = "broken",
      value = as.character(counter)
    )
  }
  expect_true(
    "fingerprint_deterministic" %in% failed_names(nondeterministic)
  )

  mismatched <- test_adapter()
  mismatched$lifecycle$source_ref <- function(...) {
    list(sourceType = "other")
  }
  expect_true(
    "source_ref_catalog_agreement" %in% failed_names(mismatched)
  )

  duplicate <- test_adapter()
  original_catalog <- duplicate$lifecycle$field_catalog
  duplicate$lifecycle$field_catalog <- function(...) {
    catalog <- original_catalog(...)
    catalog$fields <- c(catalog$fields, catalog$fields)
    catalog
  }
  expect_true(
    "field_ids_unique_valid" %in% failed_names(duplicate)
  )

  unstable_renderer <- test_adapter()
  render_count <- 0L
  unstable_renderer$bindings$renderers[["test.shape.text_v1"]] <-
    function(value, ...) {
      render_count <<- render_count + 1L
      paste(value$rows, value$columns, render_count)
    }
  expect_true(
    "rendering_bounded_deterministic" %in%
      failed_names(unstable_renderer)
  )
})

test_that("built-in and fallback adapters pass compatibility without claim bleed", {
  table_result <- cap_test_adapter(
    cap_table_adapter(),
    data.frame(x = 1)
  )
  expect_true(table_result$ok)
  fallback_result <- cap_test_adapter(
    cap_structural_adapter(),
    list(x = 1)
  )
  expect_true(fallback_result$ok)
  expect_match(fallback_result$scope, "not CAP conformance")
})
