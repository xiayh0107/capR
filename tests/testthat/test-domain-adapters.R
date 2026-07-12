expect_domain_descriptor <- function(adapter, source, family,
                                     sentinels = character()) {
  expect_identical(adapter$metadata$maturity, "experimental")
  expect_identical(adapter$metadata$semantic_level, "domain")
  expect_identical(adapter$metadata$conformance_claim, "none")
  expect_identical(adapter$metadata$source_family, family)
  expect_true(adapter$metadata$capabilities$metadata_only)
  expect_false(adapter$metadata$capabilities$evaluates_user_code)
  expect_false(adapter$metadata$capabilities$materializes_payload)

  contract <- cap_test_adapter(adapter, source)
  expect_true(contract$ok)
  expect_match(contract$scope, "not CAP conformance")

  policy <- cap_policy(max_budget = 5000L)
  first <- cap_digest(
    source,
    budget = 5000L,
    policy = policy,
    adapter = adapter,
    label = paste(family, "fixture")
  )
  second <- cap_digest(
    source,
    budget = 5000L,
    policy = policy,
    adapter = adapter,
    label = paste(family, "fixture")
  )
  expected_fields <- sprintf(
    "f1:%s@%s#compact",
    family,
    c("overview", "structure", "semantics")
  )
  selected <- vapply(
    Filter(function(field) isTRUE(field$selected), first$manifest$fields),
    `[[`,
    character(1),
    "fieldId"
  )

  expect_identical(first$source$sourceType, family)
  expect_identical(selected, expected_fields)
  expect_identical(first$fingerprint, second$fingerprint)
  expect_identical(first$text, second$text)
  expect_identical(
    capr_canonical_json(first$artifact),
    capr_canonical_json(second$artifact)
  )
  expect_identical(
    cap_validate_manifest_text(first$text, first$manifest),
    list()
  )
  expect_true("capr_caveat_metadata_only" %in% vapply(
    first$caveats,
    `[[`,
    character(1),
    "code"
  ))

  artifact_text <- capr_canonical_json(first$artifact)
  for (sentinel in sentinels) {
    expect_false(grepl(sentinel, artifact_text, fixed = TRUE))
  }
  first
}

test_that("domain adapter constructors are explicit experimental descriptors", {
  adapters <- list(
    relational = cap_relational_adapter(),
    temporal = cap_temporal_adapter(),
    spatial = cap_spatial_adapter()
  )

  expect_identical(
    vapply(adapters, function(x) x$metadata$id, character(1)),
    c(
      relational = "org.capr.relational",
      temporal = "org.capr.temporal",
      spatial = "org.capr.spatial"
    )
  )
  expect_true(all(vapply(
    adapters,
    function(x) identical(x$metadata$conformance_claim, "none"),
    logical(1)
  )))
  expect_error(
    cap_digest(list(value = 1), adapter = adapters$relational),
    class = "capr_adapter_invalid"
  )
  expect_error(
    cap_digest(list(value = 1), adapter = adapters$temporal),
    class = "capr_adapter_invalid"
  )
  expect_error(
    cap_digest(list(value = 1), adapter = adapters$spatial),
    class = "capr_adapter_invalid"
  )
})

test_that("declared database schemas preserve topology without DBI access", {
  schema <- cap_db_schema(
    tables = list(
      customers = c(customer_id = "integer", email = "text"),
      orders = c(
        order_id = "integer",
        customer_id = "integer",
        amount = "decimal"
      )
    ),
    primary_keys = list(
      customers = "customer_id",
      orders = "order_id"
    ),
    foreign_keys = list(list(
      from_table = "orders",
      from_columns = "customer_id",
      to_table = "customers",
      to_columns = "customer_id"
    ))
  )
  expect_s3_class(schema, "capr_db_schema")
  digest <- expect_domain_descriptor(
    cap_relational_adapter(), schema, "relational"
  )
  overview <- digest$materialization$outcomes[[
    "f1:relational@overview#compact"
  ]]$value
  structure_value <- digest$materialization$outcomes[[
    "f1:relational@structure#compact"
  ]]$value
  semantics <- digest$materialization$outcomes[[
    "f1:relational@semantics#compact"
  ]]$value
  expect_identical(overview$kind, "database_schema")
  expect_identical(overview$table_count, 2L)
  expect_identical(overview$primary_key_count, 2L)
  expect_identical(overview$foreign_key_count, 1L)
  expect_true(semantics$declared_metadata_only)
  expect_false(semantics$database_connection_accessed)
  expect_false(semantics$remote_queries_executed)

  changed <- cap_db_schema(
    tables = list(
      customers = c(customer_id = "integer", email = "text"),
      orders = c(order_id = "integer", customer_id = "integer")
    )
  )
  expect_false(identical(
    digest$fingerprint,
    cap_digest(changed, adapter = cap_relational_adapter())$fingerprint
  ))
  expect_error(
    cap_db_schema(
      tables = list(customers = c(customer_id = "integer")),
      foreign_keys = list(list(
        from_table = "customers",
        from_columns = "missing",
        to_table = "customers",
        to_columns = "customer_id"
      ))
    ),
    class = "capr_adapter_invalid"
  )
  expect_error(
    cap_db_schema(tables = list(customers = data.frame(id = 1L))),
    class = "capr_adapter_invalid"
  )
})

