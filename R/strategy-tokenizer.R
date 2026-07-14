#' Construct a pluggable budget tokenizer
#'
#' A tokenizer owns the budget accounting of a digest: it counts the actual
#' cost of every rendered field. The built-in `heuristic_v1` tokenizer stays
#' the default and keeps conformance runs byte-identical; a custom tokenizer
#' (for example a CJK-aware or model-exact one) replaces accounting wholesale
#' and is stamped into the digest text header, every manifest row, and the
#' resolution sidecar so artifacts remain self-describing.
#'
#' @param id Tokenizer id (lowercase letters, digits, `.`, `_`, `-`). The
#'   built-in ids are reserved.
#' @param version Semantic version of the tokenizer.
#' @param count `function(rendered, field_id)` returning one non-negative
#'   integer token count for a rendered field.
#' @param provider Provider label recorded in listings and sidecars.
#' @return A `capr_tokenizer` object.
#' @export
cap_tokenizer <- function(id, version, count, provider = "host") {
  structure(
    list(
      schema = capr_schema("tokenizer"),
      id = capr_strategy_id(id, "capr_tokenizer_invalid"),
      version = capr_strategy_version(version, "capr_tokenizer_invalid"),
      provider = capr_assert_scalar_character(
        provider, "provider", condition = "capr_tokenizer_invalid"
      ),
      count = if (is.function(count) && length(formals(count)) >= 2L) {
        count
      } else {
        capr_abort(
          "capr_tokenizer_invalid",
          "`count` must be a function(rendered, field_id)",
          field = "count"
        )
      }
    ),
    class = "capr_tokenizer"
  )
}

capr_validate_tokenizer <- function(tokenizer) {
  if (!inherits(tokenizer, "capr_tokenizer") ||
      !identical(tokenizer$schema, capr_schema("tokenizer")) ||
      !is.function(tokenizer$count)) {
    capr_abort("capr_tokenizer_invalid", "invalid capR tokenizer object")
  }
  invisible(tokenizer)
}

capr_builtin_tokenizer <- function() {
  structure(
    list(
      schema = capr_schema("tokenizer"),
      id = .capr_default_tokenizer_id,
      version = "1.0.0",
      provider = "capR",
      count = function(rendered, field_id) {
        capr_actual_cost(field_id, rendered)
      }
    ),
    class = "capr_tokenizer"
  )
}

capr_resolve_tokenizer <- function(tokenizer) {
  if (is.null(tokenizer)) {
    return(capr_builtin_tokenizer())
  }
  if (inherits(tokenizer, "capr_tokenizer")) {
    capr_validate_tokenizer(tokenizer)
    return(tokenizer)
  }
  if (is.character(tokenizer) && length(tokenizer) == 1L &&
      !is.na(tokenizer)) {
    if (identical(tokenizer, .capr_default_tokenizer_id)) {
      return(capr_builtin_tokenizer())
    }
    entry <- .capr_strategy_registry()$tokenizers[[tokenizer]]
    if (!is.null(entry)) {
      return(entry)
    }
    capr_abort(
      "capr_tokenizer_invalid",
      "tokenizer is not registered",
      tokenizer_id = tokenizer
    )
  }
  capr_abort(
    "capr_tokenizer_invalid",
    "tokenizer must be NULL, a tokenizer id, or a capr_tokenizer object"
  )
}

# Budget accounting must never fail open: a count violation aborts instead of
# degrading to zero cost.
capr_tokenizer_count <- function(tokenizer, field_id, rendered) {
  count <- tryCatch(
    tokenizer$count(rendered, field_id),
    error = function(e) e
  )
  if (inherits(count, "condition") ||
      !is.numeric(count) || length(count) != 1L || is.na(count) ||
      !is.finite(count) || count < 0 || count != floor(count)) {
    capr_abort(
      "capr_tokenizer_invalid",
      "tokenizer `count` must return one non-negative integer",
      tokenizer_id = tokenizer$id,
      field_id = field_id,
      parent = if (inherits(count, "condition")) count else NULL
    )
  }
  as.integer(count)
}

#' Register, unregister, and list budget tokenizers
#'
#' The tokenizer registry follows the adapter registry contract:
#' re-registering an identical tokenizer is idempotent, registering a
#' different tokenizer under an existing id raises
#' `capr_registry_conflict`, and built-in ids cannot be shadowed.
#'
#' @param tokenizer A `capr_tokenizer` from [cap_tokenizer()].
#' @return `cap_register_tokenizer()` returns the tokenizer invisibly;
#'   `cap_unregister_tokenizer()` returns the removed count invisibly;
#'   `cap_list_tokenizers()` returns a deterministic data frame.
#' @export
cap_register_tokenizer <- function(tokenizer) {
  capr_validate_tokenizer(tokenizer)
  capr_strategy_id(tokenizer$id, "capr_tokenizer_invalid")
  capr_strategy_register(
    "tokenizers", tokenizer, "count", "capr_tokenizer_invalid"
  )
}

#' @rdname cap_register_tokenizer
#' @param id Tokenizer id to remove; `NULL` clears the registry.
#' @export
cap_unregister_tokenizer <- function(id = NULL) {
  capr_strategy_unregister("tokenizers", id)
}

#' @rdname cap_register_tokenizer
#' @export
cap_list_tokenizers <- function() {
  capr_strategy_list("tokenizers")
}
