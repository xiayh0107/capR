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

test_that("explicit implementation specs pin captured values and helper specs", {
  make_captured <- function(value, implementation_spec = list()) {
    adapter <- test_adapter(extractor = function(x, level = "base",
                                                  context = list()) {
      list(rows = nrow(x), columns = ncol(x), captured = value)
    })
    adapter$implementation_spec <- implementation_spec
    cap_validate_adapter(adapter)
    adapter
  }
  implicit_first <- make_captured("first")
  implicit_second <- make_captured("second")
  # capR deliberately does not serialize arbitrary closure environments.
  expect_identical(
    capR:::capr_binding_signature(implicit_first),
    capR:::capr_binding_signature(implicit_second)
  )

  first <- make_captured(
    "first",
    list(captured = list(value = "first"), helper = list(version = 1L))
  )
  second <- make_captured(
    "second",
    list(captured = list(value = "second"), helper = list(version = 1L))
  )

  expect_false(identical(
    capR:::capr_binding_signature(first),
    capR:::capr_binding_signature(second)
  ))
  registry <- cap_registry(global = FALSE)
  expect_invisible(cap_register_adapter(
    "data.frame", first, registry = registry
  ))
  expect_error(
    cap_register_adapter("data.frame", second, registry = registry),
    class = "capr_registry_conflict"
  )
  expect_error(
    cap_check_adapter_pin(second, cap_adapter_pin(first)),
    class = "capr_adapter_pin_mismatch"
  )

  invalid <- test_adapter()
  invalid$implementation_spec <- list(environment = new.env())
  expect_error(
    cap_validate_adapter(invalid),
    class = "capr_adapter_invalid"
  )

  integer_spec <- test_adapter()
  integer_spec$implementation_spec <- list(value = 1L)
  double_spec <- test_adapter()
  double_spec$implementation_spec <- list(value = 1)
  expect_false(identical(
    capR:::capr_binding_signature(integer_spec),
    capR:::capr_binding_signature(double_spec)
  ))
})
