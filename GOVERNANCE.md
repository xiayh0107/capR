# Governance

## Project boundary

capR is an R implementation and host integration for CAP-Digest. It is not the authority for CAP-Digest normative changes.

| Category | Destination |
|---|---|
| capR implementation bug | capR issue and patch |
| capR API or architecture decision | capR issue, ADR, and implementation |
| Adapter-specific behavior | adapter owner or extension package |
| Upstream schema/grammar/gate ambiguity | cap-docs issue or CAPP process |
| New stable source family | upstream specification and fixture proposal first |

## Decision records

Architecture decisions use ADRs in `docs/decisions/` with states proposed, accepted, superseded, or rejected. Superseded ADRs remain in history.

## Compatibility review

Explicit review is required for public API signatures, adapter resolution precedence, adapter identity/version rules, field IDs, canonical artifacts, sidecars, CAP finding-code mappings, security defaults, and conformance claim wording.

## Stable versus experimental

Public documentation must separate stable built-in behavior, community adapters, experimental behavior, and structural fallback. “Can produce a digest” is not equivalent to “CAP-Digest conformant.”

## Release authority

A release is approved only when declared scope, reports, artifacts, unsupported features, and tags agree.
