capr_patch_adapter <- function(digest, source, adapter, registry) {
  if (is.null(adapter)) {
    adapter <- digest$adapter
    if (is.null(adapter)) {
      capr_abort(
        "capr_adapter_pin_mismatch",
        "reloaded digest requires an explicit compatible adapter"
      )
    }
  } else if (!inherits(adapter, "capr_adapter")) {
    adapter <- cap_resolve_adapter(
      source, adapter = adapter, registry = registry
    )
  }
  cap_validate_adapter(adapter)
  if (!is.null(digest$adapter_pin)) {
    cap_check_adapter_pin(adapter, digest$adapter_pin)
  }
  adapter
}

capr_patch_manifest_row <- function(field, candidate, outcome,
                                    digest) {
  list(
    fieldId = field$id,
    fieldLabel = field$label,
    sourceType = digest$source$sourceType,
    timing = field$timing,
    trust = field$trust,
    exec = field$exec,
    level = candidate$level,
    selected = isTRUE(outcome$ok),
    rejectedReason = if (outcome$ok) NULL else "field_validation_failed",
    estimatedCost = candidate$estimated_cost,
    actualCost = if (outcome$ok) outcome$actual_cost else 0L,
    priorValue = candidate$prior_value,
    renderMethod = capr_render_method(field$id, field),
    redacted = if (outcome$ok) isTRUE(outcome$redacted) else FALSE,
    ok = isTRUE(outcome$ok),
    warnings = if (outcome$ok) {
      as.list(unname(outcome$warnings))
    } else {
      list()
    },
    errorClass = if (outcome$ok) NULL else outcome$error_class,
    # Canonical patch rows follow the same timing normalization as manifests.
    elapsedMs = 0L,
    fingerprint = digest$fingerprint,
    tokenizer = digest$manifest$budget$tokenizer
  )
}

