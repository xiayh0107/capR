# capR

**Hand an LLM evidence about your data — never the data itself.**

[中文快速上手 →](vignettes/quickstart.Rmd) ·
[Concepts →](docs/concepts.md) ·
[Documentation map →](docs/index.md)

## The problem

You want a model to analyze a data frame, so you paste it into the prompt.
Three things go wrong at once:

- **It leaks.** That innocent-looking table has an `api_token` column, and
  now a secret lives in a prompt log.
- **You can't check the answer.** The model says "the table has 4,512
  rows" — was that read from your data or hallucinated? There is no way to
  tell.
- **There is no throttle.** The model wants more detail, so you paste
  more. Nobody decided how much of your data the model is entitled to see,
  and nothing recorded what it saw.

## What capR does

capR is a compiler from **R object** to **evidence pack**. Instead of your
data, the model receives a *digest*: a small, budgeted text document where
every fact carries a citable field id, secrets are redacted before
rendering, and everything the model was *not* shown is listed as
explicitly requestable. When the model answers, capR checks its citations
mechanically, and a deterministic *gate* — not the model, and not
politeness — decides whether any follow-up disclosure is allowed.

capR never calls a model. No provider, credentials, or network access is
required or used; you (or an agent framework) carry the text to the model
and bring the reply back. That makes every disclosure decision auditable,
reproducible, and yours.

## Sixty seconds

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
```

The digest text the model gets looks like this (abbreviated):

```text
cap digest text=v1 fields=f1 fp=... tokenizer=heuristic_v1 budget=160/500
# source: table label=orders rows=2 cols=3

<field id="f1:table@shape#base" trust="code" level="1">
2 rows x 3 columns
</field>

<field id="f1:table@columns#compact" trust="derived" level="1">
order_id <chr> e.g. <data>A001</data>, <data>A002</data>
amount <dbl> e.g. <data>12.5</data>, <data>19.0</data>
api_token <chr> e.g. <data>[masked: sensitive name]</data>
</field>

<caveats>
- [cap_caveat_redacted] f1:table@columns#compact: values in "api_token" were masked
</caveats>

<available_on_request>
f1:table@sample#k10 exec=local_scan level=1 estimated=300
</available_on_request>
```

Read it the way the model must: the only facts that exist are inside
`<field>` blocks, each with a citable id; the `api_token` values were
masked before rendering (`sk_test_123` appears nowhere); and the sample
rows were *not* sent — they are listed as requestable, at a stated cost,
subject to your policy.

When the model replies, it must cite those ids, and you verify instead of
trusting:

```r
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

A citation of a field that was never disclosed fails validation. A request
for more data goes through `cap_gate()`, which approves or denies it
against your policy and a follow-up budget, and only an approval can be
materialized into a patch. The full round trip is five functions:

```text
cap_digest()  ->  model reads digest$text
                  model replies with claims + citations + requests
cap_validate_response()  ->  are the citations real?
cap_gate()               ->  may any request be disclosed?
cap_patch() + cap_apply_patch()  ->  extend the digest, repeat
```

## Let a model drive the loop

The round trip above is manual by design, but you don't have to hand-roll
it. `cap_agent_session()` runs it as a multi-turn loop with any model
client you supply, produces a deterministic audit transcript with
per-turn grounding metrics, and with the suggested
[aisdk](https://github.com/YuLab-SMU/aisdk) package the session becomes
four native tools an aisdk agent can call directly:

```r
session <- cap_agent_session(orders, budget = 500)
cap_agent_run(session, ask = your_model_client)   # ask: function(text) -> reply
cap_agent_transcript(session)                     # who saw what, and why

analyst <- cap_aisdk_agent(session, model = "claude-sonnet-5")  # or any provider
```

However the model behaves, it can only cite disclosed fields, only request
listed ones, and every extra disclosure is decided by the gate under your
policy. See `vignette("agentic-workflow")`.

## Install

```r
# install.packages("pak")
pak::pak("xiayh0107/capR")              # current development line (1.1.x)
pak::pak("xiayh0107/capR@capR-v1.0.0")  # published stable v1.0
```

GitHub is the publication channel; CRAN is a separate future decision.
Runtime dependencies are just `digest`, `jsonlite`, and `methods`.

## What capR never does

- Never contacts a model provider or the network — grep the source.
- Never lets rendering run before redaction (contract-enforced).
- Never lets the model authorize disclosure — the gate does, fail-closed.
- Never produces irreproducible artifacts: identical inputs give
  byte-identical digests, manifests, and transcripts, verified against an
  independent Python implementation.

You can re-verify the shipped evidence offline at any time:

```r
report <- cap_run_fixtures()
stopifnot(report$ok, report$level == 3L)
cap_verify_vendor()
```

## Scope, honestly

capR implements the pinned **CAP-Digest v1.0** protocol. The *stable,
conformance-claimed* surface is tables: `data.frame`, plus optional
`tbl_df` and `data.table`. Everything else — grouped tables, ggplot
specifications, and ten metadata-only descriptor families (nested, array,
relational, temporal, spatial, graph, scientific, model, visual, live) —
is public but **experimental**, discloses bounded structure rather than
payload values, and carries `conformance_claim = "none"`. The v1.0 claim
does not cover remote or credentialed extraction, CAP-Core semantics,
arbitrary-object conformance, or scientific correctness of the model's
conclusions. Structural fallback is off by default.

The CLI mirrors the R API for file-based pipelines and evaluates no
arbitrary R:

```sh
Rscript "$(Rscript -e 'cat(system.file("exec", "capr", package = "capR"))')" help
```

## Documentation

Start at the **[documentation map](docs/index.md)**. The short list:

- [中文快速上手（推荐）](vignettes/quickstart.Rmd) — the full story in
  Chinese, executable end to end.
- [Concepts](docs/concepts.md) — the mental model in plain language.
- [Getting started](vignettes/getting-started.Rmd) — build and read your
  first digest.
- [Agentic workflow](vignettes/agentic-workflow.Rmd) — close the loop with
  a model.
- [Strategy plugins](vignettes/strategy-plugins.Rmd) — custom planners and
  tokenizers.
- [Security model](SECURITY.md) · [Adoption and claims](ADOPTION.md) ·
  [Public API and compatibility](docs/api/public-api-v1.md)

Upstream CAP-Digest resources are pinned to tag `cap-digest-v1.0.0`,
commit `d7890d4449107a88faed0e0c653d3751b57575f2`; vendored normative
resources take precedence over capR implementation guidance.
