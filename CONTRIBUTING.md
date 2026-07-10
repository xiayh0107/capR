# Contributing

capR is a protocol implementation project. Contributions must preserve the boundary between upstream CAP-Digest requirements and capR implementation choices.

## Classify the change

1. documentation clarification;
2. capR implementation choice;
3. adapter extension;
4. fixture or conformance work;
5. suspected upstream CAP ambiguity or normative change.

A capR pull request must not silently redefine upstream schemas, field ID grammar, digest text grammar, gate semantics, or stable finding codes.

## Documentation-first rule

Changes to public architecture, API behavior, adapter resolution, conformance claims, security defaults, or release evidence require corresponding documentation in the same pull request. Major design changes should add or update an ADR under `docs/decisions/`.

## Adapter contributions

New adapters must document adapter identity, provider, host classes, source family, maturity, semantic level, field catalog, execution/privacy behavior, test status, and conformance claim. Use the [adapter proposal template](docs/adapters/adapter-template.md).

## Upstream resources

Vendored CAP resources are read-only baselines. Update them only through a documented vendoring operation tied to a published upstream version or commit.

## Review red lines

Reject changes that add class-specific orchestration to the core, use silent last-registration-wins behavior, serialize executable functions into field metadata, render before redaction, omit failed fields, let model output invoke extractors directly, or broaden claims without fixture evidence.
