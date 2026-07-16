capr_count_pattern <- function(pattern, text) {
  match <- gregexpr(pattern, text, perl = TRUE)[[1L]]
  if (identical(match[[1L]], -1L)) 0L else length(match)
}

capr_text_abort <- function(code, message = code, field_id = NULL) {
  capr_abort(
    "capr_text_invalid",
    message,
    finding_code = code,
    field_id = field_id
  )
}

capr_validate_data_fences <- function(body, field_id) {
  tags <- regmatches(
    body,
    gregexpr("</?data>", body, perl = TRUE)
  )[[1L]]
  if (!length(tags) || identical(tags[[1L]], character(0)) ||
      identical(tags[[1L]], "")) {
    return(invisible(TRUE))
  }
  open <- FALSE
  for (tag in tags) {
    if (identical(tag, "<data>")) {
      if (open) {
        capr_text_abort(
          "text_nested_data",
          "digest text contains nested data fences",
          field_id
        )
      }
      open <- TRUE
    } else {
      if (!open) {
        capr_text_abort(
          "text_unopened_data",
          "digest text closes an unopened data fence",
          field_id
        )
      }
      open <- FALSE
    }
  }
  if (open) {
    capr_text_abort(
      "text_unclosed_data",
      "digest text contains an unclosed data fence",
      field_id
    )
  }
  invisible(TRUE)
}

#' Parse CAP-Digest text=v1
#'
#' @param text Digest text.
#' @return A strict parsed representation with evidence anchors.
#' @export
cap_parse_digest_text <- function(text) {
  text <- capr_assert_scalar_character(
    text, "text", condition = "capr_text_invalid"
  )
  lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  if (!length(lines) ||
      !startsWith(lines[[1L]], "cap digest text=v1 fields=f1 ")) {
    capr_text_abort(
      "text_unknown_version",
      "digest text has an unknown or missing version line"
    )
  }
  if (length(lines) < 2L || !startsWith(lines[[2L]], "# source:")) {
    capr_text_abort(
      "text_missing_source_line",
      "digest text is missing its source line"
    )
  }
  open_count <- capr_count_pattern("<field\\b", text)
  close_count <- capr_count_pattern("</field>", text)
  if (open_count != close_count) {
    capr_text_abort(
      "text_unclosed_field",
      "digest text contains an unclosed field block"
    )
  }
  pattern <- "(?s)<field\\s+([^>]+)>\\n(.*?)\\n</field>"
  locations <- gregexpr(pattern, text, perl = TRUE)[[1L]]
  blocks <- regmatches(text, list(locations))[[1L]]
  if (!length(blocks)) {
    capr_text_abort(
      "text_no_field_blocks",
      "digest text contains no normal field blocks"
    )
  }
  captures <- attr(locations, "capture.start")
  capture_lengths <- attr(locations, "capture.length")
  fields <- list()
  field_ids <- character()
  for (index in seq_along(blocks)) {
    attrs_text <- substr(
      text,
      captures[index, 1L],
      captures[index, 1L] + capture_lengths[index, 1L] - 1L
    )
    body <- substr(
      text,
      captures[index, 2L],
      captures[index, 2L] + capture_lengths[index, 2L] - 1L
    )
    attr_locations <- gregexpr(
      '([A-Za-z][A-Za-z0-9_]*)="([^"]*)"',
      attrs_text,
      perl = TRUE
    )[[1L]]
    attr_matches <- regmatches(attrs_text, list(attr_locations))[[1L]]
    attrs <- list()
    if (length(attr_matches)) {
      for (value in attr_matches) {
        key <- sub('^([A-Za-z][A-Za-z0-9_]*)=".*"$', "\\1", value)
        attr_value <- sub('^[A-Za-z][A-Za-z0-9_]*="([^"]*)"$', "\\1", value)
        attrs[[key]] <- attr_value
      }
    }
    field_id <- attrs$id
    if (is.null(field_id) || !nzchar(field_id)) {
      capr_text_abort(
        "text_field_missing_id",
        "field block is missing its id attribute"
      )
    }
    if (!grepl(.capr_field_id_pattern, field_id, perl = TRUE)) {
      capr_text_abort(
        "text_invalid_field_id",
        "field block has an invalid field ID",
        field_id
      )
    }
    if (field_id %in% field_ids) {
      capr_text_abort(
        "text_duplicate_field_id",
        "field ID appears more than once",
        field_id
      )
    }
    if (is.null(attrs$trust) || is.null(attrs$level)) {
      capr_text_abort(
        "text_field_missing_required_attr",
        "field block is missing trust or level",
        field_id
      )
    }
    if (grepl("<field\\b|</field>", body, perl = TRUE)) {
      capr_text_abort(
        "text_nested_field",
        "field blocks cannot be nested",
        field_id
      )
    }
    capr_validate_data_fences(body, field_id)
    field_ids <- c(field_ids, field_id)
    fields[[field_id]] <- list(attributes = attrs, body = body)
  }
  structure(
    list(
      schema = capr_schema("parsed_digest_text"),
      version_line = lines[[1L]],
      source_line = lines[[2L]],
      field_ids = unname(field_ids),
      fields = fields
    ),
    class = "capr_parsed_digest_text"
  )
}

