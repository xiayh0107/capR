# ADR-0006: Agentic companion layer over the deterministic core

- Status: Accepted
- Date: 2026-07-14

## Context

The quickstart documents a ten-step agent pipeline (digest -> send text to a
model -> validate -> gate -> patch -> apply -> re-send), but capR shipped no
code that closes that loop: every host had to hand-write the round trip, and
no LLM framework could drive a digest natively. Anthropic's
workflow-vs-agent guidance frames the fix: the deterministic core is the
auditable workflow substrate and must stay that way; the missing piece is an
opt-in agentic layer where a model dynamically requests evidence while the
host gate keeps authorizing each disclosure.

## Decision

Three additive layers compose the untouched core
(`cap_digest`/`cap_validate_response`/`cap_gate`/`cap_patch`/`cap_apply_patch`):

1. **Base-R agent sessions** (`R/agent-session.R`): `cap_agent_session()`
   holds the live object, the resolved adapter, and the cross-turn follow-up
   budget (the gate itself is stateless per call). `cap_agent_step()`
   advances one model response through the full validate -> gate -> patch ->
   apply path; `cap_agent_run()` loops a host-supplied
   `ask(function(text) -> response)` until answered, denied,
   budget-exhausted, stale, invalid, or the turn limit. Sessions close
   themselves only on `stale_source` (fail-closed; disclosure never resumes
   over a drifted source). Transcripts (`capr.agent_transcript.v1`) and turn
   records (`capr.agent_turn.v1`) live in the `capr.*` implementation
   namespace, embed the canonical artifacts, contain no timestamps or random
   ids, and serialize byte-identically across identical runs. With
   `artifact_dir`, each turn publishes canonical `turn-NNN/` artifact
   directories via `cap_write_artifacts()` plus an atomically rewritten
   transcript sidecar.
2. **Provider-neutral tools** (`R/agent-tools-core.R`): four fine-grained
   tool implementations (`capr_read_digest`, `capr_request_fields`,
   `capr_submit_claims`, `capr_session_status`) in base R. Fine granularity
   follows the agent-computer-interface principle -- each tool returns a
   targeted, self-correcting result -- and costs no safety because every
   mutating call is synthesized into a full `cap.contract_response.v1` and
   pushed through the core. Model-input mistakes come back as structured
   error payloads so a tool loop can self-correct; session invariants keep
   failing closed. Tool-driven steps do not close the session (except
   staleness), so a model may be denied and still submit claims.
3. **aisdk adapter** (`R/aisdk-tools.R`, Suggests-only): `cap_aisdk_tools()`
   wraps the neutral implementations in `aisdk::tool()` objects with
   explicit `z_object()` schemas; `cap_aisdk_agent()` binds them to an
   `aisdk::create_agent()` whose system prompt is
   `cap_agent_instructions()`. aisdk was chosen over ellmer by project
   direction; because the tool logic lives in the neutral layer, an ellmer
   adapter would be a thin addition, not a rewrite.

Dependency posture: `Imports` stays exactly `digest, jsonlite, methods`.
aisdk enters `Suggests` only, guarded by `capr_require_suggests()`
(`capr_dependency_missing` condition). aisdk is not on CRAN at the time of
this decision; hosts install it from GitHub (documented in the vignette),
and a CRAN release of capR would need `Additional_repositories` or a
Suggests review before submission.

MCP exposure is **deferred**: aisdk 1.5.0 ships only a client-side
`openai_hosted_mcp_tool` and no MCP server. When a host needs one, the
recorded alternative is posit-dev `mcptools` (which consumes ellmer tools)
over the same provider-neutral layer, or a future aisdk server surface.

## Consequences

A model can now drive the digest loop natively while every disclosure is
still decided by `cap_gate()` under host policy -- the model gained a
steering wheel, not keys to the vault. The zero-network invariant holds: the
package constructs tool/agent objects but never performs a model call.
Sessions are process-local by design (they require the live object and
pinned catalog that `cap_read_artifacts()` cannot restore). All new exports
are experimental and inherit no conformance claim; the conformance fixtures
and interop harness are unaffected.

## Amendment (2026-07-14, post-review)

An execution-verified review plus a literature pass amended three points:

1. **Bounded self-correction (partially reverses "no auto-retry in v1").**
   Research on agent self-correction consistently finds that concrete,
   execution-based validation feedback substantially improves correction
   rates, while unbounded retry loops are an availability risk needing an
   explicit correction budget. capR has exactly such a validator, so
   `cap_agent_run(max_repairs = 0L)` now offers an opt-in, bounded repair
   loop that feeds `cap_validate_response()` findings back verbatim.
   The default remains fail-closed; only validation failures (never
   deterministic gate denials) are repairable.
2. **Grounding metrics.** Attribution research treats verifiable grounding
   as a deployment prerequisite; each turn now carries a deterministic
   `capr.agent_grounding.v1` block computed against the pre-step manifest.
3. **Spotlighting.** In line with data/control-flow-separation defenses
   (CaMeL and successors), the instruction constant declares digest content
   untrusted, and instruction-bearing prompts fence it between explicit
   BEGIN/END markers. The gate remains the actual enforcement point; the
   framing only reduces model confusion.

The same review narrowed the tool layer's condition handling to
`capr_agent_invalid` (host bugs must propagate), added closure-environment
fingerprints to strategy registration, and made tokenizer failures
uniformly typed.

## Amendment (2026-07-15, dependency posture and bridges)

Two statements above have been overtaken by facts, and the integration
gained a second direction:

1. **CRAN status corrected.** "aisdk is not on CRAN" is no longer true:
   aisdk 1.4.12 has been on CRAN since 2026-06-02. A CRAN release of capR
   no longer needs `Additional_repositories` for the aisdk Suggests entry.
2. **MCP exposure re-planned.** aisdk core still ships no MCP server, but
   the family satellite `aisdk.mcp` (MCP client + server) now exists. MCP
   exposure of the capR tool surface is now planned through the
   `aisdk.evidence` bridge satellite over `aisdk.mcp`, superseding the
   mcptools-only fallback recorded above (which stays valid for ellmer
   hosts).
3. **Reverse-direction bridges added.** `cap_aisdk_tokenizer()` (budget
   accounting through `aisdk::count_tokens()`: Anthropic-native exact
   counts with heuristic fallback, pinned like any custom tokenizer) and
   `cap_aisdk_ask()` (a schema-constrained `ask` factory for
   `cap_agent_run()` over `aisdk::generate_object()` structured output)
   complement the tools/agent adapters above. aisdk stays Suggests-only,
   and the model/network call still happens inside aisdk on the host's
   behalf -- never in capR core.

## Alternatives

A monolithic "submit one contract-response JSON" tool was rejected: composing
that JSON inside one tool argument is the highest-error format for models,
and request/claim lifecycles differ inside a tool loop. Making the session
an R6 class was rejected for consistency with the package's classed-
environment state pattern (`capr_registry`). Auto-retrying invalid responses
inside `cap_agent_run()` was rejected for v1: fail-closed is the safer
default, and tool-mode hosts already get self-correction by keeping the
session open.
