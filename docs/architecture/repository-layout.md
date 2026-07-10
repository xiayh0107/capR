# Repository Layout

## Current bootstrap

This revision lands documentation only. Future R package files will be added in this same repository in controlled phases.

## Target repository tree

```text
capR/
├── DESCRIPTION
├── NAMESPACE
├── R/
│   ├── api-digest.R
│   ├── api-validate.R
│   ├── api-gate.R
│   ├── api-patch.R
│   ├── api-adapter.R
│   ├── api-registry.R
│   ├── adapter-object.R
│   ├── registry.R
│   ├── source-ref.R
│   ├── field-catalog.R
│   ├── planner.R
│   ├── materialize.R
│   ├── redaction.R
│   ├── render-text-v1.R
│   ├── manifest-v1.R
│   ├── validation-v1.R
│   ├── gate-v1.R
│   ├── patch-v1.R
│   ├── fallback.R
│   ├── errors.R
│   ├── adapter-table.R
│   └── zzz.R
├── inst/extdata/cap-digest/v1.0.0/
│   ├── schemas/
│   ├── fixtures/
│   ├── packs/
│   ├── reports/
│   └── VENDORING.md
├── tests/
│   ├── testthat/
│   ├── contract/
│   └── fixtures/
├── tools/
│   ├── vendor-cap-digest.R
│   ├── schema-harness/
│   ├── interop-harness.R
│   └── release-artifacts.R
├── vignettes/
├── exec/capr
├── docs/
├── release-artifacts/
└── .github/workflows/
```

## Placement rules

- R implementation code belongs in `R/`.
- Published upstream resources belong under a versioned `inst/extdata` path and are read-only.
- Development and release harnesses belong under `tools/`.
- End-user tutorials belong in `vignettes/`.
- Architecture and implementer documentation belongs in `docs/`.
- Generated package-site output must not overwrite the hand-written `docs/` source tree.
- Release evidence is committed under `release-artifacts/` before tagging.

## Local project state

A future user project may contain `.cap/`, but that directory is not part of the R package source tree and is not a CAP specification artifact.

```text
.cap/
├── registry/registry.lock.json
├── digests/<digest-id>/
│   ├── digest.txt
│   ├── manifest.json
│   └── resolution.capr.json
├── reports/
└── cache/
```

Canonical CAP artifacts and capR sidecars must remain distinguishable.
