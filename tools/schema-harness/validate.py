#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import json
import sys
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator
from referencing import Registry, Resource


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_VENDOR = ROOT / "inst" / "extdata" / "cap-digest" / "v1.0.0"


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def schema_registry(schema_dir: Path) -> tuple[dict[str, dict[str, Any]], Registry]:
    schemas: dict[str, dict[str, Any]] = {}
    resources: list[tuple[str, Resource[Any]]] = []
    for path in sorted(schema_dir.glob("*.schema.json")):
        schema = load_json(path)
        if schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
            raise ValueError(f"{path}: schema is not Draft 2020-12")
        Draft202012Validator.check_schema(schema)
        schema_id = schema.get("$id")
        if not schema_id:
            raise ValueError(f"{path}: missing $id")
        schema_key = schema.get("properties", {}).get("schema", {}).get(
            "const", path.name.removesuffix(".schema.json")
        )
        schemas[schema_key] = schema
        resources.append((schema_id, Resource.from_contents(schema)))
    return schemas, Registry().with_resources(resources)


def fixture_cases(vendor: Path) -> list[tuple[str, str, Any]]:
    fixtures = vendor / "fixtures"
    basic = fixtures / "basic-table"
    positive_validation = load_json(basic / "expected-validation.json")
    negative_validation = load_json(basic / "negative-validation.json")
    followup = fixtures / "followup-basic"
    cases: list[tuple[str, str, Any]] = [
        ("basic manifest", "cap.manifest.v1", load_json(basic / "expected-manifest.json")),
        ("basic response", "cap.contract_response.v1", positive_validation["response"]),
        ("basic validation", "cap.validation_result.v1", positive_validation["validation"]),
        (
            "followup approved response",
            "cap.contract_response.v1",
            load_json(followup / "request-approved.json"),
        ),
        (
            "followup validation",
            "cap.validation_result.v1",
            load_json(followup / "expected-validation-approved.json"),
        ),
        (
            "followup gate approved",
            "cap.gate_result.v1",
            load_json(followup / "expected-gate-approved.json"),
        ),
        (
            "followup gate stale",
            "cap.gate_result.v1",
            load_json(followup / "expected-gate-stale.json"),
        ),
        (
            "followup patch",
            "cap.digest_patch.v1",
            load_json(followup / "expected-patch.json"),
        ),
        (
            "security failure manifest",
            "cap.manifest.v1",
            load_json(fixtures / "security-adversarial" / "renderer-failure-manifest.json"),
        ),
        (
            "pack conformance report",
            "cap.pack_conformance_report.v1",
            load_json(fixtures / "pack-table-basic" / "expected-pack-report.json"),
        ),
        (
            "vendored conformance report",
            "cap.conformance_report.v1",
            load_json(vendor / "reports" / "digest-conformance-report.json"),
        ),
    ]
    for index, case in enumerate(negative_validation["cases"]):
        cases.append(
            (
                f"negative response {index}",
                "cap.contract_response.v1",
                case["response"],
            )
        )
        cases.append(
            (
                f"negative validation {index}",
                "cap.validation_result.v1",
                case["validation"],
            )
        )
    return cases


def errors_for(
    instance: Any,
    schema_name: str,
    schemas: dict[str, dict[str, Any]],
    registry: Registry,
) -> list[str]:
    if schema_name not in schemas:
        return [f"no vendored schema for {schema_name}"]
    validator = Draft202012Validator(schemas[schema_name], registry=registry)
    return [
        f"{'/'.join(str(part) for part in error.absolute_path)}: {error.message}"
        for error in sorted(validator.iter_errors(instance), key=lambda error: list(error.absolute_path))
    ]


def emitted_artifact_cases(paths: list[Path]) -> list[tuple[str, str, Any]]:
    cases: list[tuple[str, str, Any]] = []
    for root in paths:
        files = [root] if root.is_file() else sorted(root.rglob("*.json"))
        for path in files:
            instance = load_json(path)
            schema_name = instance.get("schema") if isinstance(instance, dict) else None
            if not schema_name and path.name == "contract-response.json":
                schema_name = "cap.contract_response.v1"
            if not schema_name:
                continue
            if schema_name.startswith("capr."):
                continue
            cases.append((str(path), schema_name, instance))
    return cases


def negative_cases(vendor: Path) -> list[tuple[str, str, Any]]:
    manifest = load_json(vendor / "fixtures" / "basic-table" / "expected-manifest.json")
    missing_fingerprint = copy.deepcopy(manifest)
    missing_fingerprint.pop("fingerprint")
    bad_gate = load_json(vendor / "fixtures" / "followup-basic" / "expected-gate-stale.json")
    bad_gate["requests"][0]["decision"] = "silently_allowed"
    patch = load_json(vendor / "fixtures" / "followup-basic" / "expected-patch.json")
    bad_patch = copy.deepcopy(patch)
    bad_patch["operations"][0]["op"] = "execute_arbitrary_code"
    validation = load_json(vendor / "fixtures" / "followup-basic" / "expected-validation-approved.json")
    bad_validation = copy.deepcopy(validation)
    bad_validation["unexpected"] = True
    return [
        ("invalid manifest missing fingerprint", "cap.manifest.v1", missing_fingerprint),
        ("invalid gate decision", "cap.gate_result.v1", bad_gate),
        ("invalid patch operation", "cap.digest_patch.v1", bad_patch),
        ("invalid validation property", "cap.validation_result.v1", bad_validation),
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--vendor-root", type=Path, default=DEFAULT_VENDOR)
    parser.add_argument("--artifacts", type=Path, action="append", default=[])
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    vendor = args.vendor_root.resolve()
    checks: list[dict[str, Any]] = []
    try:
        schemas, registry = schema_registry(vendor / "schemas")
    except Exception as exc:
        checks.append(
            {
                "name": "schema meta-validation",
                "expected": "valid",
                "ok": False,
                "errors": [str(exc)],
            }
        )
        schemas, registry = {}, Registry()
    else:
        checks.append(
            {
                "name": "schema meta-validation",
                "expected": "valid",
                "ok": True,
                "errors": [],
                "count": len(schemas),
                "draft": "2020-12",
            }
        )

    for name, schema_name, instance in [
        *fixture_cases(vendor),
        *emitted_artifact_cases(args.artifacts),
    ]:
        errors = errors_for(instance, schema_name, schemas, registry)
        checks.append(
            {
                "name": name,
                "schema": schema_name,
                "expected": "valid",
                "ok": not errors,
                "errors": errors,
            }
        )
    for name, schema_name, instance in negative_cases(vendor):
        errors = errors_for(instance, schema_name, schemas, registry)
        checks.append(
            {
                "name": name,
                "schema": schema_name,
                "expected": "invalid",
                "ok": bool(errors),
                "errors": errors,
            }
        )

    report = {
        "schema": "capr.schema_harness_report.v1",
        "validator": {
            "name": "python-jsonschema",
            "version": "4.26.0",
            "draft": "2020-12",
        },
        "ok": all(check["ok"] for check in checks),
        "checks": checks,
    }
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
    if not report["ok"]:
        for check in checks:
            if not check["ok"]:
                print(f"FAIL: {check['name']}", file=sys.stderr)
                for error in check["errors"]:
                    print(f"  {error}", file=sys.stderr)
        return 1
    print(f"Draft 2020-12 schema harness passed {len(checks)} checks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
