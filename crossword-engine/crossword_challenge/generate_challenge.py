#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
from typing import Optional, Set


ROOT = os.path.dirname(os.path.abspath(__file__))
RESOURCE_PATH = os.path.join(ROOT, "mini-crossword", "Resources", "Challenges", "challenges.json")
PUZZLE_DIR = os.path.join(ROOT, "mini-crossword", "Resources", "Puzzles")
SECONDARY_PATH = os.path.join(ROOT, "Puzzles", "Challenges", "challenges.json")


def slugify(name: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")
    return slug or "challenge"


def load_catalog(path: str) -> dict:
    if not os.path.exists(path):
        return {"challenges": []}
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict) or "challenges" not in data:
        return {"challenges": []}
    if not isinstance(data["challenges"], list):
        data["challenges"] = []
    return data


def write_catalog(path: str, catalog: dict) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(catalog, handle, indent=2, ensure_ascii=True)
        handle.write("\n")


def find_default_puzzle() -> Optional[str]:
    if not os.path.isdir(PUZZLE_DIR):
        return None
    candidates = [
        name
        for name in sorted(os.listdir(PUZZLE_DIR))
        if name.startswith("puzzle_") and name.endswith(".json")
    ]
    return candidates[0] if candidates else None


def unique_id(base: str, existing: Set[str]) -> str:
    if base not in existing:
        return base
    index = 2
    while f"{base}_{index}" in existing:
        index += 1
    return f"{base}_{index}"


def main() -> int:
    parser = argparse.ArgumentParser(description="Add a challenge to the bundled challenges catalog.")
    parser.add_argument("--name", required=True, help="Challenge display name.")
    parser.add_argument("--puzzle", default=None, help="Puzzle file name (e.g. puzzle_2026-02-01.json).")
    parser.add_argument("--count", type=int, default=25, help="Number of puzzles in the challenge.")
    parser.add_argument("--id", default=None, help="Optional challenge id override.")
    args = parser.parse_args()

    puzzle_file = args.puzzle or find_default_puzzle()
    if not puzzle_file:
        print("No puzzle file found. Pass --puzzle explicitly.", file=sys.stderr)
        return 1

    paths = [RESOURCE_PATH, SECONDARY_PATH]
    catalogs = {path: load_catalog(path) for path in paths}
    existing_ids = set()
    for catalog in catalogs.values():
        existing_ids.update(item.get("id") for item in catalog.get("challenges", []) if isinstance(item, dict))

    if args.id:
        if args.id in existing_ids:
            print(f"Challenge id '{args.id}' already exists.", file=sys.stderr)
            return 1
        challenge_id = args.id
    else:
        challenge_id = unique_id(slugify(args.name), existing_ids)

    count = max(1, args.count)
    challenge = {
        "id": challenge_id,
        "name": args.name,
        "puzzleFile": puzzle_file,
        "puzzleCount": count
    }

    for path, catalog in catalogs.items():
        catalog.setdefault("challenges", []).append(challenge)
        write_catalog(path, catalog)

    print(f"Added challenge '{args.name}' ({challenge_id}) with {count} puzzles.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
