# Experimental Tidy and ggplot Adapters

> Status: experimental in capR 1.1 development; CAP conformance claim: none.

capR distinguishes an R host class from a semantic source family. A tibble is
a different R class from a base data frame, but both can represent the same
`table` source family. A ggplot object represents a declarative plot
specification and therefore uses the separate `plot` source family.

## Resolution and opt-in

| R object | Default behavior | Semantic opt-in |
| --- | --- | --- |
| `data.frame` | stable `org.capr.table` | not needed |
| plain `tbl_df` | stable `org.capr.table` | not needed |
| `grouped_df` / `rowwise_df` | inherited table behavior; grouping is ignored | `adapter = cap_grouped_table_adapter()` |
| `ggplot` | fails closed with `capr_adapter_not_found` | `adapter = cap_ggplot_adapter()` or an explicit registry entry |

The experimental adapters are explicit by design. An unconditional S3 bridge
would run before the registry and silently shadow community adapters for the
same class. Explicit opt-in also prevents existing grouped-tibble workflows
from changing adapter identity, fingerprint, and Digest text in a patch
release.

```r
grouped_digest <- cap_digest(
  grouped_tbl,
  adapter = cap_grouped_table_adapter(),
  budget = 500
)

plot_digest <- cap_digest(
  plot,
  adapter = cap_ggplot_adapter(),
  budget = 800
)
```

A host can register the ggplot adapter in an isolated registry while retaining
normal priority and ambiguity handling:

```r
registry <- cap_registry(global = FALSE)
cap_register_adapter(
  "ggplot",
  cap_ggplot_adapter,
  priority = -100L,
  registry = registry,
  origin = "capR experimental"
)
plot_digest <- cap_digest(plot, registry = registry, budget = 800)
```

## Grouped-table evidence

`cap_grouped_table_adapter()` preserves the built-in shape, columns, and gated
sample fields and adds:

```text
f1:table@capr_grouping#compact
```

The field reports only grouping mode (`grouped` or `rowwise`), grouping
variable names, group count, and the `.drop` setting when available. It never
iterates group rows or emits group-key values. Other inherited table fields
retain their documented behavior, including bounded examples and
sensitive-name redaction.

Its fingerprint covers the underlying table structure plus grouping mode,
variable names, group count, and `.drop`; it does not hash group keys or cell
values.

## ggplot specification evidence

`cap_ggplot_adapter()` provides four bounded assemble-time fields:

```text
f1:plot@overview#base
f1:plot@data_schema#compact
f1:plot@mapping#declared
f1:plot@layers#compact
```

They describe the plot class, plot-level data schema, unevaluated aesthetic
mappings, declared labels, facet/coordinate metadata, explicit scale classes,
theme metadata, and bounded layer declarations. Data-frame cell values,
mapping environments, `plot_env`, function bodies, and ggproto closures are
not traversed. Fixed aesthetic and geom/stat parameter names may be reported,
but their values are excluded.

The adapter deliberately does not call `ggplot_build()`, `layer_data()`,
`print()`, `ggsave()`, or any layer data function. Those operations can execute
statistics, evaluate mappings, train scales, invoke user code, and render
pixels. Consequently this adapter cannot support claims about computed layer
values, trained axes, visual appearance, occlusion, or whether the chart is
statistically correct.

The plot fingerprint covers only the normalized, bounded declaration and data
schema included by these fields. It does not prove pixel equivalence and does
not change when cell values change without a schema or plot-specification
change.

## Claim boundary

Both adapters have `maturity = "experimental"` and
`conformance_claim = "none"`. Their adapter-contract results establish capR
extension compatibility, not CAP-Digest conformance or scientific validity.
The published stable claim remains limited to the v1.0 table fixtures and the
documented local table hosts.
