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
    code_units = data.get("code_units", []) if isinstance(data.get("code_units", []), list) else []
    conflicts = data.get("conflicts", []) if isinstance(data.get("conflicts", []), list) else []
    dependencies = data.get("dependencies", []) if isinstance(data.get("dependencies", []), list) else []

    sections = {
        "story": stories,
        "need": needs,
        "constraint": constraints,
        "test": tests,
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
        for cuid in story.get("linked_code", []) or []:
            if cuid not in code_by_id:
                add_issue(issues, "ERROR", f"Story {sid} references missing code unit {cuid}")
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

    for test in tests:
        tid = test.get("id", "<unknown>")
        linked_stories = test.get("linked_stories", []) or []
        linked_constraints = test.get("linked_constraints", []) or []
        linked_acs = test.get("linked_acceptance_criteria", []) or []
        if not linked_stories and not linked_constraints:
            add_issue(issues, "WARNING", f"Test {tid} has no linked stories or constraints")
        for sid in linked_stories:
            if sid not in story_by_id:
                add_issue(issues, "ERROR", f"Test {tid} references missing story {sid}")
        for cid in linked_constraints:
            if cid not in constraint_by_id:
                add_issue(issues, "ERROR", f"Test {tid} references missing constraint {cid}")
        for ac_id in linked_acs:
            if ac_id not in ac_by_id:
                add_issue(issues, "ERROR", f"Test {tid} references missing acceptance criterion {ac_id}")

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
            if not (constraint.get("verified_by_tests") or constraint.get("verification_strategy") or constraint.get("enforced_by_code")):
                add_issue(issues, "WARNING", f"Constraint {cid} has no verification strategy, tests, or enforced_by_code")
        for tid in constraint.get("verified_by_tests", []) or []:
            if tid not in test_by_id:
                add_issue(issues, "ERROR", f"Constraint {cid} references missing test {tid}")
        for cuid in constraint.get("enforced_by_code", []) or []:
            if cuid not in code_by_id:
                add_issue(issues, "ERROR", f"Constraint {cid} references missing code unit {cuid}")

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
