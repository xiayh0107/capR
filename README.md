# capR

capR is an R-hosted implementation of **CAP-Digest v1.0 L0-L3** for the
published v1.0 fixture suite and the **table** source family. It resolves one
adapter, then runs one class-independent, policy-bounded pipeline.

The stable host representations are base `data.frame` plus optional
`tbl_df` and `data.table`. Community, experimental, and structural fallback
adapters do not inherit the stable table conformance claim.

Opt-in experimental constructors are also available for grouping-aware
`grouped_df`/`rowwise_df` evidence and bounded declarative `ggplot`
specifications. They require an explicit `adapter =` choice (or an explicit
registry entry for ggplot), never build a plot, and have
`conformance_claim = "none"`.

Ten further public constructors cover nested, array, relational, temporal,
spatial, graph, scientific, model, visual, and lazy/live objects. They are all
explicit, metadata-only experimental adapters, and all set
`conformance_claim = "none"`. Payload values are excluded, delayed objects are
not materialized, and live objects are not queried or collected. Relational
metadata can also be declared without DBI via `cap_db_schema()`.

## Install

```r
# install.packages("pak")
# Current 1.1 development APIs, including complex-object adapters
pak::pak("xiayh0107/capR")

# Published stable v1.0 fixture implementation
pak::pak("xiayh0107/capR@capR-v1.0.0")
```

GitHub is the publication target; CRAN publication is a separate future
decision. The tagged v1.0 package does not contain the unreleased 1.1
experimental constructors.

## Verified quick start

```r
library(capR)

orders <- data.frame(
  order_id = c("A001", "A002"),
  amount = c(12.5, 19),
  api_token = c("sk_test_123", "sk_test_456"),
  check.names = FALSE
)

digest <- cap_digest(orders, budget = 500, label = "orders")
cat(digest$text)

response <- list(
  claims = list(list(
    id = "shape",
    text = "The table has two rows and three columns.",
    evidence = list("f1:table@shape#base")
  )),
  evidence = list(),
  warnings = list(),
  requests = list()
)
validation <- cap_validate_response(digest, response)
stopifnot(validation$ok)
```

No model provider, credentials, remote service, or network access is required.
Sensitive-name values are redacted before rendering, source strings are
escaped, failed fields remain explicit, and follow-up extraction requires a
validated response plus host gate approval.

## Offline evidence

```r
report <- cap_run_fixtures()
stopifnot(report$ok, report$level == 3L)
cap_verify_vendor()
```

The release evidence set contains the source package, conformance report,
strict Draft 2020-12 schema report, independent structural interoperability
report, comparison report, fixture summary, environment metadata, and
checksummed manifests under `release-artifacts/capR-v1.0.0/`.

## CLI

```sh
Rscript "$(Rscript -e 'cat(system.file("exec", "capr", package = "capR"))')" help
Rscript /path/to/capr digest --input orders.csv --output artifacts --budget 500
```

The CLI accepts file-based inputs and delegates to public APIs. It does not
evaluate arbitrary R source.

## Agentic companion layer (opt-in, experimental)

`cap_agent_session()` ships the documented digest -> validate -> gate ->
patch round trip as a runnable loop. capR still contains zero network code:
the model call is injected by the host, and the gate -- never the model --
authorizes each follow-up disclosure.

```r
session <- cap_agent_session(orders, budget = 500)
cap_agent_run(session, ask = your_model_client)  # ask: function(text) -> response
cap_agent_transcript(session)                    # deterministic audit trail
```

With the suggested [aisdk](https://github.com/YuLab-SMU/aisdk) package
installed, `cap_aisdk_tools(session)` / `cap_aisdk_agent(session)` expose the
session as native aisdk tools so an aisdk agent drives the loop itself. See
`vignette("agentic-workflow")` and ADR-0006.

## Scope and non-goals

The v1.0 claim does not cover:

- remote or credentialed extraction;
- CAP-Core runtime or object semantics;
- arbitrary R object conformance;
- scientific or statistical correctness;
- automatic claim inheritance by community, experimental, or fallback
  adapters.

Structural fallback is disabled by default and, when explicitly enabled, is
bounded, structural-only, and marked `conformance_claim = "none"`.

## Documentation

- [Documentation index](docs/index.md)
- [中文快速上手（推荐）](vignettes/quickstart.Rmd)
- [复杂案例：多中心测序质控](vignettes/advanced-table-workflow.Rmd)
- [跨对象案例：tibble、分组与 ggplot](vignettes/tidy-ggplot-workflow.Rmd)
- [复杂对象全景：十类结构、设计动机与安全适配](vignettes/complex-object-workflow.Rmd)
- [Agent 情景教程：Nested](vignettes/nested-object-workflow.Rmd)
- [Agent 情景教程：Array](vignettes/array-object-workflow.Rmd)
- [Agent 情景教程：Relational](vignettes/relational-object-workflow.Rmd)
- [Agent 情景教程：Temporal](vignettes/temporal-object-workflow.Rmd)
- [Agent 情景教程：Spatial](vignettes/spatial-object-workflow.Rmd)
- [Agent 情景教程：Graph](vignettes/graph-object-workflow.Rmd)
- [Agent 情景教程：Scientific](vignettes/scientific-object-workflow.Rmd)
- [Agent 情景教程：Model](vignettes/model-object-workflow.Rmd)
- [Agent 情景教程：Visual](vignettes/visual-object-workflow.Rmd)
- [Agent 情景教程：Live](vignettes/live-object-workflow.Rmd)
- [Agentic workflow: closing the digest loop](vignettes/agentic-workflow.Rmd)
- [Getting started vignette](vignettes/getting-started.Rmd)
- [Stable public API and compatibility](docs/api/public-api-v1.md)
- [Experimental complex-object families](docs/adapters/complex-object-families.md)
- [Experimental tidy and ggplot adapters](docs/adapters/experimental-object-types.md)
- [CLI reference](docs/cli.md)
- [Adapter authoring](docs/handbook/writing-adapters.md)
- [Security model](SECURITY.md)
- [Adoption and conformance claim](ADOPTION.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Release process](docs/handbook/ci-release.md)

Upstream CAP-Digest resources are pinned to tag `cap-digest-v1.0.0`, commit
`d7890d4449107a88faed0e0c653d3751b57575f2`; vendored normative resources
take precedence over capR implementation guidance.
