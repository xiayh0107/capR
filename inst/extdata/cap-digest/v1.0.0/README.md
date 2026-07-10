# cap-digest-v1.0.0

This package is the CAP-Digest v1.0.0 stable artifact set.

## Included

- v1.0 stable-track documents, CAPPs, and dated review records;
- CAP-Digest JSON schemas under `schemas/`;
- fixture families under `fixtures/`;
- `packs/table-basic/` metadata and non-executable renderer/redactor notes;
- conformance, interoperability, and comparison reports under `reports/`;
- manifest and reference-version records.

## Reproduce

```bash
python -m unittest discover reference/python/tests
python reference/python/scripts/validate_schema_fixtures.py
python reference/python/scripts/validate_fixtures.py --scope digest --report digest-fixtures.json
python reference/python/scripts/package_release_artifacts.py --release cap-digest-v1.0.0 --stable
python reference/python/scripts/validate_digest_release_manifest.py release-artifacts/cap-digest-v1.0.0
```
