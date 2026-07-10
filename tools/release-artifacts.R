#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) {
  stop(
    "usage: Rscript tools/release-artifacts.R capR-vX.Y.Z[-rcN]",
    call. = FALSE
  )
}
release <- args[[1L]]
if (!grepl("^capR-v[0-9]+\\.[0-9]+\\.[0-9]+(?:-rc[0-9]+)?$", release)) {
  stop("invalid release label", call. = FALSE)
}

root <- normalizePath(".", mustWork = TRUE)
description <- read.dcf(file.path(root, "DESCRIPTION"))
version <- unname(description[1L, "Version"])
expected_base <- sub("^capR-v([0-9]+\\.[0-9]+\\.[0-9]+).*$", "\\1", release)
if (!startsWith(version, expected_base)) {
  stop(sprintf(
    "DESCRIPTION version %s does not match release %s",
    version, release
  ), call. = FALSE)
}
if (!grepl("-rc[0-9]+$", release) && !identical(version, expected_base)) {
  stop("stable release requires the exact stable DESCRIPTION version", call. = FALSE)
}

run <- function(command, arguments, stdout = TRUE, stderr = TRUE,
                env = character()) {
  result <- system2(
    command,
    arguments,
    stdout = stdout,
    stderr = stderr,
    env = env
  )
  status <- attr(result, "status") %||% 0L
  if (status != 0L) {
    output <- if (is.character(result)) paste(result, collapse = "\n") else ""
    stop(sprintf("%s failed (%d)\n%s", command, status, output), call. = FALSE)
  }
  result
}
`%||%` <- function(x, y) if (is.null(x)) y else x
r_string <- function(x) encodeString(x, quote = '"')

dirty <- run(
  "git",
  c("status", "--porcelain", "--untracked-files=all"),
  stderr = FALSE
)
if (length(dirty)) {
  stop(
    "release artifacts must be generated from a clean worktree",
    call. = FALSE
  )
}
source_revision <- trimws(run(
  "git", c("rev-parse", "HEAD"), stderr = FALSE
)[[1L]])

workspace <- tempfile("capr-release-")
dir.create(workspace, recursive = TRUE)
on.exit(unlink(workspace, recursive = TRUE, force = TRUE), add = TRUE)
stage <- file.path(workspace, release)
dir.create(stage)
for (directory in c(
  "package", "reports", "fixture-summary", "metadata"
)) {
  dir.create(file.path(stage, directory))
}

build_root <- file.path(workspace, "build")
dir.create(build_root)
old <- setwd(build_root)
on.exit(setwd(old), add = TRUE)
build_output <- run(
  file.path(R.home("bin"), "R"),
  c("CMD", "build", shQuote(root))
)
setwd(old)
archive_source <- file.path(build_root, sprintf("capR_%s.tar.gz", version))
if (!file.exists(archive_source)) {
  stop("R CMD build did not produce the expected archive", call. = FALSE)
}
archive <- file.path(stage, "package", basename(archive_source))
file.copy(archive_source, archive, copy.mode = TRUE)

check_log <- file.path(stage, "metadata", "R-CMD-check.log")
old <- setwd(build_root)
run(
  file.path(R.home("bin"), "R"),
  c("CMD", "check", "--no-manual", shQuote(archive_source)),
  stdout = check_log,
  stderr = check_log,
  env = "_R_CHECK_CRAN_INCOMING_=FALSE"
)
setwd(old)

library_root <- file.path(workspace, "library")
dir.create(library_root)
run(
  file.path(R.home("bin"), "R"),
  c(
    "CMD", "INSTALL",
    paste0("--library=", shQuote(library_root)),
    shQuote(archive_source)
  )
)
driver <- file.path(workspace, "release-driver.R")
conformance_path <- file.path(
  stage, "reports", "capr-digest-conformance.json"
)
session_path <- file.path(stage, "metadata", "sessionInfo.txt")
writeLines(c(
  sprintf(".libPaths(c(%s, .libPaths()))", r_string(library_root)),
  "library(capR)",
  sprintf(
    "report <- cap_run_fixtures(report = %s)",
    r_string(conformance_path)
  ),
  "if (!report$ok) quit(status = 1L)",
  sprintf(
    "writeLines(capture.output(sessionInfo()), %s, useBytes = TRUE)",
    r_string(session_path)
  )
), driver, useBytes = TRUE)
run(file.path(R.home("bin"), "Rscript"), shQuote(driver))

