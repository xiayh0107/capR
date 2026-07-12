nested_array_selected_ids <- function(digest) {
  vapply(
    Filter(function(field) isTRUE(field$selected), digest$manifest$fields),
    `[[`, character(1), "fieldId"
  )
}

expect_descriptor_sections <- function(digest, family) {
  expect_identical(
    nested_array_selected_ids(digest),
    sprintf(
      "f1:%s@%s#compact",
      family,
      c("overview", "structure", "semantics")
    )
  )
  expect_identical(
    cap_validate_manifest_text(digest$text, digest$manifest),
    list()
  )
}

test_that("nested adapter is bounded, deterministic, and omits leaf values", {
  leaf_secret <- "NESTED_LEAF_SENTINEL_91f2"
  function_secret <- "FUNCTION_BODY_SENTINEL_a84c"
  environment_secret <- "ENVIRONMENT_SENTINEL_620d"
  hidden <- new.env(parent = emptyenv())
  hidden$secret <- environment_secret
  source <- list(
    branch = list(
      text = leaf_secret,
      numbers = c(410001L, 410002L),
      deeper = list(flag = TRUE, raw = charToRaw("private"))
    ),
    executable = local({
      secret <- function_secret
      function() secret
    }),
    environment = hidden,
    language = quote(stop("LANGUAGE_SENTINEL_771b"))
  )

  adapter <- cap_nested_adapter()
  expect_identical(adapter$metadata$id, "org.capr.nested")
  expect_identical(adapter$metadata$maturity, "experimental")
  expect_identical(adapter$metadata$semantic_level, "structural")
  expect_identical(adapter$metadata$conformance_claim, "none")
  expect_false(adapter$metadata$capabilities$leaf_values_disclosed)
  expect_true(cap_test_adapter(adapter, source)$ok)

  first <- cap_digest(source, budget = 800L, adapter = adapter)
  second <- cap_digest(source, budget = 800L, adapter = adapter)
  expect_descriptor_sections(first, "nested")
  expect_identical(first$fingerprint, second$fingerprint)
  expect_identical(first$text, second$text)
  expect_identical(
    capr_canonical_json(first$artifact),
    capr_canonical_json(second$artifact)
  )

  artifact <- capr_canonical_json(first$artifact)
  for (secret in c(
    leaf_secret,
    function_secret,
    environment_secret,
    "LANGUAGE_SENTINEL_771b",
    "410001",
    "410002"
  )) {
    expect_false(grepl(secret, artifact, fixed = TRUE), info = secret)
  }
  expect_identical(hidden$secret, environment_secret)

  structure_value <- first$materialization$outcomes[[
    "f1:nested@structure#compact"
  ]]$value
  semantics <- first$materialization$outcomes[[
    "f1:nested@semantics#compact"
  ]]$value
  expect_lte(length(structure_value$nodes), 80L)
  expect_false(semantics$payload_values_disclosed)
  expect_false(semantics$executable_objects_evaluated)
  expect_true(any(vapply(
    structure_value$nodes,
    function(node) identical(node$reason, "function_not_executed"),
    logical(1)
  )))

  same_topology_a <- list(a = list(b = "first"), c = c(1L, 2L))
  same_topology_b <- list(a = list(b = "second"), c = c(8L, 9L))
  expect_identical(
    adapter$lifecycle$fingerprint(same_topology_a, list())$value,
    adapter$lifecycle$fingerprint(same_topology_b, list())$value
  )

  wide <- stats::setNames(as.list(seq_len(100L)), sprintf("n%03d", 1:100))
  bounded <- cap_digest(wide, budget = 800L, adapter = adapter)
  bounded_structure <- bounded$materialization$outcomes[[
    "f1:nested@structure#compact"
  ]]$value
  expect_true(bounded_structure$truncated)
  expect_lte(length(bounded_structure$nodes), 80L)
})

