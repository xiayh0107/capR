test_that("graph adapter is bounded and deterministic for igraph", {
  skip_if_not_installed("igraph")

  graph <- igraph::make_ring(4, directed = TRUE)
  graph <- igraph::set_vertex_attr(
    graph, "private_label", value = paste0("VERTEX_SECRET_", 1:4)
  )
  graph <- igraph::set_edge_attr(
    graph, "private_weight", value = c(911001, 911002, 911003, 911004)
  )
  hook <- function() stop("must not run")
  environment(hook) <- emptyenv()
  graph <- igraph::set_graph_attr(
    graph, "private_hook", value = hook
  )
  before <- serialize(graph, NULL)
  adapter <- cap_graph_adapter()

  expect_identical(adapter$metadata$conformance_claim, "none")
  expect_false(adapter$metadata$capabilities$topology_values_disclosed)
  expect_false(adapter$metadata$capabilities$labels_disclosed)
  expect_false(adapter$metadata$capabilities$materializes_payload)
  expect_true(cap_test_adapter(adapter, graph)$ok)

  first <- cap_digest(graph, budget = 800L, adapter = adapter)
  second <- cap_digest(graph, budget = 800L, adapter = adapter)
  payload <- capr_canonical_json(first$artifact)
  expect_match(payload, "private_label", fixed = TRUE)
  expect_match(payload, "private_weight", fixed = TRUE)
  expect_match(payload, "private_hook", fixed = TRUE)
  expect_false(grepl("VERTEX_SECRET_", payload, fixed = TRUE))
  expect_false(grepl("911001", payload, fixed = TRUE))
  expect_match(payload, "not inspected", fixed = TRUE)
  expect_identical(
    capr_canonical_json(first$artifact),
    capr_canonical_json(second$artifact)
  )
  expect_identical(serialize(graph, NULL), before)

  changed <- igraph::add_vertices(graph, 1L)
  expect_false(identical(
    first$fingerprint,
    cap_digest(changed, budget = 800L, adapter = adapter)$fingerprint
  ))
})

test_that("graph adapter supports tbl_graph without node or edge values", {
  skip_if_not_installed("igraph")
  skip_if_not_installed("tidygraph")
  skip_if_not_installed("dplyr")

  graph <- tidygraph::as_tbl_graph(igraph::make_ring(3))
  graph <- tidygraph::activate(graph, "nodes")
  graph <- dplyr::mutate(graph, secret_node = c("NODE_A", "NODE_B", "NODE_C"))
  digest <- cap_digest(graph, adapter = cap_graph_adapter(), budget = 800L)
  payload <- capr_canonical_json(digest$artifact)

  expect_match(payload, "tbl_graph", fixed = TRUE)
  expect_match(payload, "secret_node", fixed = TRUE)
  expect_false(grepl("NODE_A", payload, fixed = TRUE))
})

test_that("graph adapter counts phylo structure without tip labels", {
  skip_if_not_installed("ape")

  tree <- ape::read.tree(
    text = "((TIP_SECRET_A:1,TIP_SECRET_B:1):1,TIP_SECRET_C:2);"
  )
  adapter <- cap_graph_adapter()
  expect_true(cap_test_adapter(adapter, tree)$ok)
  digest <- cap_digest(tree, adapter = adapter, budget = 800L)
  payload <- capr_canonical_json(digest$artifact)
  overview <- digest$materialization$outcomes[[
    "f1:graph@overview#compact"
  ]]$value
  semantics <- digest$materialization$outcomes[[
    "f1:graph@semantics#compact"
  ]]$value

  expect_identical(semantics$tips, 3L)
  expect_identical(overview$edges, 4L)
  expect_false(grepl("TIP_SECRET_A", payload, fixed = TRUE))
  expect_match(payload, "tip labels", fixed = TRUE)
})

test_that("graph adapter ignores treedata paths and attached values", {
  skip_if_not_installed("ape")
  skip_if_not_installed("treeio")

  tree <- ape::read.tree(text = "((TIP_SECRET_A:1,b:1):1,c:2);")
  object <- treeio::as.treedata(tree)
  methods::slot(object, "file") <- "TREE_FILE_SECRET_/private/tree.nwk"
  digest <- cap_digest(
    object,
    adapter = cap_graph_adapter(),
    budget = 800L
  )
  payload <- capr_canonical_json(digest$artifact)

  expect_match(payload, "treedata", fixed = TRUE)
  expect_match(payload, "file", fixed = TRUE)
  expect_false(grepl("TREE_FILE_SECRET_", payload, fixed = TRUE))
  expect_false(grepl("TIP_SECRET_A", payload, fixed = TRUE))
})

test_that("graph adapter fails closed for class-only spoofs", {
  spoof <- structure(list(), class = "igraph")
  expect_error(
    cap_digest(spoof, adapter = cap_graph_adapter()),
    class = "capr_adapter_invalid"
  )
})