test_that("declared database schemas reject spoofing and post-build mutation", {
  sentinel <- "RELATIONAL_SCHEMA_SPOOF_SECRET_9f11"
  adapter <- cap_relational_adapter()
  capture_error <- function(source) {
    tryCatch(
      {
        cap_digest(source, adapter = adapter)
        NULL
      },
      capr_adapter_invalid = function(error) error
    )
  }

  spoof <- structure(
    list(
      tables = list(list(secret_value = sentinel)),
      primary_keys = list(),
      foreign_keys = list()
    ),
    class = c("capr_db_schema", "list")
  )
  spoof_error <- capture_error(spoof)
  expect_s3_class(spoof_error, "capr_adapter_invalid")
  expect_false(grepl(sentinel, conditionMessage(spoof_error), fixed = TRUE))

  declared <- cap_db_schema(
    tables = list(records = c(id = "integer")),
    primary_keys = list(records = "id")
  )
  sealed_spoof <- spoof
  attr(sealed_spoof, "capr_db_schema_integrity") <- attr(
    declared, "capr_db_schema_integrity", exact = TRUE
  )
  sealed_spoof_error <- capture_error(sealed_spoof)
  expect_s3_class(sealed_spoof_error, "capr_adapter_invalid")
  expect_false(grepl(
    sentinel, conditionMessage(sealed_spoof_error), fixed = TRUE
  ))

  mutated <- declared
  mutated$tables[[1L]]$columns[[1L]]$type <- sentinel
  mutation_error <- capture_error(mutated)
  expect_s3_class(mutation_error, "capr_adapter_invalid")
  expect_false(grepl(
    sentinel, conditionMessage(mutation_error), fixed = TRUE
  ))

  mutated_key <- declared
  mutated_key$primary_keys[[1L]]$columns[[1L]] <- sentinel
  key_error <- capture_error(mutated_key)
  expect_s3_class(key_error, "capr_adapter_invalid")
  expect_false(grepl(
    sentinel,
    paste(capture.output(str(key_error)), collapse = "\n"),
    fixed = TRUE
  ))

  auxiliary_name_secrets <- c(
    "PRIMARY_NAME_SECRET_12c3",
    "FOREIGN_FROM_NAME_SECRET_45d6",
    "FOREIGN_TO_NAME_SECRET_78e9"
  )
  named_columns <- cap_db_schema(
    tables = list(records = c(id = "integer")),
    primary_keys = list(records = stats::setNames(
      "id", auxiliary_name_secrets[[1L]]
    )),
    foreign_keys = list(list(
      from_table = "records",
      from_columns = stats::setNames("id", auxiliary_name_secrets[[2L]]),
      to_table = "records",
      to_columns = stats::setNames("id", auxiliary_name_secrets[[3L]])
    ))
  )
  artifact <- capr_canonical_json(cap_digest(
    named_columns, adapter = adapter
  )$artifact)
  for (secret in auxiliary_name_secrets) {
    expect_false(grepl(secret, artifact, fixed = TRUE), info = secret)
  }

  colliding_columns <- c("integer", "text")
  names(colliding_columns) <- c("\t", " ")
  expect_error(
    cap_db_schema(tables = list(records = colliding_columns)),
    class = "capr_adapter_invalid"
  )

  normalized_name <- "\trecords"
  normalized_schema <- cap_db_schema(
    tables = stats::setNames(list(c(id = "integer")), normalized_name),
    primary_keys = stats::setNames(list("id"), normalized_name)
  )
  expect_true(cap_test_adapter(adapter, normalized_schema)$ok)
})

