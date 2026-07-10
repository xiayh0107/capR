# table-basic sample renderer

> Status: experimental

This renderer describes the reference output for `f1:table@sample#k10`.

Rules:

- render only after the follow-up gate allows the field;
- escape every value inside `<data>...</data>`;
- preserve source row order;
- do not render secret values that host policy has not approved;
- emit a `cap.digest_patch.v1` object rather than rewriting the base digest.
