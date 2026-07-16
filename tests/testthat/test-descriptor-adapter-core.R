test_that("descriptor snapshots are normalized once per digest pipeline", {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  snapshot <- function(x) {
    state$calls <- state$calls + 1L
    list(
      overview = list(kind = "probe", classes = as.list(class(x))),
      structure = list(component_names = as.list(names(x))),
      semantics = list(payload_values_disclosed = FALSE)
    )
  }
  adapter <- capR:::capr_new_descriptor_adapter(
    id = "org.capr.snapshot_probe",
    family = "probe",
    label = "snapshot probe",
    snapshot_fn = snapshot
  )

  digest <- cap_digest(
    list(alpha = 1L, beta = 2L),
    adapter = adapter,
    budget = 800L
  )
  expect_identical(state$calls, 1L)
  expect_true(all(vapply(
    digest$materialization$outcomes,
    `[[`,
    logical(1),
    "ok"
  )))
})

test_that("descriptor sanitizer strips host dispatch and bounds wide strings", {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  trap <- function(...) {
    state$calls <- state$calls + 1L
    stop("host method executed")
  }
  methods <- c(
    "as.character.capr_hostile_text", "[.capr_hostile_text",
    "length.capr_hostile_text", "names.capr_hostile_snapshot",
    "[.capr_hostile_snapshot", "[[.capr_hostile_snapshot"
  )
  for (name in methods) assign(name, trap, envir = .GlobalEnv)
  on.exit(rm(list = methods, envir = .GlobalEnv), add = TRUE)

  wide <- structure(
    paste0(strrep("x", 100000L), "TAIL_MUST_NOT_BE_SCANNED"),
    class = "capr_hostile_text"
  )
  snapshot <- function(x) {
    structure(
      list(
        overview = list(wide = wide),
        structure = list(component_names = list("alpha")),
        semantics = list(payload_values_disclosed = FALSE)
      ),
      class = "capr_hostile_snapshot"
    )
  }
  adapter <- capR:::capr_new_descriptor_adapter(
    id = "org.capr.sanitizer_probe",
    family = "probe",
    label = "sanitizer probe",
    snapshot_fn = snapshot,
    implementation_spec = list(fixture = "hostile-wide-string")
  )
  digest <- cap_digest(list(alpha = 1L), adapter = adapter)
  value <- digest$materialization$outcomes[[
    "f1:probe@overview#compact"
  ]]$value$wide

  expect_identical(state$calls, 0L)
  expect_lte(nchar(value, type = "chars"), 163L)
  expect_false(grepl("TAIL_MUST_NOT_BE_SCANNED", value, fixed = TRUE))
})

test_that("descriptor cache is bound to source and implementation", {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  snapshot <- function(x) {
    state$calls <- state$calls + 1L
    list(
      overview = list(kind = "probe", names = as.list(names(x))),
      structure = list(),
      semantics = list()
    )
  }
  first_adapter <- capR:::capr_new_descriptor_adapter(
    id = "org.capr.cache_probe_first",
    family = "probe",
    label = "cache probe",
    snapshot_fn = snapshot,
    implementation_spec = list(probe = "first")
  )
  second_adapter <- capR:::capr_new_descriptor_adapter(
    id = "org.capr.cache_probe_second",
    family = "probe",
    label = "cache probe",
    snapshot_fn = snapshot,
    implementation_spec = list(probe = "second")
  )
  first_source <- list(alpha = 1L)
  second_source <- list(beta = 2L)
  cache <- capR:::capr_new_snapshot_cache(first_source, first_adapter)
  context <- list(.capr_snapshot_cache = cache)

  first <- first_adapter$lifecycle$fingerprint(first_source, context)$value
  repeated <- first_adapter$lifecycle$fingerprint(first_source, context)$value
  expect_identical(first, repeated)
  expect_identical(state$calls, 1L)

  second <- first_adapter$lifecycle$fingerprint(second_source, context)$value
  expect_false(identical(first, second))
  expect_identical(state$calls, 2L)

  second_adapter$lifecycle$fingerprint(first_source, context)
  expect_identical(state$calls, 3L)
})

test_that("bundled descriptor pins include transitive helper implementations", {
  nested <- cap_nested_adapter()
  visual <- cap_visual_adapter()

  expect_true(
    "capr_nested_xml_children" %in%
      names(nested$implementation_spec$declared$functions)
  )
  expect_true(
    "capr_plot_unforced_binding" %in%
      names(visual$implementation_spec$declared$functions)
  )
  expect_identical(
    cap_adapter_pin(nested),
    cap_adapter_pin(cap_nested_adapter())
  )
})
