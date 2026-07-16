test_that("model adapter is deterministic and excludes fitted payload values", {
  secret <- "MODEL_PAYLOAD_SECRET_7f28"
  source <- data.frame(
    outcome = c(1, 2, 4, 8),
    predictor = c(0.2, 0.4, 0.6, 0.8),
    group = factor(
      c(secret, "public", secret, "public"),
      levels = c("public", secret)
    )
  )
  model <- stats::lm(outcome ~ predictor + group, data = source)
  adapter <- cap_model_adapter()

  expect_identical(adapter$metadata$id, "org.capr.model")
  expect_identical(adapter$metadata$maturity, "experimental")
  expect_identical(adapter$metadata$conformance_claim, "none")
  expect_false(adapter$metadata$capabilities$fits_model)
  expect_false(adapter$metadata$capabilities$predicts)
  expect_true(cap_test_adapter(adapter, model)$ok)

  first <- cap_digest(model, adapter = adapter, budget = 800L)
  second <- cap_digest(model, adapter = adapter, budget = 800L)
  expect_identical(
    capr_canonical_json(first$artifact),
    capr_canonical_json(second$artifact)
  )
  expect_false(grepl(
    secret, capr_canonical_json(first$artifact), fixed = TRUE
  ))
  expect_identical(first$source$sourceType, "model")
  expect_identical(
    vapply(first$manifest$fields, `[[`, character(1), "fieldId"),
    c(
      "f1:model@overview#compact",
      "f1:model@structure#compact",
      "f1:model@semantics#compact"
    )
  )

  changed <- stats::lm(outcome ~ predictor, data = source)
  expect_false(identical(
    first$fingerprint,
    cap_digest(changed, adapter = adapter)$fingerprint
  ))
  expect_error(cap_digest(model), class = "capr_adapter_not_found")

  formula_secret <- "FORMULA_LITERAL_SECRET_0c91"
  formula_model <- stats::lm(
    outcome ~ I(group == "FORMULA_LITERAL_SECRET_0c91"),
    data = source
  )
  expect_false(grepl(
    formula_secret,
    capr_canonical_json(cap_digest(
      formula_model, adapter = adapter
    )$artifact),
    fixed = TRUE
  ))
})

test_that("model metadata strips classed host components before inspection", {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  trap <- function(...) {
    state$calls <- state$calls + 1L
    stop("model method executed")
  }
  methods <- c(
    "[[.capr_hostile_model", "names.capr_hostile_model",
    "length.capr_hostile_model", "length.capr_hostile_coefficients",
    "names.capr_hostile_coefficients", "Ops.capr_hostile_response"
  )
  for (name in methods) assign(name, trap, envir = .GlobalEnv)
  on.exit(rm(list = methods, envir = .GlobalEnv), add = TRUE)

  source <- stats::lm(mpg ~ wt, data = mtcars)
  class(source) <- c("capr_hostile_model", class(source))
  raw <- unclass(source)
  raw$coefficients <- structure(
    raw$coefficients,
    class = "capr_hostile_coefficients"
  )
  terms <- raw$terms
  attr(terms, "response") <- structure(
    attr(terms, "response"), class = "capr_hostile_response"
  )
  raw$terms <- terms
  attributes(raw)$class <- class(source)
  source <- raw
  digest <- cap_digest(source, adapter = cap_model_adapter())
  expect_identical(state$calls, 0L)
  expect_identical(digest$source$sourceType, "model")
})

test_that("model adapter covers glm, merMod, recipes, and model containers", {
  glm <- stats::glm(am ~ wt, data = mtcars, family = stats::binomial())
  expect_true(cap_test_adapter(cap_model_adapter(), glm)$ok)
  glm_digest <- cap_digest(glm, adapter = cap_model_adapter())
  expect_identical(
    glm_digest$materialization$outcomes[[
      "f1:model@semantics#compact"
    ]]$value$family,
    "binomial"
  )

  skip_if_not_installed("recipes")
  recipe <- recipes::recipe(mpg ~ wt + cyl, data = mtcars)
  expect_true(cap_test_adapter(cap_model_adapter(), recipe)$ok)
  expect_identical(
    cap_digest(recipe, adapter = cap_model_adapter())$source$sourceType,
    "model"
  )

  spec_secret <- "MODEL_SPEC_SECRET_11ab"
  spec <- structure(
    list(
      mode = "regression",
      engine = "example",
      args = list(hidden = spec_secret)
    ),
    class = "model_spec"
  )
  spec_digest <- cap_digest(spec, adapter = cap_model_adapter())
  expect_false(grepl(
    spec_secret, capr_canonical_json(spec_digest$artifact), fixed = TRUE
  ))

  skip_if_not_installed("lme4")
  mixed <- lme4::lmer(
    Reaction ~ Days + (Days | Subject),
    data = lme4::sleepstudy
  )
  expect_true(cap_test_adapter(cap_model_adapter(), mixed)$ok)
  expect_identical(
    cap_digest(mixed, adapter = cap_model_adapter())$source$sourceType,
    "model"
  )
})

