.capr_condition_classes <- c(
  "capr_adapter_not_found", "capr_adapter_ambiguous", "capr_adapter_invalid",
  "capr_registry_conflict", "capr_duplicate_field_id", "capr_contract_unbound",
  "capr_adapter_pin_mismatch", "capr_fallback_disallowed", "capr_extraction_error",
  "capr_renderer_error", "capr_sidecar_invalid", "capr_policy_invalid",
  "capr_artifact_invalid", "capr_text_invalid", "capr_agent_invalid",
  "capr_dependency_missing", "capr_planner_invalid", "capr_tokenizer_invalid"
)

#' Construct a structured capR condition
#'
#' capR implementation conditions use `capr_*` classes. They are
#' deliberately separate from canonical CAP finding and gate codes.
#'
#' @param subclass A single `capr_*` condition class.
#' @param message Human-readable message.
#' @param ... Structured metadata fields.
#' @param parent Optional parent condition.
#' @param call Optional originating call.
#' @return A condition object.
#' @export
capr_condition <- function(subclass, message, ..., parent = NULL, call = NULL) {
  if (!is.character(subclass) || length(subclass) != 1L ||
      !grepl("^capr_[a-z0-9_]+$", subclass)) {
    stop("`subclass` must be one capr_* condition class", call. = FALSE)
  }
  if (!is.character(message) || length(message) != 1L || is.na(message)) {
    stop("`message` must be one non-missing string", call. = FALSE)
  }
  metadata <- list(...)
  if (length(metadata) && (is.null(names(metadata)) || any(!nzchar(names(metadata))))) {
    stop("condition metadata must be named", call. = FALSE)
  }
  structure(
    c(list(message = enc2utf8(message), call = call, parent = parent), metadata),
    class = unique(c(subclass, "capr_error", "error", "condition"))
  )
}

#' Signal a structured capR error
#' @inheritParams capr_condition
#' @return This function does not return.
#' @export
capr_abort <- function(subclass, message, ..., parent = NULL, call = sys.call(-1L)) {
  stop(capr_condition(subclass, message, ..., parent = parent, call = call))
}

#' Inspect capR conditions
#' @param condition A condition object.
#' @param subclass Optional class to test.
#' @return `capr_is()` returns a logical value;
#'   `capr_condition_fields()` returns named structured metadata.
#' @export
capr_is <- function(condition, subclass = "capr_error") {
  inherits(condition, subclass)
}

#' @rdname capr_is
#' @export
capr_condition_fields <- function(condition) {
  if (!inherits(condition, "capr_error")) {
    return(list())
  }
  condition[setdiff(names(condition), c("message", "call", "parent"))]
}
