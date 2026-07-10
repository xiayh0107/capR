# CI and Release

## Required workflows

| Workflow | Gate |
|---|---|
| `r-cmd-check.yml` | Linux R 4.1/release, macOS release, Windows release |
| `docs.yml` | roxygen diff, local Markdown links, whitespace |
| `adapter-contract.yml` | Cross-platform extension contract |
| `conformance.yml` | Offline published L0-L3 fixtures |
| `schema-harness.yml` | Strict Draft 2020-12 schema/artifact validation |
| `interop.yml` | Independent standard-library structural comparison |
| `release.yml` | Explicit artifact preparation; never tags automatically |

Branch protection should require all non-release workflows. Failed checks
archive actionable logs or reports.

## Local release gates

```sh
Rscript -e 'roxygen2::roxygenise()'
Rscript -e 'testthat::test_local(stop_on_failure = TRUE)'
R CMD build .
_R_CHECK_CRAN_INCOMING_=FALSE R CMD check --as-cran --no-manual capR_*.tar.gz
Rscript -e 'library(capR); stopifnot(cap_run_fixtures()$ok)'
Rscript tools/generate-fixture-artifacts.R schema-artifacts
python3 tools/schema-harness/validate.py \
  --artifacts schema-artifacts --report schema-artifacts/schema-report.json
python3 tools/interop-harness/interop.py \
  --artifact-root schema-artifacts --output-dir schema-artifacts/interop
```

## Release evidence

```text
release-artifacts/capR-vX.Y.Z/
├── README.md
├── MANIFEST.md
├── MANIFEST.json
├── package/capR_X.Y.Z.tar.gz
├── reports/
│   ├── capr-digest-conformance.json
│   ├── capr-schema-harness.json
│   ├── capr-interop-primary.json
│   ├── capr-interop-structural.json
│   └── capr-interop-comparison.json
├── fixture-summary/summary.json
└── metadata/
    ├── DESCRIPTION
    ├── RELEASE.json
    ├── environment.json
    ├── sessionInfo.txt
    └── R-CMD-check.log
```

Generate only from a clean commit:

```sh
Rscript tools/release-artifacts.R capR-v1.0.0
git add release-artifacts/capR-v1.0.0
git commit -m "release: add capR v1.0.0 evidence"
Rscript tools/validate-release-manifest.R \
  release-artifacts/capR-v1.0.0
```

The source input revision is recorded in metadata. The committed artifact
commit is the tag target. Release files must be committed and all checks must
pass on that exact commit before an annotated tag is created.

## RC and stable sequence

1. Freeze API, docs, scope, security defaults, and vendored resources.
2. Set the RC package version, generate/commit RC evidence, run every workflow,
   and review blockers/claim wording.
3. Optionally publish the annotated `capR-v1.0.0-rc1` prerelease.
4. Resolve blockers, set version `1.0.0`, regenerate/commit stable evidence,
   and rerun the complete matrix.
5. Create annotated `capR-v1.0.0` at the exact evidence commit.
6. Upload the source archive, reports, summary, and manifests. Verify every
   uploaded asset against committed `MANIFEST.json`.
7. Open the feedback/security/errata window described in `ADOPTION.md`.

GitHub release is the v1.0 target. CRAN publication is independent and cannot
weaken evidence gates.
