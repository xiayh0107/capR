# Follow-Up Contract and Gate v1.0

> Status: stable v1.0 - Normative gate contract - Last updated: 2026-07-07

This document freezes CAP-Digest v1.0 follow-up behavior.

## Model Contract

Models MAY return `cap.contract_response.v1` objects containing claims,
evidence references, and requests. Evidence references MUST cite selected field
ids present in both digest text and the manifest.

## Validation

Before any follow-up extraction, implementations MUST validate:

- digest text parses as `text=v1`;
- evidence field ids are known;
- evidence field ids are selected;
- selected evidence appears in digest text;
- requested field ids are known.

Invalid evidence denies follow-up requests with `invalid_evidence`.

## Gate Inputs

The gate MUST evaluate:

- requested field id;
- manifest row selected status;
- manifest and policy fingerprint;
- remaining budget;
- execution class;
- local policy;
- source availability.

## Stable Decisions

Stable deny reasons include:

- `invalid_evidence`;
- `unknown_field`;
- `already_selected`;
- `fingerprint_mismatch`;
- `budget_exceeded`;
- `not_requestable`.

The stable allow reason is `allowed`.

## Digest Patch

Approved follow-up extraction returns a `cap.digest_patch.v1` patch. The stable
fixture uses:

- `add_selected_field`;
- `remove_available_on_request`;
- a manifest row for the newly selected field.

The model does not execute extractors. The gate approves requests, and trusted
implementation code performs extraction.

## Deferred Behavior

Remote, credentialed, user-confirmed, and long-running extraction are outside
CAP-Digest v1.0.0 stable scope.
