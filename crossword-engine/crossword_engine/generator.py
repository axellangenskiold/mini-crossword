from __future__ import annotations

import random
import time
from dataclasses import dataclass
from itertools import combinations
from typing import Iterable

from .grid import Slot, build_solution_grid, extract_slots, validate_black_cells, validate_no_singletons
from .wordlist import WordIndex

GRID_SIZES = [
    (5, 5),
    (5, 6),
    (6, 5),
    (6, 6),
    (7, 5),
    (7, 6),
]


class SolverTimeout(Exception):
    pass


@dataclass
class Puzzle:
    width: int
    height: int
    black_cells: list[tuple[int, int]]
    grid_solution: list[list[str | None]]
    entries: dict[str, list[dict]]
    puzzle_id: str
    hash_hex: str


_BLACK_SET_CACHE: dict[tuple[int, int], list[list[tuple[int, int]]]] = {}


def border_cells(width: int, height: int) -> list[tuple[int, int]]:
    cells: list[tuple[int, int]] = []
    for row in range(height):
        for col in range(width):
            if row == 0 or col == 0 or row == height - 1 or col == width - 1:
                cells.append((row, col))
    return cells


def valid_black_sets(width: int, height: int) -> list[list[tuple[int, int]]]:
    cache_key = (width, height)
    if cache_key in _BLACK_SET_CACHE:
        return _BLACK_SET_CACHE[cache_key]

    border = border_cells(width, height)
    valid: list[list[tuple[int, int]]] = []
    for count in range(0, 5):
        for combo in combinations(border, count):
            if not validate_black_cells(width, height, combo):
                continue
            if not validate_no_singletons(width, height, combo):
                continue
            valid.append(list(combo))

    _BLACK_SET_CACHE[cache_key] = valid
    return valid


def pattern_for_slot(slot: Slot, grid_letters: dict[tuple[int, int], str]) -> str:
    letters: list[str] = []
    for cell in slot.cells:
        letter = grid_letters.get(cell)
        letters.append(letter if letter else ".")
    return "".join(letters)


def intersects_map(cell_to_slots: dict[tuple[int, int], list[tuple[int, int]]]) -> dict[int, set[int]]:
    neighbors: dict[int, set[int]] = {}
    for slot_entries in cell_to_slots.values():
        slot_ids = [slot_id for slot_id, _ in slot_entries]
        for slot_id in slot_ids:
            neighbors.setdefault(slot_id, set()).update(
                other for other in slot_ids if other != slot_id
            )
    return neighbors


def solve_grid(
    width: int,
    height: int,
    black_cells: Iterable[tuple[int, int]],
    word_index: WordIndex,
    rng: random.Random,
    time_limit_s: float,
    forced_word: str | None = None,
) -> tuple[dict[tuple[int, int], str], list[Slot]] | None:
    slots, cell_to_slots = extract_slots(width, height, black_cells)
    if not slots:
        return None

    slot_by_id = {slot.slot_id: slot for slot in slots}
    neighbors = intersects_map(cell_to_slots)
    grid_letters: dict[tuple[int, int], str] = {}
    assigned: dict[int, str] = {}
    used_words: set[str] = set()
    deadline = time.monotonic() + time_limit_s

    def forward_check(slot_id: int) -> bool:
        for neighbor_id in neighbors.get(slot_id, set()):
            if neighbor_id in assigned:
                continue
            neighbor = slot_by_id[neighbor_id]
            pattern = pattern_for_slot(neighbor, grid_letters)
            candidates = word_index.candidates(pattern)
            if not any(word not in used_words for word in candidates):
                return False
        return True

    def backtrack() -> bool:
        if time.monotonic() > deadline:
            raise SolverTimeout()
        if len(assigned) == len(slots):
            return True

        best_slot: Slot | None = None
        best_candidates: list[str] | None = None
        for slot in slots:
            if slot.slot_id in assigned:
                continue
            pattern = pattern_for_slot(slot, grid_letters)
            candidates = [
                word for word in word_index.candidates(pattern) if word not in used_words
            ]
            if not candidates:
                return False
            if best_candidates is None or len(candidates) < len(best_candidates):
                best_slot = slot
                best_candidates = candidates
                if len(best_candidates) == 1:
                    break

        if not best_slot or best_candidates is None:
            return False

        rng.shuffle(best_candidates)
        for word in best_candidates:
            added: dict[tuple[int, int], str] = {}
            for cell, letter in zip(best_slot.cells, word):
                existing = grid_letters.get(cell)
                if existing and existing != letter:
                    break
                if not existing:
                    added[cell] = letter
            else:
                grid_letters.update(added)
                assigned[best_slot.slot_id] = word
                used_words.add(word)

                if forward_check(best_slot.slot_id) and backtrack():
                    return True

                used_words.remove(word)
                del assigned[best_slot.slot_id]
                for cell in added:
                    del grid_letters[cell]

        return False

    def try_forced_slot(slot: Slot) -> bool:
        grid_letters.clear()
        assigned.clear()
        used_words.clear()
        for cell, letter in zip(slot.cells, forced_word or ""):
            grid_letters[cell] = letter
        assigned[slot.slot_id] = forced_word or ""
        used_words.add(forced_word or "")
        return backtrack()

    if forced_word:
        candidates = [slot for slot in slots if len(slot.cells) == len(forced_word)]
        rng.shuffle(candidates)
        for slot in candidates:
            if try_forced_slot(slot):
                return grid_letters, slots
        return None

    if backtrack():
        return grid_letters, slots
    return None


def build_entries(slots: list[Slot], answers: dict[int, str]) -> dict[str, list[dict]]:
    entries: dict[str, list[dict]] = {"across": [], "down": []}
    for slot in slots:
        answer = answers.get(slot.slot_id)
        if not answer:
            continue
        entry = {
            "number": slot.number,
            "cells": [[r, c] for r, c in slot.cells],
            "answer": answer,
            "clue": "",
        }
        entries[slot.direction].append(entry)

    for direction in entries:
        entries[direction].sort(key=lambda item: item.get("number", 0))

    return entries


def generate_puzzle(
    word_index: WordIndex,
    rng: random.Random,
    time_limit_s: float,
    hash_func,
    id_func,
    forced_word: str | None = None,
) -> Puzzle | None:
    width, height = rng.choice(GRID_SIZES)
    candidates = valid_black_sets(width, height)
    if not candidates:
        return None
    black_cells = rng.choice(candidates)

    solved = solve_grid(
        width, height, black_cells, word_index, rng, time_limit_s, forced_word=forced_word
    )
    if not solved:
        return None

    grid_letters, slots = solved
    grid_solution = build_solution_grid(width, height, black_cells, grid_letters)

    answers = {slot.slot_id: "" for slot in slots}
    for slot in slots:
        pattern = "".join(grid_letters[cell] for cell in slot.cells)
        answers[slot.slot_id] = pattern

    entries = build_entries(slots, answers)

    hash_hex = hash_func(width, height, black_cells, grid_solution)
    puzzle_id = id_func(hash_hex)

    return Puzzle(
        width=width,
        height=height,
        black_cells=black_cells,
        grid_solution=grid_solution,
        entries=entries,
        puzzle_id=puzzle_id,
        hash_hex=hash_hex,
    )