test_that("model adapter supports parsnip specs and unfit workflows", {
  skip_if_not_installed("parsnip")
  spec <- parsnip::linear_reg()
  spec_digest <- cap_digest(spec, adapter = cap_model_adapter())
  expect_identical(spec_digest$source$sourceType, "model")
  expect_true(cap_test_adapter(cap_model_adapter(), spec)$ok)

  fitted <- parsnip::fit(spec, mpg ~ wt, data = mtcars)
  fitted_digest <- cap_digest(fitted, adapter = cap_model_adapter())
  expect_identical(fitted_digest$source$sourceType, "model")
  expect_true(cap_test_adapter(cap_model_adapter(), fitted)$ok)

  skip_if_not_installed("workflows")
  workflow <- workflows::workflow()
  workflow <- workflows::add_model(workflow, spec)
  workflow_digest <- cap_digest(workflow, adapter = cap_model_adapter())
  expect_identical(workflow_digest$source$sourceType, "model")
  semantics <- workflow_digest$materialization$outcomes[[
    "f1:model@semantics#compact"
  ]]$value
  expect_false(semantics$fitting_executed)
  expect_false(semantics$prediction_executed)
})

test_that("visual adapter never draws grobs or invokes htmlwidget hooks", {
  secret <- "VISUAL_LABEL_SECRET_9c33"
  grob <- grid::textGrob(secret)
  adapter <- cap_visual_adapter()

  expect_true(cap_test_adapter(adapter, grob)$ok)
  first <- cap_digest(grob, adapter = adapter)
  second <- cap_digest(grob, adapter = adapter)
  expect_identical(
    capr_canonical_json(first$artifact),
    capr_canonical_json(second$artifact)
  )
  expect_false(grepl(
    secret, capr_canonical_json(first$artifact), fixed = TRUE
  ))
  expect_identical(first$source$sourceType, "plot")

  skip_if_not_installed("htmlwidgets")
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  payload_secret <- "HTMLWIDGET_PAYLOAD_SECRET_3a74"
  widget <- htmlwidgets::createWidget(
    "capr-test-widget",
    list(hidden = payload_secret),
    preRenderHook = function(instance) {
      state$calls <- state$calls + 1L
      instance
    }
  )
  metadata_methods <- c(
    "head.capr_hostile_visual_names", "[.capr_hostile_visual_names"
  )
  metadata_trap <- function(...) {
    state$calls <- state$calls + 1L
    stop("visual metadata method executed")
  }
  for (name in metadata_methods) {
    assign(name, metadata_trap, envir = .GlobalEnv)
  }
  on.exit(rm(list = metadata_methods, envir = .GlobalEnv), add = TRUE)
  widget_raw <- unclass(widget)
  payload <- widget_raw$x
  attr(payload, "names") <- structure(
    attr(payload, "names"), class = "capr_hostile_visual_names"
  )
  widget_raw$x <- payload
  class(widget_raw) <- class(widget)
  widget <- widget_raw
  widget_digest <- cap_digest(widget, adapter = adapter)
  expect_identical(state$calls, 0L)
  expect_false(grepl(
    payload_secret,
    capr_canonical_json(widget_digest$artifact),
    fixed = TRUE
  ))
  expect_true(cap_test_adapter(adapter, widget)$ok)
  expect_identical(state$calls, 0L)
})

test_that("visual adapter treats patchwork as declarations without building", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("patchwork")

  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  base <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point(data = function(data) {
      state$calls <- state$calls + 1L
      data
    })
  combined <- patchwork::wrap_plots(base, base)
  digest <- cap_digest(combined, adapter = cap_visual_adapter())
  expect_identical(state$calls, 0L)
  expect_identical(digest$source$sourceType, "plot")
  expect_true(cap_test_adapter(cap_visual_adapter(), combined)$ok)
  expect_identical(state$calls, 0L)
})

