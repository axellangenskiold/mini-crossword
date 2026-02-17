#!/usr/bin/env python3
import argparse
import datetime as dt
import json
import os
import sys
from typing import List


ROOT = os.path.dirname(os.path.abspath(__file__))
BANK_DIR = os.path.join(ROOT, "Puzzles", "Puzzles_FINISHED")
OUTPUT_DIR = os.path.join(ROOT, "mini-crossword", "Resources", "Puzzles")


def list_bank_puzzles() -> List[str]:
    if not os.path.isdir(BANK_DIR):
        return []
    return sorted(
        name
        for name in os.listdir(BANK_DIR)
        if name.startswith("puzzle_") and name.endswith(".json")
    )


def parse_date(value: str) -> dt.date:
    try:
        return dt.date.fromisoformat(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("Date must be YYYY-MM-DD.") from exc


def load_puzzle(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def write_puzzle(path: str, puzzle: dict) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(puzzle, handle, indent=2, ensure_ascii=True)
        handle.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Assign finished puzzles to daily dates and move them into resources."
    )
    parser.add_argument("--count", type=int, required=True, help="Number of daily puzzles to assign.")
    parser.add_argument(
        "--start-date",
        type=parse_date,
        default=dt.date.today().replace(day=1),
        help="Start date (YYYY-MM-DD). Defaults to first of current month.",
    )
    args = parser.parse_args()

    count = max(1, args.count)
    bank_puzzles = list_bank_puzzles()
    if len(bank_puzzles) < count:
        print(
            f"Not enough puzzles in {BANK_DIR}. Need {count}, found {len(bank_puzzles)}.",
            file=sys.stderr
        )
        return 1

    for offset in range(count):
        date_value = args.start_date + dt.timedelta(days=offset)
        date_str = date_value.isoformat()
        output_name = f"puzzle_{date_str}.json"
        output_path = os.path.join(OUTPUT_DIR, output_name)
        if os.path.exists(output_path):
            print(f"Puzzle already exists for {date_str}: {output_path}", file=sys.stderr)
            return 1

        source_name = bank_puzzles[offset]
        source_path = os.path.join(BANK_DIR, source_name)
        puzzle = load_puzzle(source_path)
        puzzle["date"] = date_str
        write_puzzle(output_path, puzzle)
        os.remove(source_path)

    print(f"Assigned {count} daily puzzles starting {args.start_date.isoformat()}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
