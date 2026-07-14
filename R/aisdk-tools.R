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
