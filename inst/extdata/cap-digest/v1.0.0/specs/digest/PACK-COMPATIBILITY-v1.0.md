# Digest Pack Compatibility v1.0

> Status: stable v1.0 - Normative pack rules - Last updated: 2026-07-07

This document freezes `table-basic` Digest Pack compatibility for CAP-Digest
v1.0.0.

## Stable Pack

The stable pack is `packs/table-basic/`.

Stable package contents:

- `CAP.md` metadata;
- field definitions under `fields/`;
- renderer notes under `renderers/`;
- redactor notes under `redactors/`.

## Compatibility Rules

Compatible v1.0.x changes:

- add optional pack metadata;
- add explanatory notes;
- add new fields that are not selected by existing fixtures;
- clarify renderer or redactor prose without changing expected fixture output.

Incompatible changes requiring a CAPP:

- renaming stable field ids;
- changing `f1:table@shape#base`, `f1:table@columns#compact`, or
  `f1:table@sample#k10` semantics;
- silently enabling executable pack code;
- changing pack fixture expected output;
- weakening redaction or fail-closed behavior.

## Execution Boundary

Digest Packs in v1.0 are metadata and prose guidance. Third-party executable
pack code is out of scope and must fail closed unless a host explicitly enables
it outside the stable v1.0 claim.
