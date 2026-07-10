# Roadmap

## v1.0 implementation

- [x] Phase 0: documentation and ADR baseline.
- [x] Phase 1: valid R package, dependency policy, conditions, cross-platform CI.
- [x] Phase 2: open adapter runtime, deterministic registry, pinning, policy,
  fallback, reusable contract tests.
- [x] Phase 3: pinned CAP-Digest resources, table digest/manifest path,
  redaction, parser, security and negative fixtures.
- [x] Phase 4: validation, gate, patch, pack hosting, L0-L3 report, strict
  schemas, independent interoperability, table aliases, CLI.
- [x] Phase 5 implementation: API classification, user/implementer/security
  documentation, reproducible release tooling.
- [ ] Phase 5 publication: committed RC/stable evidence, exact-commit CI,
  annotated tags, GitHub Releases, issue closure.

Detailed implementation requirements remain in
[the implementation plan](docs/roadmap/implementation-plan.md). Stable
publication must not broaden the table-only, fixture-scoped claim.

## Post-v1.0

- Operate a documented feedback, interoperability, security, and errata window.
- Handle compatible corrections in v1.0.x with regenerated evidence.
- Consider CRAN publication independently from GitHub release evidence.
- Add new source-family claims only with published fixtures and an explicit
  compatibility/conformance decision.
