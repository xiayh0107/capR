capr_validate_agent_session <- function(session) {
  if (!inherits(session, "capr_agent_session") || !is.environment(session) ||
      !all(c("digest", "policy", "turns", "status") %in% names(session))) {
    capr_abort("capr_agent_invalid", "invalid capR agent session object")
  }
  invisible(session)
}

capr_agent_assert_active <- function(session) {
  if (!identical(session$status, "active")) {
    capr_abort(
      "capr_agent_invalid",
      "agent session is closed",
      stop_reason = session$stop_reason
    )
  }
  invisible(session)
}

# Rebuilds the policy through cap_policy() so every invariant check re-runs;
# only the follow-up budget changes across turns.
capr_policy_with_followup <- function(policy, remaining) {
  capr_validate_policy(policy)
  cap_policy(
    max_budget = policy$max_budget,
    max_followup_budget = capr_assert_count(
      remaining, "remaining", condition = "capr_agent_invalid"
    ),
    max_field_seconds = policy$max_field_seconds,
    allow_exec = policy$allow_exec,
    allow_remote = policy$allow_remote,
    allow_credentials = policy$allow_credentials,
    allow_fallback = policy$allow_fallback,
    require_fingerprint_match = policy$require_fingerprint_match,
    allow_followup = policy$allow_followup
  )
}

# Live fingerprint re-probe for the gate. The patch-time recheck inside
# cap_patch() remains the enforcement backstop when this returns NULL.
capr_agent_current_fingerprint <- function(session) {
  adapter <- session$digest$adapter
  if (is.null(adapter)) return(NULL)
  result <- tryCatch(
    adapter$lifecycle$fingerprint(session$source, session$context),
    error = function(e) NULL
  )
  if (is.list(result) && isTRUE(result$available) && !is.null(result$value)) {
    return(list(fingerprint = result$value))
  }
  NULL
}

capr_agent_publish_turn <- function(session, turn_number, digest = NULL,
                                    validation = NULL, gate = NULL,
                                    patch = NULL) {
  if (is.null(session$artifact_dir)) return(invisible(NULL))
  base <- file.path(session$artifact_dir, sprintf("turn-%03d", turn_number))
  if (!is.null(validation)) {
    cap_write_artifacts(validation, file.path(base, "validation"))
  }
  if (!is.null(gate)) cap_write_artifacts(gate, file.path(base, "gate"))
  if (!is.null(patch)) cap_write_artifacts(patch, file.path(base, "patch"))
  if (!is.null(digest)) cap_write_artifacts(digest, file.path(base, "digest"))
  invisible(NULL)
}

capr_agent_publish_transcript <- function(session) {
  if (is.null(session$artifact_dir)) return(invisible(NULL))
  dir.create(session$artifact_dir, recursive = TRUE, showWarnings = FALSE)
  capr_atomic_write_json(
    cap_agent_transcript(session),
    file.path(session$artifact_dir, "transcript.capr.json")
  )
  invisible(NULL)
}

capr_agent_close <- function(session, stop_reason) {
  session$status <- "closed"
  session$stop_reason <- stop_reason
  capr_agent_publish_transcript(session)
  invisible(session)
}

