# DigestManifest and Evidence Anchors v1.0

> Status: stable v1.0 - Normative manifest contract - Last updated: 2026-07-07

This document freezes the `cap.manifest.v1` and evidence-anchor behavior used
by CAP-Digest v1.0.0.

## Manifest Envelope

A stable `DigestManifest` MUST include:

- `schema: cap.manifest.v1`;
- `digestId`;
- `source` with URI, source type, and label;
- `versions` for CAP, text, fields, and manifest;
- `budget` with requested, estimated, used, and tokenizer;
- `fingerprint`;
- `fields`.

## Field Rows

Every known candidate field in the stable fixture scope MUST have a manifest
row, including rejected and failed fields. Rows record:

- field id and label;
- source type;
- timing;
- trust;
- execution class;
- selected status;
- rejection reason when not selected;
- estimated and actual cost;
- render method;
- redaction state;
- ok/error state;
- warnings;
- field fingerprint;
- tokenizer.

## Evidence Anchors

A selected field MUST appear in both:

- digest text as a `<field id="...">` block;
- `DigestManifest.fields[]` with `selected: true`.

If a selected field is missing from text, implementations MUST report
`evidence_missing_from_text`. If digest text contains a selected-looking field
that is missing from the manifest, implementations MUST report
`text_field_missing_from_manifest`.

## Rejected and Failed Fields

Rejected fields explain selection decisions and power follow-up. Failed fields
MUST be explicit; implementations MUST NOT silently omit a field that was
attempted and failed.

## Fingerprint Discipline

Follow-up gates MUST compare requested fields against the manifest fingerprint
or the policy-provided expected fingerprint. A fingerprint mismatch denies the
request.

## Schema Compatibility

`cap.manifest.v1` compatibility is governed by
`SCHEMA-PACKAGE-v1.0.md`. New required fields or narrowed meanings require a
new schema version or CAPP-governed compatibility decision.
