#!/usr/bin/env python3
"""
Dependency-aware RICE ranking for Storm Cloud Product Development Process.

Usage:
    python <AGENTS_ROOT>/scripts/storm/rank-backlog.py docs/product/storm.json --out docs/product/reports/ranking.md

No external dependencies.
"""

from __future__ import annotations

import argparse
import json
from collections import defaultdict, deque
from pathlib import Path
from typing import Any, Dict, Iterable, List, Set, Tuple

DONE_STATUSES = {"implemented", "removed"}
SKIP_STATUSES = {"deprecated", "superseded", "removed"}
CANDIDATE_STATUSES = {"active", "proposed", "confirmed", "partial", "inferred", "needs_review", "blocked"}


def load_json(path: Path) -> Dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def story_value(story: Dict[str, Any]) -> float:
    priority = story.get("priority", {}) or {}
    reach = float(priority.get("reach", 1.0) or 1.0)
    impact = float(priority.get("impact", 1.0) or 1.0)
    confidence = float(priority.get("confidence", story.get("confidence", 0.5)) or 0.5)
    return max(reach * impact * confidence, 0.0)


def story_effort(story: Dict[str, Any]) -> float:
    priority = story.get("priority", {}) or {}
    if "effort" in priority and priority["effort"]:
        return max(float(priority["effort"]), 0.1)
    effort = priority.get("agentic_effort", {}) or {}
    parts = [
        effort.get("architecture_blast_radius", 1.0),
        effort.get("verification_complexity", 1.0),
        effort.get("dependency_overhead", 0.0),
        effort.get("migration_or_rollout_risk", 0.0),
    ]
    total = 0.0
    for part in parts:
        try:
            total += float(part or 0.0)
        except (TypeError, ValueError):
            total += 0.0
    return max(total, 0.1)


def build_prereq_graph(stories: Dict[str, Dict[str, Any]], dependencies: List[Dict[str, Any]]) -> Dict[str, Set[str]]:
    prereqs: Dict[str, Set[str]] = {sid: set() for sid in stories}
    for dep in dependencies:
        src = dep.get("from")
        dst = dep.get("to")
        if src in stories and dst in stories:
            prereqs[dst].add(src)
    for sid, story in stories.items():
        for dep in story.get("dependencies", []) or []:
            if dep in stories:
                prereqs[sid].add(dep)
    return prereqs


def detect_cycles(prereqs: Dict[str, Set[str]]) -> List[List[str]]:
    graph: Dict[str, Set[str]] = defaultdict(set)
    nodes = set(prereqs)
    for dst, srcs in prereqs.items():
        for src in srcs:
            graph[src].add(dst)
            nodes.add(src)

    visited: Set[str] = set()
    stack: Set[str] = set()
    path: List[str] = []
    cycles: List[List[str]] = []

    def dfs(node: str) -> None:
        visited.add(node)
        stack.add(node)
        path.append(node)
        for nxt in graph.get(node, set()):
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


def closure(item: str, prereqs: Dict[str, Set[str]], done: Set[str]) -> Set[str]:
    result: Set[str] = set()

    def visit(node: str) -> None:
        if node in done or node in result:
            return
        for pre in prereqs.get(node, set()):
            visit(pre)
        result.add(node)

    visit(item)
    return result


def topo_order(items: Set[str], prereqs: Dict[str, Set[str]]) -> List[str]:
    in_degree = {item: 0 for item in items}
    outgoing: Dict[str, Set[str]] = {item: set() for item in items}
    for dst in items:
        for src in prereqs.get(dst, set()):
            if src in items:
                in_degree[dst] += 1
                outgoing.setdefault(src, set()).add(dst)
    queue = deque(sorted([item for item, deg in in_degree.items() if deg == 0]))
    result: List[str] = []
    while queue:
        node = queue.popleft()
        result.append(node)
        for nxt in sorted(outgoing.get(node, set())):
            in_degree[nxt] -= 1
            if in_degree[nxt] == 0:
                queue.append(nxt)
    if len(result) != len(items):
        return sorted(items)
    return result


