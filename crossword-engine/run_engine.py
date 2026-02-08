#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import random
import time
from pathlib import Path

from crossword_engine.generator import SolverTimeout, generate_puzzle
from crossword_engine.hashing import puzzle_hash
from crossword_engine.wordlist import WordIndex, load_words


def puzzle_id_from_hash(hash_hex: str) -> str:
    return f"mcw_v1_{hash_hex[:16]}"


def load_existing_hashes(hash_path: Path) -> set[str]:
    if not hash_path.exists():
        return set()
    return {line.strip() for line in hash_path.read_text().splitlines() if line.strip()}


def append_hash(hash_path: Path, hash_hex: str) -> None:
    with hash_path.open("a", encoding="utf-8") as handle:
        handle.write(f"{hash_hex}\n")


def next_index(output_dir: Path) -> int:
    max_index = 0
    for path in output_dir.glob("puzzle_*.json"):
        stem = path.stem
        parts = stem.split("_")
        if len(parts) != 2:
            continue
        try:
            index = int(parts[1])
        except ValueError:
            continue
        max_index = max(max_index, index)
    return max_index + 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the crossword engine.")
    parser.add_argument(
        "--output-dir",
        default=str(Path(__file__).resolve().parents[1] / "Puzzles" / "Puzzles_NO_CLUES"),
        help="Directory to write puzzle JSON files",
    )
    parser.add_argument(
        "--wordlists-dir",
        default=str(Path(__file__).resolve().parent / "wordlists"),
        help="Directory containing wordlist files",
    )
    parser.add_argument("--seed", type=int, default=None, help="Seed for randomness")
    parser.add_argument("--time-limit", type=float, default=2.5, help="Solver time limit in seconds")
    parser.add_argument("--sleep", type=float, default=0.0, help="Sleep between puzzles")
    parser.add_argument("--max", type=int, default=0, help="Stop after generating N puzzles")
    args = parser.parse_args()

    rng = random.Random(args.seed)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    wordlists_dir = Path(args.wordlists_dir)
    word_data = load_words(wordlists_dir, min_len=2, max_len=7)
    if not word_data.words:
        raise SystemExit(f"No words loaded from {wordlists_dir}")

    word_index = WordIndex(word_data.words)

    hash_path = output_dir / "_hashes.txt"
    existing_hashes = load_existing_hashes(hash_path)
    index = next_index(output_dir)

    print(f"Loaded {len(word_data.words)} words")
    print(f"Existing puzzle hashes: {len(existing_hashes)}")
    print(f"Writing puzzles to: {output_dir}")

    try:
        generated = 0
        while True:
            try:
                puzzle = generate_puzzle(
                    word_index=word_index,
                    rng=rng,
                    time_limit_s=args.time_limit,
                    hash_func=puzzle_hash,
                    id_func=puzzle_id_from_hash,
                )
            except SolverTimeout:
                continue

            if not puzzle:
                continue

            if puzzle.hash_hex in existing_hashes:
                continue

            grid_preview = [
                "".join("-" if cell is None else cell for cell in row)
                for row in puzzle.grid_solution
            ]
            puzzle_data = {
                "gridPreview": grid_preview,
                "id": puzzle.puzzle_id,
                "date": "",
                "width": puzzle.width,
                "height": puzzle.height,
                "blackCells": [[r, c] for r, c in puzzle.black_cells],
                "gridSolution": puzzle.grid_solution,
                "entries": puzzle.entries,
            }

            output_path = output_dir / f"puzzle_{index:06d}.json"
            output_path.write_text(json.dumps(puzzle_data, indent=2))
            append_hash(hash_path, puzzle.hash_hex)
            existing_hashes.add(puzzle.hash_hex)

            print(f"Generated {output_path.name} ({puzzle.puzzle_id})")
            index += 1
            generated += 1

            if args.max and generated >= args.max:
                print("Reached max puzzle count. Stopping engine.")
                return 0

            if args.sleep:
                time.sleep(args.sleep)
    except KeyboardInterrupt:
        print("Stopping engine.")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
