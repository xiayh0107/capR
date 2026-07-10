# sensitive-name redactor

The `table-basic` pack expects column example values to be masked when the column name matches a sensitive-name pattern.

Recommended patterns:

```text
password
secret
token
api_key
credential
private_key
```

Example rendering:

```text
api_token <chr> e.g. <data>[masked: sensitive name]</data>
```

This pack-level note does not override host policy. A host may apply stricter redaction.
