# CAP-Digest Validator Codes v1.0

> Status: stable v1.0 - Normative finding registry - Last updated: 2026-07-07

This document freezes stable CAP-Digest v1.0 finding codes used by the
reference fixture suite.

## Digest Text Parser

- `text_unknown_version`
- `text_missing_source_line`
- `text_unclosed_field`
- `text_field_missing_id`
- `text_invalid_field_id`
- `text_duplicate_field_id`
- `text_field_missing_required_attr`
- `text_nested_field`
- `text_nested_data`
- `text_unopened_data`
- `text_unclosed_data`
- `text_no_field_blocks`

## Manifest/Text Consistency

- `evidence_missing_from_text`
- `text_field_missing_from_manifest`

## Contract Validation

- `digest_text_invalid`
- `unknown_evidence_field`
- `unselected_evidence_field`
- `missing_evidence_in_text`
- `unknown_request_field`

## Follow-Up Gate

- `invalid_evidence`
- `unknown_field`
- `already_selected`
- `fingerprint_mismatch`
- `budget_exceeded`
- `not_requestable`
- `allowed`

## Report Compatibility

Implementations MAY emit additional diagnostics, but v1.0 conformance requires
equivalent behavior for the stable fixture suite and MUST NOT reuse these codes
with different meanings.
