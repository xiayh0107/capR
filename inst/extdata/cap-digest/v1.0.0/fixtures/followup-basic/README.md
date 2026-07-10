# followup-basic

This fixture family exercises CAP-Digest Level 2 follow-up behavior.

It currently includes:

- `request-approved.json` — a model request for `f1:table@sample#k10`.
- `expected-validation-approved.json` — expected `cap.validation_result.v1` output.
- `expected-gate-approved.json` — expected `cap.gate_result.v1` output with a typed `cap.digest_patch.v1` patch.
- `expected-gate-stale.json` — expected stale-source gate output.

The fixture reuses the base digest and manifest from `fixtures/basic-table/`.