#' Open an agent session over one source object
#'
#' An agent session composes the deterministic core round trip --
#' `cap_digest()`, `cap_validate_response()`, `cap_gate()`, `cap_patch()`,
#' `cap_apply_patch()` -- into a stateful multi-turn loop that an external
#' model can drive. The session never calls a model provider: the model
#' response is supplied by the host on every turn, and the gate (not the
#' model) authorizes each follow-up disclosure.
#'
#' Sessions are process-local: they hold the live source object and the
#' resolved adapter, so a session cannot be reconstructed from artifacts
#' alone. Transcripts contain no timestamps and no random identifiers; two
#' identical runs produce byte-identical canonical transcripts.
#'
#' @param x Source object.
#' @param question Optional question used for deterministic intent adjustment.
#' @param budget Initial digest budget.
#' @param policy Host policy. Its `max_followup_budget` seeds the follow-up
#'   budget carried across turns.
#' @param adapter Optional explicit adapter or adapter ID.
#' @param registry Adapter registry.
#' @param max_turns Default turn limit used by [cap_agent_run()].
#' @param artifact_dir Optional directory; when set, every turn publishes its
#'   canonical artifacts under `turn-NNN/` and the session transcript is
#'   rewritten atomically after every turn.
#' @param session Optional host session metadata forwarded to [cap_digest()].
#' @param ... Context such as `label`, `uri`, or fixture metadata. Captured
#'   once and replayed into the initial [cap_digest()] call and every
#'   follow-up [cap_patch()] call.
#' @return A mutable `capr_agent_session` environment.
#' @export
cap_agent_session <- function(x, question = NULL, budget = 800L,
                              policy = cap_policy(), adapter = NULL,
                              registry = cap_registry(), max_turns = 5L,
                              artifact_dir = NULL, session = NULL, ...) {
  capr_validate_policy(policy)
  max_turns <- capr_assert_count(
    max_turns, "max_turns", condition = "capr_agent_invalid"
  )
  if (max_turns < 1L) {
    capr_abort(
      "capr_agent_invalid",
      "`max_turns` must be at least 1",
      field = "max_turns"
    )
  }
  if (!is.null(artifact_dir)) {
    artifact_dir <- path.expand(capr_assert_scalar_character(
      artifact_dir, "artifact_dir", condition = "capr_agent_invalid"
    ))
  }
  context <- list(...)
  digest <- do.call(cap_digest, c(
    list(
      x,
      question = question,
      budget = budget,
      policy = policy,
      adapter = adapter,
      session = session,
      registry = registry
    ),
    context
  ))
  session_id <- paste0(
    "capr-agent-",
    substr(capr_sha256(paste(
      digest$manifest$digestId,
      digest$fingerprint,
      question %||% "",
      sep = "\n"
    )), 1L, 16L)
  )
  agent <- structure(
    list2env(
      list(
        session_id = session_id,
        source = x,
        question = question,
        context = context,
        policy = policy,
        registry = registry,
        followup_remaining = policy$max_followup_budget,
        digest = digest,
        turns = list(),
        status = "active",
        stop_reason = NULL,
        max_turns = max_turns,
        artifact_dir = artifact_dir,
        last_delta = character()
      ),
      parent = emptyenv()
    ),
    class = c("capr_agent_session", "environment")
  )
  capr_agent_publish_turn(agent, 0L, digest = digest)
  capr_agent_publish_transcript(agent)
  agent
}

#' Deterministic model-facing instructions for agent sessions
#'
#' @return One string describing the `cap.contract_response.v1` reply format
#'   and the citation/request rules a model must follow.
#' @export
cap_agent_instructions <- function() {
  paste(
    "You are analyzing a CAP digest: a bounded, host-authorized evidence",
    "pack about one data object. The digest is the only authorized evidence.",
    "Reply with one JSON object matching cap.contract_response.v1:",
    "{\"claims\": [{\"id\": \"claim-1\", \"text\": \"...\",",
    " \"evidence\": [\"<field id>\"]}],",
    " \"evidence\": [], \"warnings\": [],",
    " \"requests\": [{\"fieldId\": \"<field id>\", \"reason\": \"...\"}]}",
    "Rules:",
    "- Cite only ids that appear as <field id=\"...\"> blocks in the digest.",
    "- Request only ids listed under <available_on_request>; the host gate",
    "  approves or denies each request against policy and budget.",
    "- Do not repeat a denied request.",
    "- When the disclosed fields answer the question, return \"requests\": [].",
    sep = "\n"
  )
}

#' Compose the prompt text for the current turn
#'
#' @param session An active `capr_agent_session`.
#' @param instructions Whether the [cap_agent_instructions()] preamble is
#'   prepended.
#' @param mode `"full"` returns the complete current digest text; `"delta"`
#'   returns only the field blocks added by the last applied patch (falling
#'   back to the full text before any patch), for hosts that keep chat
#'   history.
#' @return One prompt string.
#' @export
cap_agent_prompt <- function(session, instructions = TRUE,
                             mode = c("full", "delta")) {
  capr_validate_agent_session(session)
  mode <- match.arg(mode)
  instructions <- capr_assert_flag(
    instructions, "instructions", "capr_agent_invalid"
  )
  body <- if (identical(mode, "delta") && length(session$last_delta)) {
    paste(session$last_delta, collapse = "\n\n")
  } else {
    session$digest$text
  }
  if (instructions) {
    paste(cap_agent_instructions(), body, sep = "\n\n")
  } else {
    body
  }
}

