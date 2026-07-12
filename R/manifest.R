capr_render_method <- function(field_id, field) {
  stable <- c(
    "f1:table@shape#base" = "table_shape_base_v1",
    "f1:table@columns#compact" = "table_columns_compact_v1",
    "f1:table@sample#k10" = "table_sample_k10_v1"
  )
  if (field_id %in% names(stable)) {
    return(unname(stable[[field_id]]))
  }
  field$contracts$renderer %||% NULL
}

capr_manifest_candidate <- function(plan, field_id) {
  candidates <- Filter(
    function(candidate) identical(candidate$field$id, field_id),
    plan$candidates
  )
  selected <- Filter(function(candidate) candidate$selected, candidates)
  if (length(selected)) return(selected[[1L]])
  candidates[[order(
    -vapply(candidates, `[[`, numeric(1), "score"),
    -vapply(candidates, `[[`, integer(1), "level"),
    method = "radix"
  )[[1L]]]]
}

#' Build a CAP-Digest manifest
#'
#' @param digest_id Digest identifier.
#' @param source_ref Source reference.
#' @param fingerprint Fingerprint string.
#' @param catalog Field catalog.
#' @param plan Selection plan.
#' @param materialization Materialization outcomes.
#' @param rendered Render result.
#' @return A `cap.manifest.v1` list.
#' @keywords internal
cap_build_manifest <- function(digest_id, source_ref, fingerprint, catalog,
                               plan, materialization, rendered) {
  cap_validate_field_catalog(catalog)
  rows <- lapply(catalog$fields, function(field) {
    candidate <- capr_manifest_candidate(plan, field$id)
    outcome <- materialization$outcomes[[field$id]]
    failed <- candidate$selected &&
      (is.null(outcome) || !isTRUE(outcome$ok))
    selected <- candidate$selected && !failed
    list(
      fieldId = field$id,
      fieldLabel = field$label,
      sourceType = source_ref$sourceType,
      timing = field$timing,
      trust = field$trust,
      exec = field$exec,
      level = candidate$level,
      selected = selected,
      rejectedReason = if (failed) {
        "field_validation_failed"
      } else {
        candidate$rejected_reason
      },
      estimatedCost = candidate$estimated_cost,
      actualCost = if (selected) outcome$actual_cost else 0L,
      priorValue = candidate$prior_value,
      renderMethod = if (candidate$selected) {
        capr_render_method(field$id, field)
      } else {
        NULL
      },
      redacted = if (selected) isTRUE(outcome$redacted) else FALSE,
      ok = if (failed) FALSE else TRUE,
      warnings = if (selected) as.list(unname(outcome$warnings)) else list(),
      errorClass = if (failed) outcome$error_class else NULL,
      # Canonical evidence must not vary with scheduler or machine timing.
      # Runtime timing remains available in materialization outcomes.
      elapsedMs = 0L,
      fingerprint = fingerprint,
      tokenizer = rendered$tokenizer
    )
  })
  estimated <- sum(vapply(catalog$fields, function(field) {
    max(vapply(field$levels, `[[`, integer(1), "estimatedCost"))
  }, integer(1)))
  if (identical(catalog$catalogId, "org.capr.table.v1")) {
    estimated <- estimated + 16L
  }
  list(
    schema = "cap.manifest.v1",
    digestId = digest_id,
    source = list(
      uri = source_ref$uri,
      sourceType = source_ref$sourceType,
      label = source_ref$label
    ),
    versions = list(
      cap = "2026-07-05-draft",
      text = "v1",
      fields = "f1",
      manifest = "v1"
    ),
    budget = list(
      requested = plan$budget_requested,
      estimated = as.integer(estimated),
      used = rendered$used,
      tokenizer = rendered$tokenizer
    ),
    fingerprint = fingerprint,
    fields = rows
  )
}
