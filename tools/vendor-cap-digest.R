#!/usr/bin/env Rscript

tag <- "cap-digest-v1.0.0"
commit <- "d7890d4449107a88faed0e0c653d3751b57575f2"
repository <- "https://github.com/xiayh0107/cap-docs.git"
release_root <- "release-artifacts/cap-digest-v1.0.0"
destination <- file.path("inst", "extdata", "cap-digest", "v1.0.0")

args <- commandArgs(trailingOnly = TRUE)
source_arg <- grep("^--source=", args, value = TRUE)
source_repo <- if (length(source_arg)) sub("^--source=", "", source_arg[[1L]]) else NULL

run <- function(command, args) {
  status <- system2(command, args, stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(status, "status")) && attr(status, "status") != 0L) {
    stop(paste(status, collapse = "\n"), call. = FALSE)
  }
  status
}

workspace <- tempfile("cap-digest-vendor-")
dir.create(workspace, recursive = TRUE)
on.exit(unlink(workspace, recursive = TRUE, force = TRUE), add = TRUE)

if (is.null(source_repo)) {
  source_repo <- file.path(workspace, "cap-docs")
  run("git", c(
    "clone", "--quiet", "--filter=blob:none", "--no-checkout",
    repository, source_repo
  ))
}
source_repo <- normalizePath(source_repo, mustWork = TRUE)
actual_commit <- trimws(run("git", c(
  "-C", source_repo, "rev-parse", paste0(tag, "^{}")
)))
if (!identical(actual_commit, commit)) {
  stop(sprintf(
    "tag %s resolved to %s, expected %s",
    tag, actual_commit, commit
  ), call. = FALSE)
}

archive <- file.path(workspace, "source.tar")
run("git", c(
  "-C", source_repo, "archive", "--format=tar",
  paste0("--output=", archive), tag
))
extract_root <- file.path(workspace, "source")
dir.create(extract_root)
utils::untar(archive, exdir = extract_root)

upstream_root <- file.path(extract_root, release_root)
if (!dir.exists(upstream_root)) {
  stop("stable release root is missing from the pinned tag", call. = FALSE)
}

old_lock_path <- file.path(destination, "VENDOR-LOCK.json")
acquired_at <- format(Sys.Date(), "%Y-%m-%d")
if (file.exists(old_lock_path)) {
  old_lock <- tryCatch(
    jsonlite::fromJSON(old_lock_path, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (identical(old_lock$upstream$commit, commit) &&
      is.character(old_lock$acquiredAt)) {
    acquired_at <- old_lock$acquiredAt
  }
}

unlink(destination, recursive = TRUE, force = TRUE)
dir.create(destination, recursive = TRUE, showWarnings = FALSE)
release_files <- list.files(
  upstream_root,
  recursive = TRUE,
  all.files = TRUE,
  full.names = TRUE,
  include.dirs = FALSE,
  no.. = TRUE
)
relative <- substring(release_files, nchar(upstream_root) + 2L)
destination_relative <- relative
portable_names <- c(
  "fixtures/digest-text-negative/manifest-missing-selected-field.txt" =
    "fixtures/digest-text-negative/manifest-missing.txt",
  "specs/digest/reviews/2026-07-07-capp-0008-stable-entry-disposition.md" =
    "specs/digest/reviews/capp-0008-disposition.md",
  "specs/digest/reviews/2026-07-07-capp-0009-stable-release-decision.md" =
    "specs/digest/reviews/capp-0009-release.md"
)
matched <- match(relative, names(portable_names), nomatch = 0L)
destination_relative[matched > 0L] <- unname(portable_names[matched])
for (i in seq_along(release_files)) {
  target <- file.path(destination, destination_relative[[i]])
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(release_files[[i]], target, overwrite = TRUE, copy.mode = TRUE)) {
    stop(sprintf("could not vendor %s", relative[[i]]), call. = FALSE)
  }
}
source_by_destination <- stats::setNames(
  file.path(release_root, relative),
  destination_relative
)
license_source <- file.path(extract_root, "LICENSE")
if (!file.copy(
  license_source,
  file.path(destination, "UPSTREAM-LICENSE"),
  overwrite = TRUE,
  copy.mode = TRUE
)) {
  stop("could not vendor upstream license", call. = FALSE)
}
source_by_destination[["UPSTREAM-LICENSE"]] <- "LICENSE"

vendored_files <- list.files(
  destination,
  recursive = TRUE,
  all.files = TRUE,
  full.names = TRUE,
  include.dirs = FALSE,
  no.. = TRUE
)
vendored_relative <- substring(vendored_files, nchar(destination) + 2L)
order_index <- order(vendored_relative, method = "radix")
vendored_files <- vendored_files[order_index]
vendored_relative <- vendored_relative[order_index]
entries <- lapply(seq_along(vendored_files), function(i) {
  rel <- vendored_relative[[i]]
  source <- source_by_destination[[rel]]
  list(
    source = gsub("\\\\", "/", source),
    destination = gsub("\\\\", "/", rel),
    bytes = unname(file.info(vendored_files[[i]])$size),
    sha256 = digest::digest(vendored_files[[i]], algo = "sha256", file = TRUE)
  )
})
lock <- list(
  schema = "capr.vendor_lock.v1",
  upstream = list(
    repository = repository,
    tag = tag,
    commit = commit,
    releaseRoot = release_root,
    status = "stable"
  ),
  acquiredAt = acquired_at,
  fileCount = length(entries),
  files = entries
)
lock_path <- file.path(destination, "VENDOR-LOCK.json")
writeLines(
  enc2utf8(as.character(jsonlite::toJSON(
    lock,
    auto_unbox = TRUE,
    null = "null",
    pretty = TRUE,
    digits = NA
  ))),
  lock_path,
  useBytes = TRUE
)

message(sprintf(
  "Vendored %d pinned CAP-Digest files from %s (%s)",
  length(entries), tag, commit
))
