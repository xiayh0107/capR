test_that("registry registration is idempotent and conflicting changes fail", {
  registry <- cap_registry(global = FALSE)
  adapter <- test_adapter()
  expect_invisible(cap_register_adapter("data.frame", adapter, registry = registry))
  expect_invisible(cap_register_adapter("data.frame", adapter, registry = registry))
  expect_equal(nrow(cap_list_adapters(registry)), 1L)

  changed <- test_adapter(extractor = function(x, ...) list(changed = TRUE))
  expect_error(
    cap_register_adapter("data.frame", changed, registry = registry),
    class = "capr_registry_conflict"
  )
})

test_that("resolution precedence is deterministic and inspectable", {
  registry <- cap_registry(global = FALSE)
  parent <- test_adapter(id = "org.example.parent")
  child <- test_adapter(id = "org.example.child")
  cap_register_adapter("parent_table", parent, priority = 100L, registry = registry)
  cap_register_adapter("child_table", child, priority = 0L, registry = registry)
  x <- data.frame(a = 1)
  class(x) <- c("child_table", "parent_table", "data.frame")

  resolved <- cap_resolve_adapter(x, registry = registry)
  expect_identical(resolved$metadata$id, "org.example.child")
  expect_identical(
    cap_resolution_diagnostics(resolved)$selected$mode,
    "registry_exact"
  )
  expect_identical(
    cap_resolve_adapter(x, adapter = parent, registry = registry)$metadata$id,
    "org.example.parent"
  )
  expect_identical(
    cap_resolve_adapter(
      x, adapter = "org.example.child", registry = registry
    )$metadata$id,
    "org.example.child"
  )
})

test_that("equal effective registry matches are ambiguous", {
  registry <- cap_registry(global = FALSE)
  cap_register_adapter(
    "registered_table", test_adapter(id = "org.example.one"), registry = registry
  )
  cap_register_adapter(
    "registered_table", test_adapter(id = "org.example.two"), registry = registry
  )
  source <- structure(list(x = 1), class = "registered_table")
  expect_error(
    cap_resolve_adapter(source, registry = registry),
    class = "capr_adapter_ambiguous"
  )
})

test_that("snapshot and restore reproduce resolution", {
  registry <- cap_registry(global = FALSE)
  cap_register_adapter("registered_table", test_adapter(), registry = registry)
  snapshot <- cap_registry_snapshot(registry)
  cap_unregister_adapter(registry = registry)
  expect_equal(nrow(cap_list_adapters(registry)), 0L)
  cap_registry_restore(snapshot, registry)
  source <- structure(list(x = 1), class = "registered_table")
  resolved <- cap_resolve_adapter(source, registry = registry)
  expect_identical(resolved$metadata$id, "org.example.table")
})

test_that("missing adapters fail without implicit fallback", {
  expect_error(
    cap_resolve_adapter(list(x = 1), registry = cap_registry(global = FALSE)),
    class = "capr_adapter_not_found"
  )
})
