#' capR: an R-hosted CAP-Digest runtime
#'
#' capR resolves an R object to one adapter and then runs a deterministic,
#' policy-bounded digest pipeline. Adapter compatibility is distinct from CAP
#' conformance; the latter is always versioned and fixture-scoped.
#'
#' @section Package options:
#' Options configure default magnitudes only -- never permissions, strategy
#' substitution, or redaction. Precedence is always: explicit argument, then
#' option, then built-in default. `cap_run_fixtures()` clears every capr.*
#' option for the duration of its checks, so conformance evidence is
#' hermetic.
#'
#' \describe{
#'   \item{`capr.default_budget`}{Default `budget` for [cap_digest()]
#'     (built-in `800L`).}
#'   \item{`capr.max_budget`}{Default `max_budget` for [cap_policy()]
#'     (built-in `800L`).}
#'   \item{`capr.max_followup_budget`}{Default `max_followup_budget` for
#'     [cap_policy()] (built-in `300L`).}
#'   \item{`capr.max_field_seconds`}{Default `max_field_seconds` for
#'     [cap_policy()] (built-in `5`).}
#'   \item{`capr.extra_high_risk_classes`}{Extra class names the structural
#'     fallback refuses to traverse. Append-only: built-in refusals can
#'     never be removed.}
#' }
#'
#' Deliberately not configurable via options: every `allow_*` permission,
#' `require_fingerprint_match`, planner/tokenizer selection (visible at the
#' call site only), and `sensitive_name_patterns` (per-call context only, so
#' a global option can never silently narrow redaction).
#'
#' @keywords internal
"_PACKAGE"

.capr_version <- function() {
  version <- tryCatch(
    as.character(utils::packageVersion("capR")),
    error = function(e) "1.1.0.9000"
  )
  parts <- strsplit(version, ".", fixed = TRUE)[[1L]]
  if (length(parts) > 3L) {
    paste0(paste(parts[seq_len(3L)], collapse = "."), "-dev.", paste(parts[-seq_len(3L)], collapse = "."))
  } else {
    version
  }
}
