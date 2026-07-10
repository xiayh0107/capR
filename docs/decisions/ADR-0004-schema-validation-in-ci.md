# ADR-0004: Strict schema validation in CI and release

- Status: accepted
- Date: 2026-07-10

## Context

CAP-Digest schemas use JSON Schema Draft 2020-12. Requiring a heavyweight validator on every runtime path would increase installation and execution complexity for ordinary users.

## Decision

Use lightweight structural checks in normal runtime paths and strict Draft
2020-12 validation in development, CI, conformance, and release harnesses. The
concrete v1.0 engine is Python `jsonschema==4.26.0` using
`Draft202012Validator`; direct dependencies are pinned under
`tools/schema-harness/requirements.txt`. The harness meta-validates every
vendored schema, validates fixture and capR-emitted canonical artifacts, and
proves intentionally invalid cases fail.

## Consequences

- Normal digest generation remains lightweight.
- Release evidence remains strict.
- CI must test the validator harness itself.
- The validator runs offline after its pinned development dependencies are
  installed and remains outside package Imports.
- Documentation distinguishes runtime checks from conformance validation.

## Rejected alternative

Make strict external schema validation a mandatory dependency for every `cap_digest()` call.

## Review trigger

A mature native R 2020-12 validator becomes lightweight and reliably portable,
the pinned Python toolchain becomes unsupported, or upstream schema
requirements change.