test_that("base ts metadata is deterministic and excludes payload values", {
  sentinel <- "987654321.125"
  source <- stats::ts(
    c(1, 2, 3, 4, 5, 6, 7, as.numeric(sentinel)),
    start = c(2025, 1),
    frequency = 4
  )
  before <- serialize(source, NULL)
  adapter <- cap_temporal_adapter()
  digest <- expect_domain_descriptor(
    adapter,
    source,
    "temporal",
    sentinels = sentinel
  )
  overview <- digest$materialization$outcomes[[
    "f1:temporal@overview#compact"
  ]]$value
  semantics <- digest$materialization$outcomes[[
    "f1:temporal@semantics#compact"
  ]]$value

  expect_identical(overview$kind, "ts")
  expect_identical(overview$observations, 8L)
  expect_identical(overview$series, 1L)
  expect_true(semantics$regular)
  expect_identical(semantics$frequency, 4)
  expect_false(semantics$index_values_included)
  expect_false(semantics$payload_values_included)
  expect_identical(serialize(source, NULL), before)

  changed <- stats::ts(rep(42, 8), start = c(2025, 1), frequency = 4)
  changed_digest <- cap_digest(
    changed,
    budget = 5000L,
    policy = cap_policy(max_budget = 5000L),
    adapter = adapter,
    label = "temporal fixture"
  )
  expect_identical(digest$fingerprint, changed_digest$fingerprint)
  expect_identical(digest$text, changed_digest$text)
})

test_that("temporal metadata avoids host S3 methods and unknown regularity", {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  trap <- function(...) {
    state$calls <- state$calls + 1L
    stop("host S3 method executed")
  }
  methods <- c(
    "dim.tbl_ts", "names.tbl_ts", "length.tbl_ts",
    "frequency.tbl_ts", "colnames.tbl_ts"
  )
  for (name in methods) assign(name, trap, envir = .GlobalEnv)
  on.exit(rm(list = methods, envir = .GlobalEnv), add = TRUE)

  source <- structure(
    list(index = 1:2, value = c(10, 20)),
    row.names = c(NA_integer_, -2L),
    class = c("tbl_ts", "data.frame")
  )
  digest <- cap_digest(source, adapter = cap_temporal_adapter())
  expect_identical(state$calls, 0L)
  semantics <- digest$materialization$outcomes[[
    "f1:temporal@semantics#compact"
  ]]$value
  expect_null(semantics$regular)
  expect_null(semantics$frequency)
})

test_that("dm relational metadata excludes table and key values", {
  skip_if_not_installed("dm")

  sentinel <- "DM_TABLE_VALUE_MUST_NOT_LEAK_71c9"
  customers <- data.frame(
    customer_id = c(1L, 2L),
    note = c(sentinel, "ok"),
    stringsAsFactors = FALSE
  )
  orders <- data.frame(
    order_id = c(10L, 11L),
    customer_id = c(1L, 2L),
    amount = c(20, 30)
  )
  source <- dm::dm(customers = customers, orders = orders)
  source <- dm::dm_add_pk(source, customers, customer_id)
  source <- dm::dm_add_pk(source, orders, order_id)
  source <- dm::dm_add_fk(source, orders, customer_id, customers)

  digest <- expect_domain_descriptor(
    cap_relational_adapter(),
    source,
    "relational",
    sentinels = sentinel
  )
  overview <- digest$materialization$outcomes[[
    "f1:relational@overview#compact"
  ]]$value
  structure_value <- digest$materialization$outcomes[[
    "f1:relational@structure#compact"
  ]]$value
  semantics <- digest$materialization$outcomes[[
    "f1:relational@semantics#compact"
  ]]$value
  expect_identical(overview$kind, "dm")
  expect_identical(overview$table_count, 2L)
  expect_identical(
    unlist(structure_value$table_names, use.names = FALSE),
    c("customers", "orders")
  )
  expect_false(semantics$table_values_included)
  expect_false(semantics$key_values_included)
  expect_false(semantics$remote_queries_executed)
})

