# CAP-Digest Stable Scope v1.0

> Status: stable v1.0 - Normative scope - Last updated: 2026-07-07

CAP-Digest v1.0.0 stabilizes the fixture-scoped context evidence loop for
table sources. It does not expand CAP-Digest into a runtime, policy language,
credential exchange, or CAP-Core object model.

## Stable Surface

The stable v1.0 surface includes:

- digest text `text=v1` with `fields=f1` field ids;
- table source family field ids used by the fixture suite;
- `DigestManifest` rows for selected, rejected, and failed fields;
- evidence validation against digest text and manifest anchors;
- gated follow-up requests and typed digest patches;
- `table-basic` Digest Pack metadata and compatibility rules;
- positive, negative, pack, follow-up, and safety fixtures;
- conformance levels L0-L3 for Digest behavior;
- release package, reports, and maintenance policy.

## Terminology

Stable v1.0 uses these terms:

| Term | Meaning |
|---|---|
| Digest text | Model-readable context document with version line, source line, field blocks, caveats, and optional follow-up section. |
| Field id | Stable anchor matching the `f1:<source>@<field>#<variant>` grammar. |
| DigestManifest | Machine-readable evidence inventory for selected, rejected, and failed fields. |
| Evidence anchor | A field id that appears in both the digest text and manifest when selected. |
| Follow-up gate | Non-model enforcement step that decides whether a requested field may be extracted. |
| Digest Pack | Non-executable metadata bundle that declares reusable field definitions, renderer notes, and redactor notes. |

## Non-Goals

CAP-Digest v1.0.0 does not define:

- a second required source type;
- remote or credentialed extraction behavior;
- runtime execution semantics;
- policy language semantics;
- scientific correctness;
- CAP-Core object semantics;
- hidden network or credential requirements;
- production SDK quality for `reference/python/`.

## Second Source-Type Decision

The v1.0 release keeps the second source type out of the stable gate. The
decision record is
`specs/digest/reviews/2026-07-07-second-source-type-decision.md`. A later CAPP
may add a second source-type fixture without weakening the v1.0 compatibility
claim.
