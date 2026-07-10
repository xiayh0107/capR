# CAP-Digest Conformance v1.0

> Status: stable v1.0 - Normative conformance levels - Last updated: 2026-07-07

CAP-Digest v1.0.0 defines fixture-backed conformance levels L0-L3.

## Levels

| Level | Claim | Required fixture coverage |
|---|---|---|
| L0 | Digest Producer | Produce valid digest text and `DigestManifest` for `fixtures/basic-table/`. |
| L1 | Safe Assembler | Preserve L0 and pass redaction, escaping, rejected-field, and safety coverage. |
| L2 | Follow-Up Capable | Preserve L1 and pass `fixtures/followup-basic/`. |
| L3 | Digest Pack Host | Preserve L2 and pass `fixtures/pack-table-basic/`. |

Claims MUST name the level and fixture suite version. A v1.0 claim MUST NOT
imply support for untested source types, remote extraction, credentials, or
CAP-Core behavior.

## Claim Language

Acceptable claim:

```text
Implements CAP-Digest v1.0 L2 for the published v1.0 fixture suite.
```

Unacceptable claim:

```text
Implements all CAP behavior or validates scientific correctness.
```

## Report Schema

Conformance reports use `cap.conformance_report.v1` with:

- `schema`;
- `ok`;
- `checks`;
- optional `implementation`;
- optional `capVersion`;
- optional `level`.

The stable reference command is:

```bash
python reference/python/scripts/validate_fixtures.py --scope digest --report digest-fixtures.json
```

## Interoperability

L3 conformance is sufficient for fixture-scoped v1.0 interoperability testing.
Broader ecosystem interoperability requires real independent reports beyond the
fixture-scoped structural adapter.
