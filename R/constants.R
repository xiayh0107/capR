# Central schema, version, and strategy-id constants. Runtime code resolves
# schema tags through capr_schema() so a future spec revision changes one
# table instead of scattered literals; tests and fixtures deliberately keep
# raw literals as the drift tripwire.

.capr_schemas <- c(
  # Canonical cap.* artifact schemas (pinned CAP-Digest v1.0).
  conformance_report = "cap.conformance_report.v1",
  digest = "cap.digest.v1",
  digest_pack = "cap.digest_pack.v1",
  digest_patch = "cap.digest_patch.v1",
  field = "cap.field.v1",
  field_catalog = "cap.field_catalog.v1",
  gate_result = "cap.gate_result.v1",
  manifest = "cap.manifest.v1",
  pack_conformance_report = "cap.pack_conformance_report.v1",
  pack_validation = "cap.pack_validation.v1",
  source_ref = "cap.source_ref.v1",
  validation_result = "cap.validation_result.v1",
  # capr.* implementation-namespace schemas.
  adapter = "capr.adapter.v1",
  adapter_contract_result = "capr.adapter_contract_result.v1",
  adapter_pin = "capr.adapter_pin.v1",
  agent_tool_result = "capr.agent_tool_result.v1",
  agent_transcript = "capr.agent_transcript.v1",
  agent_turn = "capr.agent_turn.v1",
  digest_pack_host = "capr.digest_pack_host.v1",
  materialization = "capr.materialization.v1",
  parsed_digest_text = "capr.parsed_digest_text.v1",
  planner = "capr.planner.v1",
  policy = "capr.policy.v1",
  registry_snapshot = "capr.registry_snapshot.v1",
  resolution = "capr.resolution.v1",
  resolution_diagnostics = "capr.resolution_diagnostics.v1",
  selection_plan = "capr.selection_plan.v1",
  snapshot_cache = "capr.snapshot_cache.v1",
  tokenizer = "capr.tokenizer.v1",
  vendor_lock = "capr.vendor_lock.v1",
  vendor_verification = "capr.vendor_verification.v1"
)

capr_schema <- function(name) {
  if (!is.character(name) || length(name) != 1L || is.na(name) ||
      !name %in% names(.capr_schemas)) {
    capr_abort(
      "capr_artifact_invalid",
      "unknown capR schema name",
      schema_name = name
    )
  }
  .capr_schemas[[name]]
}

.capr_cap_spec_version <- "2026-07-05-draft"

capr_manifest_versions <- function() {
  list(
    cap = .capr_cap_spec_version,
    text = "v1",
    fields = "f1",
    manifest = "v1"
  )
}

capr_catalog_versions <- function(catalog = "v1") {
  list(
    cap = .capr_cap_spec_version,
    fields = "f1",
    catalog = catalog
  )
}

.capr_default_planner_id <- "capr-greedy-value-cost-v1"
.capr_followup_planner_id <- "capr-approved-followup-v1"
.capr_default_tokenizer_id <- "heuristic_v1"

# Spec-bounded per-field render cap in characters; the contract probe allows
# the cap plus the "\n[truncated]" suffix.
.capr_render_char_cap <- 20000L
