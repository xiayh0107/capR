# Changelog

## 1.1.0 - Unreleased

### Documentation refactor (human-first)

- Rewrote the README to lead with the problem and a faithful annotated
  digest example instead of protocol vocabulary; scope and claims moved
  into plain language without weakening them.
- Added `docs/concepts.md`: the records-office mental model, the six core
  nouns, the round-trip diagram, the never-happens invariants, and a
  jargon decoder for every spec term used in deeper docs.
- Rebuilt `docs/index.md` from a numbered link dump into a guided map
  organized by reader goal (start here / use it / extend it / trust it /
  internals) with one-line descriptions.
- Rewrote the getting-started vignette as a real tutorial that teaches how
  to *read* a digest (header meter, citable field blocks, redaction proof,
  the requestable boundary) and shows validation failing on an undisclosed
  citation.

### Agent layer hardening and evidence features (review-driven)

- Grounding metrics: every agent turn now records a deterministic
  `capr.agent_grounding.v1` block (claims, grounded claims, ungrounded
  claim ids, cited fields, undisclosed citations, unused disclosed fields),
  judged against the fields disclosed when the model answered; transcripts
  expose the final turn's block as `finalGrounding`.
- Bounded self-correction: `cap_agent_run(max_repairs =)` optionally
  retries `invalid_response` turns with the validator's exact findings fed
  back into the prompt. Default stays `0L` (fail-closed); repair turns
  count toward `max_turns`; gate denials are never retried. Transcripts
  record `repairsUsed`.
- Prompt hardening: `cap_agent_instructions()` now declares digest content
  as untrusted data, and instruction-bearing prompts fence the digest
  between explicit BEGIN/END markers (spotlighting). `cap_agent_run()`
  gains an `instructions` cadence knob (`every`/`first`/`none`).
- Fail-closed fixes: the tool layer now catches only `capr_agent_invalid`,
  so host/library bugs propagate instead of being replayed to the model;
  `last_delta` resets every step (no stale delta prompts); reopening an
  `artifact_dir` clears stale `turn-NNN/` directories; turns record
  `gateSuperseded` when a gate approval was refused by the patch-time
  fingerprint recheck.
- Strategy seam fixes: tokenizer `count` failures and time-limit hits now
  always surface as `capr_tokenizer_invalid` (never a raw `simpleError`),
  with the cause as `parent`; strategy registration fingerprints closure
  environments, so parameterized strategies with identical source conflict
  instead of silently keeping the first implementation; `cap_patch()`
  cross-checks the digest's process-local tokenizer against the manifest
  accounting pin; empty `cap_list_planners()`/`cap_list_tokenizers()` keep
  their `id` column.

### Strategy seams (experimental)

- Added pluggable selection planners (`cap_planner()`,
  `cap_register_planner()`, `cap_unregister_planner()`,
  `cap_list_planners()`) and budget tokenizers (`cap_tokenizer()`,
  `cap_register_tokenizer()`, `cap_unregister_tokenizer()`,
  `cap_list_tokenizers()`), threaded through `cap_digest()` and
  `cap_patch()` as trailing arguments. Custom strategies control ordering
  and accounting only: eligibility filtering, execution authorization, the
  budget commit walk, and gate rules stay in the runtime, and rankings are
  validated as exact permutations. Defaults remain byte-identical; custom
  ids are stamped into the plan, the digest text header, every manifest
  row, and a new omit-when-default `strategies` sidecar block. Patches are
  pinned to the digest's accounting tokenizer.
- Added `cap_calibrate_costs()`: measures actual per-field costs against
  catalog estimates without mutating any catalog (recosting stays an
  explicit adapter-authoring decision).
- Added a `capr.*` options layer for default magnitudes only
  (`capr.default_budget`, `capr.max_budget`, `capr.max_followup_budget`,
  `capr.max_field_seconds`, `capr.extra_high_risk_classes` -- the last is
  append-only and can only extend fallback refusals). Permissions,
  strategy selection, and redaction are deliberately not option-
  configurable, and `cap_run_fixtures()` clears all capr.* options while
  running so conformance evidence stays hermetic.
- Centralized all schema tags, spec version strings, strategy ids, and the
  render cap in `R/constants.R` (`capr_schema()`); gate problem messages
  moved to a code-keyed table. Zero behavior change; tests and fixtures
  keep raw literals as the drift tripwire.

### Agentic companion layer (experimental)

- Added `cap_agent_session()`, `cap_agent_prompt()`, `cap_agent_step()`,
  `cap_agent_run()`, `cap_agent_transcript()`, and
  `cap_agent_instructions()`: a base-R, provider-agnostic session that runs
  the documented digest -> validate -> gate -> patch loop with cross-turn
  follow-up budget carry, fail-closed terminal outcomes, deterministic
  (timestamp-free, content-addressed) transcripts, and optional per-turn
  canonical artifact publishing.
- Added `cap_aisdk_tools()` and `cap_aisdk_agent()` (Suggests-only aisdk
  integration): a session becomes four native aisdk tools --
  `capr_read_digest`, `capr_request_fields`, `capr_submit_claims`,
  `capr_session_status` -- so an aisdk agent can drive the loop while the
  host gate keeps authorizing every disclosure. The package still ships zero
  network code and never calls a model provider.
