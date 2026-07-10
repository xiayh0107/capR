# CAP-Digest Schema Package v1.0

> Status: stable v1.0 - Normative schema package - Last updated: 2026-07-07

CAP-Digest v1.0.0 freezes the schema package listed below.

## Included Schemas

- `schemas/cap.conformance_report.v1.schema.json`
- `schemas/cap.contract_response.v1.schema.json`
- `schemas/cap.digest.v1.schema.json`
- `schemas/cap.digest_pack.v1.schema.json`
- `schemas/cap.digest_patch.v1.schema.json`
- `schemas/cap.field.v1.schema.json`
- `schemas/cap.field_catalog.v1.schema.json`
- `schemas/cap.gate_result.v1.schema.json`
- `schemas/cap.manifest.v1.schema.json`
- `schemas/cap.pack_conformance_report.v1.schema.json`
- `schemas/cap.validation_result.v1.schema.json`

Core schemas under `schemas/core/` are excluded from CAP-Digest v1.0.0.

## Compatibility Rules

Compatible v1.0.x schema changes:

- add optional properties without changing existing meanings;
- clarify descriptions;
- add fixture-only examples;
- widen validation where the spec already allowed the behavior.

Incompatible changes requiring a CAPP and version bump:

- new required properties;
- enum narrowing;
- changed meaning of existing properties;
- removed properties;
- changed `additionalProperties` behavior;
- new digest text grammar that old v1.0 readers cannot parse.

## Fixture Linkage

Schema changes SHOULD land with fixture coverage. If a fixture JSON file has no
schema, `validate_schema_fixtures.py` MUST document the no-schema reason.

## Release Package

The v1.0 release package copies the schema package into
`release-artifacts/cap-digest-v1.0.0/schemas/`.
