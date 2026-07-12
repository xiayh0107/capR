capr_contract_check <- function(name, code) {
  tryCatch(
    {
      code()
      list(name = name, ok = TRUE, diagnostic = NULL)
    },
    error = function(e) {
      list(
        name = name,
        ok = FALSE,
        diagnostic = list(
          class = class(e)[[1L]],
          message = conditionMessage(e)
        )
      )
    }
  )
}

capr_contract_field_ids <- function(catalog) {
  if (!is.list(catalog) || !is.list(catalog$fields)) {
    capr_abort(
      "capr_adapter_invalid",
      "field catalog must contain a `fields` list"
    )
  }
  ids <- vapply(catalog$fields, function(field) {
    id <- field$id %||% field$fieldId
    capr_assert_scalar_character(
      id,
      "fieldId",
      condition = "capr_adapter_invalid"
    )
  }, character(1))
  if (anyDuplicated(ids)) {
    capr_abort(
      "capr_duplicate_field_id",
      "adapter field IDs must be unique",
      field_ids = ids[duplicated(ids)]
    )
  }
  invalid <- !grepl(
    "^f1:[a-z][a-z0-9_-]*@[a-zA-Z0-9_]+#[a-zA-Z0-9_-]+$",
    ids
  )
  if (any(invalid)) {
    capr_abort(
      "capr_adapter_invalid",
      "adapter field IDs do not match the stable grammar",
      field_ids = ids[invalid]
    )
  }
  ids
}

capr_contract_symbolic <- function(catalog) {
  bad <- unlist(lapply(catalog$fields, function(field) {
    id <- field$id %||% field$fieldId
    contracts <- field$contracts
    if (!is.list(contracts)) return(id)
    values <- unlist(contracts, use.names = FALSE)
    if (!is.character(values) || any(!nzchar(values))) id else NULL
  }), use.names = FALSE)
  if (length(bad)) {
    capr_abort(
      "capr_adapter_invalid",
      "serialized field contracts must be symbolic strings",
      field_ids = bad
    )
  }
  invisible(TRUE)
}

capr_contract_probe_plan <- function(catalog, policy, field_id = NULL) {
  budget <- sum(vapply(catalog$fields, function(field) {
    max(vapply(field$levels, `[[`, integer(1), "estimatedCost"))
  }, integer(1)))
  plan <- cap_select_fields(
    catalog,
    budget = budget,
    policy = policy,
    include_interactive = TRUE
  )
  selected <- which(vapply(plan$candidates, function(candidate) {
    isTRUE(candidate$authorization$allowed) &&
      (is.null(field_id) || identical(candidate$field$id, field_id))
  }, logical(1)))
  if (!length(selected)) {
    capr_abort(
      "capr_adapter_invalid",
      "adapter contract probe could not select an authorized field",
      field_id = field_id
    )
  }
  levels <- vapply(
    plan$candidates[selected], `[[`, integer(1), "level"
  )
  keep <- selected[[which.max(levels)]]
  for (index in seq_along(plan$candidates)) {
    plan$candidates[[index]]$selected <- identical(index, keep)
    if (!identical(index, keep) &&
        is.null(plan$candidates[[index]]$rejected_reason)) {
      plan$candidates[[index]]$rejected_reason <- "level_superseded"
    }
  }
  plan$budget_estimated_selected <-
    plan$candidates[[keep]]$estimated_cost
  plan
}

capr_contract_probe_plans <- function(catalog, policy) {
  ids <- vapply(catalog$fields, `[[`, character(1), "id")
  stats::setNames(
    lapply(ids, function(id) capr_contract_probe_plan(catalog, policy, id)),
    ids
  )
}

