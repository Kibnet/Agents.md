#!/usr/bin/env python3
"""
Validate docs/product/storm.json for Storm Cloud Product Development Process.

Usage:
    python <AGENTS_ROOT>/scripts/storm/validate-artifacts.py docs/product/storm.json

No external dependencies.
"""

from __future__ import annotations

import json
import sys
from collections import defaultdict, deque
from pathlib import Path
from typing import Any, Dict, Iterable, List, Set, Tuple

REQUIRED_TOP_LEVEL = [
    "metadata",
    "vision",
    "product_goal",
    "needs",
    "constraints",
    "stories",
    "tests",
    "code_units",
    "conflicts",
    "dependencies",
    "ranking",
    "process_audit",
]

ACTIVE_STATUSES = {"active", "implemented", "partial", "confirmed", "proposed", "inferred", "needs_review"}
INACTIVE_STATUSES = {"deprecated", "superseded", "removed"}
GOOD_COVERAGE = {"critical", "full"}
LOW_COVERAGE = {"none", "smoke", "partial"}
SCENARIO_ACTIVE_STATUSES = {"draft", "reviewed", "automated", "manual", "failing", "passing"}
SCENARIO_INACTIVE_STATUSES = {"deprecated", "superseded"}
AUTOMATED_SCENARIO_STATUSES = {"automated", "passing", "failing"}
VALID_COVERAGE_ROLES = {
    "happy_path",
    "negative_path",
    "edge_case",
    "business_rule",
    "constraint_check",
    "regression",
    "security",
    "performance",
    "compatibility",
    "accessibility",
}


def load_json(path: Path) -> Dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"ERROR: file not found: {path}")
        sys.exit(2)
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON: {exc}")
        sys.exit(2)