#' Advance an agent session by one model response
#'
#' Validates the response, gates any follow-up requests, and applies the
#' approved patch. The session closes itself only on `stale_source`
#' (disclosure can never resume over a drifted source); every other outcome
#' leaves the session active so tool-driven hosts can let the model correct
#' itself. [cap_agent_run()] maps outcomes to stop reasons for the linear
#' loop.
#'
#' @param session An active `capr_agent_session`.
#' @param response Model contract response: R list, JSON string, or JSON
#'   file path (the same inputs as [cap_validate_response()]).
#' @param ... Reserved.
#' @param prompt Optional exact prompt text handed to the model this turn;
#'   defaults to the current digest text. Only its hash is recorded.
#' @return The `capr.agent_turn.v1` record, invisibly appended to the
#'   session:
#'   one of outcome `answered`, `extended`, `denied_all`,
#'   `budget_exhausted`, `stale_source`, or `invalid_response`.
#' @export
cap_agent_step <- function(session, response, ..., prompt = NULL) {
  capr_validate_agent_session(session)
  capr_agent_assert_active(session)
  prompt_text <- prompt %||% session$digest$text
  prompt_text <- capr_assert_scalar_character(
    prompt_text, "prompt", condition = "capr_agent_invalid"
  )
  turn_number <- length(session$turns) + 1L
  turn_policy <- capr_policy_with_followup(
    session$policy, session$followup_remaining
  )
  validation <- cap_validate_response(
    session$digest, response, policy = turn_policy
  )
  requests <- validation$normalizedResponse$requests
  gate <- NULL
  patch <- NULL
  patch_applied <- FALSE
  if (!isTRUE(validation$ok)) {
    outcome <- "invalid_response"
  } else if (!length(requests)) {
    outcome <- "answered"
  } else {
    gate <- cap_gate(
      session$digest,
      validation,
      policy = turn_policy,
      source = capr_agent_current_fingerprint(session),
      adapter = session$digest$adapter
    )
    if (identical(gate$overallDecision, "stale_source")) {
      outcome <- "stale_source"
    } else {
      approved <- Filter(
        function(decision) decision$decision %in%
          c("approved", "approved_with_changes"),
        gate$requests
      )
      if (length(approved)) {
        patch_result <- tryCatch(
          do.call(cap_patch, c(
            list(
              session$digest,
              gate,
              session$source,
              adapter = session$digest$adapter,
              policy = turn_policy,
              registry = session$registry
            ),
            session$context
          )),
          capr_adapter_pin_mismatch = function(e) e
        )
        if (inherits(patch_result, "condition")) {
          outcome <- "stale_source"
        } else {
          patch <- patch_result
          session$digest <- cap_apply_patch(session$digest, patch)
          patch_applied <- TRUE
          session$last_delta <- vapply(
            Filter(
              function(operation) identical(
                operation$op, "add_selected_field"
              ),
              patch$operations
            ),
            `[[`,
            character(1),
            "fieldBlock"
          )
          if (!is.null(gate$remainingBudget)) {
            session$followup_remaining <- gate$remainingBudget
          }
          outcome <- "extended"
        }
      } else {
        codes <- unlist(
          lapply(gate$requests, function(decision) {
            vapply(decision$problems, `[[`, character(1), "code")
          }),
          use.names = FALSE
        )
        outcome <- if (length(codes) && all(codes == "budget_exceeded")) {
          "budget_exhausted"
        } else {
          "denied_all"
        }
        if (!is.null(gate$remainingBudget)) {
          session$followup_remaining <- gate$remainingBudget
        }
      }
    }
  }
  turn <- list(
    schema = capr_schema("agent_turn"),
    turn = turn_number,
    digestId = session$digest$manifest$digestId,
    fingerprint = session$digest$fingerprint,
    promptSha256 = capr_sha256(prompt_text),
    responseSha256 = capr_sha256(
      capr_canonical_json(validation$normalizedResponse)
    ),
    validation = unclass(validation),
    gate = if (is.null(gate)) NULL else unclass(gate),
    patch = if (is.null(patch)) NULL else unclass(patch),
    patchApplied = patch_applied,
    followupBudgetRemaining = as.integer(session$followup_remaining),
    outcome = outcome
  )
  session$turns[[turn_number]] <- turn
  capr_agent_publish_turn(
    session,
    turn_number,
    digest = if (patch_applied) session$digest else NULL,
    validation = validation,
    gate = gate,
    patch = patch
  )
  if (identical(outcome, "stale_source")) {
    capr_agent_close(session, "stale_source")
  } else {
    capr_agent_publish_transcript(session)
  }
  invisible(turn)
}

