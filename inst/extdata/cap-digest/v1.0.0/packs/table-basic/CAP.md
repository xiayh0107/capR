---
schema: cap.digest_pack.v1
name: table-basic
description: Use this digest pack for tabular sources when an agent needs shape, column names, column types, compact examples, redaction caveats, or sample rows. Do not use it for chart image interpretation, SQL execution, tool execution, or CAP-Core runtime binding.
cap: 2026-07-05-draft
source_types:
  - table
provides:
  - fields
  - renderers
  - redactors
  - fixtures
status: experimental
trust_notes: Sample rows may contain sensitive data and should remain interactive unless host policy explicitly allows initial rendering.
---

# table-basic Digest Pack

This is the first experimental Digest Pack for CAP-Digest. It provides focused source-reading logic for small tabular sources such as data frames and query results.

## Boundaries

This pack does not define:

- SQL execution;
- chart or image interpretation;
- remote database access;
- tool calling;
- Skills;
- CAP-Core runtime, resource, service, or RunEvidence binding.

## Field families

- `shape`: cheap row/column count.
- `columns`: compact column names, types, and safe examples.
- `sample`: interactive sample rows.

## Privacy

Columns whose names match sensitive-name patterns should have example values masked before rendering. Sample rows should default to interactive because they may contain sensitive data.

## Source basis

This pack follows the CAP-Digest Pack rules in `specs/digest/10-digest-packs.md` and the progressive-disclosure package pattern referenced in `REFERENCES.md` under [GITHUB-SKILLS], [OPENAI-SKILLS], and [ANTHROPIC-SKILLS].
