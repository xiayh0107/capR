`%||%` <- function(x, y) if (is.null(x)) y else x

capr_assert_scalar_character <- function(x, name, allow_empty = FALSE,
                                         condition = "capr_adapter_invalid") {
  ok <- is.character(x) && length(x) == 1L && !is.na(x)
  if (!allow_empty) ok <- ok && nzchar(x)
  if (!ok) {
    capr_abort(
      condition,
      sprintf("`%s` must be one %sstring", name, if (allow_empty) "" else "non-empty "),
      field = name
    )
  }
  enc2utf8(x)
}

capr_assert_flag <- function(x, name, condition = "capr_policy_invalid") {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    capr_abort(condition, sprintf("`%s` must be TRUE or FALSE", name), field = name)
  }
  x
}

capr_assert_count <- function(x, name, condition = "capr_policy_invalid") {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x) ||
      x < 0 || x != floor(x)) {
    capr_abort(
      condition,
      sprintf("`%s` must be one non-negative integer", name),
      field = name
    )
  }
  as.integer(x)
}

capr_semver <- function(x, name = "version") {
  x <- capr_assert_scalar_character(x, name)
  if (!grepl("^[0-9]+\\.[0-9]+\\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$", x, perl = TRUE)) {
    capr_abort(
      "capr_adapter_invalid",
      sprintf("`%s` must be a semantic version", name),
      field = name,
      value = x
    )
  }
  x
}

capr_stable_order <- function(x) {
  order(enc2utf8(as.character(x)), method = "radix", na.last = TRUE)
}

capr_stable_sort <- function(x) x[capr_stable_order(x)]

capr_format_number <- function(x) {
  if (!is.numeric(x) || any(!is.finite(x))) {
    capr_abort("capr_artifact_invalid", "numbers must be finite", value = x)
  }
  out <- format(
    x, digits = 15L, scientific = FALSE, trim = TRUE, decimal.mark = "."
  )
  sub("\\.$", "", out)
}

capr_sort_object <- function(x) {
  if (!is.list(x)) return(x)
  if (!is.null(names(x)) && all(nzchar(names(x)))) {
    x <- x[capr_stable_order(names(x))]
  }
  lapply(x, capr_sort_object)
}

#' Serialize deterministic JSON
#'
#' @param x An R object representable as JSON.
#' @param pretty Whether to indent the output.
#' @return A UTF-8 JSON string with deterministically ordered object keys.
#' @export
capr_canonical_json <- function(x, pretty = FALSE) {
  pretty <- capr_assert_flag(pretty, "pretty", "capr_artifact_invalid")
  enc2utf8(as.character(jsonlite::toJSON(
    capr_sort_object(x),
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    digits = NA,
    pretty = pretty,
    force = TRUE
  )))
}

capr_sha256 <- function(x) {
  digest::digest(enc2utf8(x), algo = "sha256", serialize = FALSE)
}

# Runs `code` with every capr.* option cleared so conformance and evidence
# runs are hermetic: a hostile or forgotten global option can never change
# fixture results.
.capr_option_names <- c(
  "capr.default_budget", "capr.max_budget", "capr.max_followup_budget",
  "capr.max_field_seconds", "capr.extra_high_risk_classes"
)

capr_with_builtin_defaults <- function(code) {
  previous <- options(stats::setNames(
    rep(list(NULL), length(.capr_option_names)),
    .capr_option_names
  ))
  on.exit(options(previous), add = TRUE)
  force(code)
}

capr_bounded_diagnostics <- function(x, max_chars = 1000L) {
  max_chars <- capr_assert_count(max_chars, "max_chars", "capr_artifact_invalid")
  value <- paste(enc2utf8(as.character(x)), collapse = "\n")
  if (nchar(value, type = "chars") <= max_chars) return(value)
  paste0(substr(value, 1L, max_chars), "...")
}
