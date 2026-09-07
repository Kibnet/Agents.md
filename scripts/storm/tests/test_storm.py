"""Contract/CLI regressions. All fixtures and output writes use temporary dirs."""
from __future__ import annotations

import copy
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts/storm"))
from storm_model import (ContractError, StormModel, own_effort, own_value,
                         read_json, self_check_schema, step_metrics, validate_structure)


def artifact():
    return read_json(ROOT / "templates/storm/storm.json")


def story(key="ST-0001", **fields):
    return dict(id=key, title=key, status="proposed", provenance="fixture", confidence=1,
                acceptance_criteria=[], supports_needs=[], linked_tests=[], linked_code=[], **fields)


def node(key, **fields):
    return dict(id=key, title=key, status="proposed", provenance="fixture", confidence=1, **fields)


def edge(src, dst, index=1):
    return dict(id=f"DP-{index:04d}", **{"from": src, "to": dst}, type="prerequisite", reason="fixture")


def scenario(index=1, steps=None, status="draft"):
    return dict(id=f"SC-1-{index:03d}", title="Observable example", file="test.feature",
                coverage_role="happy_path", status=status, step_definitions=steps or [])


class CliTests(unittest.TestCase):
    def run_cli(self, data, cli, *, raw=False, write=False, root=ROOT, hash_seed="0"):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            source, report = folder / "storm.json", folder / "ranking.md"
            payload = data if raw else json.dumps(data, ensure_ascii=False)
            source.write_bytes(payload.encode("utf-8"))
            before = source.read_bytes()
            report.write_bytes(b"existing report\r\nkeep these bytes\x00")
            report_before = report.read_bytes()
            args = [sys.executable, str(root / "scripts/storm" / cli), str(source)]
            if cli == "rank-backlog.py":
                args += ["--out", str(report)]
                if write:
                    args += ["--write-json"]
            result = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", timeout=20,
                                    env=dict(os.environ, PYTHONHASHSEED=hash_seed))
            self.assertNotIn("Traceback", result.stderr + result.stdout)
            if result.returncode:
                self.assertEqual(source.read_bytes(), before)
                self.assertEqual(report.read_bytes(), report_before)
            elif cli == "validate-artifacts.py" or not write:
                self.assertEqual(source.read_bytes(), before)
            return result, source.read_bytes(), report.read_bytes()

    def both_reject(self, data, path, exit_code=1, raw=False):
        for cli in ("validate-artifacts.py", "rank-backlog.py"):
            with self.subTest(cli=cli, path=path):
                result, _, _ = self.run_cli(data, cli, raw=raw, write=True)
                self.assertEqual(result.returncode, exit_code, result.stdout + result.stderr)
                self.assertIn(path, result.stdout)

    def test_starter_11_and_12_are_readable(self):
        for version in ("1.1.0", "1.2.0"):
            data = artifact()
            data["metadata"]["schema_version"] = version
            if version == "1.1.0":
                del data["enablers"]
                data["process_audit"].pop("metrics_version")
            for cli in ("validate-artifacts.py", "rank-backlog.py"):
                result, _, _ = self.run_cli(data, cli)
                self.assertEqual(result.returncode, 0, result.stdout)

    def test_invalid_roots(self):
        for root in (None, [], "text", True, 1):
            self.both_reject(root, "$: expected object")

    def test_required_root_key(self):
        data = artifact()
        del data["stories"]
        self.both_reject(data, "$.stories")

    def test_collection_types_required_and_optional(self):
        for key in ("stories", "enablers", "gherkin_scenarios"):
            for value in (None, {}, "bad", True):
                data = artifact()
                data[key] = value
                self.both_reject(data, f"$.{key}")

    def test_collection_item_and_nested_types(self):
        for value in (None, [], "bad", 3):
            data = artifact()
            data["stories"] = [value]
            self.both_reject(data, "$.stories[0]")
        for field, value in (("acceptance_criteria", [None]), ("linked_tests", [False]),
                             ("priority", None), ("dependencies", {}), ("evidence", ["bad"])):
            data = artifact()
            item = story()
            item[field] = value
            data["stories"] = [item]
            self.both_reject(data, f"$.stories[0].{field}")

    def test_enabler_required_optional_and_null(self):
        data = artifact()
        data["enablers"] = [node("EN-0001")]
        self.assertEqual(self.run_cli(data, "rank-backlog.py")[0].returncode, 0)
        for field in ("title", "status", "provenance", "confidence"):
            broken = copy.deepcopy(data)
            del broken["enablers"][0][field]
            self.both_reject(broken, f"$.enablers[0].{field}")
        for field in ("priority", "dependencies", "supports", "linked_tests", "linked_code", "evidence"):
            broken = copy.deepcopy(data)
            broken["enablers"][0][field] = None
            self.both_reject(broken, f"$.enablers[0].{field}")

    def test_numeric_types_ranges_and_nonfinite(self):
        for field, value in (("reach", -1), ("reach", False), ("reach", None), ("reach", "1"),
                             ("impact", -0.1), ("confidence", 1.1), ("confidence", -0.1),
                             ("effort", 0), ("effort", -1), ("effort", True),
                             ("reach", float("nan")), ("impact", float("inf"))):
            data = artifact()
            data["stories"] = [story(priority={field: value})]
            self.both_reject(data, field)
        data = artifact()
        data["stories"] = [story(priority={"agentic_effort": {"verification_complexity": "2"}})]
        self.both_reject(data, "verification_complexity")
        data["stories"][0]["confidence"] = True
        self.both_reject(data, "$.stories[0].confidence")

    def test_nonfinite_extension_and_calculated_overflow(self):
        data = artifact()
        data["extension"] = {"value": float("inf")}
        self.both_reject(data, "$.extension.value")
        data = artifact()
        data["stories"] = [story(priority={"reach": 1e308, "impact": 1e308})]
        self.both_reject(data, "computed.own_value")
        data["stories"] = [story(priority={"reach": 1e308, "effort": 1e-308})]
        self.both_reject(data, "computed.priority_star")
        data["stories"] = [story(priority={"agentic_effort": {"architecture_blast_radius": 1e308, "verification_complexity": 1e308}})]
        self.both_reject(data, "computed.effort")
        data["stories"] = [story(priority={"effort": 1e308}), story("ST-0002", priority={"effort": 1e308}, dependencies=["ST-0001"])]
        self.both_reject(data, "computed.cost_star")
        self.both_reject('{"number": 1e999}', "$.number", raw=True)

    def test_malformed_json_and_read_errors(self):
        self.both_reject('{"stories":', "cannot read JSON", 2, raw=True)
        for cli in ("validate-artifacts.py", "rank-backlog.py"):
            with tempfile.TemporaryDirectory() as temp:
                result = subprocess.run([sys.executable, str(ROOT / "scripts/storm" / cli), temp], capture_output=True, text=True)
                self.assertEqual(result.returncode, 2)
                self.assertNotIn("Traceback", result.stderr)

    def test_duplicate_ids_and_dangling_typed_refs(self):
        data = artifact()
        data["stories"] = [story(), story()]
        self.both_reject(data, "duplicate ID")
        data["stories"] = [story(dependencies=["EN-9999"])]
        self.both_reject(data, "unresolved ST/CN/EN")
        data["stories"] = [story()]
        data["enablers"] = [node("EN-0001", supports=["EN-0001"])]
        self.both_reject(data, "$.enablers[0].supports")
        data["enablers"] = [node("EN-0001", linked_tests=["TS-9999"])]
        self.both_reject(data, "$.enablers[0].linked_tests")
        data["enablers"] = []
        data["code_units"] = [dict(id="CU-0001", path="x.py", kind="module", supports=["EN-9999"])]
        self.both_reject(data, "$.code_units[0].supports")

    def test_embedded_top_level_and_mixed_cycles_before_status_filter(self):
        for mode in ("embedded", "top", "mixed"):
            data = artifact()
            a, b = story(), story("ST-0002")
            a["status"] = "removed"
            b["status"] = "implemented"
            data["stories"] = [a, b]
            if mode in ("embedded", "mixed"):
                a["dependencies"] = [b["id"]]
            else:
                data["dependencies"].append(edge(b["id"], a["id"]))
            if mode == "embedded":
                b["dependencies"] = [a["id"]]
            else:
                data["dependencies"].append(edge(a["id"], b["id"], 2))
            self.both_reject(data, "dependency cycle")
        data = artifact()
        data["stories"] = [story(dependencies=["ST-0001"])]
        self.both_reject(data, "self-loop")

    def test_unknown_status_in_all_planning_sections_and_scenarios(self):
        for section, item in (("stories", story()), ("constraints", node("CN-0001")),
                              ("enablers", node("EN-0001")), ("gherkin_scenarios", scenario())):
            data = artifact()
            item["status"] = "unknown"
            data[section] = [item]
            self.both_reject(data, f"$.{section}[0].status")

    def test_write_changes_only_ranking_preserves_extensions_order_and_audit(self):
        data = artifact()
        data["extension"] = {"custom": [3, 2, 1]}
        data["process_audit"] = {"last_run_at": "old", "metrics": {"step_reuse_ratio": 0.75}}
        a, b = story("ST-0002"), story()
        a["custom"] = "kept"
        data["stories"] = [a, b]
        result, payload, report = self.run_cli(data, "rank-backlog.py", write=True)
        self.assertEqual(result.returncode, 0, result.stdout)
        after = json.loads(payload)
        self.assertEqual(list(after), list(data))
        self.assertEqual([row["item"] for row in after["ranking"]], ["ST-0001", "ST-0002"])
        after["ranking"] = data["ranking"]
        self.assertEqual(after, data)
        self.assertNotIn("unranked_items", after)
        self.assertIn(b"## unranked_items", report)

    def test_report_cannot_overwrite_input(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "storm.json"
            path.write_text(json.dumps(artifact()), encoding="utf-8")
            before = path.read_bytes()
            result = subprocess.run([sys.executable, str(ROOT / "scripts/storm/rank-backlog.py"), str(path), "--out", str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(path.read_bytes(), before)

    def test_hardlink_report_alias_preserves_both_files_with_and_without_write_json(self):
        for write_json in (False, True):
            with self.subTest(write_json=write_json), tempfile.TemporaryDirectory() as temp:
                source, report = Path(temp) / "storm.json", Path(temp) / "alias.md"
                source.write_text(json.dumps(artifact()), encoding="utf-8")
                os.link(source, report)
                self.assertTrue(source.samefile(report))
                before = source.read_bytes()
                args = [sys.executable, str(ROOT / "scripts/storm/rank-backlog.py"), str(source), "--out", str(report)]
                if write_json:
                    args.append("--write-json")
                result = subprocess.run(args, capture_output=True, text=True, encoding="utf-8")
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("file identity", result.stdout)
                self.assertNotIn("Traceback", result.stderr)
                self.assertEqual(source.read_bytes(), before)
                self.assertEqual(report.read_bytes(), before)

    def test_surrogate_extension_is_preserved_in_json_before_report_write(self):
        data = artifact()
        data["stories"] = [story()]
        data["extension"] = {"text": "before\ud800after", "nested": ["\udfff"], "\ud801": "value"}
        result, payload, report = self.run_cli(json.dumps(data), "rank-backlog.py", raw=True, write=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        after = json.loads(payload)
        self.assertEqual(after["extension"], data["extension"])
        self.assertIn(b"\\ud800", payload)
        self.assertIn(b"# Dependency-aware Ranking", report)
        after["ranking"] = data["ranking"]
        self.assertEqual(after, data)

    def test_surrogate_title_report_failure_preserves_existing_outputs(self):
        data = artifact()
        item = story()
        item["title"] = "title\ud800"
        data["stories"] = [item]
        for write_json in (False, True):
            with self.subTest(write_json=write_json):
                result, _, _ = self.run_cli(json.dumps(data), "rank-backlog.py", raw=True, write=write_json)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("--out: report text cannot be encoded as UTF-8", result.stdout)

    def test_surrogate_title_and_extension_json_only_roundtrip(self):
        data = artifact()
        item = story()
        item["title"] = "title\ud800"
        data["stories"] = [item]
        data["extension"] = {"text": "\udfff"}
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "storm.json"
            source.write_text(json.dumps(data), encoding="utf-8")
            result = subprocess.run([sys.executable, str(ROOT / "scripts/storm/rank-backlog.py"), str(source), "--write-json"], capture_output=True, text=True, encoding="utf-8")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertNotIn("Traceback", result.stderr)
            after = json.loads(source.read_bytes())
            self.assertEqual(after["ranking"][0]["title"], item["title"])
            self.assertEqual(after["extension"], data["extension"])
            after["ranking"] = data["ranking"]
            self.assertEqual(after, data)

    def test_cli_metrics_v2_distinguishes_resolution_and_reuse(self):
        data = artifact()
        data["step_definitions"] = [dict(id="SD-0001", path="step.py")]
        data["gherkin_scenarios"] = [scenario(1, ["SD-0001", "SD-0001"])]
        result, _, _ = self.run_cli(data, "validate-artifacts.py")
        self.assertEqual(result.returncode, 0)
        self.assertIn("metrics_version: 2", result.stdout)
        self.assertIn("resolved_step_reference_ratio: 2/2", result.stdout)
        self.assertIn("step_reuse_ratio: 0/1", result.stdout)

    def test_cn_en_cycle_and_unknown_dependency_state(self):
        data = artifact()
        data["stories"] = [story(dependencies=["CN-0001"])]
        data["constraints"] = [node("CN-0001", dependencies=["EN-0001"])]
        data["enablers"] = [node("EN-0001", dependencies=["ST-0001"])]
        self.both_reject(data, "dependency cycle")
        del data["enablers"][0]["dependencies"]
        data["constraints"][0]["dependency_state"] = "done"
        self.both_reject(data, "$.constraints[0].dependency_state")

    def test_enabler_support_only_reason_visible_in_cli_and_report(self):
        data = artifact()
        data["stories"] = [story()]
        data["enablers"] = [node("EN-0001", supports=["ST-0001"])]
        result, payload, report = self.run_cli(data, "rank-backlog.py", write=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("EN-0001: support_without_dependency", result.stdout)
        self.assertIn(b"EN-0001 | support_without_dependency", report)
        self.assertEqual([row["item"] for row in json.loads(payload)["ranking"]], ["ST-0001"])

    def test_duplicate_acceptance_id_and_nested_required(self):
        data = artifact()
        criterion = dict(id="AC-0001", text="test", coverage_level="none", linked_tests=[])
        item = story()
        item["acceptance_criteria"] = [criterion, copy.deepcopy(criterion)]
        data["stories"] = [item]
        self.both_reject(data, "duplicate ID AC-0001")
        item["acceptance_criteria"] = [dict(id="AC-0001")]
        self.both_reject(data, "$.stories[0].acceptance_criteria[0].text")

    def test_contract_failure_does_not_create_new_report_directory(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            source, report = folder / "storm.json", folder / "new" / "ranking.md"
            source.write_text('{"stories": null}', encoding="utf-8")
            result = subprocess.run([sys.executable, str(ROOT / "scripts/storm/rank-backlog.py"), str(source), "--out", str(report), "--write-json"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertFalse(report.parent.exists())

    def test_schema_self_check_error_is_controlled_in_both_clis_without_writes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "scripts/storm").mkdir(parents=True)
            (root / "schemas").mkdir()
            for file in ("storm_model.py", "validate-artifacts.py", "rank-backlog.py"):
                shutil.copyfile(ROOT / "scripts/storm" / file, root / "scripts/storm" / file)
            schema = read_json(ROOT / "schemas/storm-artifacts.schema.json")
            schema["$defs"]["unused"] = {"oneOf": []}
            (root / "schemas/storm-artifacts.schema.json").write_text(json.dumps(schema), encoding="utf-8")
            for cli in ("validate-artifacts.py", "rank-backlog.py"):
                result, _, _ = self.run_cli(artifact(), cli, root=root, write=True)
                self.assertEqual(result.returncode, 1)
                self.assertIn("schema.$defs.unused: unsupported schema keyword oneOf", result.stdout)

    def test_ranking_is_identical_across_process_hash_seeds(self):
        data = artifact()
        data["enablers"] = [node(f"EN-{i:04d}", priority={"effort": effort}) for i, effort in enumerate([1e16, 1, 3, 0.01], 1)]
        data["stories"] = [story(dependencies=[f"EN-{i:04d}" for i in range(1, 5)], priority={"effort": 2})]
        outputs = []
        for seed in ("1", "2", "17", "99"):
            result, payload, report = self.run_cli(data, "rank-backlog.py", write=True, hash_seed=seed)
            self.assertEqual(result.returncode, 0)
            outputs.append((payload, report))
        self.assertTrue(all(output == outputs[0] for output in outputs))


class ModelTests(unittest.TestCase):
    def test_schema_self_check_includes_all_defs_and_metadata_is_inert(self):
        schema = read_json(ROOT / "schemas/storm-artifacts.schema.json")
        self_check_schema(schema)
        for key in ("oneOf", "minItems", "format", "unknownValidation"):
            broken = copy.deepcopy(schema)
            broken["$defs"]["unused"] = {key: []}
            with self.assertRaisesRegex(ContractError, "unsupported schema keyword"):
                self_check_schema(broken)
        validate_structure({}, {"type": "object", "$defs": {"unused": {"title": "safe", "description": "text", "$comment": "text", "default": 1, "examples": [None]}}, "properties": {"minimum": {"type": "string"}}})

    def test_local_refs_and_invalid_schemas(self):
        for ref in ("https://example.com/schema", "other.json#/$defs/x", "#/$defs/missing", "#/bad~2escape"):
            with self.assertRaisesRegex(ContractError, r"schema.\$ref"):
                self_check_schema({"$ref": ref})
        with self.assertRaisesRegex(ContractError, "unsupported schema keyword"):
            self_check_schema({"default": {"unknownValidation": True}, "$ref": "#/default"})
        schema = {"$defs": {"a/b~c": {"type": "integer"}}, "$ref": "#/$defs/a~1b~0c"}
        validate_structure(2, schema)
        with self.assertRaises(ContractError):
            validate_structure(True, schema)
        for schema in ({"type": ["wrong"]}, {"required": "wrong"}, {"properties": []},
                       {"enum": []}, {"items": 1}, {"pattern": "["}, {"minimum": False}):
            with self.subTest(schema=schema), self.assertRaises(ContractError):
                self_check_schema(schema)

    def test_supported_keywords_enforced(self):
        schema = {"type": "object", "required": ["x"], "properties": {"x": {"type": ["integer", "string"], "pattern": "^ok$", "minimum": 2, "maximum": 4}}, "additionalProperties": False}
        for value in ({}, {"x": 1}, {"x": 5}, {"x": "bad"}, {"x": True}, {"x": 2, "extra": 1}):
            with self.assertRaises(ContractError):
                validate_structure(value, schema)
        for value in ({"x": 3}, {"x": "ok"}):
            validate_structure(value, schema)

    def test_zero_factors_defaults_and_effort_precedence(self):
        for factor in ("reach", "impact", "confidence"):
            data = artifact()
            data["stories"] = [story(priority={factor: 0})]
            self.assertEqual(StormModel(data).ranking[0]["own_value"], 0)
        data = artifact()
        data["stories"] = [story(priority={"reach": 1e308, "impact": 1e308, "confidence": 0})]
        self.assertEqual(StormModel(data).ranking[0]["own_value"], 0)
        item = story()
        self.assertEqual(own_value(item), 1)
        del item["confidence"]
        self.assertEqual(own_value(item), 0.5)
        self.assertEqual(own_effort(item), 2)
        item["priority"] = {"effort": 0.025, "agentic_effort": {"architecture_blast_radius": 100}}
        self.assertEqual(own_effort(item), 0.025)
        item["priority"] = {"agentic_effort": {"architecture_blast_radius": 0, "verification_complexity": 0}}
        self.assertEqual(own_effort(item), 0.1)
        data = artifact()
        data["stories"] = [dict(item, confidence=1)]
        self.assertIn("0.1 effort floor", StormModel(data).ranking[0]["explanation"])
        data["stories"] = [story(priority={"effort": 1e-9, "reach": 1e-8})]
        row = StormModel(data).ranking[0]
        self.assertEqual(row["cost_star"], 1e-9)
        self.assertEqual(row["own_value"], 1e-8)

    def test_diamond_cn_en_graph_cost_once_and_determinism(self):
        data = artifact()
        data["enablers"] = [node("EN-0001", priority={"effort": 3, "reach": 999, "impact": 999})]
        data["constraints"] = [node("CN-0001", dependencies=["EN-0001"])]
        data["stories"] = [story(priority={"effort": 2}, dependencies=["CN-0001", "EN-0001"]), story("ST-0002", priority={"effort": 5}, dependencies=["EN-0001"])]
        data["dependencies"] = [edge("EN-0001", "CN-0001"), edge("EN-0001", "ST-0001", 2)]
        model = StormModel(data)
        self.assertEqual(model.prereqs["ST-0001"], {"CN-0001", "EN-0001"})
        self.assertEqual([r["item"] for r in model.ranking], ["EN-0001", "ST-0001", "ST-0002"])
        self.assertEqual(sum(r["own_effort"] for r in model.ranking), 10)
        self.assertEqual(model.ranking[0]["own_value"], 0)
        self.assertEqual(model.ranking[0]["cost_star"], 5)
        self.assertEqual(model.ranking[-1]["cost_star"], 5)
        self.assertIn("CN-0001", model.ranking[0]["explanation"])
        self.assertEqual(data["enablers"][0]["status"], "proposed")
        for _ in range(4):
            self.assertEqual(StormModel(data).ranking, model.ranking)

    def test_supports_only_unranked_then_explicit_dependency_cost(self):
        data = artifact()
        data["stories"] = [story(priority={"effort": 2})]
        data["enablers"] = [node("EN-0001", supports=["ST-0001"], priority={"effort": 9})]
        model = StormModel(data)
        self.assertEqual(model.ranking[0]["cost_star"], 2)
        self.assertEqual(model.unranked_items, [{"item": "EN-0001", "reason": "support_without_dependency"}])
        data["dependencies"] = [edge("EN-0001", "ST-0001")]
        model = StormModel(data)
        self.assertEqual([r["item"] for r in model.ranking], ["EN-0001", "ST-0001"])
        self.assertEqual(sum(r["own_effort"] for r in model.ranking), 11)
        self.assertEqual(model.unranked_items, [])

    def test_blocked_and_retired_prerequisites_and_cn_state(self):
        for prefix, section in (("ST", "stories"), ("EN", "enablers"), ("CN", "constraints")):
            for status in ("blocked", "deprecated", "superseded", "removed"):
                data = artifact()
                pre = story(f"{prefix}-0002") if prefix == "ST" else node(f"{prefix}-0002")
                pre["status"] = status
                if prefix == "CN":
                    pre["dependency_state"] = "open"
                data[section].append(pre)
                data["stories"].append(story(dependencies=[pre["id"]]))
                model = StormModel(data)
                self.assertFalse(any(r["item"] == "ST-0001" for r in model.ranking))
                blocked = next(r for r in model.unranked_items if r["item"] == "ST-0001")
                self.assertIn(f"{pre['id']}:{status}", blocked["blockers"])
        data = artifact()
        data["stories"] = [story(dependencies=["CN-0001"])]
        data["constraints"] = [node("CN-0001", dependency_state="blocked")]
        self.assertEqual(StormModel(data).ranking, [])
        data["constraints"][0]["dependency_state"] = "open"
        self.assertEqual(len(StormModel(data).ranking), 1)

    def test_implemented_prerequisite_has_no_cost_value_or_ancestor_work(self):
        for prefix, section in (("ST", "stories"), ("EN", "enablers")):
            data = artifact()
            pre = story(f"{prefix}-0002", priority={"effort": 100}, dependencies=["EN-0003"]) if prefix == "ST" else node(f"{prefix}-0002", priority={"effort": 100}, dependencies=["EN-0003"])
            pre["status"] = "implemented"
            data[section].append(pre)
            data["enablers"].append(node("EN-0003"))
            data["stories"].append(story(dependencies=[pre["id"]], priority={"effort": 1}))
            model = StormModel(data)
            self.assertEqual([r["item"] for r in model.ranking], ["ST-0001"])
            self.assertEqual(model.ranking[0]["cost_star"], 1)
            self.assertEqual(model.ranking[0]["value_star"], 1)

    def test_cn_is_transitive_and_direction_is_predecessor(self):
        data = artifact()
        data["stories"] = [story(priority={"effort": 7}), story("ST-0002", priority={"effort": 1}, dependencies=["CN-0001"])]
        data["constraints"] = [node("CN-0001", dependencies=["ST-0001"])]
        model = StormModel(data)
        self.assertEqual(model.ranking[0]["item"], "ST-0001")
        self.assertEqual(model.ranking[1]["item"], "ST-0002")
        self.assertEqual(model.ranking[0]["cost_star"], 8)
        self.assertEqual(model.ranking[0]["closure"], ["ST-0001", "CN-0001", "ST-0002"])

    def test_reuse_one_two_duplicate_retired_and_empty(self):
        data = artifact()
        self.assertIsNone(step_metrics(data)["step_reuse_ratio"])
        self.assertEqual(step_metrics(data)["step_reuse_counts"], (0, 0))
        data["step_definitions"] = [dict(id="SD-0001", path="step.py"), dict(id="SD-0002", path="unused.py")]
        data["gherkin_scenarios"] = [scenario(1, ["SD-0001", "SD-0001"])]
        self.assertEqual(step_metrics(data)["step_reuse_ratio"], 0)
        self.assertEqual(step_metrics(data)["resolved_step_reference_ratio"], 1)
        data["gherkin_scenarios"].append(scenario(2, ["SD-0001"]))
        self.assertEqual(step_metrics(data)["step_reuse_counts"], (1, 1))
        data["gherkin_scenarios"][1]["status"] = "deprecated"
        self.assertEqual(step_metrics(data)["step_reuse_counts"], (0, 1))
        data["gherkin_scenarios"][0]["status"] = "superseded"
        self.assertIsNone(step_metrics(data)["step_reuse_ratio"])


class PromptContractTests(unittest.TestCase):
    def test_full_cycle_and_trace_preserve_analysis_only_boundary(self):
        full = (ROOT / "prompts/storm/00-full-cycle.md").read_text(encoding="utf-8")
        trace = (ROOT / "prompts/storm/02-trace-tests.md").read_text(encoding="utf-8")
        self.assertIn("Tests, code и test annotations не менять", full)
        self.assertIn("только coverage/traceability analysis", full)
        self.assertNotIn("безопасные test annotations", full)
        self.assertNotIn("только characterization/regression tests", full)
        self.assertIn("delivery-task", full)
        self.assertIn("QUEST", full)
        self.assertIn("сначала выбери `delivery-task` и пройди QUEST", trace)

    def test_bdd_outputs_and_metrics_contract_are_consistent(self):
        trace = (ROOT / "templates/storm/traceability.md").read_text(encoding="utf-8")
        for field in ("Rule", "Scenario", "Test", "Step Definition", "Code"):
            self.assertIn(field, trace)
        audit = (ROOT / "prompts/storm/10-audit-and-improve-process.md").read_text(encoding="utf-8")
        for field in ("process_audit.metrics_version = 2", "resolved_step_reference_ratio", "step_reuse_ratio", "distinct active scenarios", "null"):
            self.assertIn(field, audit)
        template = (ROOT / "templates/storm/process-audit.md").read_text(encoding="utf-8")
        self.assertIn("Metrics version: 2", template)
        self.assertIn("Duplicates within one scenario do not count as reuse", template)



if __name__ == "__main__":
    unittest.main()