def collect_ids(items: Iterable[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
    result: Dict[str, Dict[str, Any]] = {}
    for item in items:
        item_id = item.get("id")
        if isinstance(item_id, str):
            result[item_id] = item
    return result


def add_issue(issues: List[Tuple[str, str]], severity: str, message: str) -> None:
    issues.append((severity, message))


def graph_cycles(nodes: Set[str], edges: List[Tuple[str, str]]) -> List[List[str]]:
    graph: Dict[str, List[str]] = defaultdict(list)
    for src, dst in edges:
        graph[src].append(dst)

    visited: Set[str] = set()
    stack: Set[str] = set()
    path: List[str] = []
    cycles: List[List[str]] = []

    def dfs(node: str) -> None:
        visited.add(node)
        stack.add(node)
        path.append(node)
        for nxt in graph.get(node, []):
            if nxt not in visited:
                dfs(nxt)
            elif nxt in stack:
                try:
                    idx = path.index(nxt)
                    cycles.append(path[idx:] + [nxt])
                except ValueError:
                    cycles.append([node, nxt])
        stack.remove(node)
        path.pop()

    for node in nodes:
        if node not in visited:
            dfs(node)
    return cycles


def safe_len(value: Any) -> int:
    return len(value) if isinstance(value, list) else 0


def as_list(value: Any) -> List[Any]:
    return value if isinstance(value, list) else []


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: validate-artifacts.py docs/product/storm.json")
        return 2

    path = Path(sys.argv[1])
    data = load_json(path)
    issues: List[Tuple[str, str]] = []

    for key in REQUIRED_TOP_LEVEL:
        if key not in data:
            add_issue(issues, "ERROR", f"Missing top-level key: {key}")

    stories = data.get("stories", []) if isinstance(data.get("stories", []), list) else []
    needs = data.get("needs", []) if isinstance(data.get("needs", []), list) else []
    constraints = data.get("constraints", []) if isinstance(data.get("constraints", []), list) else []
    tests = data.get("tests", []) if isinstance(data.get("tests", []), list) else []
    gherkin_features = data.get("gherkin_features", []) if isinstance(data.get("gherkin_features", []), list) else []
    gherkin_rules = data.get("gherkin_rules", []) if isinstance(data.get("gherkin_rules", []), list) else []
    gherkin_scenarios = data.get("gherkin_scenarios", []) if isinstance(data.get("gherkin_scenarios", []), list) else []
    step_definitions = data.get("step_definitions", []) if isinstance(data.get("step_definitions", []), list) else []
    code_units = data.get("code_units", []) if isinstance(data.get("code_units", []), list) else []
    conflicts = data.get("conflicts", []) if isinstance(data.get("conflicts", []), list) else []
    dependencies = data.get("dependencies", []) if isinstance(data.get("dependencies", []), list) else []

    sections = {
        "story": stories,
        "need": needs,
        "constraint": constraints,
        "test": tests,
        "gherkin_feature": gherkin_features,
        "gherkin_rule": gherkin_rules,
        "gherkin_scenario": gherkin_scenarios,
        "step_definition": step_definitions,
        "code_unit": code_units,
        "conflict": conflicts,
        "dependency": dependencies,
    }

    all_ids: Dict[str, str] = {}
    duplicates: List[str] = []
    for section_name, items in sections.items():
        for item in items:
            item_id = item.get("id")
            if not item_id:
                add_issue(issues, "ERROR", f"{section_name} without id: {item}")
                continue
            if item_id in all_ids:
                duplicates.append(item_id)
            all_ids[item_id] = section_name
    for item_id in sorted(set(duplicates)):
        add_issue(issues, "ERROR", f"Duplicate id: {item_id}")

    story_by_id = collect_ids(stories)
    need_by_id = collect_ids(needs)
    constraint_by_id = collect_ids(constraints)
    test_by_id = collect_ids(tests)
    feature_by_id = collect_ids(gherkin_features)
    rule_by_id = collect_ids(gherkin_rules)
    scenario_by_id = collect_ids(gherkin_scenarios)
    step_by_id = collect_ids(step_definitions)
    code_by_id = collect_ids(code_units)

    ac_by_id: Dict[str, Dict[str, Any]] = {}
    for story in stories:
        for ac in story.get("acceptance_criteria", []) or []:
            ac_id = ac.get("id")
            if not ac_id:
                add_issue(issues, "ERROR", f"Acceptance criterion without id in {story.get('id')}")
            elif ac_id in ac_by_id:
                add_issue(issues, "ERROR", f"Duplicate acceptance criterion id: {ac_id}")
            else:
                ac_by_id[ac_id] = ac

    active_stories = [s for s in stories if s.get("status") not in INACTIVE_STATUSES]
    implemented_stories = [s for s in stories if s.get("status") == "implemented"]

    for story in stories:
        sid = story.get("id", "<unknown>")
        status = story.get("status")
        if status not in INACTIVE_STATUSES:
            if not story.get("acceptance_criteria"):
                add_issue(issues, "WARNING", f"Active story {sid} has no acceptance criteria")
            if not story.get("supports_needs"):
                add_issue(issues, "WARNING", f"Active story {sid} has no supports_needs")
        if status == "implemented" and not story.get("linked_tests") and not story.get("test_strategy"):
            add_issue(issues, "ERROR", f"Implemented story {sid} has no linked tests or test_strategy")
        if status in {"deprecated", "superseded"} and not (story.get("deprecation_reason") or story.get("superseded_by")):
            add_issue(issues, "WARNING", f"Inactive story {sid} should have deprecation_reason or superseded_by")

        for nid in story.get("supports_needs", []) or []:
            if nid not in need_by_id:
                add_issue(issues, "ERROR", f"Story {sid} references missing need {nid}")
        for nid in story.get("threatens_needs", []) or []:
            if nid not in need_by_id and nid not in constraint_by_id:
                add_issue(issues, "ERROR", f"Story {sid} threatens missing need/constraint {nid}")
        for tid in story.get("linked_tests", []) or []:
            if tid not in test_by_id:
                add_issue(issues, "ERROR", f"Story {sid} references missing test {tid}")
        for scid in story.get("linked_scenarios", []) or []:
            if scid not in scenario_by_id:
                add_issue(issues, "ERROR", f"Story {sid} references missing scenario {scid}")
        for cuid in story.get("linked_code", []) or []:
            if cuid not in code_by_id:
                add_issue(issues, "ERROR", f"Story {sid} references missing code unit {cuid}")
        coverage_level = story.get("behavior_coverage_level")
        if coverage_level is not None and not (isinstance(coverage_level, int) and 0 <= coverage_level <= 5):
            add_issue(issues, "WARNING", f"Story {sid} has invalid behavior_coverage_level: {coverage_level}")
        if status not in INACTIVE_STATUSES and not story.get("linked_scenarios") and not story.get("gherkin_exception"):
            linked_from_scenarios = [
                scenario
                for scenario in gherkin_scenarios
                if scenario.get("linked_story") == sid and scenario.get("status") not in SCENARIO_INACTIVE_STATUSES
            ]
            if not linked_from_scenarios:
                add_issue(issues, "WARNING", f"Active story {sid} has no linked Gherkin scenarios or gherkin_exception")
        for ac in story.get("acceptance_criteria", []) or []:
            ac_id = ac.get("id", "<unknown>")
            coverage = ac.get("coverage_level")
            if coverage not in {"none", "smoke", "partial", "critical", "full"}:
                add_issue(issues, "WARNING", f"AC {ac_id} in {sid} has invalid or missing coverage_level: {coverage}")
            if coverage in GOOD_COVERAGE and not ac.get("linked_tests"):
                add_issue(issues, "WARNING", f"AC {ac_id} marked {coverage} but has no linked_tests")
            for tid in ac.get("linked_tests", []) or []:
                if tid not in test_by_id:
                    add_issue(issues, "ERROR", f"AC {ac_id} references missing test {tid}")
            for rid in ac.get("linked_rules", []) or []:
                if rid not in rule_by_id:
                    add_issue(issues, "ERROR", f"AC {ac_id} references missing Gherkin rule {rid}")
            for scid in ac.get("linked_scenarios", []) or []:
                if scid not in scenario_by_id:
                    add_issue(issues, "ERROR", f"AC {ac_id} references missing Gherkin scenario {scid}")

    for test in tests:
        tid = test.get("id", "<unknown>")
        linked_stories = test.get("linked_stories", []) or []
        linked_constraints = test.get("linked_constraints", []) or []
        linked_acs = test.get("linked_acceptance_criteria", []) or []
        linked_scenarios = test.get("linked_scenarios", []) or []
        if not linked_stories and not linked_constraints and not linked_scenarios:
            add_issue(issues, "WARNING", f"Test {tid} has no linked stories, scenarios, or constraints")
        for sid in linked_stories:
            if sid not in story_by_id:
                add_issue(issues, "ERROR", f"Test {tid} references missing story {sid}")
        for cid in linked_constraints:
            if cid not in constraint_by_id:
                add_issue(issues, "ERROR", f"Test {tid} references missing constraint {cid}")
        for ac_id in linked_acs:
            if ac_id not in ac_by_id:
                add_issue(issues, "ERROR", f"Test {tid} references missing acceptance criterion {ac_id}")
        for scid in linked_scenarios:
            if scid not in scenario_by_id:
                add_issue(issues, "ERROR", f"Test {tid} references missing Gherkin scenario {scid}")

    for need in needs:
        nid = need.get("id", "<unknown>")
        if not need.get("supported_by_stories") and need.get("status") not in {"proposed", "needs_review", "deprecated", "superseded"}:
            add_issue(issues, "WARNING", f"Need {nid} has no supported_by_stories")
        for sid in need.get("supported_by_stories", []) or []:
            if sid not in story_by_id:
                add_issue(issues, "ERROR", f"Need {nid} references missing story {sid}")
        for cid in need.get("protected_by_constraints", []) or []:
            if cid not in constraint_by_id:
                add_issue(issues, "ERROR", f"Need {nid} references missing constraint {cid}")

    for constraint in constraints:
        cid = constraint.get("id", "<unknown>")
        if constraint.get("status") not in INACTIVE_STATUSES:
            if not (
                constraint.get("verified_by_tests")
                or constraint.get("verified_by_scenarios")
                or constraint.get("verification_strategy")
                or constraint.get("enforced_by_code")
            ):
                add_issue(issues, "WARNING", f"Constraint {cid} has no verification strategy, tests, or enforced_by_code")
        for tid in constraint.get("verified_by_tests", []) or []:
            if tid not in test_by_id:
                add_issue(issues, "ERROR", f"Constraint {cid} references missing test {tid}")
        for scid in constraint.get("verified_by_scenarios", []) or []:
            if scid not in scenario_by_id:
                add_issue(issues, "ERROR", f"Constraint {cid} references missing Gherkin scenario {scid}")
        for cuid in constraint.get("enforced_by_code", []) or []:
            if cuid not in code_by_id:
                add_issue(issues, "ERROR", f"Constraint {cid} references missing code unit {cuid}")

    for feature in gherkin_features:
        fid = feature.get("id", "<unknown>")
        if not feature.get("file"):
            add_issue(issues, "ERROR", f"Gherkin feature {fid} has no file")
        for nid in feature.get("supports_needs", []) or []:
            if nid not in need_by_id:
                add_issue(issues, "ERROR", f"Gherkin feature {fid} references missing need {nid}")
        for rid in feature.get("contains_rules", []) or []:
            if rid not in rule_by_id:
                add_issue(issues, "ERROR", f"Gherkin feature {fid} references missing rule {rid}")

    for rule in gherkin_rules:
        rid = rule.get("id", "<unknown>")
        fid = rule.get("feature_id")
        if fid and fid not in feature_by_id:
            add_issue(issues, "ERROR", f"Gherkin rule {rid} references missing feature {fid}")
        for sid in rule.get("linked_stories", []) or []:
            if sid not in story_by_id:
                add_issue(issues, "ERROR", f"Gherkin rule {rid} references missing story {sid}")
        for ac_id in rule.get("linked_acceptance_criteria", []) or []:
            if ac_id not in ac_by_id:
                add_issue(issues, "ERROR", f"Gherkin rule {rid} references missing acceptance criterion {ac_id}")
        for cid in rule.get("linked_constraints", []) or []:
            if cid not in constraint_by_id:
                add_issue(issues, "ERROR", f"Gherkin rule {rid} references missing constraint {cid}")
        for scid in rule.get("scenarios", []) or []:
            if scid not in scenario_by_id:
                add_issue(issues, "ERROR", f"Gherkin rule {rid} references missing scenario {scid}")

    active_scenarios = [s for s in gherkin_scenarios if s.get("status") not in SCENARIO_INACTIVE_STATUSES]
    deprecated_drift = 0
    orphan_scenarios = 0
    for scenario in gherkin_scenarios:
        scid = scenario.get("id", "<unknown>")
        status = scenario.get("status")
        coverage_role = scenario.get("coverage_role")
        tags = set(as_list(scenario.get("tags")))
        linked_story = scenario.get("linked_story")
        verifies_needs = as_list(scenario.get("verifies_needs"))
        protects_constraints = as_list(scenario.get("protects_constraints"))

        if status not in SCENARIO_ACTIVE_STATUSES and status not in SCENARIO_INACTIVE_STATUSES:
            add_issue(issues, "WARNING", f"Gherkin scenario {scid} has invalid or missing status: {status}")
        if coverage_role not in VALID_COVERAGE_ROLES:
            add_issue(issues, "WARNING", f"Gherkin scenario {scid} has invalid or missing coverage_role: {coverage_role}")
        if f"@scenario:{scid}" not in tags:
            add_issue(issues, "WARNING", f"Gherkin scenario {scid} is missing @scenario:{scid} tag")

        if linked_story:
            if linked_story not in story_by_id:
                add_issue(issues, "ERROR", f"Gherkin scenario {scid} references missing story {linked_story}")
            elif story_by_id[linked_story].get("status") in INACTIVE_STATUSES and status not in SCENARIO_INACTIVE_STATUSES:
                deprecated_drift += 1
                if not verifies_needs and not protects_constraints:
                    add_issue(issues, "ERROR", f"Active scenario {scid} is linked only to inactive story {linked_story}")
            if f"@story:{linked_story}" not in tags:
                add_issue(issues, "WARNING", f"Gherkin scenario {scid} is missing @story:{linked_story} tag")
        elif not verifies_needs and not protects_constraints:
            if status not in SCENARIO_INACTIVE_STATUSES:
                orphan_scenarios += 1
                add_issue(issues, "WARNING", f"Active scenario {scid} has no linked_story, verifies_needs, or protects_constraints")

        if linked_story and not verifies_needs and not protects_constraints:
            has_need_tag = any(isinstance(tag, str) and tag.startswith("@need:") for tag in tags)
            if not has_need_tag:
                add_issue(issues, "WARNING", f"Gherkin scenario {scid} has no verifies_needs, protects_constraints, or @need tag")

        for nid in verifies_needs:
            if nid not in need_by_id:
                add_issue(issues, "ERROR", f"Gherkin scenario {scid} references missing need {nid}")
            if f"@need:{nid}" not in tags:
                add_issue(issues, "WARNING", f"Gherkin scenario {scid} is missing @need:{nid} tag")
        for cid in protects_constraints:
            if cid not in constraint_by_id:
                add_issue(issues, "ERROR", f"Gherkin scenario {scid} references missing constraint {cid}")
            if f"@constraint:{cid}" not in tags:
                add_issue(issues, "WARNING", f"Gherkin scenario {scid} is missing @constraint:{cid} tag")
        for nid in scenario.get("threatens_needs", []) or []:
            if nid not in need_by_id and nid not in constraint_by_id:
                add_issue(issues, "ERROR", f"Gherkin scenario {scid} threatens missing need/constraint {nid}")

        linked_tests = as_list(scenario.get("linked_tests"))
        linked_steps = as_list(scenario.get("step_definitions"))
        automation_status = scenario.get("automation_status")
        is_automated = status in AUTOMATED_SCENARIO_STATUSES or automation_status in AUTOMATED_SCENARIO_STATUSES
        if is_automated and not linked_tests and not linked_steps:
            add_issue(issues, "ERROR", f"Automated scenario {scid} has no linked_tests or step_definitions")
        for tid in linked_tests:
            if isinstance(tid, str) and tid.startswith("TS-") and tid not in test_by_id:
                add_issue(issues, "ERROR", f"Gherkin scenario {scid} references missing test {tid}")
        for sdid in linked_steps:
            if isinstance(sdid, str) and sdid.startswith("SD-") and sdid not in step_by_id:
                add_issue(issues, "ERROR", f"Gherkin scenario {scid} references missing step definition {sdid}")

    step_texts: Dict[str, List[str]] = defaultdict(list)
    for step in step_definitions:
        sdid = step.get("id", "<unknown>")
        step_text = step.get("step_text")
        if isinstance(step_text, str) and step_text.strip():
            normalized = " ".join(step_text.lower().split())
            step_texts[normalized].append(sdid)
        for scid in step.get("supports_scenarios", []) or []:
            if scid not in scenario_by_id:
                add_issue(issues, "ERROR", f"Step definition {sdid} references missing scenario {scid}")
    for text, ids in step_texts.items():
        if len(ids) > 1:
            add_issue(issues, "WARNING", f"Duplicate step text across step definitions {', '.join(sorted(ids))}: {text}")

    for code in code_units:
        cuid = code.get("id", "<unknown>")
        supports = code.get("supports", []) or []
        if not supports:
            add_issue(issues, "WARNING", f"Code unit {cuid} has no supports links")
        for ref in supports:
            if ref not in story_by_id and ref not in constraint_by_id and not ref.startswith("EN-"):
                add_issue(issues, "ERROR", f"Code unit {cuid} supports missing item {ref}")

    for conflict in conflicts:
        cfid = conflict.get("id", "<unknown>")
        item = conflict.get("story_or_constraint")
        if item and item not in story_by_id and item not in constraint_by_id:
            add_issue(issues, "ERROR", f"Conflict {cfid} references missing story_or_constraint {item}")
        for field in ["need_a", "need_b"]:
            ref = conflict.get(field)
            if ref and ref not in need_by_id and ref not in constraint_by_id:
                add_issue(issues, "ERROR", f"Conflict {cfid} references missing {field}: {ref}")
        rule_id = conflict.get("rule_id")
        if rule_id and rule_id not in rule_by_id:
            add_issue(issues, "ERROR", f"Conflict {cfid} references missing rule_id: {rule_id}")
        scenario_id = conflict.get("scenario_id")
        if scenario_id and scenario_id not in scenario_by_id:
            add_issue(issues, "ERROR", f"Conflict {cfid} references missing scenario_id: {scenario_id}")
        if not conflict.get("assumptions"):
            add_issue(issues, "WARNING", f"Conflict {cfid} has no assumptions")
        if conflict.get("status") == "resolved" and not conflict.get("injections"):
            add_issue(issues, "WARNING", f"Resolved conflict {cfid} has no injections")

    dep_edges: List[Tuple[str, str]] = []
    dep_nodes: Set[str] = set(story_by_id) | set(constraint_by_id)
    for dep in dependencies:
        did = dep.get("id", "<unknown>")
        src = dep.get("from")
        dst = dep.get("to")
        if not src or not dst:
            add_issue(issues, "ERROR", f"Dependency {did} missing from/to")
            continue
        if src not in dep_nodes and not src.startswith("EN-"):
            add_issue(issues, "ERROR", f"Dependency {did} has missing from: {src}")
        if dst not in dep_nodes and not dst.startswith("EN-"):
            add_issue(issues, "ERROR", f"Dependency {did} has missing to: {dst}")
        dep_edges.append((src, dst))
        dep_nodes.add(src)
        dep_nodes.add(dst)

    cycles = graph_cycles(dep_nodes, dep_edges)
    for cycle in cycles:
        add_issue(issues, "ERROR", f"Dependency cycle: {' -> '.join(cycle)}")

    total_ac = 0
    good_ac = 0
    low_ac = 0
    for story in active_stories:
        for ac in story.get("acceptance_criteria", []) or []:
            total_ac += 1
            if ac.get("coverage_level") in GOOD_COVERAGE:
                good_ac += 1
            if ac.get("coverage_level") in LOW_COVERAGE:
                low_ac += 1

    stories_with_tests = sum(1 for s in active_stories if s.get("linked_tests"))
    stories_without_needs = sum(1 for s in active_stories if not s.get("supports_needs"))
    tests_without_links = sum(1 for t in tests if not t.get("linked_stories") and not t.get("linked_constraints"))
    code_without_links = sum(1 for c in code_units if not c.get("supports"))
    unresolved_conflicts = sum(1 for c in conflicts if c.get("status") in {"open", "needs_review"})
    low_confidence_items = 0
    item_count_with_confidence = 0
    for items in [stories, needs, constraints]:
        for item in items:
            conf = item.get("confidence")
            if isinstance(conf, (int, float)):
                item_count_with_confidence += 1
                if conf < 0.6:
                    low_confidence_items += 1

    active_story_ids = {s.get("id") for s in active_stories if s.get("id")}
    active_constraint_ids = {
        c.get("id")
        for c in constraints
        if c.get("id") and c.get("status") not in INACTIVE_STATUSES
    }
    active_scenario_story_ids = {
        s.get("linked_story")
        for s in active_scenarios
        if isinstance(s.get("linked_story"), str) and s.get("linked_story") in active_story_ids
    }
    stories_with_behavior = sum(
        1
        for story in active_stories
        if story.get("linked_scenarios") or story.get("id") in active_scenario_story_ids
    )
    stories_with_gherkin_exception = sum(1 for story in active_stories if story.get("gherkin_exception"))
    ac_with_rule_or_scenario = 0
    for story in active_stories:
        for ac in story.get("acceptance_criteria", []) or []:
            if ac.get("linked_rules") or ac.get("linked_scenarios"):
                ac_with_rule_or_scenario += 1
    automated_scenarios = [
        s
        for s in active_scenarios
        if (s.get("status") in AUTOMATED_SCENARIO_STATUSES or s.get("automation_status") in AUTOMATED_SCENARIO_STATUSES)
        and (s.get("linked_tests") or s.get("step_definitions"))
    ]
    passing_scenarios = [
        s
        for s in active_scenarios
        if (s.get("status") == "passing" or s.get("automation_status") == "passing")
        and (s.get("linked_tests") or s.get("step_definitions"))
    ]
    scenario_constraint_ids = {
        cid
        for scenario in active_scenarios
        for cid in as_list(scenario.get("protects_constraints"))
        if isinstance(cid, str)
    }
    constraints_with_scenarios = len(active_constraint_ids & scenario_constraint_ids)
    step_refs = [
        ref
        for scenario in active_scenarios
        for ref in as_list(scenario.get("step_definitions"))
        if isinstance(ref, str)
    ]
    reused_step_refs = [ref for ref in step_refs if ref in step_by_id]
    bdd_issue_count = sum(
        1
        for _, msg in issues
        if "gherkin" in msg.lower() or "scenario" in msg.lower() or "step definition" in msg.lower()
    )

    print("Storm artifact validation")
    print(f"File: {path}")
    print()
    print("Metrics:")
    print(f"  stories_total: {len(stories)}")
    print(f"  active_stories: {len(active_stories)}")
    print(f"  implemented_stories: {len(implemented_stories)}")
    print(f"  stories_with_tests_ratio: {stories_with_tests}/{len(active_stories)}" if active_stories else "  stories_with_tests_ratio: n/a")
    print(f"  acceptance_criteria_good_coverage_ratio: {good_ac}/{total_ac}" if total_ac else "  acceptance_criteria_good_coverage_ratio: n/a")
    print(f"  acceptance_criteria_low_coverage: {low_ac}")
    print(f"  tests_without_links: {tests_without_links}")
    print(f"  code_units_without_links: {code_without_links}")
    print(f"  stories_without_needs: {stories_without_needs}")
    print(f"  unresolved_conflicts: {unresolved_conflicts}")
    print(f"  dependency_cycles: {len(cycles)}")
    print(f"  low_confidence_items: {low_confidence_items}/{item_count_with_confidence}" if item_count_with_confidence else "  low_confidence_items: n/a")
    print(f"  active_scenarios: {len(active_scenarios)}")
    print(f"  behavior_coverage_ratio: {stories_with_behavior}/{len(active_stories)}" if active_stories else "  behavior_coverage_ratio: n/a")
    print(f"  stories_with_gherkin_exception: {stories_with_gherkin_exception}")
    print(f"  rule_coverage_ratio: {ac_with_rule_or_scenario}/{total_ac}" if total_ac else "  rule_coverage_ratio: n/a")
    print(f"  automation_coverage_ratio: {len(automated_scenarios)}/{len(active_scenarios)}" if active_scenarios else "  automation_coverage_ratio: n/a")
    print(f"  constraint_scenario_coverage_ratio: {constraints_with_scenarios}/{len(active_constraint_ids)}" if active_constraint_ids else "  constraint_scenario_coverage_ratio: n/a")
    print(f"  executable_specification_ratio: {len(passing_scenarios)}/{len(active_scenarios)}" if active_scenarios else "  executable_specification_ratio: n/a")
    print(f"  orphan_scenarios: {orphan_scenarios}")
    print(f"  deprecated_drift: {deprecated_drift}")
    print(f"  step_reuse_ratio: {len(reused_step_refs)}/{len(step_refs)}" if step_refs else "  step_reuse_ratio: n/a")
    print(f"  bdd_lint_issues: {bdd_issue_count}")
    print()

    errors = [msg for severity, msg in issues if severity == "ERROR"]
    warnings = [msg for severity, msg in issues if severity == "WARNING"]

    if errors:
        print("Errors:")
        for msg in errors:
            print(f"  - {msg}")
        print()
    if warnings:
        print("Warnings:")
        for msg in warnings:
            print(f"  - {msg}")
        print()

    if errors:
        print(f"FAILED: {len(errors)} errors, {len(warnings)} warnings")
        return 1
    print(f"OK: 0 errors, {len(warnings)} warnings")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
