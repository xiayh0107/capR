# capR

> Status: documentation bootstrap · Runtime code not started · Last updated: 2026-07-10

`capR` is the planned R-hosted implementation of CAP-Digest. The repository is organized documentation-first so that architecture, extension boundaries, conformance claims, and release evidence are reviewed before runtime code grows.

## Project position

The first stable implementation target is deliberately narrow:

```text
CAP-Digest v1.0
+ R host integration
+ table source family
+ fixture-scoped conformance
```

The project is **not** initially a general AI framework, a CAP-Core runtime, or a claim that arbitrary R objects are CAP-Digest conformant.

The key implementation rule is:

> Resolve one source adapter, then run one class-independent digest pipeline.

This prevents the core package from becoming an endless collection of `cap_digest.<class>()` methods.

## Documentation map

- [Documentation index](docs/index.md)
- [Project charter](docs/project-charter.md)
- [Architecture overview](docs/architecture/overview.md)
- [Repository layout](docs/architecture/repository-layout.md)
- [Adapter contract](docs/architecture/adapter-contract.md)
- [Runtime API draft](docs/api/runtime-api.md)
- [Implementer guide](docs/handbook/implementer-guide.md)
- [Implementation roadmap](docs/roadmap/implementation-plan.md)
- [Architecture decisions](docs/decisions/README.md)
- [Project status](PROJECT-STATUS.md)

## Current scope

This bootstrap contains development documentation only. It intentionally does not yet add `DESCRIPTION`, `NAMESPACE`, `R/`, `tests/`, vendored fixtures, or CI workflows that imply executable package behavior.

The future R package will live in this same repository. The reserved layout and the sequence for introducing package files are defined in [Repository layout](docs/architecture/repository-layout.md).

## Upstream basis

capR consumes, rather than redefines, CAP-Digest:

- [CAP-Digest v1.0 stable scope](https://github.com/xiayh0107/cap-docs/blob/main/specs/digest/STABLE-SCOPE-v1.0.md)
- [CAP-Digest Source Adapter Guide](https://github.com/xiayh0107/cap-docs/blob/main/specs/digest/SOURCE-ADAPTER-GUIDE.md)
- [CAP-Digest Implementer and Adoption Guide](https://github.com/xiayh0107/cap-docs/blob/main/specs/digest/IMPLEMENTER-ADOPTION-v1.0.md)

Normative CAP documents and published fixtures take precedence over capR implementation guidance.

## Next gate

The next development gate is **Phase 1: package bootstrap**. It starts only after the documentation baseline and the initial ADR set are accepted.
