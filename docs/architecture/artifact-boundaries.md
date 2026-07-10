# Canonical Artifacts and capR Sidecars

## Rule

Canonical CAP artifacts must remain independently valid and comparable. Implementation-specific metadata is stored in a sidecar unless the canonical schema explicitly permits the property.

## Canonical outputs

```text
digest.txt
digest.json
manifest.json
validation.json
gate.json
patch.json
conformance-report.json
```

Their shapes and finding codes follow the vendored CAP-Digest release.

## capR sidecars

```text
resolution.capr.json
registry.lock.json
run.capr.json
diagnostics.capr.json
```

A resolution sidecar may contain adapter identity, provider version, resolution mode, matched class, priority, fingerprint algorithm, and capR version.

## Prohibited mixing

Do not add closures or R source code to serialized field metadata, insert undocumented properties into closed schemas, change canonical manifests for debugging, treat `.cap/` as CAP-Core semantics, or require a sidecar to interpret canonical evidence anchors.

## Reproducibility

Release reports must be reproducible from committed canonical artifacts. Sidecars may explain execution provenance but are not the sole evidence that a CAP fixture passed.
