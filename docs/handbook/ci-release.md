# CI and Release

## Planned workflows

```text
r-cmd-check.yml
adapter-contract.yml
conformance.yml
schema-harness.yml
docs.yml
release.yml
```

## Pull request gates

Before merge: R CMD check passes once code exists; unit, adapter, fixture, and security tests pass; strict schema checks pass; Markdown links pass; `git diff --check` passes; and changed public behavior includes documentation and changelog entries.

## Release evidence

```text
release-artifacts/capR-vX.Y.Z/
├── README.md
├── MANIFEST.md
├── MANIFEST.json
├── package/
├── reports/
│   ├── capr-digest-conformance.json
│   ├── capr-interop-structural.json
│   └── capr-interop-comparison.json
├── fixture-summary/
└── metadata/
    ├── DESCRIPTION
    └── sessionInfo.txt
```

Release files are committed before the tag is created.

## Claim review

Verify that source families match fixtures, community/fallback adapters are separate, unsupported features are explicit, canonical artifacts validate, provenance is reproducible, vendored resources are unchanged, and security defaults match documentation.

GitHub releases are the first target. CRAN readiness is a later decision and must not weaken evidence gates.