#' Materialize an approved typed digest patch
#'
#' @param digest Base digest.
#' @param gate_result Gate decisions from `cap_gate()`.
#' @param source Current source object.
#' @param adapter Optional compatible adapter.
#' @param policy Host policy.
#' @param registry Adapter registry.
#' @param ... Runtime context.
#' @param tokenizer Optional tokenizer id or [cap_tokenizer()] object. It
#'   must match the digest's pinned accounting tokenizer; `NULL` reuses the
#'   digest's process-local tokenizer (or the built-in when the digest was
#'   built with `heuristic_v1`).
#' @return A canonical `cap.digest_patch.v1`.
#' @export
cap_patch <- function(digest, gate_result, source, adapter = NULL,
                      policy = cap_policy(), registry = cap_registry(),
                      ..., tokenizer = NULL) {
  if (!inherits(digest, "cap_digest") ||
      !inherits(gate_result, "cap_gate_result")) {
    capr_abort(
      "capr_artifact_invalid",
      "patch materialization requires a digest and gate result"
    )
  }
  manifest_tokenizer <- digest$manifest$budget$tokenizer
  if (!is.null(tokenizer)) {
    tokenizer <- capr_resolve_tokenizer(tokenizer)
    if (!identical(tokenizer$id, manifest_tokenizer)) {
      capr_abort(
        "capr_tokenizer_invalid",
        "tokenizer does not match the digest accounting pin",
        expected = manifest_tokenizer,
        actual = tokenizer$id
      )
    }
  } else if (!is.null(digest$tokenizer)) {
    tokenizer <- digest$tokenizer
    if (!identical(tokenizer$id, manifest_tokenizer)) {
      capr_abort(
        "capr_tokenizer_invalid",
        "digest process-local tokenizer does not match the accounting pin",
        expected = manifest_tokenizer,
        actual = tokenizer$id
      )
    }
  } else if (identical(manifest_tokenizer, .capr_default_tokenizer_id)) {
    tokenizer <- capr_builtin_tokenizer()
  } else {
    capr_abort(
      "capr_tokenizer_invalid",
      "digest accounting uses a non-default tokenizer; pass it explicitly",
      tokenizer_id = manifest_tokenizer
    )
  }
  if (!identical(gate_result$digestId, digest$manifest$digestId) ||
      !identical(gate_result$fingerprint, digest$fingerprint)) {
    capr_abort(
      "capr_artifact_invalid",
      "gate result does not belong to the base digest"
    )
  }
  approved <- Filter(
    function(decision) decision$decision %in%
      c("approved", "approved_with_changes"),
    gate_result$requests
  )
  if (!length(approved)) {
    capr_abort(
      "capr_artifact_invalid",
      "gate result contains no approved request"
    )
  }
  if (is.null(digest$catalog)) {
    capr_abort(
      "capr_artifact_invalid",
      "reloaded digest lacks the process-local field catalog"
    )
  }
  capr_validate_policy(policy)
  adapter <- capr_patch_adapter(digest, source, adapter, registry)
  context <- list(...)
  context$.capr_snapshot_cache <- capr_new_snapshot_cache(source, adapter)
  context$label <- context$label %||% digest$source$label
  context$uri <- context$uri %||% digest$source$uri
  context$sensitive_name_patterns <- context$sensitive_name_patterns %||%
    .capr_sensitive_name_patterns
  current <- adapter$lifecycle$fingerprint(source, context)
  if (!isTRUE(current$available) ||
      !identical(current$value, digest$fingerprint)) {
    capr_abort(
      "capr_adapter_pin_mismatch",
      "source fingerprint changed after gate approval",
      expected = digest$fingerprint,
      actual = current$value %||% NULL
    )
  }

  operations <- list()
  manifest_rows <- list()
  estimated_delta <- 0L
  used_delta <- 0L
  for (decision in approved) {
    field_id <- decision$request$fieldId
    existing <- Filter(
      function(row) identical(row$fieldId, field_id),
      digest$manifest$fields
    )
    if (!length(existing) || isTRUE(existing[[1L]]$selected)) {
      capr_abort(
        "capr_artifact_invalid",
        "approved request is unknown or already selected",
        field_id = field_id
      )
    }
    fields <- Filter(
      function(field) identical(field$id, field_id),
      digest$catalog$fields
    )
    if (!length(fields)) {
      capr_abort(
        "capr_artifact_invalid",
        "approved field is absent from the pinned catalog",
        field_id = field_id
      )
    }
    field <- fields[[1L]]
    levels <- Filter(
      function(level) identical(
        as.integer(level$level),
        as.integer(decision$approvedLevel)
      ),
      field$levels
    )
    if (!length(levels)) {
      capr_abort(
        "capr_artifact_invalid",
        "approved field level is absent from the pinned catalog",
        field_id = field_id
      )
    }
    candidate <- list(
      field = field,
      field_index = match(field_id, vapply(
        digest$catalog$fields, `[[`, character(1), "id"
      )),
      level = as.integer(levels[[1L]]$level),
      estimated_cost = as.integer(levels[[1L]]$estimatedCost),
      prior_value = field$selectionHints$priorValue %||% 0,
      intent_adjustment = 0,
      score = field$selectionHints$priorValue %||% 0,
      ratio = 0,
      authorization = cap_authorize_execution(policy, field$exec),
      selected = TRUE,
      rejected_reason = NULL
    )
    plan <- structure(
      list(
        schema = capr_schema("selection_plan"),
        catalog_id = digest$catalog$catalogId,
        budget_requested = as.integer(
          decision$approvedBudget %||% candidate$estimated_cost
        ),
        budget_estimated_selected = candidate$estimated_cost,
        planner = .capr_followup_planner_id,
        tokenizer = digest$manifest$budget$tokenizer,
        question = decision$request$reason,
        candidates = list(candidate)
      ),
      class = "capr_selection_plan"
    )
    materialization <- cap_materialize(
      plan, adapter, source, policy, context, tokenizer = tokenizer
    )
    outcome <- materialization$outcomes[[field_id]]
    row <- capr_patch_manifest_row(field, candidate, outcome, digest)
    manifest_rows[[length(manifest_rows) + 1L]] <- row
    estimated_delta <- estimated_delta + candidate$estimated_cost
    used_delta <- used_delta + row$actualCost
    if (outcome$ok) {
      field_block <- paste(
        sprintf(
          '<field id="%s" trust="%s" level="%d">',
          field$id, field$trust, candidate$level
        ),
        outcome$rendered,
        "</field>",
        sep = "\n"
      )
      operations <- c(operations, list(
        list(
          op = "add_selected_field",
          fieldId = field_id,
          fieldBlock = field_block
        ),
        list(
          op = "remove_available_on_request",
          fieldId = field_id
        )
      ))
    } else {
      operations[[length(operations) + 1L]] <- list(
        op = "add_caveat_line",
        line = sprintf(
          "- [cap_caveat_field_failed] %s: follow-up materialization failed",
          field_id
        )
      )
    }
  }
  suffix <- sub(
    "^f1:[^@]+@([^#]+)#(.+)$",
    "\\1-\\2",
    approved[[1L]]$request$fieldId
  )
  structure(
    list(
      schema = capr_schema("digest_patch"),
      patchId = sprintf(
        "cap-patch-%s-%s",
        digest$manifest$digestId,
        suffix
      ),
      baseDigestId = digest$manifest$digestId,
      baseFingerprint = digest$fingerprint,
      budgetDelta = list(
        estimated = as.integer(estimated_delta),
        used = as.integer(used_delta)
      ),
      operations = operations,
      manifestRows = manifest_rows
    ),
    class = c("cap_digest_patch", "list")
  )
}

