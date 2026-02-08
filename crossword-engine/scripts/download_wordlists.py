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
TOKEN_RE = re.compile(r"[A-Za-z]+")


def normalize_word(raw: str) -> str | None:
    word = raw.strip().upper()
    if not word:
        return None
    if not WORD_RE.match(word):
        return None
    return word


def normalized_tokens(raw: str, split_tokens: bool) -> list[str]:
    tokens = TOKEN_RE.findall(raw) if split_tokens else [raw]
    normalized: list[str] = []
    for token in tokens:
        word = normalize_word(token)
        if word:
            normalized.append(word)
    return normalized


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


def parse_richpeople_names(payload: dict) -> list[str]:
    words: list[str] = []
    for item in payload.get("richPeople", []):
        if isinstance(item, dict):
            name = item.get("name")
            if isinstance(name, str):
                words.append(name)
    return words


def parse_us_presidents_names(payload: dict) -> list[str]:
    words: list[str] = []
    for entry in payload.get("objects", []):
        if not isinstance(entry, dict):
            continue
        if entry.get("role_type_label") != "President":
            continue
        person = entry.get("person")
        if not isinstance(person, dict):
            continue
        first = person.get("firstname")
        last = person.get("lastname")
        if isinstance(first, str) and isinstance(last, str):
            words.append(f"{first} {last}")
            continue
        name = person.get("name")
        if isinstance(name, str):
            words.append(name)
    return words


def parse_norse_deities(payload: dict) -> list[str]:
    words: list[str] = []
    deities = payload.get("norse_deities")
    if isinstance(deities, dict):
        for key in ("gods", "goddesses"):
            entries = deities.get(key, [])
            if isinstance(entries, list):
                words.extend(str(item) for item in entries)
    return words


def parse_egyptian_gods(payload: dict) -> list[str]:
    words: list[str] = []
    gods = payload.get("egyptian_gods")
    if isinstance(gods, dict):
        words.extend(gods.keys())
    return words


def parse_hebrew_god_names(payload: dict) -> list[str]:
    words: list[str] = []
    for entry in payload.get("names", []):
        if isinstance(entry, dict):
            name = entry.get("name")
            if isinstance(name, str):
                words.append(name)
    return words


def parse_country_capital_cities(payload: list) -> list[str]:
    words: list[str] = []
    for entry in payload:
        if isinstance(entry, dict):
            city = entry.get("city")
            if isinstance(city, str):
                words.append(city)
    return words


def parse_continents(payload: list) -> list[str]:
    words: set[str] = set()
    for entry in payload:
        if isinstance(entry, dict):
            continent = entry.get("continent")
            if isinstance(continent, str):
                words.add(continent)
    return list(words)


def parse_us_cities_top(payload: dict) -> list[str]:
    words: list[str] = []
    for entry in payload.get("cities", []):
        if isinstance(entry, dict):
            city = entry.get("city")
            if isinstance(city, str):
                words.append(city)
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
        if parser == "richpeople_names":
            return parse_richpeople_names(payload)
        if parser == "us_presidents_names":
            return parse_us_presidents_names(payload)
        if parser == "norse_deities":
            return parse_norse_deities(payload)
        if parser == "egyptian_gods":
            return parse_egyptian_gods(payload)
        if parser == "hebrew_god_names":
            return parse_hebrew_god_names(payload)
        if parser == "country_capital_cities":
            if isinstance(payload, list):
                return parse_country_capital_cities(payload)
            return []
        if parser == "continents":
            if isinstance(payload, list):
                return parse_continents(payload)
            return []
        if parser == "us_cities_top":
            return parse_us_cities_top(payload)
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
            for normalized in normalized_tokens(str(raw), False):
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
            split_tokens = bool(source.get("split_tokens"))
            for raw in collect_words_for_source(source):
                for normalized in normalized_tokens(str(raw), split_tokens):
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