test_that("nested adapter supports list-columns and nested tibbles", {
  sentinel <- "LIST_COLUMN_SENTINEL_30c1"
  nested <- data.frame(id = 1:2)
  nested$payload <- I(list(
    list(secret = sentinel, values = c(700001L, 700002L)),
    data.frame(inner = sentinel, check.names = FALSE)
  ))
  adapter <- cap_nested_adapter()
  digest <- cap_digest(nested, budget = 800L, adapter = adapter)
  expect_descriptor_sections(digest, "nested")
  expect_false(grepl(
    sentinel,
    capr_canonical_json(digest$artifact),
    fixed = TRUE
  ))
  overview <- digest$materialization$outcomes[[
    "f1:nested@overview#compact"
  ]]$value
  semantics <- digest$materialization$outcomes[[
    "f1:nested@semantics#compact"
  ]]$value
  expect_identical(overview$kind, "nested_table")
  expect_identical(overview$list_columns, 1L)
  expect_identical(unlist(semantics$list_columns), "payload")
  expect_true(cap_test_adapter(adapter, nested)$ok)

  skip_if_not_installed("tibble")
  tibble_source <- tibble::tibble(
    id = 1:2,
    payload = list(list(secret = sentinel), list(secret = sentinel))
  )
  tibble_digest <- cap_digest(
    tibble_source,
    budget = 800L,
    adapter = adapter
  )
  expect_identical(
    tibble_digest$materialization$outcomes[[
      "f1:nested@overview#compact"
    ]]$value$kind,
    "nested_table"
  )
  expect_false(grepl(
    sentinel,
    capr_canonical_json(tibble_digest$artifact),
    fixed = TRUE
  ))
})

test_that("nested adapter describes XML topology without XML values", {
  skip_if_not_installed("xml2")
  text_secret <- "XML_TEXT_SENTINEL_a6f4"
  attribute_secret <- "XML_ATTRIBUTE_SENTINEL_3c8d"
  document <- xml2::read_xml(sprintf(
    paste0(
      "<root private='%s'><group><item code='x'>%s</item>",
      "<item>safe</item></group></root>"
    ),
    attribute_secret,
    text_secret
  ))
  adapter <- cap_nested_adapter()

  document_digest <- cap_digest(document, budget = 800L, adapter = adapter)
  node_digest <- cap_digest(
    xml2::xml_root(document),
    budget = 800L,
    adapter = adapter
  )
  expect_descriptor_sections(document_digest, "nested")
  expect_descriptor_sections(node_digest, "nested")
  expect_true(cap_test_adapter(adapter, document)$ok)
  expect_true(cap_test_adapter(adapter, xml2::xml_root(document))$ok)

  document_artifact <- capr_canonical_json(document_digest$artifact)
  node_artifact <- capr_canonical_json(node_digest$artifact)
  for (secret in c(text_secret, attribute_secret)) {
    expect_false(grepl(secret, document_artifact, fixed = TRUE))
    expect_false(grepl(secret, node_artifact, fixed = TRUE))
  }
  semantics <- document_digest$materialization$outcomes[[
    "f1:nested@semantics#compact"
  ]]$value
  expect_false(semantics$text_values_disclosed)
  expect_false(semantics$attribute_values_disclosed)
  expect_false(semantics$attribute_names_inspected)

  repeated <- cap_digest(document, budget = 800L, adapter = adapter)
  expect_identical(
    capr_canonical_json(document_digest$artifact),
    capr_canonical_json(repeated$artifact)
  )

  wide <- xml2::read_xml(paste0(
    "<root>", paste(rep("<item/>", 5000L), collapse = ""), "</root>"
  ))
  wide_digest <- cap_digest(wide, budget = 800L, adapter = adapter)
  wide_structure <- wide_digest$materialization$outcomes[[
    "f1:nested@structure#compact"
  ]]$value
  root <- wide_structure$elements[[1L]]
  expect_identical(root$child_elements_observed, 21L)
  expect_false(root$child_count_exact)
  expect_identical(root$children_captured, 20L)
  expect_true(wide_structure$truncated)
})

test_that("nested adapter parses only bounded inline JSON without leaf values", {
  secret <- "JSON_LEAF_SECRET_5dc2"
  source <- jsonlite::toJSON(
    list(records = list(list(id = 1L, value = secret))),
    auto_unbox = TRUE
  )
  adapter <- cap_nested_adapter()
  digest <- cap_digest(source, adapter = adapter)
  expect_descriptor_sections(digest, "nested")
  expect_true(cap_test_adapter(adapter, source)$ok)
  expect_false(grepl(
    secret, capr_canonical_json(digest$artifact), fixed = TRUE
  ))
  overview <- digest$materialization$outcomes[[
    "f1:nested@overview#compact"
  ]]$value
  semantics <- digest$materialization$outcomes[[
    "f1:nested@semantics#compact"
  ]]$value
  expect_identical(overview$kind, "json")
  expect_true(semantics$parsed_inline)
  expect_false(semantics$paths_or_urls_opened)

  hostile <- structure("https://example.invalid/payload.json", class = "json")
  expect_error(
    cap_digest(hostile, adapter = adapter),
    class = "capr_adapter_invalid"
  )
})

