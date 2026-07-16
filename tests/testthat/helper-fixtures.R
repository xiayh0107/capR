cap_fixture_root <- function() {
  installed <- system.file(
    "extdata", "cap-digest", "v1.0.0", "fixtures",
    package = "capR"
  )
  if (nzchar(installed)) return(installed)
  source_test_path(
    "inst", "extdata", "cap-digest", "v1.0.0", "fixtures"
  )
}

source_test_path <- function(...) {
  parts <- c(...)
  candidates <- c(
    do.call(
      testthat::test_path,
      as.list(c("..", "..", parts))
    ),
    do.call(
      testthat::test_path,
      as.list(c("..", "..", "00_pkg_src", "capR", parts))
    )
  )
  existing <- candidates[file.exists(candidates)]
  if (!length(existing)) return(candidates[[1L]])
  normalizePath(existing[[1L]], mustWork = TRUE)
}

read_fixture_json <- function(...) {
  jsonlite::fromJSON(
    file.path(cap_fixture_root(), ...),
    simplifyVector = FALSE
  )
}

read_fixture_text <- function(...) {
  path <- file.path(cap_fixture_root(), ...)
  connection <- file(path, "rb")
  tryCatch(
    enc2utf8(readChar(
      connection,
      nchars = file.info(path)$size,
      useBytes = TRUE
    )),
    finally = close(connection)
  )
}

fixture_fingerprint <- function(family = "basic-table") {
  read_fixture_json(family, "policy.json")$fingerprint
}

fixture_table <- function(family = "basic-table") {
  source <- read_fixture_json(family, "source.json")
  columns <- lapply(source$columns, function(column) {
    examples <- unlist(column$examples, use.names = FALSE)
    values <- switch(
      column$type,
      dbl = as.numeric(examples),
      int = as.integer(examples),
      lgl = as.logical(examples),
      enc2utf8(as.character(examples))
    )
    length(values) <- source$rows
    values
  })
  names(columns) <- vapply(
    source$columns, `[[`, character(1), "name"
  )
  table <- as.data.frame(
    columns,
    check.names = FALSE,
    stringsAsFactors = FALSE,
    optional = TRUE
  )
  attr(table, "capr_label") <- source$label
  artifact_family <- if (identical(family, "followup-basic")) {
    "basic-table"
  } else {
    family
  }
  attr(table, "capr_uri") <- sprintf(
    "fixture://%s/source.json", artifact_family
  )
  if (!is.null(source$sampleRows)) {
    attr(table, "capr_fixture_sample_rows") <- source$sampleRows
  }
  attr(table, "capr_digest_id") <- if (family %in% c(
    "basic-table", "followup-basic"
  )) {
    "cap-digest-basic-table"
  } else {
    paste0("cap-digest-", family)
  }
  table
}
