# Project Status

> Updated: 2026-07-10

## Current state

| Area | State | Evidence |
|---|---|---|
| R package | implemented | Build, install, load, and R CMD check gates |
| Adapter runtime | implemented | Deterministic resolution, pinning, fallback, contract suite |
| Table L0/L1 | implemented | Byte-exact basic-table plus security/negative fixtures |
| Follow-up L2 | implemented | Validation, pure gate, typed patch, stale/pin checks |
| Pack host L3 | implemented | Fail-closed table-basic metadata host |
| Schema | implemented | Strict Draft 2020-12 development/release harness |
| Interoperability | implemented | Independent standard-library Python structural harness |
| CLI and docs | implemented | Public-API wrappers, vignettes, compatibility/security docs |
| Stable release | release candidate | Final committed artifacts, CI, tag, and GitHub Release pending |

## Release claim under review

```text
Implementation: capR 1.0.0
CAP-Digest: v1.0.0, cap-digest-v1.0.0
Level: L0-L3
Fixture scope: published v1.0 digest fixture suite
Stable source family: table
Stable R hosts: data.frame, tbl_df, data.table
```

This claim excludes remote/credentialed extraction, CAP-Core semantics,
arbitrary-object conformance, and scientific correctness. Community,
experimental, and fallback adapters remain separately labeled.

## Active release gate

Generate and commit `release-artifacts/capR-v1.0.0/`, validate its manifest,
pass every required GitHub check on the exact commit, then create the annotated
`capR-v1.0.0` tag and matching GitHub Release assets.
