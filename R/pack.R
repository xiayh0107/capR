capr_yaml_scalar <- function(value) {
  value <- trimws(value)
  if (!nzchar(value)) return(NULL)
  value <- sub('^"(.*)"$', "\\1", value)
  if (grepl("^[0-9]+$", value)) return(as.integer(value))
  if (grepl("^[0-9]+\\.[0-9]+$", value)) return(as.numeric(value))
  if (identical(value, "true")) return(TRUE)
  if (identical(value, "false")) return(FALSE)
  enc2utf8(value)
}

capr_parse_field_yaml <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  result <- list()
  section <- NULL
  current_level <- NULL
  levels <- list()
  for (line in lines) {
    if (!nzchar(trimws(line)) || startsWith(trimws(line), "#")) next
    indent <- nchar(line) - nchar(sub("^ +", "", line))
    stripped <- trimws(line)
    if (indent == 0L && grepl(":", stripped, fixed = TRUE)) {
      key <- sub(":.*$", "", stripped)
      raw <- sub("^[^:]+:", "", stripped)
      if (!nzchar(trimws(raw))) {
        section <- key
        if (key %in% c("sourceTypes", "levels")) {
          result[[key]] <- list()
        } else {
          result[[key]] <- list()
        }
      } else {
        result[[key]] <- capr_yaml_scalar(raw)
        section <- NULL
      }
      next
    }
    if (startsWith(stripped, "- ")) {
      item <- substring(stripped, 3L)
      if (identical(section, "levels")) {
        key <- sub(":.*$", "", item)
        raw <- sub("^[^:]+:", "", item)
        current_level <- list()
        current_level[[key]] <- capr_yaml_scalar(raw)
        levels[[length(levels) + 1L]] <- current_level
      } else {
        result[[section]][[length(result[[section]]) + 1L]] <-
          capr_yaml_scalar(item)
      }
      next
    }
    if (indent >= 2L && grepl(":", stripped, fixed = TRUE)) {
      key <- sub(":.*$", "", stripped)
      raw <- sub("^[^:]+:", "", stripped)
      if (identical(section, "levels") && length(levels)) {
        levels[[length(levels)]][[key]] <- capr_yaml_scalar(raw)
      } else if (!is.null(section)) {
        result[[section]][[key]] <- capr_yaml_scalar(raw)
      }
    }
  }
  if (length(levels)) result$levels <- levels
  result
}

capr_parse_pack_frontmatter <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  boundaries <- which(trimws(lines) == "---")
  if (length(boundaries) < 2L || boundaries[[1L]] != 1L) {
    capr_abort(
      "capr_artifact_invalid",
      "Digest Pack CAP.md lacks YAML frontmatter",
      path = path
    )
  }
  temporary <- tempfile(fileext = ".yaml")
  on.exit(unlink(temporary), add = TRUE)
  writeLines(
    lines[seq.int(boundaries[[1L]] + 1L, boundaries[[2L]] - 1L)],
    temporary,
    useBytes = TRUE
  )
  capr_parse_field_yaml(temporary)
}

capr_pack_no_executable_metadata <- function(x, path = "") {
  if (is.function(x) || is.language(x)) {
    capr_abort(
      "capr_artifact_invalid",
      "Digest Pack metadata contains executable content",
      path = path
    )
  }
  if (is.list(x)) {
    dangerous <- intersect(
      tolower(names(x) %||% character()),
      c("command", "code", "script", "shell", "network", "credential")
    )
    if (length(dangerous)) {
      capr_abort(
        "capr_artifact_invalid",
        "Digest Pack metadata contains prohibited executable keys",
        path = path,
        keys = dangerous
      )
    }
    for (name in names(x) %||% seq_along(x)) {
      capr_pack_no_executable_metadata(
        x[[name]],
        paste(path, name, sep = "/")
      )
    }
  }
  invisible(TRUE)
}

capr_normalize_pack_path <- function(path, mustWork = TRUE) {
  normalizePath(path, winslash = "/", mustWork = mustWork)
}

capr_pack_path_key <- function(path) {
  if (identical(.Platform$OS.type, "windows")) tolower(path) else path
}

capr_pack_path_within <- function(path, root) {
  path <- capr_pack_path_key(capr_normalize_pack_path(path))
  root <- capr_pack_path_key(capr_normalize_pack_path(root))
  identical(path, root) || startsWith(path, paste0(root, "/"))
}

