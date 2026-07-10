# capr CLI

Locate the installed wrapper with:

```r
system.file("exec", "capr", package = "capR")
```

Portable invocation uses `Rscript /path/to/capr`. Commands:

| Command | Purpose |
|---|---|
| `digest` | Read CSV and call `cap_digest()` |
| `validate-response` | Read artifacts/JSON and call `cap_validate_response()` |
| `gate` | Call pure `cap_gate()` with optional current fingerprint |
| `patch` | Read approved gate + CSV and call `cap_patch()` |
| `run-fixtures` | Run the complete offline L0-L3 suite |
| `inspect` | Emit a deterministic digest summary |
| `version`, `help` | Version and machine-readable operating guidance |

Examples:

```sh
Rscript /path/to/capr digest \
  --input orders.csv --output artifacts --label orders --budget 500

Rscript /path/to/capr validate-response \
  --digest artifacts --response response.json --output validation

Rscript /path/to/capr run-fixtures --output capr-conformance.json
```

Canonical JSON is written to stdout and errors to stderr. Exit codes are 0 for
success, 1 for an internal runtime failure, 2 for usage/input errors, and 3 for
a valid validation/gate result that does not authorize continuation.

Inputs are CSV and JSON only. The CLI does not evaluate R source, deserialize
R objects, enable fallback, contact remote services, or accept credentials.
Protocol behavior remains in the corresponding public R API.
