# capR Documentation

This documentation system is the design baseline for the future R package in this repository.

## Read by role

### Project reviewer

1. [Project charter](project-charter.md)
2. [Architecture overview](architecture/overview.md)
3. [Implementation plan](roadmap/implementation-plan.md)
4. [Architecture decisions](decisions/README.md)

### Runtime implementer

1. [Repository layout](architecture/repository-layout.md)
2. [Adapter contract](architecture/adapter-contract.md)
3. [Registry resolution](architecture/registry-resolution.md)
4. [Artifact boundaries](architecture/artifact-boundaries.md)
5. [Runtime API](api/runtime-api.md)
6. [Error model](api/error-model.md)
7. [Implementer workflow](handbook/implementer-guide.md)

### Adapter author

1. [Adapter API](api/adapter-api.md)
2. [Writing adapters](handbook/writing-adapters.md)
3. [Table-family adapter](adapters/table-family.md)
4. [Adapter template](adapters/adapter-template.md)
5. [Testing and conformance](handbook/testing-conformance.md)

### Release maintainer

1. [Security model](architecture/security-model.md)
2. [Testing and conformance](handbook/testing-conformance.md)
3. [CI and release](handbook/ci-release.md)
4. [Adoption and claims](../ADOPTION.md)

## Document authority

This repository documents capR implementation decisions. Upstream CAP-Digest normative documents and published fixtures remain authoritative for CAP behavior.

## Maintenance rule

A change to architecture, public API, adapter behavior, security defaults, or conformance language is incomplete until the corresponding document is updated.
