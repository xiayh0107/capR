# Built-in Table-Family Adapter

> Status: planned stable implementation target.

## Host classes

```text
data.frame -> table
tbl_df     -> table (optional dependency)
data.table -> table (optional dependency)
```

These are host representations of one source family, not three CAP source families.

## Stable field targets

The built-in adapter first implements fields exercised by the published CAP-Digest v1.0 table fixtures, including examples such as:

```text
f1:table@shape#base
f1:table@columns#compact
f1:table@sample#k10
f1:table@missingness#full
```

The exact stable field set comes from the vendored release, not this planning document.

## Safety

Dimensions/schema may be local cheap operations; sampling and scans are budgeted; sensitive names and values are redacted; data strings are escaped; sampling is deterministic; renderer failures create failed rows; and lazy/remote table backends are not automatically treated as local tables.

## Conformance

Only the built-in table adapter participates in the first fixture-scoped claim. Optional host-class aliases must produce equivalent table semantics and pass the same compatibility tests.

The adapter does not interpret statistical significance, scientific meaning, or domain importance.