canonical_root <- file.path(workspace, "canonical-artifacts")
run(
  file.path(R.home("bin"), "Rscript"),
  c(
    shQuote(file.path(root, "tools", "generate-fixture-artifacts.R")),
    shQuote(canonical_root)
  ),
  env = sprintf("R_LIBS_USER=%s", library_root)
)
python <- Sys.which("python3")
if (!nzchar(python)) {
  stop("python3 is required by the release schema and interop gates", call. = FALSE)
}
schema_report <- file.path(stage, "reports", "capr-schema-harness.json")
run(
  python,
  c(
    shQuote(file.path(root, "tools", "schema-harness", "validate.py")),
    "--vendor-root", shQuote(file.path(
      root, "inst", "extdata", "cap-digest", "v1.0.0"
    )),
    "--artifacts", shQuote(canonical_root),
    "--report", shQuote(schema_report)
  )
)
interop_root <- file.path(workspace, "interop")
run(
  python,
  c(
    shQuote(file.path(root, "tools", "interop-harness", "interop.py")),
    "--artifact-root", shQuote(canonical_root),
    "--vendor-root", shQuote(file.path(
      root, "inst", "extdata", "cap-digest", "v1.0.0"
    )),
    "--output-dir", shQuote(interop_root)
  )
)
interop_files <- c(
  "capr-interop-primary.json",
  "capr-interop-structural.json",
  "capr-interop-comparison.json"
)
for (filename in interop_files) {
  file.copy(
    file.path(interop_root, filename),
    file.path(stage, "reports", filename),
    copy.mode = TRUE
  )
}

conformance <- jsonlite::fromJSON(
  conformance_path, simplifyVector = FALSE
)
fixture_summary <- list(
  schema = "capr.fixture_summary.v1",
  release = release,
  caprVersion = version,
  capDigest = list(
    version = "1.0.0",
    tag = "cap-digest-v1.0.0",
    commit = "d7890d4449107a88faed0e0c653d3751b57575f2"
  ),
  claimedLevel = 3L,
  sourceFamily = "table",
  checks = conformance$checks
)
writeLines(
  as.character(jsonlite::toJSON(
    fixture_summary,
    auto_unbox = TRUE,
    null = "null",
    pretty = TRUE,
    digits = NA
  )),
  file.path(stage, "fixture-summary", "summary.json"),
  useBytes = TRUE
)
file.copy(
  file.path(root, "DESCRIPTION"),
  file.path(stage, "metadata", "DESCRIPTION"),
  copy.mode = TRUE
)
python_version <- trimws(run(
  python, "--version", stderr = TRUE
)[[1L]])
environment <- list(
  schema = "capr.release_environment.v1",
  r = R.version.string,
  platform = R.version$platform,
  python = python_version,
  schemaValidator = "python-jsonschema 4.26.0 / Draft 2020-12"
)
writeLines(
  as.character(jsonlite::toJSON(
    environment,
    auto_unbox = TRUE,
    pretty = TRUE
  )),
  file.path(stage, "metadata", "environment.json"),
  useBytes = TRUE
)
release_metadata <- list(
  schema = "capr.release_metadata.v1",
  release = release,
  caprVersion = version,
  status = if (grepl("-rc", release)) "release-candidate" else "stable",
  sourceRevision = source_revision,
  capDigest = list(
    version = "1.0.0",
    tag = "cap-digest-v1.0.0",
    commit = "d7890d4449107a88faed0e0c653d3751b57575f2"
  ),
  claimedLevel = 3L,
  fixtureScope = list(
    "basic-table", "digest-text-negative", "security-adversarial",
    "followup-basic", "pack-table-basic"
  ),
  sourceFamily = "table",
  stableHostAdapters = list("data.frame", "tbl_df", "data.table"),
  unsupported = list(
    "remote or credentialed extraction",
    "CAP-Core runtime or object semantics",
    "arbitrary R object conformance",
    "scientific or statistical correctness guarantees"
  ),
  generationCommand = sprintf(
    "Rscript tools/release-artifacts.R %s", release
  )
)
writeLines(
  as.character(jsonlite::toJSON(
    release_metadata,
    auto_unbox = TRUE,
    null = "null",
    pretty = TRUE
  )),
  file.path(stage, "metadata", "RELEASE.json"),
  useBytes = TRUE
)

