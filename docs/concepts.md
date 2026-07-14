# capR concepts

Everything in capR falls out of one decision: **the model is a reader, not
a user.** It can read what you disclosed, cite what it read, and ask for
more — but it cannot touch your object, and it cannot grant its own
requests. This page gives you the six nouns and one loop that the whole
API is built from. No protocol background needed.

## The records-office metaphor

Think of capR as the records office that sits between an archive (your R
object) and an outside investigator (the model):

- A **clerk** (*adapter*) knows how to handle one kind of record and
  prepares excerpts, blacking out secrets before anything is copied.
- The office issues a bounded **excerpt file** (*digest*): each exhibit
  has a number, the file states what it cost to produce, and the last page
  lists records that exist but were *not* copied.
- The investigator's report is only accepted if every statement cites
  exhibit numbers that are really in the file (*validation*).
- Requests for more records go to a **gatekeeper** (*gate*) who applies
  written **office rules** (*policy*) and a spending limit — the
  investigator's enthusiasm is not an argument.
- Approved records arrive as a numbered **addendum** (*patch*), and the
  file's ledger (*manifest*) records every disclosure forever.

## The six nouns

| Noun | Plain meaning | Where in the API |
|---|---|---|
| **Digest** | The bounded text document the model reads: disclosed `<field>` blocks, caveats, and an `<available_on_request>` list. Comes with a machine-readable manifest of everything selected and rejected. | `cap_digest()` → `$text`, `$manifest` |
| **Field** | One disclosable fact about the object (its shape, its column summary, sample rows), with a stable citable id like `f1:table@shape#base`, an estimated token cost, and an execution class saying how invasive it is to compute. | listed in the digest text and manifest |
| **Adapter** | The per-object-type plugin that declares which fields exist and how to extract, redact, and render them. Adapters never orchestrate; the pipeline is the same for every type. | `cap_table_adapter()`, `cap_new_adapter()`, `cap_register_adapter()` |
| **Policy** | Your written limits: token budgets, per-field time limit, which execution classes may run, whether follow-up is allowed. Fails closed — anything unknown or remote is denied unless you explicitly allow it. | `cap_policy()` |
| **Gate** | The deterministic decision step for follow-up requests. It reads no data, executes nothing, and approves or denies each request against the policy, the remaining follow-up budget, and source freshness. | `cap_gate()` |
| **Patch** | The only way a digest grows: materialization of gate-approved fields, applied as a typed, once-only extension with its own audit rows. | `cap_patch()`, `cap_apply_patch()` |

## The one loop

```text
        you                                the model
   ┌────────────┐    digest$text     ┌──────────────────┐
   │ cap_digest ├───────────────────►│ reads evidence    │
   └────────────┘                    │ cites field ids   │
         ▲                           │ may request more  │
         │                           └────────┬─────────┘
         │ cap_apply_patch                    │ claims + requests
         │                                    ▼
   ┌─────┴──────┐     approved      ┌──────────────────────┐
   │ cap_patch  │◄──────────────────┤ cap_validate_response │
   └────────────┘     cap_gate      │  (are citations real?)│
                    (may it? no data└──────────────────────┘
                     is read here)
```

Every arrow is a plain R function call, so you can run the loop by hand,
script it, or let `cap_agent_session()` / `cap_agent_run()` drive it for
you with a model client you supply. The gate stays in the loop either way.

## What never happens

These are invariants, not defaults:

- **No network, no model calls.** capR ships zero HTTP code. The model
  conversation happens outside, in your client or agent framework.
- **Redaction before rendering, always.** A renderer never sees an
  unredacted value; the ordering is contract-enforced at runtime.
- **The model never authorizes anything.** Disclosure decisions come from
  the gate under your policy, fail-closed: unknown execution classes,
  stale sources, exceeded budgets, and unlisted fields are all denials.
- **Determinism.** Identical inputs produce byte-identical artifacts — no
  timestamps, no randomness, content-derived ids — verified in CI against
  an independent Python implementation. If two runs differ, something
  actually changed.

## Jargon decoder

Words you will meet in the deeper docs, decoded once:

| Term | Decoded |
|---|---|
| **CAP-Digest v1.0** | The upstream protocol capR implements. Its spec, schemas, and test fixtures are vendored (copied and checksum-locked) into the package, so behavior is pinned, not aspirational. |
| **Evidence anchor** | A field id used as a citation. "Anchored" means the id exists, was selected, and appears in the digest text. |
| **Manifest** | The machine-readable ledger of a digest: every field considered, selected or rejected (and why), costs, redaction flags. The text and the manifest are cross-checked; divergence is an error. |
| **Conformance claim / L0–L3** | How much of the official fixture suite an adapter's behavior is verified against. L3 is the full suite. Only the stable table family carries a claim; experimental adapters say `conformance_claim = "none"` — public, but you're trusting code review, not fixtures. |
| **Fingerprint** | A hash identifying the source object's state. Follow-up is refused if it changed since the digest — no disclosing from an object that silently mutated. |
| **Execution class** | A field's invasiveness label (`local_cheap`, `local_scan`, `remote`, `credentialed`, `unsafe`, ...). Policy allows classes, not individual fields; remote/credentialed/unknown are denied by default. |
| **Interactive field** | A field never included up front, only obtainable through the validated request → gate → patch path (e.g. sample rows). |
| **Budget / tokenizer** | Disclosure is metered in estimated tokens. The tokenizer that does the counting is pluggable (`cap_tokenizer()`); the default is pinned for reproducibility. |
| **Sidecar** | A capR-specific provenance file (`resolution.capr.json`) written next to the canonical protocol artifacts, keeping implementation detail out of the pinned schemas. |
| **Canonical artifact** | One of the protocol-defined JSON/text files (`digest.json`, `manifest.json`, `gate.json`, ...) that any CAP-Digest implementation must produce byte-compatibly. |
| **Agent session / transcript** | The optional stateful loop runner (`cap_agent_session()`) and its deterministic audit record: per-turn validation, gate, patch, grounding metrics, and content hashes of every prompt and reply. |

## Where to go next

- Do it once by hand: [Getting started](../vignettes/getting-started.Rmd)
  or, in Chinese and more depth, the
  [中文快速上手](../vignettes/quickstart.Rmd).
- Let a model drive: [Agentic workflow](../vignettes/agentic-workflow.Rmd).
- Digest something that isn't a table:
  [complex-object families](adapters/complex-object-families.md).
- Teach capR a new object type:
  [writing adapters](handbook/writing-adapters.md).
- Verify the security story: [security model](architecture/security-model.md)
  and [SECURITY.md](../SECURITY.md).