test_that("nested table metadata strips S3 methods before traversal", {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  trap <- function(...) {
    state$calls <- state$calls + 1L
    stop("host table method executed")
  }
  methods <- c(
    "dim.capr_hostile_nested", "nrow.capr_hostile_nested",
    "ncol.capr_hostile_nested", "names.capr_hostile_nested",
    "[[.capr_hostile_nested", "length.capr_hostile_nested"
  )
  for (name in methods) assign(name, trap, envir = .GlobalEnv)
  on.exit(rm(list = methods, envir = .GlobalEnv), add = TRUE)

  source <- structure(
    list(id = 1:2, nested = list(list(a = 1L), list(a = 2L))),
    row.names = c(NA_integer_, -2L),
    class = c("capr_hostile_nested", "data.frame")
  )
  digest <- cap_digest(source, adapter = cap_nested_adapter())
  expect_identical(state$calls, 0L)
  expect_identical(digest$source$sourceType, "nested")
})

test_that("array adapter reports base shape without cell values", {
  sentinel <- 987654321L
  matrix_source <- matrix(
    c(sentinel, 123456789L, 42L, 43L),
    nrow = 2L,
    dimnames = list(c("r1", "r2"), c("c1", "c2"))
  )
  array_source <- array(seq_len(24L), dim = c(2L, 3L, 4L))
  adapter <- cap_array_adapter()
  expect_identical(adapter$metadata$id, "org.capr.array")
  expect_identical(adapter$metadata$maturity, "experimental")
  expect_identical(adapter$metadata$semantic_level, "structural")
  expect_identical(adapter$metadata$conformance_claim, "none")
  expect_false(adapter$metadata$capabilities$payload_values_disclosed)
  expect_true(cap_test_adapter(adapter, matrix_source)$ok)
  expect_true(cap_test_adapter(adapter, array_source)$ok)

  first <- cap_digest(matrix_source, budget = 800L, adapter = adapter)
  second <- cap_digest(matrix_source, budget = 800L, adapter = adapter)
  expect_descriptor_sections(first, "array")
  expect_identical(
    capr_canonical_json(first$artifact),
    capr_canonical_json(second$artifact)
  )
  expect_false(grepl(
    as.character(sentinel),
    capr_canonical_json(first$artifact),
    fixed = TRUE
  ))
  overview <- first$materialization$outcomes[[
    "f1:array@overview#compact"
  ]]$value
  semantics <- first$materialization$outcomes[[
    "f1:array@semantics#compact"
  ]]$value
  expect_identical(overview$kind, "base_matrix")
  expect_identical(unlist(overview$dimensions), c(2L, 2L))
  expect_false(semantics$payload_values_disclosed)
  expect_false(semantics$payload_materialized)

  changed_values <- matrix(
    c(8L, 9L, 10L, 11L),
    nrow = 2L,
    dimnames = dimnames(matrix_source)
  )
  expect_identical(
    adapter$lifecycle$fingerprint(matrix_source, list())$value,
    adapter$lifecycle$fingerprint(changed_values, list())$value
  )
})

test_that("base array metadata never dispatches host dimension methods", {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  trap <- function(...) {
    state$calls <- state$calls + 1L
    stop("array method executed")
  }
  methods <- c("dim.capr_hostile_array", "length.capr_hostile_array")
  for (name in methods) assign(name, trap, envir = .GlobalEnv)
  on.exit(rm(list = methods, envir = .GlobalEnv), add = TRUE)

  source <- structure(
    1:4,
    dim = c(2L, 2L),
    class = c("capr_hostile_array", "matrix", "array")
  )
  digest <- cap_digest(source, adapter = cap_array_adapter())
  expect_identical(state$calls, 0L)
  expect_identical(digest$source$sourceType, "array")
})

test_that("array adapter supports Matrix objects without stored values", {
  skip_if_not_installed("Matrix")
  first_secret <- 812345671
  second_secret <- 812345672
  sparse <- Matrix::sparseMatrix(
    i = c(1L, 3L),
    j = c(2L, 1L),
    x = c(first_secret, second_secret),
    dims = c(3L, 3L)
  )
  adapter <- cap_array_adapter()
  digest <- cap_digest(sparse, budget = 800L, adapter = adapter)
  expect_descriptor_sections(digest, "array")
  expect_true(cap_test_adapter(adapter, sparse)$ok)
  artifact <- capr_canonical_json(digest$artifact)
  expect_false(grepl(as.character(first_secret), artifact, fixed = TRUE))
  expect_false(grepl(as.character(second_secret), artifact, fixed = TRUE))
  structure_value <- digest$materialization$outcomes[[
    "f1:array@structure#compact"
  ]]$value
  expect_true(structure_value$sparse)
  expect_identical(structure_value$stored_entries, 2L)
  expect_false(structure_value$delayed)
})

