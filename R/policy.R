.capr_execution_classes <- c(
  "local_cheap", "local_scan", "local_isolated",
  "remote", "remote_query", "credentialed", "unsafe", "unknown"
)

#' Construct a host policy
#'
#' Adapter capabilities describe what code can do; this policy decides what it
#' may do. Unknown, remote, credentialed, and unsafe execution is denied by
#' default.
#'
#' @param max_budget Initial digest budget.
#' @param max_followup_budget Follow-up budget.
#' @param max_field_seconds Positive elapsed-time limit for one field.
#' @param allow_exec Allowed execution classes.
#' @param allow_remote,allow_credentials,allow_fallback Boolean permissions.
#' @param require_fingerprint_match Whether follow-up requires source freshness.
#' @param allow_followup Whether follow-up is enabled.
#' @return A normalized `capr_policy`.
#' @export
cap_policy <- function(max_budget = getOption("capr.max_budget", 800L),
                       max_followup_budget = getOption(
                         "capr.max_followup_budget", 300L
                       ),
                       max_field_seconds = getOption(
                         "capr.max_field_seconds", 5
                       ),
                       allow_exec = c("local_cheap", "local_scan"),
                       allow_remote = FALSE, allow_credentials = FALSE,
                       allow_fallback = FALSE,
                       require_fingerprint_match = TRUE,
                       allow_followup = TRUE) {
  max_budget <- capr_assert_count(max_budget, "max_budget")
  max_followup_budget <- capr_assert_count(
    max_followup_budget, "max_followup_budget"
  )
  if (!is.numeric(max_field_seconds) ||
      length(max_field_seconds) != 1L ||
      is.na(max_field_seconds) ||
      !is.finite(max_field_seconds) ||
      max_field_seconds <= 0) {
    capr_abort(
      "capr_policy_invalid",
      "`max_field_seconds` must be one positive finite number",
      field = "max_field_seconds"
    )
  }
  if (!is.character(allow_exec) || anyNA(allow_exec)) {
    capr_abort(
      "capr_policy_invalid",
      "`allow_exec` must be a character vector",
      field = "allow_exec"
    )
  }
  allow_exec <- unique(enc2utf8(allow_exec))
  unknown <- setdiff(allow_exec, .capr_execution_classes)
  if (length(unknown)) {
    capr_abort(
      "capr_policy_invalid",
      "unknown execution classes fail closed",
      execution_classes = unknown
    )
  }
  allow_remote <- capr_assert_flag(allow_remote, "allow_remote")
  allow_credentials <- capr_assert_flag(
    allow_credentials, "allow_credentials"
  )
  allow_fallback <- capr_assert_flag(allow_fallback, "allow_fallback")
  require_fingerprint_match <- capr_assert_flag(
    require_fingerprint_match, "require_fingerprint_match"
  )
  allow_followup <- capr_assert_flag(allow_followup, "allow_followup")
  if ("remote" %in% allow_exec && !allow_remote) {
    capr_abort(
      "capr_policy_invalid",
      "remote execution is listed but `allow_remote` is FALSE",
      field = "allow_remote"
    )
  }
  if ("credentialed" %in% allow_exec && !allow_credentials) {
    capr_abort(
      "capr_policy_invalid",
      "credentialed execution is listed but `allow_credentials` is FALSE",
      field = "allow_credentials"
    )
  }
  structure(
    list(
      schema = capr_schema("policy"),
      max_budget = max_budget,
      max_followup_budget = max_followup_budget,
      max_field_seconds = as.numeric(max_field_seconds),
      allow_exec = capr_stable_sort(allow_exec),
      allow_remote = allow_remote,
      allow_credentials = allow_credentials,
      allow_fallback = allow_fallback,
      require_fingerprint_match = require_fingerprint_match,
      allow_followup = allow_followup
    ),
    class = "capr_policy"
  )
}

#' @export
print.capr_policy <- function(x, ...) {
  cat("<capr_policy>\n")
  cat(sprintf(
    "  budget: %d initial; %d follow-up; %.3fs per field\n",
    x$max_budget, x$max_followup_budget, x$max_field_seconds
  ))
  cat(sprintf(
    "  execution: %s\n",
    if (length(x$allow_exec)) paste(x$allow_exec, collapse = ", ") else "none"
  ))
  cat(sprintf(
    "  remote: %s; credentials: %s; fallback: %s; follow-up: %s\n",
    x$allow_remote, x$allow_credentials, x$allow_fallback, x$allow_followup
  ))
  invisible(x)
}

capr_validate_policy <- function(policy) {
  if (!inherits(policy, "capr_policy") ||
      !identical(policy$schema, capr_schema("policy"))) {
    capr_abort("capr_policy_invalid", "invalid capR policy object")
  }
  invisible(policy)
}

#' Authorize an execution class
#'
#' @param policy A `capr_policy`.
#' @param execution_class Declared execution class.
#' @param capabilities Optional adapter capabilities.
#' @return An inspectable decision with `allowed` and `reason`.
#' @export
cap_authorize_execution <- function(policy, execution_class,
                                    capabilities = list()) {
  capr_validate_policy(policy)
  execution_class <- capr_assert_scalar_character(
    execution_class, "execution_class", condition = "capr_policy_invalid"
  )
  if (!execution_class %in% .capr_execution_classes ||
      identical(execution_class, "unknown")) {
    return(list(
      allowed = FALSE,
      reason = "unknown_execution_class",
      execution_class = execution_class
    ))
  }
  if (execution_class %in% c("remote", "remote_query") &&
      !policy$allow_remote) {
    return(list(
      allowed = FALSE, reason = "remote_denied",
      execution_class = execution_class
    ))
  }
  if (identical(execution_class, "credentialed") &&
      !policy$allow_credentials) {
    return(list(
      allowed = FALSE, reason = "credentials_denied",
      execution_class = execution_class
    ))
  }
  if (execution_class %in% c("unsafe") ||
      !execution_class %in% policy$allow_exec) {
    return(list(
      allowed = FALSE, reason = "execution_class_denied",
      execution_class = execution_class
    ))
  }
  list(
    allowed = TRUE, reason = "authorized",
    execution_class = execution_class
  )
}

capr_policy_sidecar <- function(policy) {
  capr_validate_policy(policy)
  unclass(policy)
}
