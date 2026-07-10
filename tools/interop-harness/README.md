# Independent structural interoperability harness

`interop.py` uses only the Python standard library. It does not import capR,
load an R package, or call capR constructors, parsers, validators, or adapter
bindings. It reads the emitted files directly and checks:

- the exact canonical artifact inventory;
- JSON parsing and required schema identifiers;
- standalone/embedded digest text and manifest equality;
- field-anchor uniqueness and selected/rejected consistency;
- published fixture text, manifest, patch, finding-code, and pack behavior;
- the complete conformance fixture matrix and release provenance.

It emits a primary projection, independent structural report, and comparison
report. Missing/extra files, malformed content, anchor drift, fixture drift, or
matrix disagreement makes the command fail.

```sh
python3 tools/interop-harness/interop.py \
  --artifact-root schema-artifacts \
  --vendor-root inst/extdata/cap-digest/v1.0.0 \
  --output-dir schema-artifacts/interop
```

