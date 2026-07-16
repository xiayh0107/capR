# aisdk adapter layer. Everything here is a thin wrapper over the
# provider-neutral implementations in agent-tools-core.R; aisdk is a
# suggested dependency and every entry point is guarded. capR still never
# calls a model: these functions only construct tool/agent objects, and the
# model call happens inside the host's aisdk runtime.

capr_aisdk_tool_specs <- function(session) {
  list(
    list(
      name = "capr_read_digest",
      description = paste(
        "Read the current CAP digest for the R object in this session.",
        "The digest is the ONLY authorized evidence about the object.",
        "Disclosed evidence appears as <field id=\"...\"> blocks; cite those",
        "exact ids in claims. Fields listed under <available_on_request>",
        "are not yet disclosed; use capr_request_fields to ask the host",
        "gate to disclose them."
      ),
      parameters = aisdk::z_empty_object(),
      execute = function() {
        capr_agent_tool_read_digest(session)
      }
    ),
    list(
      name = "capr_request_fields",
      description = paste(
        "Ask the host gate to disclose additional evidence fields.",
        "Only ids listed under <available_on_request> in the digest can be",
        "requested. The gate, not you, authorizes disclosure: each request",
        "is approved or denied against host policy and the remaining",
        "follow-up budget. The result lists per-request decisions, any",
        "newly disclosed <field> blocks, and the remaining budget.",
        "Do not retry a denied request."
      ),
      parameters = aisdk::z_object(
        requests = aisdk::z_array(
          items = aisdk::z_object(
            field_id = aisdk::z_string(paste(
              "Exact id copied from <available_on_request>,",
              "e.g. \"f1:table@sample#k10\"."
            )),
            reason = aisdk::z_string(
              "One sentence: why this field is needed for the question."
            ),
            level = aisdk::z_integer(
              paste(
                "Detail level shown for this field in",
                "<available_on_request>."
              ),
              nullable = TRUE
            ),
            budget = aisdk::z_integer(
              paste(
                "Token budget to spend; defaults to the field's",
                "estimated cost."
              ),
              nullable = TRUE
            ),
            .required = c("field_id", "reason")
          ),
          description = "Fields to request; keep the list short and justified."
        ),
        .required = "requests"
      ),
      execute = function(requests) {
        capr_agent_tool_request_fields(session, requests)
      }
    ),
    list(
      name = "capr_submit_claims",
      description = paste(
        "Validate your final claims against the digest before answering",
        "the user. Each claim must cite the digest field ids that support",
        "it. Returns ok=true when every citation refers to a disclosed",
        "field; otherwise returns the exact validation errors so you can",
        "fix the claim or its citations. Claims citing undisclosed or",
        "unknown fields are rejected."
      ),
      parameters = aisdk::z_object(
        claims = aisdk::z_array(
          items = aisdk::z_object(
            id = aisdk::z_string(
              "Short stable claim id, e.g. \"claim-1\"."
            ),
            text = aisdk::z_string("One factual statement."),
            evidence = aisdk::z_array(
              items = aisdk::z_string("A disclosed digest field id."),
              description = paste(
                "Digest field ids that directly support this claim."
              )
            ),
            .required = c("id", "text", "evidence")
          ),
          description = "Claims with evidence citations."
        ),
        .required = "claims"
      ),
      execute = function(claims) {
        capr_agent_tool_submit_claims(session, claims)
      }
    ),
    list(
      name = "capr_session_status",
      description = paste(
        "Report session progress: turns used, remaining follow-up budget,",
        "disclosed field ids, and which fields can still be requested."
      ),
      parameters = aisdk::z_empty_object(),
      execute = function() {
        capr_agent_tool_status(session)
      }
    )
  )
}

#' Expose an agent session as aisdk tools
#'
#' Builds `aisdk::tool()` objects over a [cap_agent_session()] so any aisdk
#' agent or chat loop can drive the digest -> validate -> gate -> patch round
#' trip natively. Every tool call still runs through the deterministic core:
#' the gate authorizes each disclosure, and denied requests stay denied.
#'
#' @param session An active `capr_agent_session`.
#' @return A list of four aisdk tools: `capr_read_digest`,
#'   `capr_request_fields`, `capr_submit_claims`, and `capr_session_status`.
#' @export
cap_aisdk_tools <- function(session) {
  capr_require_suggests("aisdk", "cap_aisdk_tools()")
  capr_validate_agent_session(session)
  lapply(capr_aisdk_tool_specs(session), function(spec) {
    aisdk::tool(
      name = spec$name,
      description = spec$description,
      parameters = spec$parameters,
      execute = spec$execute
    )
  })
}

