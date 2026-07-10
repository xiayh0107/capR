# CAP-Digest Interoperability v1.0

> Status: stable v1.0 - Interoperability evidence - Last updated: 2026-07-07

CAP-Digest v1.0.0 interoperability is fixture-scoped.

## Evidence

The release package includes:

- `reports/digest-conformance-report.json`;
- `reports/digest-interop-reference.json`;
- `reports/digest-interop-independent-structural.json`;
- `reports/digest-interop-comparison.json`.

The reference report is produced by the Python fixture validator. The
independent structural report is produced without importing `cap_digest`
modules; it inspects published fixture artifacts and expected outputs.

## Comparison Claim

The comparison report claims only:

```text
fixture-scoped CAP-Digest v1.0 interoperability evidence
```

It does not claim broad ecosystem interoperability, production-readiness, or
support for source types outside the stable fixture suite.

## Future Evidence

Post-release adopters should submit external reports that include:

- implementation identity;
- version;
- command or harness used;
- fixture matrix;
- unsupported features;
- security deviations;
- comparison against the stable reference outputs.
