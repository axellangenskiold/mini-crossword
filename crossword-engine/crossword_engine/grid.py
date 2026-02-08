from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class Slot:
    slot_id: int
    direction: str
    number: int
    cells: list[tuple[int, int]]


def is_border_cell(row: int, col: int, width: int, height: int) -> bool:
    return row == 0 or col == 0 or row == height - 1 or col == width - 1


def border_neighbors(cell: tuple[int, int], width: int, height: int) -> list[tuple[int, int]]:
    row, col = cell
    candidates = [
        (row - 1, col),
        (row + 1, col),
        (row, col - 1),
        (row, col + 1),
    ]
    neighbors = []
    for r, c in candidates:
        if 0 <= r < height and 0 <= c < width and is_border_cell(r, c, width, height):
            neighbors.append((r, c))
    return neighbors


def corners(width: int, height: int) -> set[tuple[int, int]]:
    return {
        (0, 0),
        (0, width - 1),
        (height - 1, 0),
        (height - 1, width - 1),
    }


def valid_corners_for_cell(cell: tuple[int, int], width: int, height: int) -> set[tuple[int, int]]:
    row, col = cell
    valid: set[tuple[int, int]] = set()
    if row == 0:
        valid |= {(0, 0), (0, width - 1)}
    if row == height - 1:
        valid |= {(height - 1, 0), (height - 1, width - 1)}
    if col == 0:
        valid |= {(0, 0), (height - 1, 0)}
    if col == width - 1:
        valid |= {(0, width - 1), (height - 1, width - 1)}
    return valid


def validate_black_cells(
    width: int, height: int, black_cells: Iterable[tuple[int, int]]
) -> bool:
    black_set = {tuple(cell) for cell in black_cells}
    if len(black_set) > 4:
        return False
    for row, col in black_set:
        if not is_border_cell(row, col, width, height):
            return False

    if not black_set:
        return True

    corners_set = corners(width, height)
    visited: set[tuple[int, int]] = set()

    for start in list(black_set):
        if start in visited:
            continue
        stack = [start]
        component: set[tuple[int, int]] = set()
        while stack:
            cell = stack.pop()
            if cell in visited:
                continue
            visited.add(cell)
            component.add(cell)
            for neighbor in border_neighbors(cell, width, height):
                if neighbor in black_set and neighbor not in visited:
                    stack.append(neighbor)

        component_corners = component & corners_set
        for cell in component:
            valid = valid_corners_for_cell(cell, width, height)
            if not (component_corners & valid):
                return False

    return True


def extract_slots(
    width: int, height: int, black_cells: Iterable[tuple[int, int]]
) -> tuple[list[Slot], dict[tuple[int, int], list[tuple[int, int]]]]:
    black_set = {tuple(cell) for cell in black_cells}
    slots: list[Slot] = []
    cell_to_slots: dict[tuple[int, int], list[tuple[int, int]]] = {}
    next_number = 1
    slot_id = 0

    for row in range(height):
        for col in range(width):
            if (row, col) in black_set:
                continue

            starts_across = (
                (col == 0 or (row, col - 1) in black_set)
                and (col + 1 < width and (row, col + 1) not in black_set)
            )
            starts_down = (
                (row == 0 or (row - 1, col) in black_set)
                and (row + 1 < height and (row + 1, col) not in black_set)
            )

            number = None
            if starts_across or starts_down:
                number = next_number
                next_number += 1

            if starts_across:
                cells: list[tuple[int, int]] = []
                c = col
                while c < width and (row, c) not in black_set:
                    cells.append((row, c))
                    c += 1
                slots.append(Slot(slot_id=slot_id, direction="across", number=number, cells=cells))
                slot_id += 1

            if starts_down:
                cells = []
                r = row
                while r < height and (r, col) not in black_set:
                    cells.append((r, col))
                    r += 1
                slots.append(Slot(slot_id=slot_id, direction="down", number=number, cells=cells))
                slot_id += 1

    for slot in slots:
        for index, cell in enumerate(slot.cells):
            cell_to_slots.setdefault(cell, []).append((slot.slot_id, index))

    return slots, cell_to_slots


def validate_no_singletons(
    width: int, height: int, black_cells: Iterable[tuple[int, int]]
) -> bool:
    black_set = {tuple(cell) for cell in black_cells}
    slots, cell_to_slots = extract_slots(width, height, black_set)
    if not slots:
        return False

    for row in range(height):
        for col in range(width):
            if (row, col) in black_set:
                continue
            if (row, col) not in cell_to_slots:
                return False
    return True


def build_solution_grid(
    width: int, height: int, black_cells: Iterable[tuple[int, int]], letters: dict[tuple[int, int], str]
) -> list[list[str | None]]:
    black_set = {tuple(cell) for cell in black_cells}
    grid: list[list[str | None]] = []
    for row in range(height):
        row_cells: list[str | None] = []
        for col in range(width):
            if (row, col) in black_set:
                row_cells.append(None)
            else:
                row_cells.append(letters.get((row, col)))
        grid.append(row_cells)
    return grid