test_that("MultiAssayExperiment metadata excludes assay and sample values", {
  skip_if_not_installed("MultiAssayExperiment")

  sentinel <- "876543210.875"
  counts <- matrix(
    c(1:11, as.numeric(sentinel)),
    nrow = 3,
    dimnames = list(paste0("g", 1:3), paste0("s", 1:4))
  )
  source <- MultiAssayExperiment::MultiAssayExperiment(
    experiments = list(
      rna = counts,
      protein = counts[1:2, , drop = FALSE]
    )
  )
  before <- serialize(source, NULL)
  digest <- expect_domain_descriptor(
    cap_relational_adapter(),
    source,
    "relational",
    sentinels = sentinel
  )
  overview <- digest$materialization$outcomes[[
    "f1:relational@overview#compact"
  ]]$value
  structure <- digest$materialization$outcomes[[
    "f1:relational@structure#compact"
  ]]$value
  semantics <- digest$materialization$outcomes[[
    "f1:relational@semantics#compact"
  ]]$value

  expect_identical(overview$kind, "MultiAssayExperiment")
  expect_identical(overview$experiment_count, 2L)
  expect_identical(structure$experiment_names, list("rna", "protein"))
  expect_false(semantics$table_values_included)
  expect_false(semantics$sample_identifiers_included)
  expect_false(semantics$assay_values_included)
  expect_false(semantics$assays_materialized)
  expect_identical(serialize(source, NULL), before)
})

test_that("zoo metadata excludes index and payload values", {
  skip_if_not_installed("zoo")

  payload_sentinel <- "765432109.625"
  index_sentinel <- "2099-12-31"
  source <- zoo::zoo(
    c(as.numeric(payload_sentinel), 2, 3),
    order.by = as.Date(c(index_sentinel, "2100-01-01", "2100-01-02"))
  )
  digest <- expect_domain_descriptor(
    cap_temporal_adapter(),
    source,
    "temporal",
    sentinels = c(payload_sentinel, index_sentinel)
  )
  overview <- digest$materialization$outcomes[[
    "f1:temporal@overview#compact"
  ]]$value
  expect_identical(overview$kind, "zoo")
})

test_that("xts metadata excludes index and payload values", {
  skip_if_not_installed("xts")

  payload_sentinel <- "654321098.375"
  index_sentinel <- "2098-06-15"
  source <- xts::xts(
    matrix(c(as.numeric(payload_sentinel), 2, 3), ncol = 1),
    order.by = as.POSIXct(
      c(index_sentinel, "2098-06-16", "2098-06-17"),
      tz = "UTC"
    )
  )
  digest <- expect_domain_descriptor(
    cap_temporal_adapter(),
    source,
    "temporal",
    sentinels = c(payload_sentinel, index_sentinel)
  )
  overview <- digest$materialization$outcomes[[
    "f1:temporal@overview#compact"
  ]]$value
  expect_identical(overview$kind, "xts")
})

test_that("tbl_ts metadata excludes index and table values", {
  skip_if_not_installed("tsibble")

  sentinel <- "TSIBBLE_VALUE_MUST_NOT_LEAK_a13e"
  source <- tsibble::tsibble(
    id = c("A", "A", "B", "B"),
    when = as.Date("2025-01-01") + 0:3,
    value = c(sentinel, "ok", "ok", "ok"),
    key = id,
    index = when
  )
  digest <- expect_domain_descriptor(
    cap_temporal_adapter(),
    source,
    "temporal",
    sentinels = sentinel
  )
  overview <- digest$materialization$outcomes[[
    "f1:temporal@overview#compact"
  ]]$value
  expect_identical(overview$kind, "tbl_ts")
})

