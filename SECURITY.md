# Security Policy

## Supported versions

| Version | Security support |
|---|---|
| 1.0.x | Supported |
| Development branch | Best effort until the next release |

## Private reporting

Do not put secrets, credentials, private source values, or an exploitable
proof-of-concept in a public issue. Use
[GitHub private vulnerability reporting](https://github.com/xiayh0107/capR/security/advisories/new).
If that channel is unavailable, contact the maintainer address in
`DESCRIPTION` and request a private channel before sharing sensitive details.

Include the affected capR version/commit, adapter ID/version, source family,
non-sensitive reproduction, expected behavior, impact, and whether the case
involves I/O, credentials, remote access, code execution, stale fingerprints,
or adapter drift. Receipt is acknowledged as soon as practical; coordinated
disclosure and a v1.0.x erratum are used for confirmed release defects.

## Stable security posture

capR treats every source touch as potentially executable. The default policy:

```text
local_cheap and local_scan: allowed through guarded materialization
remote and credentialed access: denied
unsafe and unknown execution: denied
structural fallback: denied unless explicitly enabled
follow-up: validation + host gate + fingerprint + adapter pin required
```

The stable invariants are:

- resolve and pin one adapter before source work;
- authorize before extraction;
- extract, redact, render, then escape/assemble;
- never render a failed field as normal evidence;
- keep canonical CAP artifacts separate from capR diagnostics/sidecars;
- treat model field requests as advisory until the host gate approves them;
- restore working directory, options, locale, and random state after guarded
  extraction;
- bound fallback traversal and renderer output;
- never load executable code, commands, network targets, or credentials from
  Digest Pack metadata.

Sensitive-name fixture values are masked before renderer input. Extractor
warning messages are not copied verbatim into canonical artifacts. Data strings
cannot create `field`, `data`, `contract`, caveat, or request structure.

## Explicit limitations

The v1.0 stable path does not provide operating-system sandboxing for arbitrary
third-party adapter code. It therefore denies unknown/high-risk execution by
default and treats adapter installation as trusted host administration.
Remote/credentialed extraction, lazy database backends, CAP-Core execution
semantics, model correctness, and scientific correctness are out of scope.

## Release response

Security fixes require unit and adversarial regression tests, regenerated
fixture/schema/interop evidence, a new release manifest, and a changelog entry.
Published checksums and tags are never silently replaced; corrections use a new
v1.0.x release.