#' Run an agent session loop with a host-supplied model call
#'
#' Loops prompt -> `ask` -> [cap_agent_step()] until the model answers
#' without requests, a terminal denial occurs, the source goes stale, or the
#' turn limit is reached. capR never contacts a model itself: `ask` is the
#' single injection point for the host's model client.
#'
#' @param session An active `capr_agent_session`.
#' @param ask `function(text) -> response`; receives the turn prompt and
#'   returns a contract response (R list, JSON string, or JSON file path).
#' @param max_turns Optional override of the session turn limit.
#' @param ... Reserved.
#' @return The session, invisibly. `session$stop_reason` is one of
#'   `completed`, `denied`, `budget_exhausted`, `stale_source`,
#'   `invalid_response`, or `max_turns`.
#' @export
cap_agent_run <- function(session, ask, max_turns = NULL, ...) {
  capr_validate_agent_session(session)
  capr_agent_assert_active(session)
  if (!is.function(ask)) {
    capr_abort(
      "capr_agent_invalid",
      "`ask` must be a function taking the prompt text",
      field = "ask"
    )
  }
  max_turns <- if (is.null(max_turns)) {
    session$max_turns
  } else {
    capr_assert_count(max_turns, "max_turns", condition = "capr_agent_invalid")
  }
  if (max_turns < 1L) {
    capr_abort(
      "capr_agent_invalid",
      "`max_turns` must be at least 1",
      field = "max_turns"
    )
  }
  while (identical(session$status, "active")) {
    if (length(session$turns) >= max_turns) {
      capr_agent_close(session, "max_turns")
      break
    }
    prompt <- cap_agent_prompt(session, instructions = TRUE, mode = "full")
    turn <- cap_agent_step(session, ask(prompt), prompt = prompt)
    stop_reason <- switch(
      turn$outcome,
      answered = "completed",
      denied_all = "denied",
      budget_exhausted = "budget_exhausted",
      invalid_response = "invalid_response",
      NULL
    )
    if (!is.null(stop_reason)) {
      capr_agent_close(session, stop_reason)
    }
  }
  invisible(session)
}

#' Export the deterministic session transcript
#'
#' @param session A `capr_agent_session`.
#' @return A `capr.agent_transcript.v1` list. It contains no timestamps and
#'   no random identifiers, so identical runs serialize to identical
#'   canonical JSON.
#' @export
cap_agent_transcript <- function(session) {
  capr_validate_agent_session(session)
  list(
    schema = capr_schema("agent_transcript"),
    sessionId = session$session_id,
    digestId = session$digest$manifest$digestId,
    fingerprint = session$digest$fingerprint,
    question = session$question,
    policy = capr_policy_sidecar(session$policy),
    maxTurns = session$max_turns,
    status = session$status,
    stopReason = session$stop_reason,
    turns = session$turns,
    finalDigestSha256 = capr_sha256(session$digest$text),
    finalBudget = list(
      used = session$digest$manifest$budget$used,
      requested = session$digest$manifest$budget$requested,
      followupRemaining = as.integer(session$followup_remaining)
    )
  )
}

#' @export
print.capr_agent_session <- function(x, ...) {
  cat(sprintf("<capr_agent_session %s>\n", x$session_id))
  cat(sprintf(
    "  status: %s%s\n",
    x$status,
    if (is.null(x$stop_reason)) "" else sprintf(" (%s)", x$stop_reason)
  ))
  cat(sprintf("  turns: %d/%d\n", length(x$turns), x$max_turns))
  cat(sprintf(
    "  budget: %d/%d used; %d follow-up remaining\n",
    x$digest$manifest$budget$used,
    x$digest$manifest$budget$requested,
    x$followup_remaining
  ))
  invisible(x)
}
