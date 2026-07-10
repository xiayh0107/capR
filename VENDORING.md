# Vendored CAP-Digest resources

capR vendors the stable CAP-Digest v1.0.0 release under
`inst/extdata/cap-digest/v1.0.0/`.

- Upstream: `https://github.com/xiayh0107/cap-docs.git`
- Tag: `cap-digest-v1.0.0`
- Commit: `d7890d4449107a88faed0e0c653d3751b57575f2`
- Source root: `release-artifacts/cap-digest-v1.0.0/`
- Local lock: `inst/extdata/cap-digest/v1.0.0/VENDOR-LOCK.json`

The lock records the upstream path, local destination, byte size, and SHA-256
for every copied file, including the upstream license. Runtime and test code
read only the vendored copy and never fetch normative files from the network.

To reproduce from an existing upstream checkout:

```sh
Rscript tools/vendor-cap-digest.R --source=../cap-docs
```

Without `--source`, the tool clones the pinned repository and verifies that
the tag resolves to the expected commit before copying anything.

An update requires a reviewed change to the tag and commit constants, a fresh
vendor lock, fixture and schema checks, and a changelog entry. Tests must never
rewrite expected upstream artifacts.