test_that("array adapter does not materialize DelayedArray payloads", {
  skip_if_not_installed("DelayedArray")
  first_secret <- 723456781L
  second_secret <- 723456782L
  delayed <- DelayedArray::DelayedArray(matrix(
    c(first_secret, second_secret, 1L, 2L),
    nrow = 2L
  ))
  adapter <- cap_array_adapter()
  digest <- cap_digest(delayed, budget = 800L, adapter = adapter)
  expect_descriptor_sections(digest, "array")
  expect_true(cap_test_adapter(adapter, delayed)$ok)
  artifact <- capr_canonical_json(digest$artifact)
  expect_false(grepl(as.character(first_secret), artifact, fixed = TRUE))
  expect_false(grepl(as.character(second_secret), artifact, fixed = TRUE))
  overview <- digest$materialization$outcomes[[
    "f1:array@overview#compact"
  ]]$value
  structure_value <- digest$materialization$outcomes[[
    "f1:array@structure#compact"
  ]]$value
  semantics <- digest$materialization$outcomes[[
    "f1:array@semantics#compact"
  ]]$value
  expect_identical(overview$kind, "delayed_array")
  expect_true(structure_value$delayed)
  expect_false(semantics$payload_materialized)
  expect_false(semantics$delayed_operations_evaluated)
})

test_that("array adapter hides HDF5 payloads and backing paths", {
  skip_if_not_installed("HDF5Array")
  filepath <- tempfile("HDF5_BACKING_SENTINEL_", fileext = ".h5")
  on.exit(unlink(filepath), add = TRUE)
  first_secret <- 623456781L
  second_secret <- 623456782L
  hdf5 <- HDF5Array::writeHDF5Array(
    matrix(c(first_secret, second_secret, 1L, 2L), nrow = 2L),
    filepath = filepath,
    name = "payload"
  )
  adapter <- cap_array_adapter()
  digest <- cap_digest(hdf5, budget = 800L, adapter = adapter)
  expect_descriptor_sections(digest, "array")
  expect_true(cap_test_adapter(adapter, hdf5)$ok)
  artifact <- capr_canonical_json(digest$artifact)
  expect_false(grepl(as.character(first_secret), artifact, fixed = TRUE))
  expect_false(grepl(as.character(second_secret), artifact, fixed = TRUE))
  expect_false(grepl(basename(filepath), artifact, fixed = TRUE))
  overview <- digest$materialization$outcomes[[
    "f1:array@overview#compact"
  ]]$value
  structure_value <- digest$materialization$outcomes[[
    "f1:array@structure#compact"
  ]]$value
  semantics <- digest$materialization$outcomes[[
    "f1:array@semantics#compact"
  ]]$value
  expect_identical(overview$kind, "hdf5_array")
  expect_true(structure_value$delayed)
  expect_true(structure_value$file_backed)
  expect_false(semantics$payload_materialized)
  expect_false(semantics$backing_path_disclosed)

  repeated <- cap_digest(hdf5, budget = 800L, adapter = adapter)
  expect_identical(
    capr_canonical_json(digest$artifact),
    capr_canonical_json(repeated$artifact)
  )
})

test_that("nested package metadata cannot dispatch hostile helper methods", {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  trap <- function(...) {
    state$calls <- state$calls + 1L
    stop("host metadata method executed")
  }
  method_names <- c(
    "[.capr_evil_names", "length.capr_evil_names",
    "length.capr_evil_json", "xml_find_all.xml_node",
    "xml_find_first.xml_node",
    "$.xml_node", "[[.xml_nodeset", "length.xml_nodeset"
  )
  for (name in method_names) assign(name, trap, envir = .GlobalEnv)
  on.exit(rm(list = method_names, envir = .GlobalEnv), add = TRUE)

  source <- list(branch = list(leaf = 1L))
  attr(source, "names") <- structure(
    attr(source, "names"), class = "capr_evil_names"
  )
  expect_true(cap_test_adapter(cap_nested_adapter(), source)$ok)

  json <- structure(
    '{"branch":{"leaf":1}}',
    class = c("json", "capr_evil_json")
  )
  expect_true(cap_test_adapter(cap_nested_adapter(), json)$ok)

  if (requireNamespace("xml2", quietly = TRUE)) {
    document <- xml2::read_xml("<root><branch><leaf/></branch></root>")
    expect_true(cap_test_adapter(cap_nested_adapter(), document)$ok)
  }
  expect_identical(state$calls, 0L)
})

test_that("array adapter rejects rank before traversing unbounded axes", {
  high_rank <- array(1L, dim = rep(1L, 65L))
  expect_error(
    cap_digest(high_rank, adapter = cap_array_adapter()),
    class = "capr_adapter_invalid"
  )
})
