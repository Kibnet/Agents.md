"""Shared STORM contract and planning model; Python 3.11+, standard library only.

This is the explicitly bounded schema subset documented by the STORM profile,
not a general JSON Schema implementation. Validation never mutates input data.
"""
from __future__ import annotations

import heapq
import json
import math
import re
from collections import defaultdict
from pathlib import Path
from typing import Any

SCHEMA_PATH = Path(__file__).resolve().parents[2] / "schemas/storm-artifacts.schema.json"
RETIRED = {"deprecated", "superseded", "removed"}
SCENARIO_RETIRED = {"deprecated", "superseded"}
ANNOTATIONS = {"$schema", "$id", "title", "description", "$comment", "default", "examples"}
KEYWORDS = {"$ref", "$defs", "type", "required", "properties", "items", "enum", "pattern", "minimum", "maximum", "additionalProperties"}
TYPES = {"object", "array", "string", "number", "integer", "boolean", "null"}
EFFORT_DEFAULTS = dict(architecture_blast_radius=1, verification_complexity=1,
                       dependency_overhead=0, scenario_automation_cost=0,
                       step_reuse_penalty=0, migration_or_rollout_risk=0)
SECTIONS = ("needs", "constraints", "stories", "enablers", "tests", "gherkin_features",
            "gherkin_rules", "gherkin_scenarios", "step_definitions", "code_units", "conflicts", "dependencies")


class ContractError(ValueError):
    """Invalid artifact or unsupported schema; exit 1 with a field path."""


class InputError(ValueError):
    """Unreadable file or malformed JSON; exit 2."""


def read_json(path: Path) -> Any:
    try:
        # The parser accepts NaN/Infinity so the numeric traversal can report the
        # exact field as a contract error, including overflow of valid 1e999 JSON.
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, ValueError, RecursionError) as exc:
        raise InputError(f"{path}: cannot read JSON: {exc}") from None


def resolve_ref(root: dict, ref: str) -> Any:
    if not isinstance(ref, str) or (ref != "#" and not ref.startswith("#/")):
        raise ContractError(f"schema.$ref: only local JSON Pointers are supported: {ref!r}")
    node = root
    try:
        for token in ref[2:].split("/") if ref != "#" else []:
            if re.search(r"~(?![01])", token):
                raise KeyError(token)
            token = token.replace("~1", "/").replace("~0", "~")
            node = node[int(token)] if isinstance(node, list) else node[token]
    except (KeyError, IndexError, ValueError, TypeError):
        raise ContractError(f"schema.$ref: unresolved local pointer: {ref}") from None
    if not isinstance(node, (dict, bool)):
        raise ContractError(f"schema.$ref: target is not a schema: {ref}")
    return node


def self_check_schema(root: dict) -> None:
    seen: set[int] = set()
    def check(node: Any, path: str) -> None:
        if isinstance(node, bool):
            return
        if not isinstance(node, dict):
            raise ContractError(f"{path}: schema must be an object or boolean")
        if id(node) in seen:
            return
        seen.add(id(node))
        unknown = set(node) - KEYWORDS - ANNOTATIONS
        if unknown:
            raise ContractError(f"{path}: unsupported schema keyword {sorted(unknown)[0]}")
        if "$ref" in node:
            # A local pointer may target any schema location, including one
            # otherwise stored as annotation data; validate that target too.
            check(resolve_ref(root, node["$ref"]), f"{path}.$ref({node['$ref']})")
        if "type" in node:
            types = node["type"] if isinstance(node["type"], list) else [node["type"]]
            if not types or any(not isinstance(t, str) or t not in TYPES for t in types):
                raise ContractError(f"{path}.type: invalid type declaration")
        if "required" in node and (not isinstance(node["required"], list) or any(not isinstance(x, str) for x in node["required"])):
            raise ContractError(f"{path}.required: expected array of property names")
        if "enum" in node and (not isinstance(node["enum"], list) or not node["enum"]):
            raise ContractError(f"{path}.enum: expected nonempty array")
        if "pattern" in node:
            try:
                re.compile(node["pattern"])
            except (TypeError, re.error):
                raise ContractError(f"{path}.pattern: invalid regular expression") from None
        for key in ("minimum", "maximum"):
            if key in node:
                number(node[key], f"{path}.{key}")
        for container in ("properties", "$defs"):
            if container in node:
                if not isinstance(node[container], dict):
                    raise ContractError(f"{path}.{container}: expected object")
                for key, child in node[container].items():
                    check(child, f"{path}.{container}.{key}")
        for key in ("items", "additionalProperties"):
            if key in node:
                check(node[key], f"{path}.{key}")
    check(root, "schema")


