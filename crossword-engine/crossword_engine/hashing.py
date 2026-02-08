from __future__ import annotations

import hashlib
from typing import Iterable


def canonical_bytes(
    width: int,
    height: int,
    black_cells: Iterable[tuple[int, int]],
    grid_solution: list[list[str | None]],
) -> bytes:
    black_set = {tuple(cell) for cell in black_cells}
    black_part = ";".join(f"{r},{c}" for r, c in sorted(black_set))

    rows: list[str] = []
    for row in range(height):
        letters: list[str] = []
        for col in range(width):
            if (row, col) in black_set:
                letters.append("#")
            else:
                cell = grid_solution[row][col]
                letters.append(cell if cell else "?")
        rows.append("".join(letters))

    canonical = "|".join([f"{width}x{height}", black_part, "/".join(rows)])
    return canonical.encode("utf-8")


def puzzle_hash(
    width: int,
    height: int,
    black_cells: Iterable[tuple[int, int]],
    grid_solution: list[list[str | None]],
) -> str:
    digest = hashlib.sha256(canonical_bytes(width, height, black_cells, grid_solution)).hexdigest()
    return digest
