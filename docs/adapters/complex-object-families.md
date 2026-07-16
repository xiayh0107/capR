# Experimental Complex-Object Families

> Status: experimental in capR 1.1 development; CAP conformance claim: none.

capR provides ten public, opt-in constructors for bounded descriptions of
complex R objects:

```text
cap_nested_adapter()      cap_array_adapter()
cap_relational_adapter()  cap_temporal_adapter()
cap_spatial_adapter()     cap_graph_adapter()
cap_scientific_adapter()  cap_model_adapter()
cap_visual_adapter()      cap_live_adapter()
```

Every constructor returns an adapter with `maturity = "experimental"` and
`conformance_claim = "none"`. None has a built-in S3 bridge. The host must make
the semantic choice explicit, normally with `adapter =` (a deliberate registry
entry is the other opt-in path):

```r
digest <- cap_digest(
  object,
  adapter = cap_array_adapter(),
  budget = 1000
)
```

Passing `cap_test_adapter()` establishes compatibility with the capR extension
contract; it does not establish CAP conformance, payload correctness, or domain
validity.

The user-facing tutorials now model a multi-turn agent session for every family:
the first Digest is intentionally small, the agent returns claims and a bounded
field request, `cap_validate_response()` and `cap_gate()` decide whether that
request is legal, and a user-authorized second Digest supplies the next metadata
view. The current descriptor families declare `followup = FALSE`, so the Gate
correctly returns `not_available` for an implicit Patch; this is deliberate and
keeps a metadata-only adapter from silently becoming a payload extractor. The
stable table vignette demonstrates the full Gate → `cap_patch()` →
`cap_apply_patch()` materialization path.

## Common three-field contract

All ten adapters use the same bounded descriptor shape:

```text
f1:<sourceType>@overview#compact
f1:<sourceType>@structure#compact
f1:<sourceType>@semantics#compact
```

- `overview` reports kind, host classes, and bounded size/count metadata.
- `structure` reports bounded component, schema, slot, or attribute names.
- `semantics` states domain relationships and, importantly, what was not
  disclosed, traversed, materialized, or evaluated. Metadata-only adapters may
  still inspect bounded components to establish class, length, or shape; inline
  JSON is parsed locally within its documented bound.

The `visual` constructor emits `sourceType = "plot"`; the `live` constructor
emits `sourceType = "external"`. All other constructor names match their
`sourceType`.

The fingerprint covers only the normalized metadata emitted by the adapter.
Changing an undisclosed payload value may therefore leave the fingerprint and
Digest ID unchanged. These fingerprints prove descriptor freshness, not full
object-content freshness.

## Support matrix

| Constructor | `sourceType` | Explicitly supported hosts | Bounded evidence | Never executed or disclosed |
| --- | --- | --- | --- | --- |
| `cap_nested_adapter()` | `nested` | Plain lists; data frames/tibbles with at least one list-column; inline jsonlite `json` object/array strings up to 1 MB; xml2 `xml_document`/`xml_node` | Container paths, depth, bounded child probes, leaf types, XML element names (depth 4, 80 nodes, 20 children per container) | Leaf values, JSON values, XML text/attribute values; environments, functions, and language objects are not traversed; external filesystem/URL resources are not opened |
| `cap_array_adapter()` | `array` | Base matrix/array; Matrix classes including sparse matrices; `DelayedArray`; `HDF5Array` | Rank up to 64, dimensions, storage kind, sparse stored-entry count, delayed/file-backed flags | Cell values, dimname values, backing paths, delayed operations, HDF5 payload reads or materialization |
| `cap_relational_adapter()` | `relational` | Declared `capr_db_schema` from `cap_db_schema()`; in-memory `dm`; `MultiAssayExperiment` | Declared table/column/type/primary-key/foreign-key metadata; bounded `dm` table names; experiment count/names and sample-map shape | Table/key/sample values, sample identifiers, sample-map values, assay values, assay materialization, DBI access, remote queries |
| `cap_temporal_adapter()` | `temporal` | Base `ts`; `zoo`; `xts`; `tbl_ts` | Observation/series counts, dimensions, series or column names; regularity/frequency only for base `ts` | Payload values, index values, collection or queries; regularity is left unknown for non-`ts` hosts |
| `cap_spatial_adapter()` | `spatial` | `sf`; `sfc`; in-memory `stars`; `GRanges` (`stars_proxy` is rejected) | Feature count, dimensions up to rank 64, component/column/slot names, sf geometry-column name | Table values and coordinate, bounding-box, CRS, or genomic-range elements are not disclosed; proxy-backed files are not accessed |
| `cap_graph_adapter()` | `graph` | `igraph`; `tbl_graph`; `phylo`; `treedata` | Vertex/edge/tip counts, directedness, component/schema names, attribute names | Edge endpoints, tip-label values, graph/node/edge attribute values, executable components |
| `cap_scientific_adapter()` | `scientific` | `SummarizedExperiment`/`RangedSummarizedExperiment`; `SingleCellExperiment`; `Seurat`; `phyloseq` | Assay/component names, dimensions up to rank 64, metadata schemas, layer/slot names | Assay cells, row/column/sample/feature identifier values, metadata values, and file-backed payload materialization |
| `cap_model_adapter()` | `model` | `lm`; `glm`; `merMod`; `recipe`; `workflow`; parsnip `model_spec`/`model_fit` | Training schema, term/coefficient counts, family/engine/mode, step and component classes | Formula/term expressions, coefficient names/values, training values; `summary()`, `predict()`, `fit()`, `prep()`, `bake()`, or `refit()` calls |
| `cap_visual_adapter()` | `plot` | ggplot; patchwork; grid grob; gtable; htmlwidget | Object/component schema, child/layer/geom/stat classes, data schema, dependency and payload-field names | Plot build/draw/render, mapping or layer-function evaluation, labels/parameter values, JavaScript, hooks, browser access, pixels |
| `cap_live_adapter()` | `external` | `tbl_sql`/`tbl_lazy`; Arrow Dataset/ArrowObject; DBI connections; base connections; environments; R6; external pointers | Cached lazy-query component classes; connection slot/attribute names; environment/R6/Arrow kind, class, and lock state | Query rendering/execution, row collection, connection traversal/opening, credentials, all environment binding names/values, active bindings, R6 methods, external-pointer dereference |

