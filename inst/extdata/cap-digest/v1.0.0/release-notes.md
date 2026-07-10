# cap-digest-v1.0.0 Release Notes

CAP-Digest v1.0.0 stable stabilizes the fixture-scoped digest loop for table
sources: digest text `text=v1`, field ids `fields=f1`, `cap.manifest.v1`,
`cap.validation_result.v1`, follow-up gate behavior, `cap.digest_patch.v1`, and
the `table-basic` Digest Pack compatibility surface.

Included evidence:

- frozen v1.0 documents under `specs/digest/`;
- CAP-Digest schemas under `schemas/`;
- positive, negative, follow-up, pack, and safety fixtures under `fixtures/`;
- conformance report plus reference and independent structural interop reports;
- CAPP-0008 stable entry gates and CAPP-0009 stable release decision records.

Out of scope: new source-type semantics, remote or credentialed extraction,
runtime execution, policy language semantics, CAP-Core behavior changes, and
scientific correctness claims.
