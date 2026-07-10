# CAP-Digest Text Grammar v1.0

> Status: stable v1.0 - Normative grammar - Last updated: 2026-07-07

This document freezes the digest text grammar for `text=v1` and `fields=f1`.

## Version Line

The first line MUST start with:

```text
cap digest text=v1 fields=f1
```

The line MUST also identify the source fingerprint, tokenizer, and budget in
the form used by the fixture suite:

```text
fp=<fingerprint> tokenizer=<tokenizer> budget=<used>/<requested>
```

## Source Line

The second line MUST start with:

```text
# source:
```

For the stable table fixture family, the source line records source type,
label, row count, and column count.

## Field Blocks

Selected evidence fields MUST be serialized as:

```xml
<field id="f1:table@shape#base" trust="code" level="1">
field body
</field>
```

Required attributes:

- `id`;
- `trust`;
- `level`.

Field ids MUST be unique within a digest text document. Field ids MUST match:

```text
f1:<source-family>@<field-name>#<variant>
```

with lowercase alphanumeric, underscore, and hyphen components as enforced by
the reference parser.

## Data Fences

Raw source values in field bodies SHOULD be wrapped in `<data>...</data>`.
Implementations MUST escape literal source text that would otherwise create
`<field>`, `</field>`, `<data>`, `</data>`, or contract-like markup.

Nested data fences, unopened data fences, and unclosed data fences are invalid.

## Caveats

Digest text MAY include:

```xml
<caveats>
- [cap_caveat_redacted] ...
</caveats>
```

Security-relevant caveats SHOULD cite the field id and reason.

## Available-On-Request

Digest text MAY include:

```xml
<available_on_request>
f1:table@sample#k10 exec=local_scan level=1 estimated=300
</available_on_request>
```

This section is only advisory to the model. The follow-up gate enforces policy,
fingerprint, budget, and request validity.

## Invalid Text Findings

The stable parser finding codes are listed in
`VALIDATOR-CODES-v1.0.md`. Implementations may produce richer diagnostics but
MUST preserve equivalent rejection behavior for stable negative fixtures.
