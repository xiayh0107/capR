capr_vendor_root <- function() {
  installed <- system.file(
    "extdata", "cap-digest", "v1.0.0",
    package = "capR"
  )
  if (nzchar(installed)) return(installed)
  source <- file.path(
    "inst", "extdata", "cap-digest", "v1.0.0"
  )
  if (dir.exists(source)) return(normalizePath(source))
  capr_abort(
    "capr_artifact_invalid",
    "vendored CAP-Digest v1.0.0 resources are unavailable"
  )
}

#' Inspect the pinned CAP-Digest release
#'
#' @return Version, tag, commit, and fixture-scope metadata.
#' @export
cap_vendor_info <- function() {
  lock <- jsonlite::fromJSON(
    file.path(capr_vendor_root(), "VENDOR-LOCK.json"),
    simplifyVector = FALSE
  )
  list(
    version = "1.0.0",
    tag = lock$upstream$tag,
    commit = lock$upstream$commit,
    repository = lock$upstream$repository,
    status = lock$upstream$status,
    fixture_scope = c(
      "basic-table", "digest-text-negative", "followup-basic",
      "pack-table-basic", "security-adversarial"
    )
  )
}

#' Verify vendored file provenance and checksums
#'
#' @param root Vendor root, primarily for testing.
#' @return A verification report. Any mismatch fails closed.
#' @export
cap_verify_vendor <- function(root = capr_vendor_root()) {
  root <- normalizePath(root, mustWork = TRUE)
  lock_path <- file.path(root, "VENDOR-LOCK.json")
  if (!file.exists(lock_path)) {
    capr_abort(
      "capr_artifact_invalid",
      "vendor lock is missing",
      root = root
    )
  }
  lock <- tryCatch(
    jsonlite::fromJSON(lock_path, simplifyVector = FALSE),
    error = function(e) capr_abort(
      "capr_artifact_invalid",
      "vendor lock is malformed",
      parent = e
    )
  )
  if (!identical(lock$schema, "capr.vendor_lock.v1") ||
      !is.list(lock$files)) {
    capr_abort(
      "capr_artifact_invalid",
      "vendor lock schema is invalid"
    )
  }
  problems <- character()
  expected <- vapply(
    lock$files, `[[`, character(1), "destination"
  )
  for (entry in lock$files) {
    path <- file.path(root, entry$destination)
    if (!file.exists(path)) {
      problems <- c(
        problems,
        sprintf("missing:%s", entry$destination)
      )
      next
    }
    bytes <- unname(file.info(path)$size)
    checksum <- digest::digest(path, algo = "sha256", file = TRUE)
    if (!identical(as.numeric(bytes), as.numeric(entry$bytes))) {
      problems <- c(
        problems,
        sprintf("size:%s", entry$destination)
      )
    }
    if (!identical(checksum, entry$sha256)) {
      problems <- c(
        problems,
        sprintf("sha256:%s", entry$destination)
      )
    }
  }
  actual <- list.files(
    root,
    recursive = TRUE,
    all.files = TRUE,
    include.dirs = FALSE,
    no.. = TRUE
  )
  actual <- setdiff(actual, "VENDOR-LOCK.json")
  unexpected <- setdiff(actual, expected)
  if (length(unexpected)) {
    problems <- c(
      problems,
      paste0("unexpected:", unexpected)
    )
  }
  if (length(problems)) {
    capr_abort(
      "capr_artifact_invalid",
      "vendored CAP-Digest resources failed provenance verification",
      problems = unname(problems)
    )
  }
  structure(
    list(
      schema = "capr.vendor_verification.v1",
      ok = TRUE,
      tag = lock$upstream$tag,
      commit = lock$upstream$commit,
      files = length(expected)
    ),
    class = "capr_vendor_verification"
  )
}
