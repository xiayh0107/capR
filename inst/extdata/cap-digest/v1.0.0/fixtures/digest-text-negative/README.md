# digest-text-negative

This fixture family exercises deterministic CAP-Digest text parser failures and
manifest/text consistency problems.

Cases:

- `duplicate-field-id.txt` - duplicate selected field block.
- `invalid-field-id.txt` - field ID outside the `f1` grammar.
- `unclosed-data-fence.txt` - malformed `<data>` fence.
- `manifest-missing-selected-field.txt` - selected manifest row missing from
  digest text.
- `unknown-text-field.txt` - digest text field block not selected in the
  manifest.

The manifest consistency cases reuse `fixtures/basic-table/expected-manifest.json`.