#' Validate manifest/text evidence consistency
#'
#' @param parsed Parsed text or raw text.
#' @param manifest A `cap.manifest.v1` object.
#' @return Stable problem rows.
#' @export
cap_validate_manifest_text <- function(parsed, manifest) {
  if (is.character(parsed)) parsed <- cap_parse_digest_text(parsed)
  if (!inherits(parsed, "capr_parsed_digest_text") ||
      !is.list(manifest$fields)) {
    capr_abort(
      "capr_artifact_invalid",
      "manifest/text consistency requires parsed text and manifest rows"
    )
  }
  selected <- vapply(
    Filter(function(row) isTRUE(row$selected), manifest$fields),
    `[[`,
    character(1),
    "fieldId"
  )
  missing_text <- capr_stable_sort(setdiff(selected, parsed$field_ids))
  missing_manifest <- capr_stable_sort(setdiff(parsed$field_ids, selected))
  c(
    lapply(missing_text, function(field_id) {
      list(code = "evidence_missing_from_text", fieldId = field_id)
    }),
    lapply(missing_manifest, function(field_id) {
      list(code = "text_field_missing_from_manifest", fieldId = field_id)
    })
  )
}

#' Render deterministic CAP-Digest text
#'
#' @param source_ref Source reference.
#' @param fingerprint Fingerprint string.
#' @param plan Selection plan.
#' @param materialization Materialization outcomes.
#' @param tokenizer Tokenizer identity.
#' @return Rendered text metadata.
#' @keywords internal
cap_render_digest_text <- function(source_ref, fingerprint, plan,
                                   materialization,
                                   tokenizer = .capr_default_tokenizer_id) {
  outcomes <- materialization$outcomes
  used <- sum(vapply(
    Filter(function(outcome) isTRUE(outcome$ok), outcomes),
    `[[`,
    integer(1),
    "actual_cost"
  ))
  lines <- c(
    sprintf(
      "cap digest text=v1 fields=f1 fp=%s tokenizer=%s budget=%d/%d",
      capr_escape_data(fingerprint),
      capr_escape_data(tokenizer),
      used,
      plan$budget_requested
    ),
    sprintf(
      "# source: %s label=%s rows=%d cols=%d",
      capr_escape_data(source_ref$sourceType),
      capr_escape_data(source_ref$label %||% ""),
      source_ref$identity$rows %||% 0L,
      source_ref$identity$columns %||% 0L
    ),
    ""
  )
  caveats <- list()
  anchors <- character()
  for (candidate in plan$candidates) {
    if (!candidate$selected) next
    outcome <- outcomes[[candidate$field$id]]
    if (is.null(outcome) || !outcome$ok) {
      caveats[[length(caveats) + 1L]] <- list(
        code = "cap_caveat_field_failed",
        fieldId = candidate$field$id,
        message = sprintf(
          "field failed during %s",
          outcome$stage %||% "materialization"
        )
      )
      next
    }
    lines <- c(
      lines,
      sprintf(
        '<field id="%s" trust="%s" level="%d">',
        candidate$field$id,
        candidate$field$trust,
        candidate$level
      ),
      outcome$rendered,
      "</field>",
      ""
    )
    anchors <- c(anchors, candidate$field$id)
    caveats <- c(caveats, outcome$caveats)
  }
  lines <- c(lines, "<caveats>")
  for (caveat in caveats) {
    lines <- c(
      lines,
      sprintf(
        "- [%s] %s: %s",
        caveat$code,
        caveat$fieldId,
        capr_escape_data(caveat$message)
      )
    )
  }
  lines <- c(lines, "</caveats>", "", "<available_on_request>")
  for (candidate in plan$candidates) {
    if (!identical(candidate$field$timing, "interactive") ||
        candidate$selected) next
    lines <- c(
      lines,
      sprintf(
        "%s exec=%s level=%d estimated=%d",
        candidate$field$id,
        candidate$field$exec,
        candidate$level,
        candidate$estimated_cost
      )
    )
  }
  lines <- c(lines, "</available_on_request>", "")
  list(
    text = enc2utf8(paste(lines, collapse = "\n")),
    used = as.integer(used),
    caveats = caveats,
    anchors = unname(anchors),
    tokenizer = tokenizer
  )
}
