capr_atomic_write_text <- function(text, path) {
  temp <- tempfile(".capr-write-", tmpdir = dirname(path))
  on.exit(unlink(temp), add = TRUE)
  connection <- file(temp, open = "wb")
  tryCatch(
    writeChar(enc2utf8(text), connection, eos = NULL, useBytes = TRUE),
    finally = close(connection)
  )
  if (!file.rename(temp, path)) {
    capr_abort(
      "capr_artifact_invalid",
      "could not atomically publish artifact",
      path = path
    )
  }
  invisible(path)
}

capr_atomic_write_json <- function(value, path) {
  capr_atomic_write_text(
    capr_canonical_json(value, pretty = TRUE),
    path
  )
}

capr_validate_digest_artifact <- function(artifact) {
  required <- c(
    "schema", "id", "source", "text", "manifest",
    "budgetUsed", "budgetEstimated", "fingerprint", "caveats"
  )
  if (!is.list(artifact) ||
      !identical(artifact$schema, capr_schema("digest")) ||
      length(setdiff(required, names(artifact)))) {
    capr_abort(
      "capr_artifact_invalid",
      "invalid cap.digest.v1 artifact"
    )
  }
  if (!identical(artifact$manifest$schema, capr_schema("manifest"))) {
    capr_abort(
      "capr_artifact_invalid",
      "digest embeds an invalid manifest"
    )
  }
  invisible(artifact)
}

#' Write canonical CAP artifacts and capR sidecars
#'
#' @param x A capR artifact object.
#' @param dir Destination directory.
#' @param include_sidecars Whether implementation sidecars are written.
#' @param ... Reserved.
#' @return The normalized artifact directory, invisibly.
#' @export
cap_write_artifacts <- function(x, dir, include_sidecars = TRUE, ...) {
  dir <- path.expand(capr_assert_scalar_character(
    dir, "dir", condition = "capr_artifact_invalid"
  ))
  include_sidecars <- capr_assert_flag(
    include_sidecars, "include_sidecars", "capr_artifact_invalid"
  )
  parent <- dirname(dir)
  dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  stage <- tempfile(".capr-artifacts-", tmpdir = parent)
  dir.create(stage)
  published <- FALSE
  on.exit(if (!published) unlink(stage, recursive = TRUE), add = TRUE)

  if (inherits(x, "cap_digest")) {
    capr_validate_digest_artifact(x$artifact)
    capr_atomic_write_text(x$text, file.path(stage, "digest.txt"))
    capr_atomic_write_json(x$artifact, file.path(stage, "digest.json"))
    capr_atomic_write_json(x$manifest, file.path(stage, "manifest.json"))
    if (include_sidecars) {
      capr_atomic_write_json(
        unclass(x$provenance),
        file.path(stage, "resolution.capr.json")
      )
    }
  } else {
    schema <- x$schema %||% attr(x, "schema")
    filenames <- stats::setNames(
      c(
        "validation.json", "gate.json", "patch.json",
        "conformance-report.json", "pack-conformance-report.json"
      ),
      c(
        capr_schema("validation_result"), capr_schema("gate_result"),
        capr_schema("digest_patch"), capr_schema("conformance_report"),
        capr_schema("pack_conformance_report")
      )
    )
    if (is.null(schema) || !schema %in% names(filenames)) {
      capr_abort(
        "capr_artifact_invalid",
        "unsupported artifact class for writing"
      )
    }
    capr_atomic_write_json(
      unclass(x),
      file.path(stage, filenames[[schema]])
    )
  }

  backup <- NULL
  if (dir.exists(dir)) {
    backup <- tempfile(".capr-artifacts-backup-", tmpdir = parent)
    if (!file.rename(dir, backup)) {
      capr_abort(
        "capr_artifact_invalid",
        "could not stage replacement of artifact directory",
        dir = dir
      )
    }
  }
  if (!file.rename(stage, dir)) {
    if (!is.null(backup)) file.rename(backup, dir)
    capr_abort(
      "capr_artifact_invalid",
      "could not publish artifact directory",
      dir = dir
    )
  }
  published <- TRUE
  if (!is.null(backup)) unlink(backup, recursive = TRUE)
  invisible(normalizePath(dir, mustWork = TRUE))
}

capr_read_json <- function(path) {
  tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) capr_abort(
      "capr_artifact_invalid",
      "artifact JSON is malformed",
      path = path,
      parent = e
    )
  )
}

#' Read a canonical digest artifact set
#'
#' @param dir Artifact directory.
#' @param validate Whether structural and text/manifest checks run.
#' @param ... Reserved.
#' @return A reconstructed `cap_digest`.
#' @export
cap_read_artifacts <- function(dir, validate = TRUE, ...) {
  dir <- path.expand(capr_assert_scalar_character(
    dir, "dir", condition = "capr_artifact_invalid"
  ))
  validate <- capr_assert_flag(
    validate, "validate", "capr_artifact_invalid"
  )
  required <- file.path(dir, c("digest.txt", "digest.json", "manifest.json"))
  if (any(!file.exists(required))) {
    capr_abort(
      "capr_artifact_invalid",
      "artifact directory is incomplete",
      missing = basename(required[!file.exists(required)])
    )
  }
  text_connection <- file(required[[1L]], open = "rb")
  text <- tryCatch(
    readChar(
      text_connection,
      nchars = file.info(required[[1L]])$size,
      useBytes = TRUE
    ),
    finally = close(text_connection)
  )
  text <- enc2utf8(text)
  artifact <- capr_read_json(required[[2L]])
  manifest <- capr_read_json(required[[3L]])
  if (validate) {
    capr_validate_digest_artifact(artifact)
    if (!identical(
      capr_canonical_json(artifact$manifest),
      capr_canonical_json(manifest)
    )) {
      capr_abort(
        "capr_artifact_invalid",
        "standalone and embedded manifests differ"
      )
    }
    if (!identical(artifact$text, text)) {
      capr_abort(
        "capr_artifact_invalid",
        "standalone and embedded digest text differ"
      )
    }
    problems <- cap_validate_manifest_text(text, manifest)
    if (length(problems)) {
      capr_abort(
        "capr_artifact_invalid",
        "artifact manifest and text are inconsistent",
        problems = problems
      )
    }
  }
  sidecar_path <- file.path(dir, "resolution.capr.json")
  provenance <- if (file.exists(sidecar_path)) {
    structure(capr_read_json(sidecar_path), class = "capr_resolution_sidecar")
  } else {
    NULL
  }
  structure(
    list(
      artifact = artifact,
      text = text,
      manifest = manifest,
      source = artifact$source,
      fingerprint = artifact$fingerprint,
      catalog = NULL,
      plan = artifact$plan,
      materialization = NULL,
      caveats = artifact$caveats,
      provenance = provenance,
      adapter_pin = NULL,
      adapter = NULL,
      tokenizer = NULL,
      applied_patches = character()
    ),
    class = "cap_digest"
  )
}