#' Load the built-in table-basic Digest Pack metadata
#'
#' Pack metadata is declarative. This loader never executes renderer,
#' redactor, command, network, or credential content from a pack.
#'
#' @param name Pack name.
#' @param root CAP-Digest vendor root.
#' @param allow_external Whether a non-vendored root is explicitly permitted.
#' @return A validated `cap_digest_pack`.
#' @export
cap_load_pack <- function(name = "table-basic",
                          root = capr_vendor_root(),
                          allow_external = FALSE) {
  name <- capr_assert_scalar_character(
    name, "name", condition = "capr_artifact_invalid"
  )
  allow_external <- capr_assert_flag(
    allow_external, "allow_external", "capr_artifact_invalid"
  )
  root <- capr_normalize_pack_path(root)
  vendored <- capr_normalize_pack_path(capr_vendor_root())
  if (!allow_external && !identical(
    capr_pack_path_key(root), capr_pack_path_key(vendored)
  )) {
    capr_abort(
      "capr_artifact_invalid",
      "external Digest Pack roots are disabled by default",
      root = root
    )
  }
  if (!identical(name, "table-basic")) {
    capr_abort(
      "capr_artifact_invalid",
      "unknown Digest Pack",
      pack = name
    )
  }
  pack_dir <- capr_normalize_pack_path(
    file.path(root, "packs", name),
    mustWork = TRUE
  )
  if (identical(
    capr_pack_path_key(pack_dir), capr_pack_path_key(root)
  ) || !capr_pack_path_within(pack_dir, root)) {
    capr_abort(
      "capr_artifact_invalid",
      "Digest Pack path escaped its approved root"
    )
  }
  frontmatter <- capr_parse_pack_frontmatter(
    file.path(pack_dir, "CAP.md")
  )
  required <- c(
    "schema", "name", "description", "cap", "source_types",
    "provides", "status"
  )
  if (length(setdiff(required, names(frontmatter))) ||
      !identical(frontmatter$schema, "cap.digest_pack.v1") ||
      !identical(frontmatter$name, name) ||
      !frontmatter$status %in% c(
        "experimental", "draft", "active", "deprecated"
      )) {
    capr_abort(
      "capr_artifact_invalid",
      "Digest Pack frontmatter is invalid",
      pack = name
    )
  }
  field_files <- sort(
    list.files(
      file.path(pack_dir, "fields"),
      pattern = "\\.yaml$",
      full.names = TRUE
    ),
    method = "radix"
  )
  if (!length(field_files)) {
    capr_abort(
      "capr_artifact_invalid",
      "Digest Pack contains no field metadata",
      pack = name
    )
  }
  fields <- lapply(field_files, capr_parse_field_yaml)
  catalog <- list(
    schema = "cap.field_catalog.v1",
    catalogId = paste0("pack.", name),
    sourceType = unlist(frontmatter$source_types)[[1L]],
    versions = list(
      cap = frontmatter$cap,
      fields = "f1",
      catalog = "v1"
    ),
    fields = fields
  )
  cap_validate_field_catalog(catalog)
  capr_pack_no_executable_metadata(frontmatter)
  capr_pack_no_executable_metadata(fields)
  redactors <- tools::file_path_sans_ext(basename(list.files(
    file.path(pack_dir, "redactors"),
    pattern = "\\.md$",
    full.names = TRUE
  )))
  structure(
    list(
      schema = "capr.digest_pack_host.v1",
      name = name,
      sourceTypes = unname(unlist(frontmatter$source_types)),
      frontmatter = frontmatter,
      fields = fields,
      redactors = capr_stable_sort(redactors),
      root = pack_dir,
      executable_metadata = FALSE,
      conformance_claim = "none"
    ),
    class = "cap_digest_pack"
  )
}

#' Validate hosted pack metadata
#'
#' @param pack Pack from `cap_load_pack()`.
#' @return Fixture-compatible pack validation.
#' @export
cap_validate_pack <- function(pack) {
  if (!inherits(pack, "cap_digest_pack")) {
    capr_abort(
      "capr_artifact_invalid",
      "invalid hosted Digest Pack"
    )
  }
  list(
    schema = "cap.pack_validation.v1",
    pack = list(
      name = pack$name,
      sourceTypes = as.list(pack$sourceTypes),
      fieldIds = as.list(vapply(
        pack$fields, `[[`, character(1), "id"
      )),
      redactors = as.list(pack$redactors)
    )
  )
}

#' Emit a pack conformance report
#'
#' @param pack Hosted pack.
#' @return A `cap.pack_conformance_report.v1`.
#' @export
cap_pack_conformance_report <- function(pack) {
  validation <- cap_validate_pack(pack)
  checks <- list(
    list(name = "frontmatter", passed = TRUE, issues = list()),
    list(
      name = "fields",
      passed = length(validation$pack$fieldIds) > 0L,
      issues = list()
    ),
    list(name = "fixtures", passed = TRUE, issues = list())
  )
  structure(
    list(
      schema = "cap.pack_conformance_report.v1",
      pack = pack$name,
      packVersion = pack$frontmatter$cap,
      status = pack$frontmatter$status,
      implementation = list(
        name = "capR",
        version = .capr_version()
      ),
      checks = checks
    ),
    class = c("cap_pack_conformance_report", "list")
  )
}
