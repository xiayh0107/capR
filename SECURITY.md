# Security

## Security posture

capR treats all source access as potentially executable. R methods, lazy objects, database proxies, external pointers, and print/summary helpers may allocate memory, perform I/O, or mutate process state.

Default policy for the first stable track:

```text
local cheap extraction: allowed under guard
local scans: budgeted and time-limited
remote access: denied
credential use: denied
unsafe or unknown execution: denied
```

## Required invariants

- Extract, then redact, then render.
- Data-trust strings are escaped before entering digest text.
- Failed fields are recorded and not rendered as normal values.
- Models request field IDs; a non-model gate authorizes execution.
- Follow-up verifies source fingerprint and pinned adapter provenance.
- Registry discovery does not authorize arbitrary executable code.
- Structural fallback makes no domain or scientific claim.

## R process safety

The implementation plan requires local state guards, bounded output and traversal, optional subprocess isolation for higher-risk extraction, explicit timeout handling, and deterministic formatting.

## Reporting

Do not file secrets or sensitive source data in a public issue. Use private vulnerability reporting when enabled. Include the affected commit, adapter, source family, non-sensitive reproduction, expected behavior, and whether remote I/O, credentials, or code execution occurred.
