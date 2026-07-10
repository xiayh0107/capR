capr_response_input <- function(response) {
  if (is.list(response)) return(response)
  if (!is.character(response) || length(response) != 1L || is.na(response)) {
    capr_abort(
      "capr_artifact_invalid",
      "response must be an R list, JSON string, or JSON file"
    )
  }
  tryCatch(
    jsonlite::fromJSON(response, simplifyVector = FALSE),
    error = function(e) capr_abort(
      "capr_artifact_invalid",
      "contract response JSON is malformed",
      parent = e
    )
  )
}

capr_normalize_response <- function(response) {
  response <- capr_response_input(response)
  allowed <- c("claims", "evidence", "warnings", "requests")
  unknown <- setdiff(names(response), allowed)
  problems <- list()
  if (length(unknown)) {
    problems[[length(problems) + 1L]] <- list(
      code = "contract_response_invalid",
      message = "Contract response contains unsupported top-level properties.",
      fieldId = NULL,
      path = paste(unknown, collapse = ",")
    )
  }
  normalized <- list(
    claims = response$claims %||% list(),
    evidence = response$evidence %||% list(),
    warnings = response$warnings %||% list(),
    requests = response$requests %||% list()
  )
  if (!all(vapply(normalized, is.list, logical(1)))) {
    problems[[length(problems) + 1L]] <- list(
      code = "contract_response_invalid",
      message = "Claims, evidence, warnings, and requests must be arrays.",
      fieldId = NULL,
      path = NULL
    )
    return(list(response = normalized, problems = problems))
  }
  for (index in seq_along(normalized$claims)) {
    claim <- normalized$claims[[index]]
    if (!is.list(claim) ||
        !all(c("id", "text", "evidence") %in% names(claim)) ||
        !is.character(claim$id) || length(claim$id) != 1L ||
        !nzchar(claim$id) || !is.character(claim$text) ||
        length(claim$text) != 1L || !is.list(claim$evidence) ||
        !all(vapply(claim$evidence, is.character, logical(1)))) {
      problems[[length(problems) + 1L]] <- list(
        code = "contract_response_invalid",
        message = "Claim does not match cap.contract_response.v1.",
        fieldId = NULL,
        path = sprintf("claims[%d]", index - 1L)
      )
    }
  }
  if (!all(vapply(normalized$evidence, function(value) {
    is.character(value) && length(value) == 1L && !is.na(value)
  }, logical(1))) ||
      anyDuplicated(unlist(normalized$evidence, use.names = FALSE))) {
    problems[[length(problems) + 1L]] <- list(
      code = "contract_response_invalid",
      message = "Top-level evidence must contain unique field ID strings.",
      fieldId = NULL,
      path = "evidence"
    )
  }
  for (index in seq_along(normalized$requests)) {
    request <- normalized$requests[[index]]
    if (!is.list(request) ||
        !all(c("fieldId", "reason") %in% names(request)) ||
        !is.character(request$fieldId) || length(request$fieldId) != 1L ||
        !nzchar(request$fieldId) ||
        !is.character(request$reason) || length(request$reason) != 1L) {
      problems[[length(problems) + 1L]] <- list(
        code = "contract_response_invalid",
        message = "Request does not match cap.contract_response.v1.",
        fieldId = request$fieldId %||% NULL,
        path = sprintf("requests[%d]", index - 1L)
      )
    }
  }
  list(response = normalized, problems = problems)
}

capr_digest_components <- function(digest) {
  if (inherits(digest, "cap_digest")) {
    return(list(text = digest$text, manifest = digest$manifest))
  }
  if (is.list(digest) && is.character(digest$text) &&
      is.list(digest$manifest)) {
    return(digest[c("text", "manifest")])
  }
  capr_abort(
    "capr_artifact_invalid",
    "validation requires a cap_digest or text/manifest pair"
  )
}

#' Validate a CAP contract response
#'
#' @param digest Digest object or text/manifest pair.
#' @param response R list, JSON string, or JSON file.
#' @param policy Host policy.
#' @param ... Reserved.
#' @return A canonical `cap.validation_result.v1`.
#' @export
cap_validate_response <- function(digest, response,
                                  policy = cap_policy(), ...) {
  capr_validate_policy(policy)
  components <- capr_digest_components(digest)
  normalized <- capr_normalize_response(response)
  errors <- normalized$problems
  parsed <- tryCatch(
    cap_parse_digest_text(components$text),
    capr_text_invalid = function(e) e
  )
  if (inherits(parsed, "capr_text_invalid")) {
    errors[[length(errors) + 1L]] <- list(
      code = "digest_text_invalid",
      message = sprintf(
        "Digest text failed CAP-Digest text parsing: %s.",
        parsed$finding_code
      ),
      fieldId = NULL,
      path = NULL
    )
    text_ids <- character()
  } else {
    text_ids <- parsed$field_ids
  }
  rows <- components$manifest$fields
  ids <- vapply(rows, `[[`, character(1), "fieldId")
  names(rows) <- ids
  selected <- ids[vapply(
    rows, function(row) isTRUE(row$selected), logical(1)
  )]

  evidence <- unlist(
    normalized$response$evidence,
    use.names = FALSE
  )
  for (claim in normalized$response$claims) {
    if (is.list(claim) && is.list(claim$evidence)) {
      evidence <- c(
        evidence,
        unlist(claim$evidence, use.names = FALSE)
      )
    }
  }
  evidence <- capr_stable_sort(unique(enc2utf8(as.character(evidence))))
  for (field_id in evidence) {
    if (!field_id %in% ids) {
      errors[[length(errors) + 1L]] <- list(
        code = "evidence_unknown_field",
        message = "Evidence field is not present in DigestManifest.fields.",
        fieldId = field_id,
        path = "evidence"
      )
    } else if (!field_id %in% selected) {
      errors[[length(errors) + 1L]] <- list(
        code = "evidence_rejected_field",
        message = paste(
          "Evidence field is present in the manifest but was not",
          "selected into digest text."
        ),
        fieldId = field_id,
        path = "evidence"
      )
    } else if (!field_id %in% text_ids) {
      errors[[length(errors) + 1L]] <- list(
        code = "evidence_missing_from_text",
        message = paste(
          "Evidence field is selected in the manifest but missing",
          "from digest text."
        ),
        fieldId = field_id,
        path = "evidence"
      )
    }
  }
  requests <- normalized$response$requests
  for (index in seq_along(requests)) {
    field_id <- requests[[index]]$fieldId %||% ""
    if (nzchar(field_id) && !field_id %in% ids) {
      errors[[length(errors) + 1L]] <- list(
        code = "unknown_request_field",
        message = "Requested field is not present in DigestManifest.fields.",
        fieldId = field_id,
        path = sprintf("requests[%d].fieldId", index - 1L)
      )
    }
  }
  structure(
    list(
      schema = "cap.validation_result.v1",
      digestId = components$manifest$digestId,
      fingerprint = components$manifest$fingerprint,
      ok = !length(errors),
      errors = errors,
      warnings = list(),
      normalizedResponse = normalized$response
    ),
    class = c("cap_validation_result", "list")
  )
}
