# CAP-Digest Security and Privacy v1.0

> Status: stable v1.0 - Normative security requirements - Last updated: 2026-07-07

CAP-Digest v1.0.0 freezes the following security and privacy requirements.

## Redaction

Implementations MUST redact sensitive values before rendering digest text.
The stable fixture covers sensitive-name masking for names containing patterns
such as `password`, `secret`, `token`, `api_key`, `credential`, and
`private_key`.

## Escaping

Implementations MUST escape source values that could inject digest tags,
contract tags, or data-fence delimiters.

## Failed Fields

Extractor or renderer failures MUST be recorded in the manifest. Silent field
omission is not conformant.

## Follow-Up Guarding

The model may request fields but MUST NOT execute extractors. The gate MUST
validate evidence, field ids, selected status, fingerprint, budget, execution
class, and local policy before extraction.

## Privacy Boundaries

CAP-Digest v1.0.0 does not define credentialed extraction, remote service
access, or user secret exchange. Such behavior must be documented outside a
v1.0 conformance claim.

## Layer Boundaries

CAP-Digest v1.0.0 does not inherit CAP-Core runtime, policy, service-binding,
or RunEvidence semantics. CAP-Core artifacts are excluded from the Digest
release package unless cited as non-normative context.