- Added the `agentic-workflow` vignette, ADR-0006, and the
  `capr_agent_invalid` / `capr_dependency_missing` condition classes.
- Added `cap_aisdk_tokenizer()`: a budget tokenizer over
  `aisdk::count_tokens()` for model-exact accounting (Anthropic-native
  counting endpoint; aisdk's local heuristic for other providers and as
  offline fallback), stamped and patch-pinned like any custom tokenizer.
- Added `cap_aisdk_ask()`: a schema-constrained `ask` factory for
  `cap_agent_run()` over `aisdk::generate_object()` structured output
  (forced tool call or JSON mode), so model replies parse as
  `cap.contract_response.v1` by construction while
  `cap_validate_response()` stays the semantic authority.
- MCP server exposure remains deferred from capR itself; ADR-0006 (as
  amended) records the plan to expose the tool surface through the
  aisdk.evidence bridge satellite over aisdk.mcp.

### Documentation

- Added an executable Chinese quickstart vignette covering the complete
  digest, response validation, gated follow-up, patch, artifact I/O, fixture,
  and CLI workflow.
- Added an executable advanced Chinese vignette using a mixed-type,
  multi-center sequencing QC table to demonstrate two-round evidence
  disclosure, redaction, escaping, gated sampling, and artifact round-trips.
- Added an executable cross-object vignette showing the stable plain-tibble
  path, explicit grouped-table semantics, fail-closed ggplot resolution, and
  the bounded declarative plot adapter.
- Added a systematic Chinese complex-object vignette covering the research
  taxonomy, why each family exists, official-source map, selection guide,
  hard limits, executable metadata-only examples, and non-inference rules.
- Added a class matrix and safety guide for ten public complex-object descriptor
  families, including delayed/materialization and lazy/live query boundaries.

### Experimental adapters

- Added public, opt-in adapters for grouped and rowwise tibbles and for bounded
  ggplot specifications. Both are experimental and have
  `conformance_claim = "none"`.
- Added public, explicit descriptor constructors for nested, array, relational,
  temporal, spatial, graph, scientific, model, visual, and lazy/live objects.
  All expose bounded metadata only and have `conformance_claim = "none"`.
- Added `cap_db_schema()` for validated table/type/primary-key/foreign-key
  declarations that can be digested without DBI or database access.

### Runtime

- Canonical manifest `elapsedMs` values are normalized to zero for every
  source family so scheduler timing cannot make otherwise identical artifacts
  differ; measured time remains available in process-local materialization
  outcomes.
- Generated-adapter pins now cover lifecycle functions and an explicit
  implementation spec; descriptor snapshots are normalized once per digest,
  and the adapter contract suite probes every locally authorized field.
- Structural fallback now strips ordinary S3 classes before introspection and
  rejects S4, delayed, declarative-execution, and live/external hosts instead
  of invoking their methods.
- Complex descriptors strip classed metadata before indexing, cap container,
  rank, component, and XML traversal, keep environment/R6 frames opaque,
  and pin snapshot/helper implementations in adapter signatures.
- Declared database schemas now revalidate canonical structure and a
  deterministic consistency seal at Digest time; malformed class spoofs,
  post-construction mutation, and non-semantic key-vector names fail closed or
  are excluded before artifact rendering.

### Scope

- The published stable claim remains limited to the CAP-Digest v1.0 table
  fixtures and the documented local `data.frame`, `tbl_df`, and `data.table`
  hosts; the new experimental adapters do not inherit that claim.
- The ggplot adapter inspects bounded declarations and data schema only. It
  does not build plots, execute statistics or mappings, inspect pixels, or
  establish scientific or visual correctness.
- Complex-object descriptors do not disclose payload values or execute object
  behavior. Delayed/file-backed arrays are not materialized, and live/lazy
  objects are not queried, collected, opened, or dereferenced.
- No canonical schema, CLI, fixture, or stable conformance claim changes.

## 1.0.0 - 2026-07-10

### Added

- Deterministic adapter objects, S3 bridge, registry lifecycle, ambiguity
  failures, provenance pinning, host policy, and bounded structural fallback.
- Stable table-family path for `data.frame`, `tbl_df`, and `data.table`.
- CAP-Digest text=v1 rendering/parsing, canonical manifest and artifact I/O,
  redaction-before-rendering, guarded extraction, and deterministic planning.
- Contract-response validation, pure follow-up gate, typed digest patch
  materialization/application, and fail-closed table-basic Pack hosting.
- Reusable adapter contract suite and offline CAP-Digest v1.0 L0-L3 runner.
- Strict Draft 2020-12 schema harness and independent structural
  interoperability/comparison harness.
- `capr` CLI, user/adapter vignettes, release artifact packager, manifest
  validator, and cross-platform workflows.
- Pinned CAP-Digest `cap-digest-v1.0.0` resources with per-file SHA-256
  provenance.

### Scope

- Conformance is limited to the published v1.0 fixtures and `table` source
  family.
- Remote/credentialed extraction, CAP-Core semantics, arbitrary-object
  conformance, and scientific correctness are not claimed.
