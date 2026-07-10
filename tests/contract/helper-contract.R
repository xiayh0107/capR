# Extension packages may source this helper or call capR::cap_test_adapter()
# directly. Passing verifies adapter compatibility, not CAP conformance.
expect_capr_adapter_contract <- function(adapter, source, context = list()) {
  result <- capR::cap_test_adapter(adapter, source, context)
  testthat::expect_true(
    result$ok,
    info = paste(
      vapply(
        Filter(function(x) !x$ok, result$checks),
        function(x) paste(x$name, x$diagnostic$message, sep = ": "),
        character(1)
      ),
      collapse = "\n"
    )
  )
  invisible(result)
}
