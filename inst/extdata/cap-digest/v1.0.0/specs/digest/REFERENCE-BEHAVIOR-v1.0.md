# CAP-Digest Reference Behavior v1.0

> Status: stable v1.0 - Reference baseline - Last updated: 2026-07-07

The Python reference implementation is an executable companion for CAP-Digest
v1.0.0. It is not the specification and is not the only valid implementation.

## Stable Behaviors

The reference baseline covers:

- table source assembly for shape and compact columns;
- deterministic selected/rejected manifest rows;
- sensitive-name redaction before digest rendering;
- XML-like digest text escaping for source values;
- `text=v1` parser validation;
- manifest/text consistency validation;
- contract response validation;
- follow-up gate approval and denial decisions;
- typed digest patch rendering for `f1:table@sample#k10`;
- `table-basic` Digest Pack metadata loading;
- conformance report emission;
- release package generation and manifest validation.

## Stable Commands

```bash
python -m unittest discover reference/python/tests
python reference/python/scripts/validate_schema_fixtures.py
python reference/python/scripts/validate_fixtures.py --scope digest --report digest-fixtures.json
python reference/python/scripts/package_release_artifacts.py --release cap-digest-v1.0.0 --stable
python reference/python/scripts/validate_digest_release_manifest.py release-artifacts/cap-digest-v1.0.0
```

## Non-Goals

The reference implementation is intentionally minimal. It does not claim
production SDK quality, remote source support, credential handling, or complete
tokenization.
