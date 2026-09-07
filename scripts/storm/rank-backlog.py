#!/usr/bin/env python3
"""Deterministic STORM ranking using the shared validated ST/CN/EN model."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from storm_model import ContractError, InputError, StormModel, load_model


def rank(data: dict) -> tuple[list[dict], list[dict]]:
    model = StormModel(data)
    return model.ranking, model.unranked_items


def markdown(ranked: list[dict], unranked: list[dict]) -> str:
    lines = ["# Dependency-aware Ranking", "", "## Ranked backlog", "",
             "| Rank | Item | Title | Chosen for | Closure | Value* | Cost* | Priority* | Own value | Own effort |",
             "|---:|---|---|---|---|---:|---:|---:|---:|---:|"]
    for row in ranked:
        title = row["title"].replace("|", "\\|").replace("\n", " ")
        closure = ", ".join(row["closure"])
        lines.append(f"| {row['rank']} | {row['item']} | {title} | {row['chosen_for']} | {closure} | "
                     f"{row['value_star']} | {row['cost_star']} | {row['priority_star']} | {row['own_value']} | {row['own_effort']} |")
    lines += ["", "## Explanations", ""]
    lines += [f"- {row['item']}: {row['explanation']}" for row in ranked]
    lines += ["", "## unranked_items", "", "| ID | Reason | Blockers |", "|---|---|---|"]
    lines += [f"| {row['item']} | {row['reason']} | {', '.join(row.get('blockers', []))} |" for row in unranked]
    lines += ["", "## Method", "",
              "Top-level from -> to means from precedes to; embedded dependencies are prerequisites. "
              "CN preserves transitive order without executable rows, value or effort. "
              "EN supports is traceability only; a dependency path to a story is required for ranking. "
              "Implemented ST/EN satisfies a prerequisite without cost/value. Blocked and retired prerequisites block the closure. "
              "Each unpaid ST/EN is charged once. Sum own_effort across rows; cost_star repeats the selected package cost. "
              "Conditional payment does not change artifact statuses. Equal priority/value/cost selects ascending ID."]
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("storm_json", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--write-json", action="store_true", help="update only ranking in storm.json")
    args = parser.parse_args()
    try:
        if args.out:
            # Path equality alone misses existing hard links to the artifact.
            # Check identity before any mkdir/open/write of either output.
            if (args.out.resolve() == args.storm_json.resolve()
                    or (args.out.exists() and args.out.samefile(args.storm_json))):
                raise ContractError("--out: report must not overwrite the input artifact (same path or file identity)")
        model = load_model(args.storm_json)
        ranked, unranked = model.ranking, model.unranked_items
        # Prepare the complete bytes of every requested output before the first
        # write. An encoding failure must not truncate an existing file.
        report_bytes = None
        if args.out:
            try:
                report_bytes = markdown(ranked, unranked).encode("utf-8")
            except UnicodeEncodeError as exc:
                raise ContractError(f"--out: report text cannot be encoded as UTF-8: {exc}") from None
        updated = dict(model.data, ranking=ranked)
        payload = json.dumps(updated, ensure_ascii=False, indent=2, allow_nan=False) + "\n"
        # UTF-8 can represent all Unicode scalar values. For lone surrogates
        # retained by JSON parsing, emit the equivalent JSON \uXXXX escape;
        # ordinary Unicode and extension values stay readable and preserved.
        payload_bytes = payload.encode("utf-8", errors="backslashreplace")
        if args.out:
            args.out.parent.mkdir(parents=True, exist_ok=True)
            args.out.write_bytes(report_bytes)
            print(f"Wrote ranking report: {args.out}")
        if args.write_json:
            args.storm_json.write_bytes(payload_bytes)
            print(f"Updated ranking in: {args.storm_json}")
    except (ContractError, InputError, OSError, UnicodeError) as exc:
        print(f"ERROR: {exc}")
        return 1 if isinstance(exc, ContractError) else 2
    print(f"Ranked {len(ranked)} backlog items")
    for row in ranked[:10]:
        print(f"{row['rank']:>2}. {row['item']} priority*={row['priority_star']} closure={','.join(row['closure'])}")
    print("unranked_items:")
    for row in unranked:
        print(f"  {row['item']}: {row['reason']}" + (f" ({', '.join(row['blockers'])})" if row.get('blockers') else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