def number(value: Any, path: str) -> float:
    try:
        valid = type(value) in (int, float) and math.isfinite(value)
    except OverflowError:
        valid = False
    if not valid:
        raise ContractError(f"{path}: expected finite number (not bool, null or string)")
    return float(value)


def reject_nonfinite(value: Any, path: str = "$") -> None:
    if type(value) in (int, float):
        number(value, path)
    elif isinstance(value, dict):
        for key, child in value.items():
            reject_nonfinite(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_nonfinite(child, f"{path}[{index}]")


def validate_structure(data: Any, root: dict) -> None:
    self_check_schema(root)
    reject_nonfinite(data)
    def matches(value: Any, kind: str) -> bool:
        return {"object": lambda: isinstance(value, dict), "array": lambda: isinstance(value, list),
                "string": lambda: isinstance(value, str), "number": lambda: type(value) in (int, float),
                "integer": lambda: type(value) in (int, float) and int(value) == value,
                "boolean": lambda: type(value) is bool, "null": lambda: value is None}[kind]()
    def check(value: Any, schema: Any, path: str, refs: frozenset = frozenset()) -> None:
        if schema is True:
            return
        if schema is False:
            raise ContractError(f"{path}: additional value is not permitted")
        if "$ref" in schema:
            ref = schema["$ref"]
            marker = (ref, id(value))
            if marker in refs:
                raise ContractError(f"schema.$ref: non-progressing reference cycle at {ref}")
            check(value, resolve_ref(root, ref), path, refs | {marker})
        if "type" in schema:
            kinds = schema["type"] if isinstance(schema["type"], list) else [schema["type"]]
            if not any(matches(value, kind) for kind in kinds):
                raise ContractError(f"{path}: expected {'|'.join(kinds)}, got {type(value).__name__}")
        if "enum" in schema and not any(value == entry and (type(value) is bool) == (type(entry) is bool) for entry in schema["enum"]):
            raise ContractError(f"{path}: unsupported value {value!r}; expected one of {schema['enum']}")
        if isinstance(value, str) and "pattern" in schema and not re.search(schema["pattern"], value):
            raise ContractError(f"{path}: does not match {schema['pattern']}")
        if type(value) in (int, float):
            for key, bad in (("minimum", lambda n: value < n), ("maximum", lambda n: value > n)):
                if key in schema and bad(schema[key]):
                    raise ContractError(f"{path}: violates {key} {schema[key]}")
        if isinstance(value, dict):
            for key in schema.get("required", []):
                if key not in value:
                    raise ContractError(f"{path}.{key}: required property is missing")
            properties = schema.get("properties", {})
            for key, child in value.items():
                check(child, properties.get(key, schema.get("additionalProperties", True)), f"{path}.{key}")
        if isinstance(value, list) and "items" in schema:
            for index, child in enumerate(value):
                check(child, schema["items"], f"{path}[{index}]")
    check(data, root, "$")


def own_value(item: dict, path: str | None = None) -> float:
    if not item["id"].startswith("ST-"):
        return 0.0
    p = item.get("priority", {})
    # Zero is data, never a missing-value default.
    factors = (p.get("reach", 1), p.get("impact", 1), p.get("confidence", item.get("confidence", 0.5)))
    # A zero multiplier yields exactly zero, even when the other finite factors
    # would overflow an intermediate product on their own.
    if 0 in factors:
        return 0.0
    return number(math.prod(factors), f"{path or item['id']}.computed.own_value")


def own_effort(item: dict, path: str | None = None) -> float:
    if item["id"].startswith("CN-"):
        return 0.0
    p = item.get("priority", {})
    path = path or item["id"]
    if "effort" in p:
        result = number(p["effort"], f"{path}.priority.effort")
        if result <= 0:
            raise ContractError(f"{path}.priority.effort: explicit effort must be > 0; omit it to use decomposition")
        return result
    effort = p.get("agentic_effort", {})
    return max(number(sum(effort.get(k, v) for k, v in EFFORT_DEFAULTS.items()), f"{path}.computed.effort"), 0.1)


class StormModel:
    def __init__(self, data: Any, schema: dict | None = None):
        validate_structure(data, read_json(SCHEMA_PATH) if schema is None else schema)
        self.data = data
        self.items: dict[str, dict] = {}
        self.paths: dict[str, str] = {}
        self.groups: dict[str, set[str]] = defaultdict(set)
        for section in SECTIONS:
            for index, item in enumerate(data.get(section, [])):
                self.add_id(item, section, f"$.{section}[{index}]")
                if section == "stories":
                    for ai, ac in enumerate(item["acceptance_criteria"]):
                        self.add_id(ac, "acceptance_criteria", f"$.{section}[{index}].acceptance_criteria[{ai}]")
        for section in ("vision", "product_goal"):
            if "id" in data[section]:
                self.add_id(data[section], section, f"$.{section}")
        self.nodes = {key: self.items[key] for group in ("stories", "constraints", "enablers") for key in sorted(self.groups[group])}
        self.prereqs: dict[str, set[str]] = {key: set() for key in self.nodes}
        self.validate_references()
        for node, item in self.nodes.items():
            for index, src in enumerate(item.get("dependencies", [])):
                self.add_edge(src, node, f"{self.paths[node]}.dependencies[{index}]")
        for index, dep in enumerate(data["dependencies"]):
            self.add_edge(dep["from"], dep["to"], f"$.dependencies[{index}]")
        self.topological(set(self.nodes))  # Entire graph, including retired items.
        self.values = {key: own_value(item, self.paths[key]) for key, item in self.nodes.items()}
        self.efforts = {key: own_effort(item, self.paths[key]) for key, item in self.nodes.items()}
        # Compute before either CLI publishes anything: overflow and blockers use
        # exactly the same graph and conditional prerequisite payments.
        self.ranking, self.unranked_items = self.rank()

    def add_id(self, item: dict, group: str, path: str) -> None:
        key = item["id"]
        if not isinstance(key, str):
            raise ContractError(f"{path}.id: expected string")
        if key in self.items:
            raise ContractError(f"{path}.id: duplicate ID {key}; first at {self.paths[key]}")
        self.items[key], self.paths[key] = item, path
        self.groups[group].add(key)

    def validate_references(self) -> None:
        mappings = {
            "supports_needs": ("needs",), "threatens_needs": ("needs", "constraints"),
            "linked_tests": ("tests",), "verified_by_tests": ("tests",),
            "linked_code": ("code_units",), "enforced_by_code": ("code_units",),
            "linked_stories": ("stories",), "supported_by_stories": ("stories",),
            "threatened_by_stories": ("stories",), "linked_story": ("stories",),
            "linked_acceptance_criteria": ("acceptance_criteria",),
            "linked_constraints": ("constraints",), "protects_constraints": ("constraints",),
            "protected_by_constraints": ("constraints",), "protects_needs": ("needs",),
            "verifies_needs": ("needs",), "supported_by_needs": ("needs",),
            "linked_scenarios": ("gherkin_scenarios",), "verified_by_scenarios": ("gherkin_scenarios",),
            "supports_scenarios": ("gherkin_scenarios",), "scenarios": ("gherkin_scenarios",),
            "scenario_id": ("gherkin_scenarios",), "linked_rules": ("gherkin_rules",),
            "contains_rules": ("gherkin_rules",), "rule_id": ("gherkin_rules",),
            "feature_id": ("gherkin_features",), "step_definitions": ("step_definitions",),
            "story_or_constraint": ("stories", "constraints"),
            "need_a": ("needs", "constraints"), "need_b": ("needs", "constraints"),
            "supports_goal": ("product_goal",), "changed_items": SECTIONS + ("acceptance_criteria",),
        }
        for key, item in self.items.items():
            fields = dict(mappings)
            if key.startswith("EN-"):
                fields["supports"] = ("stories", "constraints")
            elif key.startswith("CU-"):
                fields["supports"] = ("stories", "constraints", "enablers")
            for field, groups in fields.items():
                if field not in item:
                    continue
                refs = item[field] if isinstance(item[field], list) else [item[field]]
                allowed = set().union(*(self.groups[group] for group in groups))
                for index, ref in enumerate(refs):
                    if not isinstance(ref, str) or ref not in allowed:
                        raise ContractError(f"{self.paths[key]}.{field}[{index}]: unresolved or wrong-kind reference {ref!r}; expected {'/'.join(groups)}")

    def add_edge(self, src: str, dst: str, path: str) -> None:
        for field, value in (("from", src), ("to", dst)):
            if value not in self.nodes:
                raise ContractError(f"{path}.{field}: unresolved ST/CN/EN reference {value!r}")
        if src == dst:
            raise ContractError(f"{path}: self-loop {src}")
        self.prereqs[dst].add(src)

    def topological(self, nodes: set[str]) -> list[str]:
        indegree = {key: len(self.prereqs[key] & nodes) for key in nodes}
        outgoing: dict[str, set[str]] = defaultdict(set)
        for dst in nodes:
            for src in self.prereqs[dst] & nodes:
                outgoing[src].add(dst)
        ready = [key for key, degree in indegree.items() if degree == 0]
        heapq.heapify(ready)
        result = []
        while ready:
            key = heapq.heappop(ready)
            result.append(key)
            for dst in sorted(outgoing[key]):
                indegree[dst] -= 1
                if indegree[dst] == 0:
                    heapq.heappush(ready, dst)
        if len(result) != len(nodes):
            remaining = sorted(nodes - set(result))
            raise ContractError(f"$.dependencies: dependency cycle involving {', '.join(remaining)}")
        return result

    def closure(self, key: str, paid: set[str]) -> set[str]:
        result, pending = set(), [key]
        while pending:
            node = pending.pop()
            if node in paid or node in result:
                continue
            result.add(node)
            pending.extend(self.prereqs[node])
        return result

    def blocker(self, key: str) -> str | None:
        item = self.nodes[key]
        status = item["status"]
        if status in RETIRED or status == "blocked":
            return f"{key}:{status}"
        if key.startswith("CN-") and item.get("dependency_state", "open") == "blocked":
            return f"{key}:dependency_state=blocked"
        return None

    def rank(self) -> tuple[list[dict], list[dict]]:
        paid = {key for key, item in self.nodes.items() if not key.startswith("CN-") and item["status"] == "implemented"}
        candidates = {key for key in self.groups["stories"] if key not in paid and self.nodes[key]["status"] not in RETIRED}
        ranked, unranked = [], {}
        while candidates:
            scores = []
            for key in sorted(candidates):
                closure = self.closure(key, paid)
                blockers = sorted(filter(None, (self.blocker(node) for node in closure)))
                if blockers:
                    unranked[key] = {"item": key, "reason": "blocked_prerequisite", "blockers": blockers}
                    continue
                # Stable summation order also fixes results across process hash
                # seeds, not just repeated calls inside the same interpreter.
                value = number(sum(self.values[node] for node in sorted(closure)), f"{self.paths[key]}.computed.value_star")
                cost = number(sum(self.efforts[node] for node in sorted(closure)), f"{self.paths[key]}.computed.cost_star")
                priority = number(value / cost, f"{self.paths[key]}.computed.priority_star")
                scores.append((-priority, -value, cost, key, closure))
            if not scores:
                break
            neg_priority, neg_value, cost, chosen, closure = min(scores, key=lambda row: row[:4])
            ordered = self.topological(closure)
            for key in ordered:
                if key.startswith("CN-"):
                    continue
                item = self.nodes[key]
                floored = "effort" not in item.get("priority", {}) and self.efforts[key] == 0.1
                ranked.append(dict(rank=len(ranked) + 1, item=key, title=item["title"], chosen_for=chosen,
                                   closure=ordered, value_star=-neg_value, cost_star=cost,
                                   priority_star=-neg_priority, own_value=self.values[key],
                                   own_effort=self.efforts[key], explanation=f"Closure for {chosen}: {', '.join(ordered)}. CN nodes impose order with zero cost/value; ST/EN prerequisites are paid once. Sum own_effort, not repeated package cost_star."
                                   + (" Decomposition total uses the 0.1 effort floor." if floored else "")))
                paid.add(key)
                candidates.discard(key)
                unranked.pop(key, None)
        for key in sorted(self.groups["enablers"] - paid):
            item = self.nodes[key]
            if item["status"] in RETIRED:
                reason = "retired"
            else:
                has_path = any(key in self.closure(story, set()) for story in self.groups["stories"])
                reason = "no_rankable_story" if has_path else ("support_without_dependency" if item.get("supports") else "no_dependency_path_to_story")
            unranked[key] = {"item": key, "reason": reason}
        for key in sorted(self.groups["stories"]):
            if self.nodes[key]["status"] in RETIRED:
                unranked[key] = {"item": key, "reason": "retired"}
        return ranked, [unranked[key] for key in sorted(unranked)]


def load_model(path: Path) -> StormModel:
    try:
        return StormModel(read_json(path))
    except RecursionError:
        raise ContractError("$: nesting exceeds supported processing depth") from None


def step_metrics(data: dict) -> dict:
    known = {item["id"] for item in data.get("step_definitions", [])}
    refs, usage = [], defaultdict(set)
    for scenario in data.get("gherkin_scenarios", []):
        if scenario["status"] in SCENARIO_RETIRED:
            continue
        for ref in scenario.get("step_definitions", []):
            refs.append(ref)
            if ref in known:
                usage[ref].add(scenario["id"])
    resolved = sum(ref in known for ref in refs)
    reused = sum(len(scenarios) >= 2 for scenarios in usage.values())
    return dict(metrics_version=2, resolved_step_reference_ratio=resolved / len(refs) if refs else None,
                resolved_step_reference_counts=(resolved, len(refs)),
                step_reuse_ratio=reused / len(usage) if usage else None, step_reuse_counts=(reused, len(usage)))
