from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

WORD_RE = re.compile(r"^[A-Z]+$")
CATEGORIES = ["core", "names", "geo", "slang", "abbreviations"]


def normalize_word(raw: str) -> str | None:
    word = raw.strip().upper()
    if not word:
        return None
    if not WORD_RE.match(word):
        return None
    return word


def read_word_file(path: Path, min_len: int, max_len: int) -> set[str]:
    if not path.exists():
        return set()
    words: set[str] = set()
    for line in path.read_text().splitlines():
        normalized = normalize_word(line)
        if not normalized:
            continue
        if min_len <= len(normalized) <= max_len:
            words.add(normalized)
    return words


def load_allowlist(path: Path, min_len: int, max_len: int) -> set[str]:
    return read_word_file(path, min_len, max_len)


def load_banlist(path: Path, min_len: int, max_len: int) -> set[str]:
    return read_word_file(path, min_len, max_len)


@dataclass
class WordData:
    words: list[str]
    by_length: dict[int, list[str]]


class WordIndex:
    def __init__(self, words: list[str]):
        self.words = words
        self.by_length: dict[int, list[str]] = {}
        for word in words:
            self.by_length.setdefault(len(word), []).append(word)

        self._index: dict[int, list[dict[str, set[int]]]] = {}
        self._cache: dict[int, dict[str, list[str]]] = {}
        self._all_indices: dict[int, set[int]] = {}
        self._build_index()

    def _build_index(self) -> None:
        for length, words in self.by_length.items():
            positions: list[dict[str, set[int]]] = [dict() for _ in range(length)]
            for idx, word in enumerate(words):
                for pos, ch in enumerate(word):
                    positions[pos].setdefault(ch, set()).add(idx)
            self._index[length] = positions
            self._cache[length] = {}
            self._all_indices[length] = set(range(len(words)))

    def candidates(self, pattern: str) -> list[str]:
        length = len(pattern)
        if length not in self.by_length:
            return []
        cache = self._cache[length]
        if pattern in cache:
            return cache[pattern]

        indices = set(self._all_indices[length])
        positions = self._index[length]
        for pos, ch in enumerate(pattern):
            if ch == ".":
                continue
            indices &= positions[pos].get(ch, set())
            if not indices:
                break

        words = [self.by_length[length][idx] for idx in indices]
        cache[pattern] = words
        return words


def load_words(wordlists_dir: Path, min_len: int, max_len: int) -> WordData:
    combined: set[str] = set()
    for category in CATEGORIES:
        combined |= read_word_file(wordlists_dir / f"{category}.txt", min_len, max_len)

    allowlist = load_allowlist(wordlists_dir / "allowlist.txt", min_len, max_len)
    banlist = load_banlist(wordlists_dir / "banlist.txt", min_len, max_len)

    combined |= allowlist
    combined -= banlist

    words = sorted(combined)
    by_length: dict[int, list[str]] = {}
    for word in words:
        by_length.setdefault(len(word), []).append(word)

    return WordData(words=words, by_length=by_length)
