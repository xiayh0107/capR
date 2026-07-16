# Project Status

> Updated: 2026-07-11

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
| Stable release | published | Committed evidence, exact-commit CI, annotated tag, and GitHub Release |
| Development | 1.1.0.9000 | Experimental grouped/ggplot support plus ten bounded complex-object families, tests, and documentation |

## Published release claim

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

## Stable release evidence

The committed `release-artifacts/capR-v1.0.0/` directory contains the source
package, fixture and interoperability reports, environment metadata, and
checksummed manifests. The annotated `capR-v1.0.0` tag and matching GitHub
Release assets identify the exact stable evidence commit.
