#!/usr/bin/env python3
import argparse
import json
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

WORD_RE = re.compile(r"^[A-Z]+$")


def normalize_word(raw: str) -> str | None:
    word = raw.strip().upper()
    if not word:
        return None
    if not WORD_RE.match(word):
        return None
    return word


def fetch_text(url: str) -> str:
    if shutil.which("curl"):
        result = subprocess.run(
            ["curl", "-fsSL", url], capture_output=True, text=True, check=False
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or f"curl failed for {url}")
        return result.stdout
    with urllib.request.urlopen(url) as response:
        return response.read().decode("utf-8")


def fetch_json(url: str) -> dict:
    return json.loads(fetch_text(url))


def parse_us_airport_codes_iata(payload: dict) -> list[str]:
    words: list[str] = []
    for state_entry in payload.get("states", []):
        if not isinstance(state_entry, dict):
            continue
        for _, airports in state_entry.items():
            if not isinstance(airports, list):
                continue
            for airport in airports:
                if not isinstance(airport, dict):
                    continue
                for _, codes in airport.items():
                    if not isinstance(codes, dict):
                        continue
                    code = codes.get("IATA")
                    if isinstance(code, str):
                        words.append(code)
    return words


def load_sources(sources_path: Path) -> dict:
    return json.loads(sources_path.read_text())


def collect_words_for_source(source: dict) -> list[str]:
    fmt = source.get("format")
    url = source.get("url")
    if not url:
        return []

    if fmt == "text":
        text = fetch_text(url)
        return [line for line in text.splitlines()]
    if fmt == "json":
        payload = fetch_json(url)
        parser = source.get("parser")
        if parser == "us_airport_codes_iata":
            return parse_us_airport_codes_iata(payload)
        json_key = source.get("json_key")
        if json_key and isinstance(payload.get(json_key), list):
            return [str(item) for item in payload[json_key]]
    return []


def write_wordlist(path: Path, words: set[str]) -> None:
    sorted_words = sorted(words)
    path.write_text("\n".join(sorted_words) + ("\n" if sorted_words else ""))


def load_frequency_words(sources: dict, min_len: int, max_len: int) -> set[str]:
    entries = sources.get("frequency", [])
    words: set[str] = set()
    for source in entries:
        for raw in collect_words_for_source(source):
            normalized = normalize_word(str(raw))
            if not normalized:
                continue
            if min_len <= len(normalized) <= max_len:
                words.add(normalized)
    return words


def main() -> int:
    parser = argparse.ArgumentParser(description="Download and normalize wordlists.")
    parser.add_argument(
        "--wordlists-dir",
        default=str(Path(__file__).resolve().parents[1] / "wordlists"),
        help="Directory for wordlists and word_sources.json",
    )
    parser.add_argument("--min-length", type=int, default=2)
    parser.add_argument("--max-length", type=int, default=7)
    args = parser.parse_args()

    wordlists_dir = Path(args.wordlists_dir)
    sources_path = wordlists_dir / "word_sources.json"

    if not sources_path.exists():
        print(f"Missing word_sources.json at {sources_path}", file=sys.stderr)
        return 1

    sources = load_sources(sources_path)

    frequency_words = load_frequency_words(sources, args.min_length, args.max_length)
    if frequency_words:
        print(f"frequency: {len(frequency_words)} words (filter for core)")

    for category, entries in sources.items():
        if category == "frequency":
            continue
        words: set[str] = set()
        for source in entries:
            for raw in collect_words_for_source(source):
                normalized = normalize_word(str(raw))
                if not normalized:
                    continue
                if args.min_length <= len(normalized) <= args.max_length:
                    words.add(normalized)
        if category == "core" and frequency_words:
            words &= frequency_words
        output_path = wordlists_dir / f"{category}.txt"
        write_wordlist(output_path, words)
        print(f"{category}: {len(words)} words -> {output_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
