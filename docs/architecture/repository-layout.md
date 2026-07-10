# Repository Layout

## Current package

The v1.0 implementation, documentation, vendored resources, tests, CLI, and
release harnesses share this repository.

## Target repository tree

```text
capR/
├── DESCRIPTION
├── NAMESPACE
├── R/
│   ├── digest.R
│   ├── validation.R
│   ├── gate.R
│   ├── patch.R
│   ├── adapter.R
│   ├── registry.R
│   ├── table-adapter.R
│   ├── planner.R
│   ├── materialize.R
│   ├── text.R
│   ├── manifest.R
│   ├── artifacts.R
│   ├── fallback.R
│   ├── policy.R
│   ├── pack.R
│   ├── conformance.R
│   ├── vendor.R
│   ├── contract.R
│   ├── provenance.R
│   ├── conditions.R
│   └── utils.R
├── inst/extdata/cap-digest/v1.0.0/
│   ├── schemas/
│   ├── fixtures/
│   ├── packs/
│   ├── reports/
│   ├── VENDOR-LOCK.json
│   └── UPSTREAM-LICENSE
├── tests/
│   ├── testthat/
│   ├── contract/
│   └── fixtures/
├── tools/
│   ├── vendor-cap-digest.R
│   ├── schema-harness/
│   ├── interop-harness/
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
