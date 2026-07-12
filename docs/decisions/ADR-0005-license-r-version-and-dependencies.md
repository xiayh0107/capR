# ADR-0005: License, R version, and dependency boundaries

- Status: Accepted
- Date: 2026-07-10

## Context

The executable package needs stable licensing and compatibility decisions
before runtime code accumulates. Strict schema validation, optional table host
classes, and process isolation have different operational costs and must not
silently broaden the stable conformance claim.

## Decision

capR uses the MIT license and supports R 4.1.0 or newer. CI covers R 4.1.0 and
the current R release on Linux, plus the current release on macOS and Windows.

Runtime imports are deliberately small:

- `jsonlite` provides deterministic UTF-8 JSON I/O;
- `digest` provides SHA-256 fingerprints and provenance checks.

The following remain optional:

- `testthat` for package and reusable adapter-contract tests;
- `withr` and `callr` for test/development isolation boundaries;
- `tibble` and `data.table` for table host compatibility, without creating
  new CAP source-family claims;
- `dplyr` and `ggplot2` to construct representative optional grouped-table and
  plot objects in tests and executable vignettes; the experimental adapters
  inspect those objects without adding either package to runtime Imports;
- the optional matrix, Bioconductor, tidy-modeling, spatial, graph/tree,
  time-series, Arrow/DBI, XML, widget, and R6 packages listed in `Suggests` to
  construct and verify their experimental host objects; ordinary table
  digestion does not load them;
- `jsonvalidate` for strict JSON Schema Draft 2020-12 CI and release checks.

Strict schema validation is not performed on every `cap_digest()` call.
Runtime code performs bounded structural checks; CI and release tooling apply
the complete vendored schema suite.

## Consequences

The ordinary table digest path stays offline and lightweight. Optional
dependencies cannot expand authorization or conformance scope. Supporting R
4.1 means package syntax and base APIs must remain compatible with that
version. Any new import needs a documented runtime need and compatibility
review.

## Alternatives

GPL licensing was considered but would unnecessarily constrain adapter
ecosystem reuse. Requiring a newer R release would simplify maintenance but
reduce deployability without a demonstrated runtime need. Importing a schema
engine and isolation backend was rejected because both are release/development
concerns for the v1.0 stable fixture path.
