#!/usr/bin/env python3
import json
import os
import shutil
import sys


ROOT = os.path.dirname(os.path.abspath(__file__))
RES_PUZZLES_DIR = os.path.join(ROOT, "mini-crossword", "Resources", "Puzzles")
RES_CHALLENGES_DIR = os.path.join(ROOT, "mini-crossword", "Resources", "Challenges")
RES_CHALLENGES_CATALOG = os.path.join(RES_CHALLENGES_DIR, "challenges.json")
LEGACY_CHALLENGES_DIR = os.path.join(ROOT, "Puzzles", "Challenges")


def remove_puzzle_files() -> int:
    removed = 0
    if not os.path.isdir(RES_PUZZLES_DIR):
        return removed
    for name in os.listdir(RES_PUZZLES_DIR):
        if name.startswith("puzzle_") and name.endswith(".json"):
            os.remove(os.path.join(RES_PUZZLES_DIR, name))
            removed += 1
    return removed


def reset_challenges_catalog() -> None:
    os.makedirs(RES_CHALLENGES_DIR, exist_ok=True)
    with open(RES_CHALLENGES_CATALOG, "w", encoding="utf-8") as handle:
        json.dump({"challenges": []}, handle, indent=2, ensure_ascii=True)
        handle.write("\n")


def remove_challenge_folders() -> int:
    removed = 0
    if not os.path.isdir(RES_CHALLENGES_DIR):
        return removed
    for name in os.listdir(RES_CHALLENGES_DIR):
        if name == "challenges.json":
            continue
        path = os.path.join(RES_CHALLENGES_DIR, name)
        if os.path.isdir(path):
            shutil.rmtree(path)
            removed += 1
        elif name.endswith(".json") and name != "challenges.json":
            os.remove(path)
            removed += 1
    return removed


def remove_legacy_challenges() -> int:
    if os.path.isdir(LEGACY_CHALLENGES_DIR):
        shutil.rmtree(LEGACY_CHALLENGES_DIR)
        return 1
    return 0


def main() -> int:
    puzzles_removed = remove_puzzle_files()
    challenges_removed = remove_challenge_folders()
    reset_challenges_catalog()
    legacy_removed = remove_legacy_challenges()

    print(
        "Reset complete: removed "
        f"{puzzles_removed} daily puzzles, "
        f"{challenges_removed} challenge folders/files, "
        f"{legacy_removed} legacy challenge folder."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