test_that("graph metadata strips host S3 methods before inspection", {
  skip_if_not_installed("ape")
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  trap <- function(...) {
    state$calls <- state$calls + 1L
    stop("tree method executed")
  }
  methods <- c(
    "[[.phylo", "names.phylo", "length.phylo",
    "[.capr_evil_graph_names", "length.capr_evil_graph_names"
  )
  previous <- lapply(methods, function(name) {
    get0(name, envir = .GlobalEnv, inherits = FALSE)
  })
  for (name in methods) assign(name, trap, envir = .GlobalEnv)
  on.exit({
    for (index in seq_along(methods)) {
      if (is.null(previous[[index]])) {
        rm(list = methods[[index]], envir = .GlobalEnv)
      } else {
        assign(methods[[index]], previous[[index]], envir = .GlobalEnv)
      }
    }
  }, add = TRUE)

  tree <- ape::read.tree(text = "(A:1,B:1);")
  attr(tree, "names") <- structure(
    attr(tree, "names"), class = "capr_evil_graph_names"
  )
  digest <- cap_digest(tree, adapter = cap_graph_adapter())
  expect_identical(state$calls, 0L)
  expect_identical(digest$source$sourceType, "graph")
})

test_that("scientific adapter exposes assay schema without cell values", {
  skip_if_not_installed("SummarizedExperiment")
  skip_if_not_installed("S4Vectors")

  counts <- matrix(c(987654321L, 2L, 3L, 4L), nrow = 2L)
  row_data <- S4Vectors::DataFrame(
    annotation = c("ROW_META_SECRET_A", "ROW_META_SECRET_B")
  )
  column_data <- S4Vectors::DataFrame(
    patient = c("COL_META_SECRET_A", "COL_META_SECRET_B")
  )
  hook <- function() stop("must not run")
  environment(hook) <- emptyenv()
  object <- SummarizedExperiment::SummarizedExperiment(
    assays = list(counts = counts),
    rowData = row_data,
    colData = column_data,
    metadata = list(hook = hook)
  )
  before <- serialize(object, NULL)
  adapter <- cap_scientific_adapter()

  expect_identical(adapter$metadata$conformance_claim, "none")
  expect_false(adapter$metadata$capabilities$assay_values_disclosed)
  expect_false(adapter$metadata$capabilities$identifiers_disclosed)
  expect_false(adapter$metadata$capabilities$materializes_assays)
  expect_true(cap_test_adapter(adapter, object)$ok)

  first <- cap_digest(object, adapter = adapter, budget = 800L)
  second <- cap_digest(object, adapter = adapter, budget = 800L)
  payload <- capr_canonical_json(first$artifact)
  structure_value <- first$materialization$outcomes[[
    "f1:scientific@structure#compact"
  ]]$value
  expect_identical(structure_value$assay_schema[[1L]]$name, "counts")
  expect_identical(
    unlist(
      structure_value$assay_schema[[1L]]$dimensions,
      use.names = FALSE
    ),
    c(2L, 2L)
  )
  expect_match(payload, "annotation", fixed = TRUE)
  expect_match(payload, "patient", fixed = TRUE)
  expect_false(grepl("987654321", payload, fixed = TRUE))
  expect_false(grepl("ROW_META_SECRET_A", payload, fixed = TRUE))
  expect_false(grepl("COL_META_SECRET_A", payload, fixed = TRUE))
  expect_match(payload, "not inspected", fixed = TRUE)
  expect_identical(
    capr_canonical_json(first$artifact),
    capr_canonical_json(second$artifact)
  )
  expect_identical(serialize(object, NULL), before)
})

test_that("scientific adapter supports SingleCellExperiment metadata", {
  skip_if_not_installed("SingleCellExperiment")

  object <- SingleCellExperiment::SingleCellExperiment(
    assays = list(counts = matrix(c(1L, 2L, 3L, 4L), nrow = 2L))
  )
  SingleCellExperiment::reducedDim(object, "PCA") <- matrix(
    c(919191, 2, 3, 4),
    nrow = 2L
  )
  digest <- cap_digest(
    object,
    adapter = cap_scientific_adapter(),
    budget = 800L
  )
  payload <- capr_canonical_json(digest$artifact)

  expect_match(payload, "SingleCellExperiment", fixed = TRUE)
  expect_match(payload, "reducedDims", fixed = TRUE)
  expect_false(grepl("919191", payload, fixed = TRUE))
})

test_that("scientific adapter supports RangedSummarizedExperiment metadata", {
  skip_if_not_installed("SummarizedExperiment")
  skip_if_not_installed("GenomicRanges")
  skip_if_not_installed("IRanges")

  ranges <- GenomicRanges::GRanges(
    seqnames = c("chr1", "chr2"),
    ranges = IRanges::IRanges(start = c(101L, 501L), width = 20L)
  )
  object <- SummarizedExperiment::SummarizedExperiment(
    assays = list(counts = matrix(1:4, nrow = 2L)),
    rowRanges = ranges
  )
  expect_s4_class(object, "RangedSummarizedExperiment")
  digest <- cap_digest(object, adapter = cap_scientific_adapter())
  expect_identical(digest$source$sourceType, "scientific")
  expect_true(cap_test_adapter(cap_scientific_adapter(), object)$ok)
})

