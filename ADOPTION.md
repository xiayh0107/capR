# Adoption and Conformance Claim

## capR v1.0.0

| Field | Stable declaration |
|---|---|
| Implementation | capR |
| Implementation version | 1.0.0 |
| CAP specification | CAP-Digest v1.0.0 |
| Upstream tag | `cap-digest-v1.0.0` |
| Upstream commit | `d7890d4449107a88faed0e0c653d3751b57575f2` |
| Claimed level | L0-L3 |
| Fixture revision | published v1.0 stable release artifact |
| Stable source family | `table` |
| Stable R host adapters | `data.frame`, optional `tbl_df`, optional `data.table` |
| Conformance report | `release-artifacts/capR-v1.0.0/reports/capr-digest-conformance.json` |
| Schema report | `release-artifacts/capR-v1.0.0/reports/capr-schema-harness.json` |
| Independent report | `release-artifacts/capR-v1.0.0/reports/capr-interop-structural.json` |
| Comparison report | `release-artifacts/capR-v1.0.0/reports/capr-interop-comparison.json` |

The precise public claim is:

> capR 1.0.0 implements CAP-Digest v1.0.0 L0-L3 for the published v1.0
> fixture suite and the table source family.

## Claim layering

| Layer | Meaning |
|---|---|
| Artifact validity | Applicable text and JSON checks pass |
| Internal consistency | Text, manifest, evidence, rejection, gate, and patch agree |
| Adapter compatibility | Adapter passes the reusable capR contract suite |
| CAP conformance | Exact implementation passes the published fixture suite |

Only the built-in table adapter participates in the v1.0 conformance claim.

- `stable`: built-in table adapter and its three local host representations.
- `community`: adapter-contract compatibility only unless separately proven.
- `experimental`: no stable compatibility or conformance promise.
- `fallback`: bounded structural inspection, semantic level `structural`,
  conformance `none`.

## Unsupported features

- Remote and credentialed extraction.
- CAP-Core runtime, RunEvidence, service, or object semantics.
- Arbitrary R object or fallback conformance.
- A general policy-language specification.
- Scientific/statistical correctness or model-reasoning guarantees.
- Automatic execution of model requests.

The default policy denies unknown, unsafe, remote, and credentialed execution;
requires fingerprint and adapter-pin compatibility for follow-up; and disables
fallback unless explicitly enabled.

## Provenance and verification

Normative resources are vendored under
`inst/extdata/cap-digest/v1.0.0/`; `VENDOR-LOCK.json` records upstream
source, byte size, and SHA-256. Release files are committed before tagging.
`MANIFEST.json` records every release file checksum, and GitHub Release assets
must match those committed entries.

## Feedback and errata

Interoperability feedback and non-security errata belong in
[GitHub issues](https://github.com/xiayh0107/capR/issues). Security reports use
the private process in [SECURITY.md](SECURITY.md). Compatible corrections are
published as v1.0.x with regenerated conformance, schema, interoperability, and
manifest evidence.
