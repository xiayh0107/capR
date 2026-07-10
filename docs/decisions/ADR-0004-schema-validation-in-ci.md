# ADR-0004: Strict schema validation in CI and release

- Status: accepted
- Date: 2026-07-10

## Context

CAP-Digest schemas use JSON Schema Draft 2020-12. Requiring a heavyweight validator on every runtime path would increase installation and execution complexity for ordinary users.

## Decision

Use lightweight structural checks in normal runtime paths and strict Draft 2020-12 validation in development, CI, conformance, and release harnesses. The strict engine may use Ajv or another verified 2020-12 implementation.

## Consequences

- Normal digest generation remains lightweight.
- Release evidence remains strict.
- CI must test the validator harness itself.
- Documentation distinguishes runtime checks from conformance validation.

## Rejected alternative

Make strict external schema validation a mandatory dependency for every `cap_digest()` call.

## Review trigger

A mature native R 2020-12 validator becomes lightweight and reliably portable, or upstream schema requirements change.