test_that("scientific adapter does not read file-backed assay payloads", {
  skip_if_not_installed("HDF5Array")
  skip_if_not_installed("SummarizedExperiment")

  path <- tempfile(fileext = ".h5")
  on.exit(unlink(path), add = TRUE)
  assay <- HDF5Array::writeHDF5Array(
    matrix(c(616161L, 2L, 3L, 4L), nrow = 2L),
    filepath = path,
    name = "HDF5_DATASET_SECRET"
  )
  object <- SummarizedExperiment::SummarizedExperiment(
    assays = list(file_backed = assay)
  )
  unlink(path)

  digest <- cap_digest(
    object,
    adapter = cap_scientific_adapter(),
    budget = 800L
  )
  payload <- capr_canonical_json(digest$artifact)
  structure_value <- digest$materialization$outcomes[[
    "f1:scientific@structure#compact"
  ]]$value
  dimensions <- structure_value$assay_schema[[1L]]$dimensions

  expect_identical(unlist(dimensions, use.names = FALSE), c(2L, 2L))
  expect_false(grepl("616161", payload, fixed = TRUE))
  expect_false(grepl("HDF5_DATASET_SECRET", payload, fixed = TRUE))
  expect_false(grepl(path, payload, fixed = TRUE))
})

test_that("scientific adapter supports Seurat layers without values", {
  skip_if_not_installed("SeuratObject")
  skip_if_not_installed("Matrix")

  counts <- Matrix::sparseMatrix(
    i = c(1L, 2L, 1L, 2L),
    j = c(1L, 1L, 2L, 2L),
    x = c(818181, 5, 2, 3),
    dims = c(2L, 2L)
  )
  rownames(counts) <- c("feature-1", "feature-2")
  colnames(counts) <- c("cell-1", "cell-2")
  object <- SeuratObject::CreateSeuratObject(
    counts = counts,
    meta.data = data.frame(
      private_batch = c("SEURAT_META_SECRET_A", "SEURAT_META_SECRET_B"),
      row.names = colnames(counts)
    )
  )
  methods::slot(object, "misc") <- list(
    hook = function() stop("must not run"),
    secret = "SEURAT_MISC_SECRET"
  )
  adapter <- cap_scientific_adapter()
  expect_true(cap_test_adapter(adapter, object)$ok)
  digest <- cap_digest(object, adapter = adapter, budget = 800L)
  payload <- capr_canonical_json(digest$artifact)
  structure_value <- digest$materialization$outcomes[[
    "f1:scientific@structure#compact"
  ]]$value
  layer <- structure_value$assay_schema[[1L]]$layers[[1L]]

  expect_match(payload, "Seurat", fixed = TRUE)
  expect_match(payload, "private_batch", fixed = TRUE)
  expect_identical(unlist(layer$dimensions, use.names = FALSE), c(2L, 2L))
  expect_false(grepl("818181", payload, fixed = TRUE))
  expect_false(grepl("SEURAT_META_SECRET_A", payload, fixed = TRUE))
  expect_false(grepl("SEURAT_MISC_SECRET", payload, fixed = TRUE))
})

test_that("scientific adapter supports phyloseq component dimensions", {
  skip_if_not_installed("phyloseq")

  otu_values <- matrix(
    c(717171L, 2L, 3L, 4L),
    nrow = 2L,
    dimnames = list(c("taxon-1", "taxon-2"), c("sample-1", "sample-2"))
  )
  otu <- phyloseq::otu_table(
    otu_values,
    taxa_are_rows = TRUE
  )
  taxonomy <- phyloseq::tax_table(matrix(
    c("TAX_SECRET_A", "TAX_SECRET_B"),
    nrow = 2L,
    dimnames = list(c("taxon-1", "taxon-2"), "rank")
  ))
  object <- phyloseq::phyloseq(otu, taxonomy)
  adapter <- cap_scientific_adapter()
  expect_true(cap_test_adapter(adapter, object)$ok)
  digest <- cap_digest(object, adapter = adapter, budget = 800L)
  payload <- capr_canonical_json(digest$artifact)
  structure_value <- digest$materialization$outcomes[[
    "f1:scientific@structure#compact"
  ]]$value
  otu_schema <- Filter(
    function(component) identical(component$name, "otu_table"),
    structure_value$component_schema
  )[[1L]]

  expect_match(payload, "otu_table", fixed = TRUE)
  expect_identical(
    unlist(otu_schema$dimensions, use.names = FALSE),
    c(2L, 2L)
  )
  expect_false(grepl("717171", payload, fixed = TRUE))
  expect_false(grepl("TAX_SECRET_A", payload, fixed = TRUE))
})

test_that("scientific adapter fails closed for unsupported containers", {
  expect_null(capR:::capr_gs_dimension_vector(rep(1L, 65L)))
  unsupported <- structure(list(), class = "unsupported_scientific")
  expect_error(
    cap_digest(
      unsupported,
      adapter = cap_scientific_adapter()
    ),
    class = "capr_adapter_invalid"
  )
})
