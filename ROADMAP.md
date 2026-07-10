# Roadmap

Detailed gates and deliverables are in [docs/roadmap/implementation-plan.md](docs/roadmap/implementation-plan.md).

## Phase 0 — Documentation baseline

- [x] Define project scope and non-goals.
- [x] Define the future repository layout.
- [x] Define the source adapter contract.
- [x] Define registry resolution and conflict behavior.
- [x] Define canonical artifact and sidecar boundaries.
- [x] Define runtime and extension API drafts.
- [x] Define testing, conformance, CI, and release guidance.
- [x] Record initial ADRs.

Exit criterion: architecture can be reviewed without reading implementation code.

## Phase 1 — R package bootstrap

- [ ] Add `DESCRIPTION`, `NAMESPACE`, `R/`, `tests/`, `inst/`, and `tools/`.
- [ ] Select minimum R version and dependency policy.
- [ ] Add testthat edition 3 and cross-platform R CMD check.
- [ ] Add internal condition classes and deterministic utilities.

Exit criterion: empty but valid R package passes R CMD check.

## Phase 2 — Adapter runtime foundation

- [ ] Implement `cap_adapter()` as the single S3 bridge.
- [ ] Implement adapter objects, registration, resolution, ambiguity errors, and provenance.
- [ ] Implement structural fallback behind an explicit policy.
- [ ] Add adapter contract tests.

Exit criterion: adapter selection is deterministic, inspectable, and fail-closed.

## Phase 3 — Table-family MVP

- [ ] Vendor CAP-Digest v1.0 resources and provenance.
- [ ] Implement the `data.frame` table adapter and the full digest/manifest path.
- [ ] Match `basic-table` and `security-adversarial` behavior.

Exit criterion: a table digest and manifest are stable and fixture-compatible.

## Phase 4 — Validation, follow-up, and L3 path

- [ ] Implement response validation, gate, patch, and pack metadata hosting.
- [ ] Emit conformance and independent structural reports.

Exit criterion: the published L0-L3 fixture path is reproducible.

## Phase 5 — RC and stable release

- [ ] Prepare release artifacts and manifests.
- [ ] Publish security, adoption, and compatibility statements.
- [ ] Run RC blocker review and publish the GitHub release.

A stable release does not automatically add non-table adapters to the CAP conformance scope.
