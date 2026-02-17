#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

WORD_RE = re.compile(r"^[A-Z]+$")
DEFAULT_WORDLIST_FILES = [
    "core.txt",
    "names.txt",
    "geo.txt",
    "slang.txt",
    "abbreviations.txt",
]


def normalize_word(raw: str) -> str | None:
    word = raw.strip().upper()
    if not word:
        return None
    if not WORD_RE.match(word):
        return None
    return word


def infer_source_path(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit)

    candidates = [
        Path("Puzzles/Puzzles_FINISHED/_low_confidence_clues.json"),
        Path("mini-crossword/Puzzles/Puzzles_FINISHED/_low_confidence_clues.json"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise FileNotFoundError(
        "No low-confidence file found. Pass --source-json explicitly."
    )


def extract_words_from_json(payload: object) -> set[str]:
    words: set[str] = set()

    def add(raw: object) -> None:
        if not isinstance(raw, str):
            return
        normalized = normalize_word(raw)
        if normalized:
            words.add(normalized)

    if isinstance(payload, list):
        for item in payload:
            if isinstance(item, dict):
                # Current format: [{"answer": "WORD", ...}, ...]
                add(item.get("answer"))
                # Alternate fallback keys, in case file shape changes.
                add(item.get("word"))
            elif isinstance(item, str):
                add(item)
        return words

    if isinstance(payload, dict):
        # Support dictionary wrappers if format changes.
        for key in ("answers", "words", "entries"):
            value = payload.get(key)
            if isinstance(value, list):
                words |= extract_words_from_json(value)
        return words

    return words


def remove_words_from_file(path: Path, blocked_words: set[str], dry_run: bool) -> tuple[int, set[str]]:
    if not path.exists():
        return 0, set()

    lines = path.read_text(encoding="utf-8").splitlines()
    kept: list[str] = []
    removed_words: set[str] = set()
    removed_count = 0

    for line in lines:
        stripped = line.strip()
        normalized = normalize_word(stripped)
        if normalized and normalized in blocked_words:
            removed_count += 1
            removed_words.add(normalized)
            continue
        kept.append(line)

    if not dry_run and removed_count > 0:
        output = "\n".join(kept)
        if kept:
            output += "\n"
        path.write_text(output, encoding="utf-8")

    return removed_count, removed_words


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Remove low-confidence answer words from puzzle source wordlists "
            "(core/names/geo/slang/abbreviations)."
        )
    )
    parser.add_argument(
        "--source-json",
        default=None,
        help=(
            "Path to low-confidence JSON file. If omitted, script tries: "
            "Puzzles/Puzzles_FINISHED/_low_confidence_clues.json, then "
            "mini-crossword/Puzzles/Puzzles_FINISHED/_low_confidence_clues.json"
        ),
    )
    parser.add_argument(
        "--wordlists-dir",
        default="crossword-engine/wordlists",
        help="Directory containing wordlist text files.",
    )
    parser.add_argument(
        "--files",
        nargs="*",
        default=DEFAULT_WORDLIST_FILES,
        help="Specific wordlist files to edit (default: core/names/geo/slang/abbreviations).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be removed, without changing files.",
    )
    args = parser.parse_args()

    source_path = infer_source_path(args.source_json)
    payload = json.loads(source_path.read_text(encoding="utf-8"))
    blocked_words = extract_words_from_json(payload)

    if not blocked_words:
        print(f"No valid A-Z words found in {source_path}")
        return 0

    wordlists_dir = Path(args.wordlists_dir)
    if not wordlists_dir.exists():
        raise FileNotFoundError(f"Wordlists directory not found: {wordlists_dir}")

    print(f"Source JSON: {source_path}")
    print(f"Candidate blocked words: {len(blocked_words)}")
    print(f"Mode: {'dry-run' if args.dry_run else 'apply'}")

    removed_any: set[str] = set()
    total_removed_lines = 0

    for filename in args.files:
        path = wordlists_dir / filename
        removed_count, removed_words = remove_words_from_file(path, blocked_words, args.dry_run)
        total_removed_lines += removed_count
        removed_any |= removed_words
        print(f"{path}: removed {removed_count}")

    not_found = sorted(blocked_words - removed_any)
    print(f"Total removed lines: {total_removed_lines}")
    print(f"Unique removed words: {len(removed_any)}")
    print(f"Blocked words not found in wordlists: {len(not_found)}")

    if not_found:
        preview = ", ".join(not_found[:25])
        if len(not_found) > 25:
            preview += ", ..."
        print(f"Not found preview: {preview}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