readme <- sprintf(
  paste(
    "# %s release evidence",
    "",
    "capR %s implements CAP-Digest v1.0.0 L0-L3 for the published v1.0",
    "fixture suite and the table source family. Stable host adapters are",
    "data.frame, tbl_df, and data.table; they share one table pipeline.",
    "",
    "This claim does not cover remote or credentialed extraction, CAP-Core",
    "semantics, arbitrary R objects, or scientific/statistical correctness.",
    "Community, experimental, and structural fallback adapters do not inherit",
    "the stable table conformance claim.",
    "",
    "Reports are under reports/, fixture evidence under fixture-summary/,",
    "the installable source package under package/, and tool/environment",
    "provenance under metadata/.",
    sep = "\n"
  ),
  release,
  version
)
writeLines(readme, file.path(stage, "README.md"), useBytes = TRUE)

files_before_manifest <- list.files(
  stage,
  recursive = TRUE,
  all.files = TRUE,
  full.names = TRUE,
  include.dirs = FALSE,
  no.. = TRUE
)
relative_before <- substring(
  files_before_manifest, nchar(stage) + 2L
)
order_before <- order(relative_before, method = "radix")
files_before_manifest <- files_before_manifest[order_before]
relative_before <- relative_before[order_before]
manifest_md <- c(
  sprintf("# %s manifest", release),
  "",
  sprintf("- capR version: %s", version),
  sprintf("- Source revision: %s", source_revision),
  "- CAP-Digest: cap-digest-v1.0.0 @ d7890d4449107a88faed0e0c653d3751b57575f2",
  "- Hash: SHA-256",
  "",
  "| Path | Bytes | SHA-256 |",
  "|---|---:|---|"
)
for (index in seq_along(files_before_manifest)) {
  manifest_md <- c(
    manifest_md,
    sprintf(
      "| %s | %d | %s |",
      relative_before[[index]],
      file.info(files_before_manifest[[index]])$size,
      digest::digest(
        files_before_manifest[[index]],
        algo = "sha256",
        file = TRUE
      )
    )
  )
}
writeLines(
  manifest_md,
  file.path(stage, "MANIFEST.md"),
  useBytes = TRUE
)

manifest_files <- list.files(
  stage,
  recursive = TRUE,
  all.files = TRUE,
  full.names = TRUE,
  include.dirs = FALSE,
  no.. = TRUE
)
manifest_files <- manifest_files[
  basename(manifest_files) != "MANIFEST.json"
]
manifest_relative <- substring(
  manifest_files, nchar(stage) + 2L
)
manifest_order <- order(manifest_relative, method = "radix")
manifest_files <- manifest_files[manifest_order]
manifest_relative <- manifest_relative[manifest_order]
entries <- lapply(seq_along(manifest_files), function(index) {
  list(
    path = manifest_relative[[index]],
    bytes = unname(file.info(manifest_files[[index]])$size),
    sha256 = digest::digest(
      manifest_files[[index]], algo = "sha256", file = TRUE
    )
  )
})
manifest <- list(
  schema = "capr.release_manifest.v1",
  release = release,
  caprVersion = version,
  sourceRevision = source_revision,
  capDigestTag = "cap-digest-v1.0.0",
  capDigestCommit = "d7890d4449107a88faed0e0c653d3751b57575f2",
  hashAlgorithm = "sha256",
  generationCommand = sprintf(
    "Rscript tools/release-artifacts.R %s", release
  ),
  files = entries
)
writeLines(
  as.character(jsonlite::toJSON(
    manifest,
    auto_unbox = TRUE,
    pretty = TRUE,
    digits = NA
  )),
  file.path(stage, "MANIFEST.json"),
  useBytes = TRUE
)

output <- file.path(root, "release-artifacts", release)
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
backup <- NULL
if (dir.exists(output)) {
  backup <- tempfile(".release-backup-", tmpdir = dirname(output))
  if (!file.rename(output, backup)) {
    stop("could not stage existing release directory", call. = FALSE)
  }
}
if (!file.rename(stage, output)) {
  if (!is.null(backup)) file.rename(backup, output)
  stop("could not publish release artifact directory", call. = FALSE)
}
if (!is.null(backup)) unlink(backup, recursive = TRUE)
message(normalizePath(output, mustWork = TRUE))
