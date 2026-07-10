# security-adversarial

This fixture family backs the CAP-Digest security chapter with adversarial cases.

It checks that:

- source strings that try to close `<data>` or `<field>` tags are escaped before
  rendering;
- secret-like field names are masked before rendering;
- renderer failures are represented as failed manifest rows instead of normal
  rendered values.

The fixture intentionally tests CAP-Digest context artifact guarantees only. It
does not claim model reasoning correctness or CAP-Core execution security.
