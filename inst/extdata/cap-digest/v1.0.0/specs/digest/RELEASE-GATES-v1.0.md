# CAP-Digest Release Gates v1.0

> Status: stable v1.0 - Release gate checklist - Last updated: 2026-07-07

CAP-Digest v1.0 release candidates and stable packages must pass these gates.

## Required Commands

Run from the repository root:

```bash
python -m unittest discover reference/python/tests
python reference/python/scripts/validate_schema_fixtures.py
python reference/python/scripts/validate_fixtures.py --scope digest --report digest-fixtures.json
python reference/python/scripts/package_release_artifacts.py --release cap-digest-v1.0.0-rc1
python reference/python/scripts/package_release_artifacts.py --release cap-digest-v1.0.0 --stable
python reference/python/scripts/validate_digest_release_manifest.py
git diff --check
```

## CI Expectations

CI or release automation SHOULD run the schema, fixture, reference, conformance
report, and release-manifest checks. Release packages MUST include
`MANIFEST.json` and `MANIFEST.md`.

## RC Review

Each release candidate needs a dated review record under
`specs/digest/reviews/`. The v1.0.0-rc1 review is
`specs/digest/reviews/2026-07-07-rc1-review.md`.

## Stable Publication

Stable publication requires accepted CAPP-0009, a stable release package, and a
tag plan. The repository tag should be created after the release files are
committed so it points at a commit containing the package.
