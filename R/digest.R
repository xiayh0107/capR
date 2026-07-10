capr_digest_id <- function(x, source_ref, fingerprint, context) {
  explicit <- context$digest_id %||%
    attr(x, "capr_digest_id", exact = TRUE)
  if (!is.null(explicit)) {
    return(capr_assert_scalar_character(
      explicit, "digest_id", condition = "capr_artifact_invalid"
    ))
  }
  paste0(
    "cap-digest-",
    substr(
      capr_sha256(paste(source_ref$uri, fingerprint, sep = "\n")),
      1L,
      16L
    )
  )
}

#' Build a CAP-Digest from an R object
#'
#' This is the single class-independent orchestration path. Object classes are
#' consulted only during adapter resolution.
#'
#' @param x Source object.
#' @param question Optional question used for deterministic intent adjustment.
#' @param budget Initial digest budget.
#' @param policy Host policy.
#' @param adapter Optional explicit adapter or adapter ID.
#' @param session Optional host session metadata.
#' @param registry Adapter registry.
#' @param ... Context such as `label`, `uri`, or fixture metadata.
#' @return A `cap_digest` object containing canonical artifacts and capR
#'   provenance separately.
#' @export
cap_digest <- function(x, question = NULL, budget = 800L,
                       policy = cap_policy(), adapter = NULL,
                       session = NULL, registry = cap_registry(), ...) {
  capr_validate_policy(policy)
  context <- list(...)
  context$question <- question
  context$session <- session
  context$sensitive_name_patterns <- context$sensitive_name_patterns %||%
    .capr_sensitive_name_patterns

  resolved <- cap_resolve_adapter(
    x,
    adapter = adapter,
    registry = registry,
    allow_fallback = policy$allow_fallback
  )
  pin <- cap_adapter_pin(resolved)
  source_ref <- resolved$lifecycle$source_ref(x, context)
  fingerprint_result <- resolved$lifecycle$fingerprint(x, context)
  if (!is.list(fingerprint_result) ||
      !isTRUE(fingerprint_result$available) ||
      is.null(fingerprint_result$value)) {
    if (policy$require_fingerprint_match) {
      capr_abort(
        "capr_artifact_invalid",
        "source cannot satisfy the required fingerprint policy",
        adapter_id = resolved$metadata$id
      )
    }
    fingerprint <- ""
  } else {
    fingerprint <- capr_assert_scalar_character(
      fingerprint_result$value,
      "fingerprint",
      condition = "capr_artifact_invalid"
    )
  }
  catalog <- resolved$lifecycle$field_catalog(x, context)
  cap_validate_field_catalog(catalog)
  plan <- cap_select_fields(
    catalog,
    budget = budget,
    question = question,
    policy = policy
  )
  materialization <- cap_materialize(
    plan,
    resolved,
    x,
    policy,
    context
  )
  rendered <- cap_render_digest_text(
    source_ref,
    fingerprint,
    plan,
    materialization,
    tokenizer = plan$tokenizer
  )
  digest_id <- capr_digest_id(x, source_ref, fingerprint, context)
  manifest <- cap_build_manifest(
    digest_id,
    source_ref,
    fingerprint,
    catalog,
    plan,
    materialization,
    rendered
  )
  consistency <- tryCatch(
    cap_validate_manifest_text(rendered$text, manifest),
    capr_text_invalid = function(e) list(list(
      code = e$finding_code,
      fieldId = e$field_id
    ))
  )
  if (length(consistency) && length(rendered$anchors)) {
    capr_abort(
      "capr_artifact_invalid",
      "rendered digest text and manifest are inconsistent",
      problems = consistency
    )
  }
  provenance <- cap_resolution_sidecar(
    resolved,
    fingerprint_result$algorithm %||% "unspecified"
  )
  artifact <- list(
    schema = "cap.digest.v1",
    id = digest_id,
    source = source_ref,
    text = rendered$text,
    manifest = manifest,
    budgetUsed = rendered$used,
    budgetEstimated = manifest$budget$estimated,
    fingerprint = fingerprint,
    caveats = rendered$caveats,
    plan = list(
      schema = plan$schema,
      planner = plan$planner,
      tokenizer = plan$tokenizer,
      budgetRequested = plan$budget_requested,
      budgetEstimatedSelected = plan$budget_estimated_selected,
      candidates = lapply(plan$candidates, function(candidate) {
        list(
          fieldId = candidate$field$id,
          level = candidate$level,
          selected = candidate$selected,
          rejectedReason = candidate$rejected_reason,
          estimatedCost = candidate$estimated_cost,
          priorValue = candidate$prior_value,
          intentAdjustment = candidate$intent_adjustment
        )
      })
    )
  )
  structure(
    list(
      artifact = artifact,
      text = rendered$text,
      manifest = manifest,
      source = source_ref,
      fingerprint = fingerprint,
      catalog = catalog,
      plan = plan,
      materialization = materialization,
      caveats = rendered$caveats,
      provenance = provenance,
      adapter_pin = pin,
      adapter = resolved,
      applied_patches = character()
    ),
    class = "cap_digest"
  )
}

#' @export
print.cap_digest <- function(x, ...) {
  cat(sprintf("<cap_digest %s>\n", x$manifest$digestId))
  cat(sprintf(
    "  source: %s (%s)\n",
    x$source$label %||% "",
    x$source$sourceType
  ))
  selected <- sum(vapply(
    x$manifest$fields,
    function(row) isTRUE(row$selected),
    logical(1)
  ))
  failed <- sum(vapply(
    x$manifest$fields,
    function(row) !isTRUE(row$ok),
    logical(1)
  ))
  cat(sprintf(
    "  fields: %d selected; %d failed; budget %d/%d\n",
    selected,
    failed,
    x$manifest$budget$used,
    x$manifest$budget$requested
  ))
  cat(sprintf("  fingerprint: %s\n", x$fingerprint))
  invisible(x)
}

#' @export
summary.cap_digest <- function(object, ...) {
  list(
    digest_id = object$manifest$digestId,
    source_type = object$source$sourceType,
    fingerprint = object$fingerprint,
    selected = vapply(
      Filter(function(row) isTRUE(row$selected), object$manifest$fields),
      `[[`,
      character(1),
      "fieldId"
    ),
    failed = vapply(
      Filter(function(row) !isTRUE(row$ok), object$manifest$fields),
      `[[`,
      character(1),
      "fieldId"
    ),
    budget = object$manifest$budget,
    caveats = object$caveats
  )
}