#' Create an aisdk agent bound to an agent session
#'
#' Convenience wrapper: an `aisdk::create_agent()` whose system prompt is
#' [cap_agent_instructions()] and whose tools are [cap_aisdk_tools()]. The
#' model provider, credentials, and the model call itself live entirely in
#' aisdk; capR only supplies the evidence tools.
#'
#' @param session An active `capr_agent_session`.
#' @param name Agent name.
#' @param description Agent description shown to aisdk runtimes.
#' @param model Optional aisdk model passed through to
#'   `aisdk::create_agent()`.
#' @param ... Additional arguments for `aisdk::create_agent()`.
#' @return An aisdk agent object.
#' @export
cap_aisdk_agent <- function(session, name = "capr-analyst",
                            description = paste(
                              "Answers questions about one R object using",
                              "its bounded CAP digest evidence pack."
                            ),
                            model = NULL, ...) {
  capr_require_suggests("aisdk", "cap_aisdk_agent()")
  capr_validate_agent_session(session)
  aisdk::create_agent(
    name = name,
    description = description,
    system_prompt = cap_agent_instructions(),
    tools = cap_aisdk_tools(session),
    model = model,
    ...
  )
}

# Reverse-direction bridges. The adapters above hand capR's evidence tools
# to aisdk; the two factories below hand aisdk's model-side capabilities
# (token accounting, structured output) to capR's strategy and agent seams.
# capR core still ships zero network code: any network traffic happens
# inside aisdk, on the host's behalf, only when the host installs these.

capr_aisdk_model <- function(model, condition, caller) {
  if (inherits(model, "LanguageModelV1")) {
    return(model)
  }
  if (is.character(model) && length(model) == 1L && !is.na(model) &&
      nzchar(model)) {
    return(model)
  }
  capr_abort(
    condition,
    sprintf(
      paste(
        "`model` for %s must be an aisdk LanguageModelV1 object or a",
        "model id string such as \"anthropic:claude-sonnet-5\""
      ),
      caller
    ),
    field = "model"
  )
}

capr_aisdk_default_tokenizer_id <- function(model) {
  label <- if (is.character(model)) model else model$model_id
  if (!is.character(label) || length(label) != 1L || is.na(label) ||
      !nzchar(label)) {
    capr_abort(
      "capr_tokenizer_invalid",
      "aisdk model exposes no model id; pass `id` explicitly",
      field = "id"
    )
  }
  paste0("aisdk-", gsub("[^a-z0-9._-]+", "-", tolower(label)))
}

#' Budget tokenizer backed by aisdk token counting
#'
#' Builds a [cap_tokenizer()] whose `count` function calls
#' `aisdk::count_tokens()` on every rendered field, so digest budget
#' accounting matches what the model provider will actually charge.
#' Providers with a native counting endpoint (Anthropic
#' `/messages/count_tokens`) yield model-exact counts; other providers use
#' aisdk's local heuristic estimate.
#'
#' Unlike the built-in tokenizer, counting through this one MAY perform a
#' network call (the Anthropic endpoint), and aisdk falls back to its local
#' heuristic when that endpoint is unreachable: counts are model-exact when
#' online but are not guaranteed reproducible offline. capR itself still
#' ships zero network code -- the call happens inside aisdk, on the host's
#' behalf, only because the host installed this tokenizer. Each count runs
#' under the digest's per-field time limit, and any counting failure
#' surfaces as a typed `capr_tokenizer_invalid` error; budget accounting
#' never fails open.
#'
#' Accounting is pinned: [cap_patch()] refuses any tokenizer other than the
#' one the digest was built with, so reuse the same tokenizer object (or
#' its registered id) for every follow-up patch of the same digest.
#'
#' @param model An aisdk model: a `LanguageModelV1` object or a model id
#'   string such as `"anthropic:claude-sonnet-5"` (strings are resolved by
#'   aisdk at count time).
#' @param id Tokenizer id; defaults to the model's id, lowercased, invalid
#'   characters replaced with `-`, and prefixed with `aisdk-` (for example
#'   `aisdk-claude-sonnet-5`).
#' @param version Semantic version recorded for the tokenizer.
#' @return A `capr_tokenizer` with `provider = "aisdk"`.
#' @export
cap_aisdk_tokenizer <- function(model, id = NULL, version = "1.0.0") {
  # count_tokens() is an aisdk 1.5.0 API; CRAN's 1.4.x has no export, so the
  # symbol is resolved dynamically after the version gate (a static
  # aisdk::count_tokens reference would trip R CMD check against 1.4.x).
  capr_require_suggests(
    "aisdk", "cap_aisdk_tokenizer()", min_version = "1.5.0"
  )
  count_tokens <- getExportedValue("aisdk", "count_tokens")
  model <- capr_aisdk_model(
    model, "capr_tokenizer_invalid", "cap_aisdk_tokenizer()"
  )
  cap_tokenizer(
    id = id %||% capr_aisdk_default_tokenizer_id(model),
    version = version,
    provider = "aisdk",
    count = function(rendered, field_id) {
      as.integer(count_tokens(model, prompt = rendered))
    }
  )
}

