# Troubleshooting

## Adapter not found

`capr_adapter_not_found` means no explicit, S3, or registered adapter matched.
Fallback is disabled by default. Inspect `class(x)`,
`cap_list_adapters()`, and `cap_resolution_diagnostics()`; do not enable
fallback when domain semantics are required.

## Adapter ambiguity or pin mismatch

Equal effective registry matches fail with `capr_adapter_ambiguous`. Remove
the conflict or set an explicit adapter. Follow-up requires the original
adapter identity/provider/binding signature; reinstalling or modifying an
adapter can intentionally cause `capr_adapter_pin_mismatch`.

## Evidence validation fails

Evidence IDs must exist in `manifest$fields`, have `selected = true`, and
appear as text anchors. A requestable field is not evidence until a gate
approves it and a patch is materialized/applied.

## Gate denies a request

Inspect `gate$requests[[i]]$problems`. Common causes are invalid evidence,
unknown/already-selected fields, interactive timing mismatch, stale source,
over-budget request, denied execution class, or disabled follow-up. The gate
never runs an extractor.

## Fixture, schema, or interop drift

Run:

```sh
Rscript -e 'library(capR); print(cap_run_fixtures())'
Rscript tools/generate-fixture-artifacts.R schema-artifacts
python3 tools/schema-harness/validate.py --artifacts schema-artifacts
python3 tools/interop-harness/interop.py \
  --artifact-root schema-artifacts --output-dir schema-artifacts/interop
```

Do not update expected artifacts to hide a mismatch. Verify the vendor lock,
identify the exact field/path/finding difference, and decide whether the defect
is in capR or requires a reviewed upstream erratum.

## R CMD check and CRAN incoming

capR is a GitHub-first package and conflicts case-insensitively with an
unrelated CRAN package name. Local `--as-cran` verification therefore disables
only the CRAN incoming-name service:

```sh
_R_CHECK_CRAN_INCOMING_=FALSE R CMD check --as-cran --no-manual capR_*.tar.gz
```

All package, code, documentation, test, portability, and example checks still
run.
