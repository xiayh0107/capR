test_that("valid adapters are printable and inspectable", {
  adapter <- test_adapter()
  expect_s3_class(adapter, "capr_adapter")
  expect_invisible(cap_validate_adapter(adapter))
  expect_output(print(adapter), "org.example.table@1.0.0")
  expect_output(print(adapter), "conformance: none")
})

test_that("invalid adapter shapes fail precisely", {
  expect_error(
    test_adapter(maturity = "unknown"),
    class = "capr_adapter_invalid"
  )
  expect_error(
    test_adapter(version = "latest"),
    class = "capr_adapter_invalid"
  )
  expect_error(
    cap_new_adapter(
      id = "bad id",
      version = "1.0.0",
      provider = "x",
      provider_version = "1.0.0",
      source_family = "table",
      maturity = "community",
      semantic_level = "table",
      source_ref = identity,
      field_catalog = identity,
      fingerprint = identity,
      bindings = list()
    ),
    class = "capr_adapter_invalid"
  )
  broken <- test_adapter()
  broken$lifecycle$fingerprint <- NULL
  expect_error(cap_validate_adapter(broken), class = "capr_adapter_invalid")
})

test_that("unbound symbolic contracts fail closed", {
  adapter <- test_adapter()
  expect_error(
    capR:::capr_adapter_binding(adapter, "extractors", "missing"),
    class = "capr_contract_unbound"
  )
})
