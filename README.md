# capR

capR is an R-hosted implementation of **CAP-Digest v1.0 L0-L3** for the
published v1.0 fixture suite and the **table** source family. It resolves one
adapter, then runs one class-independent, policy-bounded pipeline.

The stable host representations are base `data.frame` plus optional
`tbl_df` and `data.table`. Community, experimental, and structural fallback
adapters do not inherit the stable table conformance claim.

## Install

```r
# install.packages("pak")
pak::pak("xiayh0107/capR@capR-v1.0.0")
```

GitHub is the v1.0 publication target; CRAN publication is a separate future
decision.

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
- [Getting started vignette](vignettes/getting-started.Rmd)
- [Stable public API and compatibility](docs/api/public-api-v1.md)
- [CLI reference](docs/cli.md)
- [Adapter authoring](docs/handbook/writing-adapters.md)
- [Security model](SECURITY.md)
- [Adoption and conformance claim](ADOPTION.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Release process](docs/handbook/ci-release.md)

Upstream CAP-Digest resources are pinned to tag `cap-digest-v1.0.0`, commit
`d7890d4449107a88faed0e0c653d3751b57575f2`; vendored normative resources
take precedence over capR implementation guidance.