#' Run the reusable adapter contract suite
#'
#' This suite verifies compatibility with capR's extension contract. It does
#' not create a CAP-Digest conformance claim.
#'
#' @param adapter A validated adapter or zero-argument factory.
#' @param source Representative source object.
#' @param context Optional adapter context.
#' @return A `capr_adapter_contract_result`.
#' @export
cap_test_adapter <- function(adapter, source, context = list()) {
  built <- capr_factory_adapter(adapter)
  adapter <- built$adapter
  policy <- cap_policy(
    max_budget = 100000L,
    max_followup_budget = 100000L,
    allow_exec = c("local_cheap", "local_scan", "local_isolated"),
    allow_fallback = identical(adapter$metadata$maturity, "fallback")
  )
  catalog <- tryCatch(
    adapter$lifecycle$field_catalog(source, context),
    error = function(e) NULL
  )
  checks <- list(
    capr_contract_check("adapter_valid", function() cap_validate_adapter(adapter)),
    capr_contract_check("identity_version", function() {
      capr_assert_scalar_character(adapter$metadata$id, "id")
      capr_semver(adapter$metadata$version)
    }),
    capr_contract_check("source_ref_catalog_agreement", function() {
      source_ref <- adapter$lifecycle$source_ref(source, context)
      catalog <- adapter$lifecycle$field_catalog(source, context)
      if (!identical(source_ref$sourceType, catalog$sourceType)) {
        capr_abort(
          "capr_adapter_invalid",
          "SourceRef and FieldCatalog source types differ",
          source_ref = source_ref$sourceType,
          catalog = catalog$sourceType
        )
      }
    }),
    capr_contract_check("field_ids_unique_valid", function() {
      current <- adapter$lifecycle$field_catalog(source, context)
      cap_validate_field_catalog(current)
      capr_contract_field_ids(current)
    }),
    capr_contract_check("contracts_symbolic_bound", function() {
      catalog <- adapter$lifecycle$field_catalog(source, context)
      capr_contract_symbolic(catalog)
      for (field in catalog$fields) {
        contracts <- field$contracts
        capr_adapter_binding(adapter, "extractors", contracts$extractor)
        capr_adapter_binding(adapter, "redactors", contracts$redactor)
        capr_adapter_binding(adapter, "renderers", contracts$renderer)
      }
    }),
    capr_contract_check("fingerprint_deterministic", function() {
      first <- adapter$lifecycle$fingerprint(source, context)
      second <- adapter$lifecycle$fingerprint(source, context)
      if (!identical(first, second)) {
        capr_abort(
          "capr_adapter_invalid",
          "adapter fingerprint is not deterministic"
        )
      }
    }),
    capr_contract_check("resolution_deterministic", function() {
      first <- cap_resolve_adapter(source, adapter = adapter)
      second <- cap_resolve_adapter(source, adapter = adapter)
      if (!identical(
        first$metadata[c("id", "version", "provider", "provider_version")],
        second$metadata[c("id", "version", "provider", "provider_version")]
      )) {
        capr_abort(
          "capr_adapter_invalid",
          "explicit adapter resolution is not deterministic"
        )
      }
    }),
    capr_contract_check("ambiguity_fails_closed", function() {
      registry <- cap_registry(global = FALSE)
      alternative <- adapter
      alternative$metadata$id <- paste0(
        adapter$metadata$id, ".ambiguity_probe"
      )
      cap_register_adapter(
        "capr_contract_probe", adapter, registry = registry
      )
      cap_register_adapter(
        "capr_contract_probe", alternative, registry = registry
      )
      probe <- structure(list(), class = "capr_contract_probe")
      result <- tryCatch(
        cap_resolve_adapter(probe, registry = registry),
        error = function(e) e
      )
      if (!inherits(result, "capr_adapter_ambiguous")) {
        capr_abort(
          "capr_adapter_invalid",
          "equal effective adapter matches did not fail closed"
        )
      }
    }),
    capr_contract_check("materialization_captures_outcomes", function() {
      current <- adapter$lifecycle$field_catalog(source, context)
      plans <- capr_contract_probe_plans(current, policy)
      for (field_id in names(plans)) {
        result <- cap_materialize(
          plans[[field_id]], adapter, source, policy, context
        )
        outcome <- result$outcomes[[field_id]]
        required <- c(
          "ok", "warnings", "elapsed_ms", "actual_cost",
          "redacted", "rendered"
        )
        if (is.null(outcome) || length(setdiff(required, names(outcome)))) {
          capr_abort(
            "capr_adapter_invalid",
            "materialization outcome is incomplete",
            field_id = field_id
          )
        }
      }
    }),
    capr_contract_check("warnings_errors_timing_captured", function() {
      current <- adapter$lifecycle$field_catalog(source, context)
      plans <- capr_contract_probe_plans(current, policy)
      for (field_id in names(plans)) {
        plan <- plans[[field_id]]
        candidate <- Filter(
          function(value) value$selected,
          plan$candidates
        )[[1L]]
        contract <- candidate$field$contracts$extractor
        original <- capr_adapter_binding(
          adapter, "extractors", contract
        )
        warning_adapter <- adapter
        warning_adapter$bindings$extractors[[contract]] <- function(...) {
          warning("contract probe warning")
          original(...)
        }
        warned <- cap_materialize(
          plan, warning_adapter, source, policy, context
        )$outcomes[[field_id]]
        if (!length(warned$warnings) ||
            !is.integer(warned$elapsed_ms)) {
          capr_abort(
            "capr_adapter_invalid",
            "extractor warnings or timing were not captured",
            field_id = field_id
          )
        }
        error_adapter <- adapter
        error_adapter$bindings$extractors[[contract]] <- function(...) {
          stop("contract probe error")
        }
        failed <- cap_materialize(
          plan, error_adapter, source, policy, context
        )$outcomes[[field_id]]
        if (failed$ok ||
            !identical(failed$error_class, "extraction_error")) {
          capr_abort(
            "capr_adapter_invalid",
            "extractor errors were not captured as failed fields",
            field_id = field_id
          )
        }
      }
    }),
    capr_contract_check("redaction_precedes_rendering", function() {
      current <- adapter$lifecycle$field_catalog(source, context)
      plans <- capr_contract_probe_plans(current, policy)
      for (field_id in names(plans)) {
        plan <- plans[[field_id]]
        candidate <- Filter(
          function(value) value$selected,
          plan$candidates
        )[[1L]]
        redactor_name <- candidate$field$contracts$redactor
        renderer_name <- candidate$field$contracts$renderer
        original_redactor <- capr_adapter_binding(
          adapter, "redactors", redactor_name
        )
        original_renderer <- capr_adapter_binding(
          adapter, "renderers", renderer_name
        )
        state <- new.env(parent = emptyenv())
        state$redacted <- FALSE
        instrumented <- adapter
        instrumented$bindings$redactors[[redactor_name]] <- function(...) {
          result <- original_redactor(...)
          state$redacted <- TRUE
          result
        }
        instrumented$bindings$renderers[[renderer_name]] <- function(...) {
          if (!state$redacted) stop("renderer ran before redactor")
          original_renderer(...)
        }
        outcome <- cap_materialize(
          plan, instrumented, source, policy, context
        )$outcomes[[field_id]]
        if (!outcome$ok || !state$redacted) {
          capr_abort(
            "capr_adapter_invalid",
            "redaction ordering contract failed",
            field_id = field_id
          )
        }
      }
    }),
    capr_contract_check("rendering_bounded_deterministic", function() {
      current <- adapter$lifecycle$field_catalog(source, context)
      plans <- capr_contract_probe_plans(current, policy)
      for (field_id in names(plans)) {
        plan <- plans[[field_id]]
        first <- cap_materialize(
          plan, adapter, source, policy, context
        )$outcomes[[field_id]]
        second <- cap_materialize(
          plan, adapter, source, policy, context
        )$outcomes[[field_id]]
        if (!identical(first$rendered, second$rendered) ||
            nchar(first$rendered, type = "chars") > 20012L) {
          capr_abort(
            "capr_adapter_invalid",
            "renderer is not deterministic and bounded",
            field_id = field_id
          )
        }
      }
    }),
    capr_contract_check("fallback_labeling", function() {
      if (identical(adapter$metadata$maturity, "fallback") &&
          (!identical(adapter$metadata$semantic_level, "structural") ||
           !identical(adapter$metadata$conformance_claim, "none"))) {
        capr_abort(
          "capr_adapter_invalid",
          "fallback adapter is mislabeled"
        )
      }
    }),
    capr_contract_check("claim_separation", function() {
      if (adapter$metadata$maturity != "stable" &&
          adapter$metadata$conformance_claim != "none") {
        capr_abort(
          "capr_adapter_invalid",
          "non-stable adapters cannot inherit the built-in conformance claim",
          maturity = adapter$metadata$maturity,
          claim = adapter$metadata$conformance_claim
        )
      }
    }),
    capr_contract_check("pin_round_trip", function() {
      cap_check_adapter_pin(adapter, cap_adapter_pin(adapter))
    }),
    capr_contract_check("incompatible_pin_fails", function() {
      pin <- cap_adapter_pin(adapter)
      changed <- adapter
      changed$metadata$provider_version <- if (identical(
        adapter$metadata$provider_version, "999.0.0"
      )) "998.0.0" else "999.0.0"
      result <- tryCatch(
        cap_check_adapter_pin(changed, pin),
        error = function(e) e
      )
      if (!inherits(result, "capr_adapter_pin_mismatch")) {
        capr_abort(
          "capr_adapter_invalid",
          "incompatible adapter pin did not fail closed"
        )
      }
    })
  )
  ok <- all(vapply(checks, `[[`, logical(1), "ok"))
  structure(
    list(
      schema = "capr.adapter_contract_result.v1",
      ok = ok,
      adapter = adapter$metadata[c(
        "id", "version", "provider", "provider_version",
        "source_family", "maturity", "conformance_claim"
      )],
      checks = checks,
      scope = "capR adapter compatibility; not CAP conformance"
    ),
    class = "capr_adapter_contract_result"
  )
}

#' @export
print.capr_adapter_contract_result <- function(x, ...) {
  cat(sprintf(
    "<capr_adapter_contract_result %s> %s\n",
    x$adapter$id,
    if (x$ok) "PASS" else "FAIL"
  ))
  for (check in x$checks) {
    cat(sprintf("  [%s] %s\n", if (check$ok) "ok" else "fail", check$name))
  }
  cat(sprintf("  scope: %s\n", x$scope))
  invisible(x)
}