def rank(data: Dict[str, Any]) -> Tuple[List[Dict[str, Any]], List[List[str]]]:
    all_stories = {
        s["id"]: s
        for s in data.get("stories", [])
        if isinstance(s, dict) and s.get("id") and s.get("status") not in SKIP_STATUSES
    }
    prereqs = build_prereq_graph(all_stories, data.get("dependencies", []) or [])
    cycles = detect_cycles(prereqs)
    if cycles:
        return [], cycles

    done: Set[str] = {sid for sid, s in all_stories.items() if s.get("status") in DONE_STATUSES}
    candidates: Set[str] = {
        sid
        for sid, s in all_stories.items()
        if s.get("status") not in DONE_STATUSES and s.get("status") not in SKIP_STATUSES
    }

    ranked: List[Dict[str, Any]] = []
    rank_no = 1

    while candidates:
        scored: List[Tuple[float, str, Set[str], float, float]] = []
        for sid in candidates:
            c = closure(sid, prereqs, done)
            if not c:
                continue
            value_star = sum(story_value(all_stories[item]) for item in c)
            cost_star = sum(story_effort(all_stories[item]) for item in c)
            priority_star = value_star / cost_star if cost_star else 0.0
            scored.append((priority_star, sid, c, value_star, cost_star))

        if not scored:
            break

        scored.sort(key=lambda row: (row[0], row[3], -row[4], row[1]), reverse=True)
        priority_star, chosen, chosen_closure, value_star, cost_star = scored[0]
        ordered_closure = topo_order(chosen_closure, prereqs)

        for item in ordered_closure:
            if item in done:
                continue
            story = all_stories[item]
            ranked.append(
                {
                    "rank": rank_no,
                    "item": item,
                    "title": story.get("title", ""),
                    "chosen_for": chosen,
                    "closure": ordered_closure,
                    "value_star": round(value_star, 4),
                    "cost_star": round(cost_star, 4),
                    "priority_star": round(priority_star, 4),
                    "own_value": round(story_value(story), 4),
                    "own_effort": round(story_effort(story), 4),
                    "explanation": f"Selected as part of closure for {chosen}; prerequisites are paid once and ranking is recalculated after selection."
                }
            )
            rank_no += 1
            done.add(item)
            candidates.discard(item)

    return ranked, []


def write_markdown(path: Path, ranked: List[Dict[str, Any]], cycles: List[List[str]]) -> None:
    lines: List[str] = []
    lines.append("# Dependency-aware Ranking")
    lines.append("")
    if cycles:
        lines.append("## Dependency cycles")
        lines.append("")
        for cycle in cycles:
            lines.append(f"- {' -> '.join(cycle)}")
        lines.append("")
        lines.append("Ranking was not computed because dependency graph is cyclic.")
    else:
        lines.append("## Ranked backlog")
        lines.append("")
        lines.append("| Rank | Item | Title | Chosen for | Closure | Value* | Cost* | Priority* | Own value | Own effort |")
        lines.append("|---:|---|---|---|---|---:|---:|---:|---:|---:|")
        for row in ranked:
            closure_text = ", ".join(row.get("closure", []))
            title = str(row.get("title", "")).replace("|", "\\|")
            lines.append(
                f"| {row['rank']} | {row['item']} | {title} | {row['chosen_for']} | {closure_text} | "
                f"{row['value_star']} | {row['cost_star']} | {row['priority_star']} | {row['own_value']} | {row['own_effort']} |"
            )
        lines.append("")
        lines.append("## Method")
        lines.append("")
        lines.append("For each candidate, the script computes the closure: the item plus all unimplemented prerequisites. It then calculates cumulative value and cost and greedily selects the best priority*. After each selection, already paid prerequisites are removed from future closures.")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("storm_json", type=Path)
    parser.add_argument("--out", type=Path, default=None)
    parser.add_argument("--write-json", action="store_true", help="write ranking back into storm.json")
    args = parser.parse_args()

    data = load_json(args.storm_json)
    ranked, cycles = rank(data)

    if args.out:
        write_markdown(args.out, ranked, cycles)
        print(f"Wrote ranking report: {args.out}")

    if args.write_json and not cycles:
        data["ranking"] = ranked
        args.storm_json.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"Updated ranking in: {args.storm_json}")

    if cycles:
        print("Dependency cycles found:")
        for cycle in cycles:
            print("  - " + " -> ".join(cycle))
        return 1

    print(f"Ranked {len(ranked)} backlog items")
    for row in ranked[:10]:
        print(f"{row['rank']:>2}. {row['item']} priority*={row['priority_star']} closure={','.join(row['closure'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