test_that("visual adapter handles a plain ggplot without building layers", {
  skip_if_not_installed("ggplot2")
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  plot <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point(data = function(data) {
      state$calls <- state$calls + 1L
      data
    })
  digest <- cap_digest(plot, adapter = cap_visual_adapter())
  expect_identical(state$calls, 0L)
  expect_identical(digest$source$sourceType, "plot")
  expect_true(cap_test_adapter(cap_visual_adapter(), plot)$ok)
  expect_identical(state$calls, 0L)
})

test_that("visual adapter supports a gtable without drawing it", {
  skip_if_not_installed("gtable")
  table <- gtable::gtable(
    widths = grid::unit(1, "cm"),
    heights = grid::unit(1, "cm")
  )
  digest <- cap_digest(table, adapter = cap_visual_adapter())
  expect_identical(digest$source$sourceType, "plot")
  expect_true(cap_test_adapter(cap_visual_adapter(), table)$ok)
})

test_that("live adapter does not evaluate bindings or disclose values", {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  source <- new.env(parent = emptyenv())
  source$ordinary <- "LIVE_VALUE_SECRET_2bd1"
  makeActiveBinding("danger", function(value) {
    state$calls <- state$calls + 1L
    "ACTIVE_BINDING_SECRET_b1c8"
  }, source)
  adapter <- cap_live_adapter()

  expect_true(cap_test_adapter(adapter, source)$ok)
  expect_identical(state$calls, 0L)
  first <- cap_digest(source, adapter = adapter)
  second <- cap_digest(source, adapter = adapter)
  expect_identical(state$calls, 0L)
  expect_identical(
    capr_canonical_json(first$artifact),
    capr_canonical_json(second$artifact)
  )
  artifact <- capr_canonical_json(first$artifact)
  expect_false(grepl("LIVE_VALUE_SECRET_2bd1", artifact, fixed = TRUE))
  expect_false(grepl("ACTIVE_BINDING_SECRET_b1c8", artifact, fixed = TRUE))
  expect_identical(first$source$sourceType, "external")
  expect_error(cap_digest(source), class = "capr_adapter_not_found")

  arrow_state <- new.env(parent = emptyenv())
  arrow_state$calls <- 0L
  dataset <- new.env(parent = emptyenv())
  class(dataset) <- c("FileSystemDataset", "Dataset", "ArrowObject", "R6")
  makeActiveBinding("schema", function(value) {
    arrow_state$calls <- arrow_state$calls + 1L
    "ARROW_SCHEMA_SECRET_38aa"
  }, dataset)
  dataset_digest <- cap_digest(dataset, adapter = adapter)
  expect_identical(arrow_state$calls, 0L)
  expect_identical(
    dataset_digest$materialization$outcomes[[
      "f1:external@overview#compact"
    ]]$value$kind,
    "arrow_dataset"
  )
})

test_that("live adapter covers lazy tables, DBI connections, and R6 safely", {
  skip_if_not_installed("dbplyr")
  skip_if_not_installed("DBI")

  lazy <- dbplyr::lazy_frame(
    identifier = 1L,
    secret = "LAZY_LITERAL_SECRET_5fd0",
    con = DBI::ANSI()
  )
  lazy_digest <- cap_digest(lazy, adapter = cap_live_adapter())
  expect_identical(lazy_digest$source$sourceType, "external")
  expect_false(grepl(
    "LAZY_LITERAL_SECRET_5fd0",
    capr_canonical_json(lazy_digest$artifact),
    fixed = TRUE
  ))
  expect_true(cap_test_adapter(cap_live_adapter(), lazy)$ok)

  skip_if_not_installed("RSQLite")
  connection <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(connection), add = TRUE)
  connection_digest <- cap_digest(
    connection, adapter = cap_live_adapter()
  )
  expect_identical(connection_digest$source$sourceType, "external")
  expect_true(DBI::dbIsValid(connection))
  expect_true(cap_test_adapter(cap_live_adapter(), connection)$ok)
  expect_true(DBI::dbIsValid(connection))

  skip_if_not_installed("R6")
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  class <- R6::R6Class(
    "CaprLiveFixture",
    public = list(ordinary = "R6_VALUE_SECRET_a119"),
    active = list(danger = function(value) {
      state$calls <- state$calls + 1L
      "R6_ACTIVE_SECRET_b88c"
    })
  )
  object <- class$new()
  object_digest <- cap_digest(object, adapter = cap_live_adapter())
  expect_identical(state$calls, 0L)
  serialized <- capr_canonical_json(object_digest$artifact)
  expect_false(grepl("R6_VALUE_SECRET_a119", serialized, fixed = TRUE))
  expect_false(grepl("R6_ACTIVE_SECRET_b88c", serialized, fixed = TRUE))
})

