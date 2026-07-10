# Contributing

capR implements a versioned protocol surface. Changes must preserve the
boundary between upstream CAP-Digest requirements and capR implementation
choices.

## Local verification

```sh
Rscript -e 'roxygen2::roxygenise()'
Rscript -e 'testthat::test_local(stop_on_failure = TRUE)'
R CMD build .
_R_CHECK_CRAN_INCOMING_=FALSE R CMD check --as-cran --no-manual capR_*.tar.gz
Rscript -e 'library(capR); stopifnot(cap_run_fixtures()$ok)'
Rscript tools/generate-fixture-artifacts.R schema-artifacts
python3 tools/schema-harness/validate.py --artifacts schema-artifacts
python3 tools/interop-harness/interop.py \
  --artifact-root schema-artifacts \
  --output-dir schema-artifacts/interop
```

The strict schema dependencies are pinned in
`tools/schema-harness/requirements.txt` and remain outside runtime Imports.

## Required GitHub checks

Branch protection should require:

- `R CMD check` for Linux R 4.1.0/release, macOS release, Windows release;
- `Documentation and hygiene`;
- `Adapter contract`;
- `CAP-Digest conformance`;
- `Draft 2020-12 schema harness`;
- `Independent interoperability`.

Check failures must retain actionable logs/reports. No workflow publishes a tag
automatically.

## Change classification

Classify a contribution as documentation, capR implementation, adapter
extension, fixture/conformance, security, or suspected upstream ambiguity.
Public behavior, adapter contract, policy defaults, sidecar formats,
conformance language, or release evidence changes require documentation and
`CHANGELOG.md` updates; major changes require an ADR.

## Adapter contributions

Document identity, provider, host classes, source family, maturity, semantic
level, field catalog, execution/privacy behavior, contract results, and exact
claim. Community adapters must use qualified field names and cannot inherit
the built-in table claim. Start from the
[adapter template](docs/adapters/adapter-template.md).

## Vendored and generated files

Vendored CAP resources are read-only. Update only through
`tools/vendor-cap-digest.R` against a reviewed published tag/commit, then
verify every checksum and rerun all gates. Generated `NAMESPACE` and `man/`
must match roxygen sources. Release artifacts are generated from a clean
commit, committed before tagging, and validated again after commit.

## Review red lines

Reject changes that add class-specific orchestration after adapter resolution,
silently choose among equal adapters, serialize executable bindings, render
before redaction, hide failed fields, let model output invoke extractors,
accept stale fingerprints/pins, mutate expected fixtures, or broaden claims
without fixture evidence.
