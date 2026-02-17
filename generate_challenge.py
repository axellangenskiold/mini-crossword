#!/usr/bin/env python3
import argparse
import json
import os
import re
import shutil
import sys
from typing import List, Set


ROOT = os.path.dirname(os.path.abspath(__file__))
BANK_DIR = os.path.join(ROOT, "Puzzles", "Puzzles_FINISHED")
CHALLENGE_ROOT = os.path.join(ROOT, "Puzzles", "Challenges")
RESOURCE_CHALLENGE_ROOT = os.path.join(ROOT, "mini-crossword", "Resources", "Challenges")
RESOURCE_CATALOG_PATH = os.path.join(RESOURCE_CHALLENGE_ROOT, "challenges.json")


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

def list_bank_puzzles() -> List[str]:
    if not os.path.isdir(BANK_DIR):
        return []
    return sorted(
        name
        for name in os.listdir(BANK_DIR)
        if name.startswith("puzzle_") and name.endswith(".json")
    )


def unique_id(base: str, existing: Set[str]) -> str:
    if base not in existing:
        return base
    index = 2
    while f"{base}_{index}" in existing:
        index += 1
    return f"{base}_{index}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a challenge from finished puzzles and update challenges.json."
    )
    parser.add_argument("--name", required=True, help="Challenge display name.")
    parser.add_argument("--count", type=int, default=25, help="Number of puzzles in the challenge.")
    parser.add_argument("--id", default=None, help="Optional challenge id override.")
    args = parser.parse_args()

    count = max(1, args.count)
    bank_puzzles = list_bank_puzzles()
    if len(bank_puzzles) < count:
        print(
            f"Not enough puzzles in {BANK_DIR}. Need {count}, found {len(bank_puzzles)}.",
            file=sys.stderr
        )
        return 1

    catalog = load_catalog(RESOURCE_CATALOG_PATH)
    existing_ids = set()
    existing_ids.update(item.get("id") for item in catalog.get("challenges", []) if isinstance(item, dict))

    if args.id:
        if args.id in existing_ids:
            print(f"Challenge id '{args.id}' already exists.", file=sys.stderr)
            return 1
        challenge_id = args.id
    else:
        challenge_id = unique_id(slugify(args.name), existing_ids)

    folder_name = slugify(args.name)
    challenge_dir = os.path.join(CHALLENGE_ROOT, folder_name)
    resource_dir = os.path.join(RESOURCE_CHALLENGE_ROOT, folder_name)
    if os.path.exists(challenge_dir):
        print(f"Challenge folder already exists: {challenge_dir}", file=sys.stderr)
        return 1

    os.makedirs(challenge_dir, exist_ok=True)
    os.makedirs(resource_dir, exist_ok=True)
    moved_files = []
    for name in bank_puzzles[:count]:
        src = os.path.join(BANK_DIR, name)
        dst = os.path.join(challenge_dir, name)
        shutil.move(src, dst)
        shutil.copy2(dst, os.path.join(resource_dir, name))
        moved_files.append(name)

    challenge = {
        "id": challenge_id,
        "name": args.name,
        "puzzleFile": moved_files[0],
        "puzzleFiles": moved_files,
        "puzzleFolder": folder_name,
        "puzzleCount": count
    }

    catalog.setdefault("challenges", []).append(challenge)
    write_catalog(RESOURCE_CATALOG_PATH, catalog)

    print(f"Added challenge '{args.name}' ({challenge_id}) with {count} puzzles.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