# Explicit z_* mirror of cap.contract_response.v1 (see
# capr_normalize_response): claims need id + text + evidence, requests need
# fieldId + reason with optional level/budget, and all four top-level keys
# are required so the model always emits the complete envelope.
capr_aisdk_contract_schema <- function() {
  aisdk::z_object(
    claims = aisdk::z_array(
      items = aisdk::z_object(
        id = aisdk::z_string("Short stable claim id, e.g. \"claim-1\"."),
        text = aisdk::z_string("One factual statement."),
        evidence = aisdk::z_array(
          items = aisdk::z_string("A disclosed digest field id."),
          description = "Digest field ids that support this claim."
        ),
        .required = c("id", "text", "evidence")
      ),
      description = "Claims with evidence citations; empty while requesting."
    ),
    evidence = aisdk::z_array(
      items = aisdk::z_string("A disclosed digest field id."),
      description = "Optional top-level citations; ids must be unique."
    ),
    warnings = aisdk::z_array(
      items = aisdk::z_string("One caveat about the answer."),
      description = "Optional caveats; usually empty."
    ),
    requests = aisdk::z_array(
      items = aisdk::z_object(
        fieldId = aisdk::z_string(
          "Exact id copied from <available_on_request>."
        ),
        reason = aisdk::z_string(
          "One sentence: why this field is needed for the question."
        ),
        level = aisdk::z_integer(
          "Detail level shown for this field.",
          nullable = TRUE
        ),
        budget = aisdk::z_integer(
          "Token budget to spend; defaults to the field's estimated cost.",
          nullable = TRUE
        ),
        .required = c("fieldId", "reason")
      ),
      description = "Follow-up disclosure requests; empty when answering."
    ),
    .required = c("claims", "evidence", "warnings", "requests")
  )
}

#' Schema-constrained ask function over aisdk structured output
#'
#' Factory producing the `ask` callback for [cap_agent_run()], implemented
#' with `aisdk::generate_object()`: the model is forced (`mode = "tool"`) or
#' instructed and re-asked (`mode = "json"`) to reply with an object that
#' parses as `cap.contract_response.v1`, which slashes `invalid_response`
#' turns and repair churn compared with free-text JSON replies.
#'
#' capR never calls a model: this factory hands the network call to aisdk,
#' on the host's behalf, under the host's own provider credentials. Each
#' call returns aisdk's parsed object verbatim -- even when aisdk's own
#' schema check still failed after `max_retries` re-asks -- because
#' [cap_validate_response()] remains the semantic authority: a malformed
#' object becomes a typed `invalid_response` turn (repairable via
#' `cap_agent_run(max_repairs =)`), and a reply from which aisdk could
#' parse no object at all is `NULL`, which the core rejects fail-closed as
#' `capr_artifact_invalid`.
#'
#' @param model An aisdk model: a `LanguageModelV1` object or a model id
#'   string such as `"anthropic:claude-sonnet-5"`.
#' @param mode Structured-output mode: `"tool"` (default; the schema is one
#'   forced tool call -- most reliable on models with native function
#'   calling) or `"json"` (JSON parsed out of the model text).
#' @param max_retries How many times aisdk re-asks the model when its
#'   output does not match the schema before handing the result to capR
#'   anyway.
#' @param ... Passed through to `aisdk::generate_object()` (for example
#'   `system`, `temperature`, `max_tokens`).
#' @return `function(prompt)` returning a contract-response list, suitable
#'   as the `ask` argument of [cap_agent_run()].
#' @export
cap_aisdk_ask <- function(model, mode = c("tool", "json"),
                          max_retries = 1L, ...) {
  # generate_object()'s list-preserving parsing is aisdk 1.5.0 behavior;
  # 1.4.x simplifies vectors and retries differently, so gate on version.
  capr_require_suggests("aisdk", "cap_aisdk_ask()", min_version = "1.5.0")
  model <- capr_aisdk_model(model, "capr_agent_invalid", "cap_aisdk_ask()")
  mode <- match.arg(mode)
  max_retries <- capr_assert_count(
    max_retries, "max_retries", condition = "capr_agent_invalid"
  )
  schema <- capr_aisdk_contract_schema()
  extra <- list(...)
  function(prompt) {
    result <- do.call(aisdk::generate_object, c(
      list(
        model = model,
        prompt = prompt,
        schema = schema,
        schema_name = "cap_contract_response",
        mode = mode,
        max_retries = max_retries
      ),
      extra
    ))
    result$object
  }
}