test_that("sf and sfc metadata exclude table, bbox, and coordinate values", {
  skip_if_not_installed("sf")

  table_sentinel <- "SF_TABLE_VALUE_MUST_NOT_LEAK_4d2a"
  coordinate_sentinel <- "98765.4321"
  geometry <- sf::st_sfc(
    sf::st_point(c(as.numeric(coordinate_sentinel), 1)),
    sf::st_point(c(2, 3)),
    crs = 4326
  )
  source <- sf::st_sf(
    note = c(table_sentinel, "ok"),
    geometry = geometry
  )

  sf_digest <- expect_domain_descriptor(
    cap_spatial_adapter(),
    source,
    "spatial",
    sentinels = c(table_sentinel, coordinate_sentinel)
  )
  sfc_digest <- expect_domain_descriptor(
    cap_spatial_adapter(),
    geometry,
    "spatial",
    sentinels = coordinate_sentinel
  )
  sf_overview <- sf_digest$materialization$outcomes[[
    "f1:spatial@overview#compact"
  ]]$value
  sfc_overview <- sfc_digest$materialization$outcomes[[
    "f1:spatial@overview#compact"
  ]]$value
  semantics <- sf_digest$materialization$outcomes[[
    "f1:spatial@semantics#compact"
  ]]$value

  expect_identical(sf_overview$kind, "sf")
  expect_identical(sfc_overview$kind, "sfc")
  expect_false(semantics$coordinate_values_included)
  expect_false(semantics$bounding_box_included)
  expect_false(semantics$coordinate_reference_values_included)
  expect_false(semantics$table_values_included)
})

test_that("stars metadata excludes cells and coordinate metadata values", {
  skip_if_not_installed("stars")

  sentinel <- "543210987.25"
  source <- stars::st_as_stars(array(
    c(as.numeric(sentinel), 2, 3, 4),
    dim = c(x = 2, y = 2)
  ))
  digest <- expect_domain_descriptor(
    cap_spatial_adapter(),
    source,
    "spatial",
    sentinels = sentinel
  )
  overview <- digest$materialization$outcomes[[
    "f1:spatial@overview#compact"
  ]]$value
  expect_identical(overview$kind, "stars")
})

test_that("GRanges metadata excludes genomic ranges and element values", {
  skip_if_not_installed("GenomicRanges")
  skip_if_not_installed("IRanges")

  range_sentinel <- "43210987"
  value_sentinel <- "GRANGES_VALUE_MUST_NOT_LEAK_301f"
  source <- GenomicRanges::GRanges(
    seqnames = c("chr1", "chr2"),
    ranges = IRanges::IRanges(
      start = c(as.integer(range_sentinel), 10L),
      width = c(5L, 3L)
    ),
    strand = c("+", "-")
  )
  source$note <- c(value_sentinel, "ok")

  digest <- expect_domain_descriptor(
    cap_spatial_adapter(),
    source,
    "spatial",
    sentinels = c(range_sentinel, value_sentinel)
  )
  overview <- digest$materialization$outcomes[[
    "f1:spatial@overview#compact"
  ]]$value
  semantics <- digest$materialization$outcomes[[
    "f1:spatial@semantics#compact"
  ]]$value
  expect_identical(overview$kind, "GRanges")
  expect_false(semantics$range_values_included)
  expect_false(semantics$table_values_included)
})

test_that("domain dimensions strip classed metadata and enforce rank bounds", {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  trap <- function(...) {
    state$calls <- state$calls + 1L
    stop("domain dimension method executed")
  }
  methods <- c(
    "length.capr_hostile_dimnames", "[[.capr_hostile_dimnames",
    "[.capr_hostile_series_names"
  )
  for (name in methods) assign(name, trap, envir = .GlobalEnv)
  on.exit(rm(list = methods, envir = .GlobalEnv), add = TRUE)

  series <- stats::ts(matrix(
    1:4, nrow = 2L,
    dimnames = list(NULL, c("first", "second"))
  ))
  dimnames <- attr(series, "dimnames", exact = TRUE)
  series_names <- dimnames[[2L]]
  attr(series_names, "class") <- "capr_hostile_series_names"
  dimnames[[2L]] <- series_names
  attr(dimnames, "names") <- NULL
  class(dimnames) <- "capr_hostile_dimnames"
  attr(series, "dimnames") <- dimnames
  expect_true(cap_test_adapter(cap_temporal_adapter(), series)$ok)
  expect_identical(state$calls, 0L)

  high_rank <- structure(
    list(values = structure(1L, dim = rep(1L, 65L))),
    class = "stars"
  )
  expect_error(
    cap_digest(high_rank, adapter = cap_spatial_adapter()),
    class = "capr_adapter_invalid"
  )
})
