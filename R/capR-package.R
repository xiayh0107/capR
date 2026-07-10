#' capR: an R-hosted CAP-Digest runtime
#'
#' capR resolves an R object to one adapter and then runs a deterministic,
#' policy-bounded digest pipeline. Adapter compatibility is distinct from CAP
#' conformance; the latter is always versioned and fixture-scoped.
#'
#' @keywords internal
"_PACKAGE"

.capr_version <- function() {
  version <- tryCatch(
    as.character(utils::packageVersion("capR")),
    error = function(e) "1.0.1.9000"
  )
  parts <- strsplit(version, ".", fixed = TRUE)[[1L]]
  if (length(parts) > 3L) {
    paste0(paste(parts[seq_len(3L)], collapse = "."), "-dev.", paste(parts[-seq_len(3L)], collapse = "."))
  } else {
    version
  }
}