Support is deliberately class- and metadata-specific. Malformed internal
metadata is rejected rather than traversed generically.
Optional host packages are needed to construct their objects, but are not
runtime Imports for the ordinary capR table path.

## Short reproducible examples

### Nested topology without leaf values

```r
nested <- list(
  experiment = list(batch = "B01", values = c(10, 20)),
  audit = list(approved = TRUE)
)

nested_digest <- cap_digest(
  nested,
  adapter = cap_nested_adapter(),
  budget = 1000,
  label = "nested experiment"
)
```

The descriptor can report paths such as `$experiment$values` and their type or
length, but not `"B01"`, `10`, or `20`.

### Base time series without observations

```r
series <- stats::ts(c(4.2, 4.4, 4.1, 4.8), frequency = 4)

temporal_digest <- cap_digest(
  series,
  adapter = cap_temporal_adapter(),
  budget = 1000,
  label = "quarterly series"
)
```

The descriptor records four observations, one series, regular spacing, and
frequency four. It does not contain the four observation values or index
values.

### Declared database schema without a connection

```r
schema <- cap_db_schema(
  tables = list(
    customers = c(customer_id = "integer", email = "text"),
    orders = c(order_id = "integer", customer_id = "integer")
  ),
  primary_keys = list(
    customers = "customer_id",
    orders = "order_id"
  ),
  foreign_keys = list(list(
    from_table = "orders",
    from_columns = "customer_id",
    to_table = "customers",
    to_columns = "customer_id"
  ))
)

schema_digest <- cap_digest(
  schema,
  adapter = cap_relational_adapter(),
  budget = 1000
)
```

`cap_db_schema()` validates in-memory declarations only. It does not accept a
DBI connection, inspect table rows, or contact a database. The relational
snapshot revalidates the canonical declaration and its deterministic
consistency seal, so malformed class spoofs and post-construction mutation
fail closed. The seal is publicly reproducible consistency metadata, not
provenance authentication; declared names and types can still disclose what
the caller places in them.

### Delayed and live objects stay delayed and live

```r
array_digest <- cap_digest(
  delayed_array,
  adapter = cap_array_adapter(),
  budget = 1000
)

live_digest <- cap_digest(
  lazy_table,
  adapter = cap_live_adapter(),
  budget = 1000
)
```

The array adapter may read dimensions and storage metadata, but never indexes,
coerces, realizes, or reads an HDF5 payload. The live adapter inspects cached
lazy-query metadata or connection class/slot metadata only. Environment, R6,
and Arrow frames are opaque—even binding names are not enumerated. It never
renders SQL, sends a query, opens or traverses a connection, collects rows, or
reads credentials.

## Resolution and overlapping classes

Explicit semantic opt-in is required. Passing `adapter =` is the documented
default; deliberately registering a constructor for a class is also an opt-in.
This prevents inherited classes from silently selecting the wrong semantics:

- a nested tibble or `tbl_ts` can otherwise inherit the stable `tbl_df` table
  bridge and lose nested/temporal meaning;
- patchwork inherits ggplot classes;
- `xts` inherits `zoo`, and `glm` inherits `lm`;
- S4 superclass relationships are not a substitute for an explicit semantic
  choice;
- lazy/live classes must never fall through to an adapter that materializes a
  table.

For a ggplot-specific four-field description (`overview`, `data_schema`,
`mapping`, and `layers`), use `cap_ggplot_adapter()` instead. The broader
`cap_visual_adapter()` uses the common three-field descriptor and also covers
grobs, gtables, patchworks, and htmlwidgets. Group-aware table evidence remains
available separately through `cap_grouped_table_adapter()`.

See also:

- [Systematic complex-object vignette](../../vignettes/complex-object-workflow.Rmd)
- [Nested scenario](../../vignettes/nested-object-workflow.Rmd)
- [Array scenario](../../vignettes/array-object-workflow.Rmd)
- [Relational scenario](../../vignettes/relational-object-workflow.Rmd)
- [Temporal scenario](../../vignettes/temporal-object-workflow.Rmd)
- [Spatial scenario](../../vignettes/spatial-object-workflow.Rmd)
- [Graph scenario](../../vignettes/graph-object-workflow.Rmd)
- [Scientific scenario](../../vignettes/scientific-object-workflow.Rmd)
- [Model scenario](../../vignettes/model-object-workflow.Rmd)
- [Visual scenario](../../vignettes/visual-object-workflow.Rmd)
- [Live scenario](../../vignettes/live-object-workflow.Rmd)
- [Experimental tidy and ggplot adapters](experimental-object-types.md)
- [Public API and compatibility](../api/public-api-v1.md)
- [Writing an adapter](../handbook/writing-adapters.md)
