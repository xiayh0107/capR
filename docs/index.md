# capR documentation

capR compiles R objects into bounded, citable evidence packs for LLMs and
gates every follow-up disclosure. If that sentence is new to you, don't
browse — take one of the three doors below.

## Start here

| If you… | Read |
|---|---|
| 想用中文完整走一遍（推荐） | [中文快速上手](../vignettes/quickstart.Rmd) — 从第一个 digest 到 gate、patch、工件落盘，全部可执行 |
| want the mental model first | [Concepts](concepts.md) — the six nouns, the one loop, and a jargon decoder |
| want working code in five minutes | [Getting started](../vignettes/getting-started.Rmd) — build a digest and actually read it |

## Use it

- [Response validation and follow-up](../vignettes/response-followup.Rmd) —
  check a model's citations, gate its requests.
- [Agentic workflow](../vignettes/agentic-workflow.Rmd) — let a model
  drive the loop via `cap_agent_session()`; mock client and aisdk shown.
- [Artifact I/O](../vignettes/artifact-io.Rmd) — persist and reload
  canonical digest artifacts.
- [CLI reference](cli.md) — the same round trip from the shell, CSV in,
  artifacts out.
- [Troubleshooting](troubleshooting.md) — the errors you'll actually hit
  and what they mean.

### Worked examples

- [复杂案例：多中心测序质控](../vignettes/advanced-table-workflow.Rmd) —
  a realistic mixed-type table, two disclosure rounds, redaction proofs.
- [跨对象案例：tibble、分组与 ggplot](../vignettes/tidy-ggplot-workflow.Rmd)

### Beyond tables (experimental, metadata-only)

[复杂对象全景](../vignettes/complex-object-workflow.Rmd) explains the ten
descriptor families and their hard limits; each family then has its own
executable tutorial:
[nested](../vignettes/nested-object-workflow.Rmd) ·
[array](../vignettes/array-object-workflow.Rmd) ·
[relational](../vignettes/relational-object-workflow.Rmd) ·
[temporal](../vignettes/temporal-object-workflow.Rmd) ·
[spatial](../vignettes/spatial-object-workflow.Rmd) ·
[graph](../vignettes/graph-object-workflow.Rmd) ·
[scientific](../vignettes/scientific-object-workflow.Rmd) ·
[model](../vignettes/model-object-workflow.Rmd) ·
[visual](../vignettes/visual-object-workflow.Rmd) ·
[live](../vignettes/live-object-workflow.Rmd)

## Extend it

- [Writing adapters](handbook/writing-adapters.md) — teach capR a new
  object type without touching the pipeline; pair with the
  [adapter authoring vignette](../vignettes/adapter-authoring.Rmd) and the
  [adapter API reference](api/adapter-api.md).
- [Strategy plugins](../vignettes/strategy-plugins.Rmd) — custom planners
  (field ranking) and tokenizers (budget accounting), plus the `capr.*`
  options layer and cost calibration.
- [Adapter contract](architecture/adapter-contract.md) and
  [registry resolution](architecture/registry-resolution.md) — the rules
  your adapter is held to.

## Trust it

- [Security model](architecture/security-model.md) and the repo-level
  [security policy](../SECURITY.md) — what is enforced, what is out of
  scope.
- [Table conformance](../vignettes/table-conformance.Rmd) and
  [testing & conformance](handbook/testing-conformance.md) — run the
  official fixture suite yourself (`cap_run_fixtures()`).
- [Adoption and conformance claims](../ADOPTION.md) — exactly what the
  v1.0 claim covers, and what it does not.
- [Public API and compatibility](api/public-api-v1.md) — stability
  promises, experimental surfaces, versioned artifacts; see also the
  [runtime API](api/runtime-api.md) and [error model](api/error-model.md).

## Project internals

- [Architecture overview](architecture/overview.md) — the pipeline in one
  diagram; deeper: [artifact boundaries](architecture/artifact-boundaries.md),
  [repository layout](architecture/repository-layout.md).
- [Architecture decision records](decisions/README.md) — why things are
  the way they are, including the
  [agentic companion layer](decisions/ADR-0006-agentic-companion-layer.md).
- [CI and release](handbook/ci-release.md) — how release evidence bundles
  are produced and reverified;
  [implementer guide](handbook/implementer-guide.md) for porting
  CAP-Digest to another host language.
- [Project charter](project-charter.md) · [Roadmap](roadmap/implementation-plan.md)

Upstream CAP-Digest normative resources and fixtures remain authoritative
for protocol behavior. capR documentation governs host integration, API
compatibility, security defaults, and release evidence.
