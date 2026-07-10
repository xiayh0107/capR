# Draft 2020-12 schema harness

The release schema gate uses Python `jsonschema==4.26.0` and explicitly
constructs `Draft202012Validator` instances. Versions of the validator and
its direct runtime dependencies are pinned in `requirements.txt`; these
packages are development/release tooling and are not capR runtime dependencies.

```sh
python3 -m pip install -r tools/schema-harness/requirements.txt
Rscript tools/generate-fixture-artifacts.R schema-artifacts
python3 tools/schema-harness/validate.py \
  --artifacts schema-artifacts \
  --report schema-artifacts/schema-report.json
```

The harness performs no network access. It checks every vendored schema with
the Draft 2020-12 meta-validator, validates all canonical JSON fixtures and
capR-emitted artifacts, and proves that intentionally invalid in-memory cases
are rejected. Updating the validator requires a reviewed requirements update,
a complete fixture run, and release evidence regeneration.