#' Apply a typed patch to an in-memory digest
#'
#' @param digest Base digest.
#' @param patch Patch from `cap_patch()`.
#' @return A new digest. Reapplying the same patch is rejected.
#' @export
cap_apply_patch <- function(digest, patch) {
  if (!inherits(digest, "cap_digest") ||
      !inherits(patch, "cap_digest_patch") ||
      !identical(patch$baseDigestId, digest$manifest$digestId) ||
      !identical(patch$baseFingerprint, digest$fingerprint)) {
    capr_abort(
      "capr_artifact_invalid",
      "patch is incompatible with the base digest"
    )
  }
  if (patch$patchId %in% digest$applied_patches) {
    capr_abort(
      "capr_artifact_invalid",
      "patch has already been applied",
      patch_id = patch$patchId
    )
  }
  result <- digest
  blocks <- vapply(
    Filter(
      function(operation) identical(operation$op, "add_selected_field"),
      patch$operations
    ),
    `[[`,
    character(1),
    "fieldBlock"
  )
  text <- result$text
  if (length(blocks)) {
    text <- sub(
      "<caveats>",
      paste0(paste(blocks, collapse = "\n\n"), "\n\n<caveats>"),
      text,
      fixed = TRUE
    )
  }
  removed <- vapply(
    Filter(
      function(operation) identical(
        operation$op, "remove_available_on_request"
      ),
      patch$operations
    ),
    `[[`,
    character(1),
    "fieldId"
  )
  if (length(removed)) {
    lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
    lines <- lines[!vapply(lines, function(line) {
      any(startsWith(line, paste0(removed, " exec=")))
    }, logical(1))]
    text <- paste(lines, collapse = "\n")
  }
  caveat_lines <- vapply(
    Filter(
      function(operation) identical(operation$op, "add_caveat_line"),
      patch$operations
    ),
    `[[`,
    character(1),
    "line"
  )
  if (length(caveat_lines)) {
    text <- sub(
      "<caveats>",
      paste(c("<caveats>", caveat_lines), collapse = "\n"),
      text,
      fixed = TRUE
    )
  }
  result$manifest$budget$used <- as.integer(
    result$manifest$budget$used + patch$budgetDelta$used
  )
  first_line <- strsplit(text, "\n", fixed = TRUE)[[1L]][[1L]]
  new_first <- sub(
    "budget=[0-9]+/[0-9]+",
    sprintf(
      "budget=%d/%d",
      result$manifest$budget$used,
      result$manifest$budget$requested
    ),
    first_line
  )
  text <- paste0(new_first, substr(text, nchar(first_line) + 1L, nchar(text)))
  for (row in patch$manifestRows) {
    index <- match(
      row$fieldId,
      vapply(result$manifest$fields, `[[`, character(1), "fieldId")
    )
    if (is.na(index)) {
      result$manifest$fields[[length(result$manifest$fields) + 1L]] <- row
    } else {
      result$manifest$fields[[index]] <- row
    }
  }
  problems <- cap_validate_manifest_text(text, result$manifest)
  if (length(problems)) {
    capr_abort(
      "capr_artifact_invalid",
      "patch application produced inconsistent artifacts",
      problems = problems
    )
  }
  result$text <- text
  result$artifact$text <- text
  result$artifact$manifest <- result$manifest
  result$artifact$budgetUsed <- result$manifest$budget$used
  result$applied_patches <- c(result$applied_patches, patch$patchId)
  result
}
