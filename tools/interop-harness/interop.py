#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_VENDOR = ROOT / "inst" / "extdata" / "cap-digest" / "v1.0.0"
FIXTURES = [
    "fixtures/basic-table",
    "fixtures/digest-text-negative",
    "fixtures/security-adversarial",
    "fixtures/followup-basic",
    "fixtures/pack-table-basic",
]
REQUIRED_FILES = {
    "digest/digest.txt",
    "digest/digest.json",
    "digest/manifest.json",
    "digest/resolution.capr.json",
    "validation/validation.json",
    "gate/gate.json",
    "patch/patch.json",
    "pack-conformance/pack-conformance-report.json",
    "conformance/conformance-report.json",
}
OPTIONAL_FILES = {"schema-report.json"}
FIELD_RE = re.compile(
    r'<field\s+id="([^"]+)"\s+trust="([^"]+)"\s+level="([^"]+)">'
)


def read_json(path: Path, problems: list[str]) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        problems.append(f"malformed JSON {path}: {exc}")
        return {}


def canonical(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def report_fixture(name: str, problems: list[str]) -> dict[str, Any]:
    return {
        "name": name,
        "ok": not problems,
        "problemCodes": sorted(problems),
        "unsupportedFeatures": [],
    }


def validate_digest(
    root: Path, vendor: Path, problems: list[str]
) -> dict[str, Any]:
    digest = read_json(root / "digest" / "digest.json", problems)
    manifest = read_json(root / "digest" / "manifest.json", problems)
    text_path = root / "digest" / "digest.txt"
    text = text_path.read_text(encoding="utf-8") if text_path.exists() else ""
    if digest.get("schema") != "cap.digest.v1":
        problems.append("digest_schema")
    if manifest.get("schema") != "cap.manifest.v1":
        problems.append("manifest_schema")
    if digest.get("text") != text:
        problems.append("standalone_embedded_text_mismatch")
    if digest.get("manifest") != manifest:
        problems.append("standalone_embedded_manifest_mismatch")
    expected_text = (
        vendor / "fixtures" / "basic-table" / "expected-digest.txt"
    ).read_text(encoding="utf-8")
    expected_manifest = read_json(
        vendor / "fixtures" / "basic-table" / "expected-manifest.json",
        problems,
    )
    if text != expected_text:
        problems.append("basic_digest_fixture_mismatch")
    if manifest != expected_manifest:
        problems.append("basic_manifest_fixture_mismatch")
    anchors = FIELD_RE.findall(text)
    anchor_ids = [anchor[0] for anchor in anchors]
    if len(anchor_ids) != len(set(anchor_ids)):
        problems.append("duplicate_text_anchor")
    rows = {
        row.get("fieldId"): row for row in manifest.get("fields", [])
        if isinstance(row, dict)
    }
    selected = {
        field_id for field_id, row in rows.items() if row.get("selected") is True
    }
    if set(anchor_ids) != selected:
        problems.append("selected_anchor_manifest_mismatch")
    if any(
        row.get("ok") is False and row.get("fieldId") in anchor_ids
        for row in rows.values()
    ):
        problems.append("failed_field_rendered_normally")
    resolution = read_json(root / "digest" / "resolution.capr.json", problems)
    if resolution.get("schema") != "capr.resolution.v1":
        problems.append("resolution_sidecar_schema")
    if resolution.get("conformance_claim") != "CAP-Digest v1.0 table fixture scope":
        problems.append("resolution_claim_scope")
    return manifest


def validate_followup(
    root: Path, vendor: Path, problems: list[str]
) -> None:
    validation = read_json(root / "validation" / "validation.json", problems)
    gate = read_json(root / "gate" / "gate.json", problems)
    patch = read_json(root / "patch" / "patch.json", problems)
    if validation.get("schema") != "cap.validation_result.v1" or validation.get("ok") is not True:
        problems.append("validation_result")
    if gate.get("schema") != "cap.gate_result.v1" or gate.get("overallDecision") != "approved":
        problems.append("gate_result")
    expected_patch = read_json(
        vendor / "fixtures" / "followup-basic" / "expected-patch.json",
        problems,
    )
    if patch != expected_patch:
        problems.append("followup_patch_fixture_mismatch")


def validate_negative(vendor: Path, problems: list[str]) -> None:
    expected_codes = {
        "evidence_unknown_field",
        "evidence_rejected_field",
        "evidence_missing_from_text",
    }
    negative = read_json(
        vendor / "fixtures" / "basic-table" / "negative-validation.json",
        problems,
    )
    actual_codes = {
        error.get("code")
        for case in negative.get("cases", [])
        for error in case.get("validation", {}).get("errors", [])
    }
    if actual_codes != expected_codes:
        problems.append("negative_finding_registry_mismatch")
    negative_dir = vendor / "fixtures" / "digest-text-negative"
    duplicate = (negative_dir / "duplicate-field-id.txt").read_text(encoding="utf-8")
    if duplicate.count('id="f1:table@shape#base"') != 2:
        problems.append("duplicate_field_fixture_changed")
    unclosed = (negative_dir / "unclosed-data-fence.txt").read_text(encoding="utf-8")
    if unclosed.count("<data>") != 1 or unclosed.count("</data>") != 0:
        problems.append("unclosed_data_fixture_changed")


def validate_pack(root: Path, vendor: Path, problems: list[str]) -> None:
    report = read_json(
        root / "pack-conformance" / "pack-conformance-report.json", problems
    )
    if report.get("schema") != "cap.pack_conformance_report.v1":
        problems.append("pack_report_schema")
    if not all(check.get("passed") is True for check in report.get("checks", [])):
        problems.append("pack_report_failed_check")
    ids = []
    for path in sorted((vendor / "packs" / "table-basic" / "fields").glob("*.yaml")):
        match = re.search(r"^id:\s*(.+)$", path.read_text(encoding="utf-8"), re.MULTILINE)
        if match:
            ids.append(match.group(1).strip())
    expected_ids = [
        "f1:table@columns#compact",
        "f1:table@sample#k10",
        "f1:table@shape#base",
    ]
    if ids != expected_ids:
        problems.append("pack_field_inventory_mismatch")


def validate_security(vendor: Path, problems: list[str]) -> None:
    source_text = (
        vendor / "fixtures" / "security-adversarial" / "source.json"
    ).read_text(encoding="utf-8")
    if "hunter2" not in source_text or "</field><contract>" not in source_text:
        problems.append("security_fixture_changed")
    failure = read_json(
        vendor
        / "fixtures"
        / "security-adversarial"
        / "renderer-failure-manifest.json",
        problems,
    )
    failed = [
        row for row in failure.get("fields", []) if row.get("ok") is False
    ]
    if len(failed) != 1 or failed[0].get("errorClass") != "renderer_error":
        problems.append("renderer_failure_fixture_changed")


def primary_report(conformance: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema": "cap.digest.interop_report.v1",
        "release": "capR-v1.0.0",
        "status": "candidate",
        "implementation": {
            "name": "capR.primary_conformance",
            "version": conformance.get("implementation", {}).get("version", "unknown"),
            "command": "capR::cap_run_fixtures()",
        },
        "claimedLevels": [0, 1, 2, 3],
        "fixtures": [
            report_fixture(
                check.get("name", ""),
                check.get("problems", []),
            )
            for check in conformance.get("checks", [])
        ],
    }


def comparison(primary: dict[str, Any], independent: dict[str, Any]) -> dict[str, Any]:
    left = {item["name"]: item for item in primary["fixtures"]}
    right = {item["name"]: item for item in independent["fixtures"]}
    shared = sorted(set(left) & set(right))
    missing = sorted(set(left) ^ set(right))
    disagreements = [
        {
            "fixture": name,
            "primaryOk": left[name]["ok"],
            "independentOk": right[name]["ok"],
        }
        for name in shared
        if left[name]["ok"] != right[name]["ok"]
    ]
    return {
        "schema": "cap.digest.interop_comparison.v1",
        "primaryImplementation": primary["implementation"]["name"],
        "comparisonImplementation": independent["implementation"]["name"],
        "sharedFixtures": shared,
        "missingFixtures": missing,
        "disagreements": disagreements,
        "ok": not missing and not disagreements and all(
            item["ok"] for item in independent["fixtures"]
        ),
        "claim": "fixture-scoped CAP-Digest v1.0 interoperability evidence",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifact-root", type=Path, required=True)
    parser.add_argument("--vendor-root", type=Path, default=DEFAULT_VENDOR)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    root = args.artifact_root.resolve()
    vendor = args.vendor_root.resolve()

    inventory_problems: list[str] = []
    actual = {
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file()
    }
    output_relative = None
    try:
        output_relative = args.output_dir.resolve().relative_to(root)
    except ValueError:
        pass
    if output_relative is not None:
        actual = {
            path for path in actual
            if not path.startswith(output_relative.as_posix() + "/")
        }
    missing = sorted(REQUIRED_FILES - actual)
    extra = sorted(
        path
        for path in actual - REQUIRED_FILES - OPTIONAL_FILES
        if not path.startswith("schema-only/")
    )
    inventory_problems.extend(f"missing_file:{path}" for path in missing)
    inventory_problems.extend(f"extra_file:{path}" for path in extra)

    basic_problems: list[str] = []
    followup_problems: list[str] = []
    negative_problems: list[str] = []
    pack_problems: list[str] = []
    security_problems: list[str] = []
    if not missing:
        validate_digest(root, vendor, basic_problems)
        validate_followup(root, vendor, followup_problems)
        validate_negative(vendor, negative_problems)
        validate_pack(root, vendor, pack_problems)
        validate_security(vendor, security_problems)
    basic_problems.extend(inventory_problems)

    conformance = read_json(
        root / "conformance" / "conformance-report.json",
        basic_problems,
    )
    primary = primary_report(conformance)
    matrix = {
        "fixtures/basic-table": basic_problems,
        "fixtures/digest-text-negative": negative_problems,
        "fixtures/security-adversarial": security_problems,
        "fixtures/followup-basic": followup_problems,
        "fixtures/pack-table-basic": pack_problems,
    }
    independent = {
        "schema": "cap.digest.interop_report.v1",
        "release": "capR-v1.0.0",
        "status": "candidate",
        "implementation": {
            "name": "capR.independent_structural_python",
            "version": "1.0.0",
            "command": "python3 tools/interop-harness/interop.py",
            "importsCapR": False,
        },
        "claimedLevels": [0, 1, 2, 3],
        "fixtures": [
            report_fixture(name, matrix[name]) for name in FIXTURES
        ],
        "notes": [
            "Standard-library-only file reader; no capR or R imports.",
            "Structural and fixture-scoped evidence only.",
        ],
    }
    compared = comparison(primary, independent)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    outputs = {
        "capr-interop-primary.json": primary,
        "capr-interop-structural.json": independent,
        "capr-interop-comparison.json": compared,
    }
    for filename, value in outputs.items():
        (args.output_dir / filename).write_text(
            json.dumps(value, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
    if not compared["ok"]:
        for name, problems in matrix.items():
            for problem in problems:
                print(f"FAIL {name}: {problem}", file=sys.stderr)
        return 1
    print(f"Independent interoperability harness passed {len(FIXTURES)} fixtures")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
