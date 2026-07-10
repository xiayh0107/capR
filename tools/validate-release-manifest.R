#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
allow_untracked <- "--allow-untracked" %in% args
paths <- args[!startsWith(args, "--")]
if (length(paths) != 1L) {
  stop(
    "usage: Rscript tools/validate-release-manifest.R [--allow-untracked] DIR",
    call. = FALSE
  )
}
root <- normalizePath(paths[[1L]], mustWork = TRUE)
manifest_path <- file.path(root, "MANIFEST.json")
if (!file.exists(manifest_path)) {
  stop("release MANIFEST.json is missing", call. = FALSE)
}
manifest <- jsonlite::fromJSON(
  manifest_path,
  simplifyVector = FALSE
)
if (!identical(manifest$schema, "capr.release_manifest.v1") ||
    !is.list(manifest$files)) {
  stop("release manifest schema is invalid", call. = FALSE)
}
expected <- vapply(
  manifest$files, `[[`, character(1), "path"
)
actual <- list.files(
  root,
  recursive = TRUE,
  all.files = TRUE,
  include.dirs = FALSE,
  no.. = TRUE
)
actual <- setdiff(actual, "MANIFEST.json")
problems <- character()
for (missing in setdiff(expected, actual)) {
  problems <- c(problems, paste0("missing:", missing))
}
for (extra in setdiff(actual, expected)) {
  problems <- c(problems, paste0("unexpected:", extra))
}
for (entry in manifest$files) {
  path <- file.path(root, entry$path)
  if (!file.exists(path)) next
  bytes <- unname(file.info(path)$size)
  checksum <- digest::digest(path, algo = "sha256", file = TRUE)
  if (!identical(as.numeric(bytes), as.numeric(entry$bytes))) {
    problems <- c(problems, paste0("size:", entry$path))
  }
  if (!identical(checksum, entry$sha256)) {
    problems <- c(problems, paste0("sha256:", entry$path))
  }
}
required <- c(
  "README.md",
  "MANIFEST.md",
  sprintf("package/capR_%s.tar.gz", manifest$caprVersion),
  "reports/capr-digest-conformance.json",
  "reports/capr-schema-harness.json",
  "reports/capr-interop-primary.json",
  "reports/capr-interop-structural.json",
  "reports/capr-interop-comparison.json",
  "fixture-summary/summary.json",
  "metadata/DESCRIPTION",
  "metadata/RELEASE.json",
  "metadata/environment.json",
  "metadata/sessionInfo.txt",
  "metadata/R-CMD-check.log"
)
for (missing in setdiff(required, expected)) {
  problems <- c(problems, paste0("required:", missing))
}
description <- read.dcf(file.path(root, "metadata", "DESCRIPTION"))
if (!identical(unname(description[1L, "Version"]), manifest$caprVersion)) {
  problems <- c(problems, "version:DESCRIPTION")
}
comparison <- jsonlite::fromJSON(
  file.path(root, "reports", "capr-interop-comparison.json"),
  simplifyVector = FALSE
)
conformance <- jsonlite::fromJSON(
  file.path(root, "reports", "capr-digest-conformance.json"),
  simplifyVector = FALSE
)
schema_report <- jsonlite::fromJSON(
  file.path(root, "reports", "capr-schema-harness.json"),
  simplifyVector = FALSE
)
if (!isTRUE(comparison$ok)) problems <- c(problems, "report:interop")
if (!isTRUE(conformance$ok)) problems <- c(problems, "report:conformance")
if (!isTRUE(schema_report$ok)) problems <- c(problems, "report:schema")

if (!allow_untracked) {
  repository <- normalizePath(
    file.path(root, "..", ".."),
    mustWork = TRUE
  )
  relative_root <- substring(
    root, nchar(repository) + 2L
  )
  tracked <- system2(
    "git",
    c("-C", shQuote(repository), "ls-files", shQuote(relative_root)),
    stdout = TRUE,
    stderr = FALSE
  )
  tracked_relative <- sub(
    paste0("^", gsub(
      "([][{}()+*^$|\\?.])", "\\\\\1", relative_root
    ), "/"),
    "",
    tracked
  )
  for (untracked in setdiff(
    c("MANIFEST.json", expected), tracked_relative
  )) {
    problems <- c(problems, paste0("untracked:", untracked))
  }
}
if (length(problems)) {
  message("Release manifest validation failed:")
  message(paste0("  ", unique(problems), collapse = "\n"))
  quit(status = 1L)
}
message(sprintf(
  "Release manifest validation passed: %s (%d files)",
  manifest$release,
  length(expected)
))