test_that("live lazy metadata strips S3 methods and keeps environments opaque", {
  skip_if_not_installed("dbplyr")
  skip_if_not_installed("DBI")
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  trap <- function(...) {
    state$calls <- state$calls + 1L
    stop("lazy method executed")
  }
  methods <- c(
    "[[.capr_hostile_lazy", "names.capr_hostile_lazy",
    "length.capr_hostile_lazy"
  )
  for (name in methods) assign(name, trap, envir = .GlobalEnv)
  on.exit(rm(list = methods, envir = .GlobalEnv), add = TRUE)

  lazy <- dbplyr::lazy_frame(id = 1L, con = DBI::ANSI())
  class(lazy) <- c("capr_hostile_lazy", class(lazy))
  digest <- cap_digest(lazy, adapter = cap_live_adapter())
  expect_identical(state$calls, 0L)
  expect_identical(digest$source$sourceType, "external")

  large <- list2env(
    stats::setNames(as.list(seq_len(1001L)), paste0("v", seq_len(1001L))),
    parent = emptyenv()
  )
  large_digest <- cap_digest(large, adapter = cap_live_adapter())
  overview <- large_digest$materialization$outcomes[[
    "f1:external@overview#compact"
  ]]$value
  structure_value <- large_digest$materialization$outcomes[[
    "f1:external@structure#compact"
  ]]$value
  expect_null(overview$binding_count)
  expect_length(structure_value$binding_names, 0L)

  unhashed <- new.env(hash = FALSE, parent = emptyenv())
  unhashed$secret <- "UNHASHED_ENV_SECRET_10f1"
  unhashed_digest <- cap_digest(unhashed, adapter = cap_live_adapter())
  expect_false(grepl(
    "UNHASHED_ENV_SECRET_10f1",
    capr_canonical_json(unhashed_digest$artifact),
    fixed = TRUE
  ))
})

test_that("live adapter covers tbl_sql without executing or collecting it", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("dplyr")

  connection <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(connection), add = TRUE)
  secret <- "TBL_SQL_CELL_SECRET_0ca7"
  DBI::dbWriteTable(
    connection,
    "records",
    data.frame(id = 1:2, value = c(secret, "public"))
  )
  table <- dplyr::tbl(connection, "records")
  expect_true(inherits(table, "tbl_sql"))

  digest <- cap_digest(table, adapter = cap_live_adapter())
  expect_identical(digest$source$sourceType, "external")
  expect_false(grepl(
    secret, capr_canonical_json(digest$artifact), fixed = TRUE
  ))
  expect_true(cap_test_adapter(cap_live_adapter(), table)$ok)
  expect_true(DBI::dbIsValid(connection))
})

test_that("live adapter inspects base connections without opening or closing", {
  connection <- textConnection("one\ntwo", open = "r")
  on.exit(close(connection), add = TRUE)
  expect_true(isOpen(connection))
  digest <- cap_digest(connection, adapter = cap_live_adapter())
  expect_identical(digest$source$sourceType, "external")
  expect_true(isOpen(connection))
  expect_true(cap_test_adapter(cap_live_adapter(), connection)$ok)
  expect_true(isOpen(connection))
})

test_that("live adapter describes an external pointer without dereferencing it", {
  pointer <- methods::new("externalptr")
  digest <- cap_digest(pointer, adapter = cap_live_adapter())
  overview <- digest$materialization$outcomes[[
    "f1:external@overview#compact"
  ]]$value
  semantics <- digest$materialization$outcomes[[
    "f1:external@semantics#compact"
  ]]$value

  expect_identical(overview$kind, "external_pointer")
  expect_identical(overview$type, "externalptr")
  expect_false(semantics$pointer_dereferenced)
  expect_true(cap_test_adapter(cap_live_adapter(), pointer)$ok)
})

test_that("live adapter inspects an Arrow Dataset without scanning files", {
  skip_if_not_installed("arrow")
  directory <- tempfile("capr-arrow-dataset-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  secret <- "ARROW_CELL_SECRET_d13f"
  arrow::write_dataset(
    data.frame(id = 1:2, value = c(secret, "public")),
    directory
  )
  dataset <- arrow::open_dataset(directory)
  unlink(directory, recursive = TRUE)

  digest <- cap_digest(dataset, adapter = cap_live_adapter())
  expect_identical(digest$source$sourceType, "external")
  expect_false(grepl(
    secret, capr_canonical_json(digest$artifact), fixed = TRUE
  ))
  expect_true(cap_test_adapter(cap_live_adapter(), dataset)$ok)
})
