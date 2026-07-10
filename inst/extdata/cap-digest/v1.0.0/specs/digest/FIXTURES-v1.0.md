# CAP-Digest Fixtures v1.0

> Status: stable v1.0 - Normative fixture index - Last updated: 2026-07-07

This document freezes the CAP-Digest v1.0 positive, negative, pack, follow-up,
and safety fixture suite.

## Positive Fixtures

| Fixture | Stable coverage |
|---|---|
| `fixtures/basic-table/` | Table source assembly, selected/rejected fields, digest text, manifest, redaction, evidence validation. |
| `fixtures/followup-basic/` | Model contract response, request validation, gate approval, stale denial, digest patch output. |
| `fixtures/pack-table-basic/` | `table-basic` Digest Pack metadata loading and pack conformance report. |

Expected outputs in these fixtures are stable v1.0 outputs. Changing them
requires a CAPP unless the existing output plainly contradicts the stable spec.

## Negative and Safety Fixtures

| Fixture | Stable coverage |
|---|---|
| `fixtures/basic-table/negative-validation.json` | Unknown, unselected, and text-missing evidence rejection. |
| `fixtures/digest-text-negative/` | Parser and manifest/text consistency failures. |
| `fixtures/security-adversarial/` | Escaping, masking, and failed renderer manifest rows. |

Adding a new negative fixture is compatible when it tests behavior already
forbidden by v1.0 documents.

## Second Source-Type Decision

CAP-Digest v1.0.0 does not require a second source type. The decision record is
`specs/digest/reviews/2026-07-07-second-source-type-decision.md`.

The v1.0 stability claim is therefore fixture-scoped: it covers the table
source loop and the cross-cutting Digest contracts exercised by the suite.

## Default CI

Default CI MUST run:

```bash
python reference/python/scripts/validate_schema_fixtures.py
python reference/python/scripts/validate_fixtures.py --scope digest --report digest-fixtures.json
```

Remote, credentialed, or large-source fixtures must be opt-in and excluded from
default CI unless a later CAPP changes the stable scope.
