import Foundation

enum NavigationPhase {
    case across
    case down
}

struct NavigationState: Hashable {
    let phase: NavigationPhase
    let entryIndex: Int
    let cellIndex: Int
}

enum NavigationLogic {
    static func orderedEntries(_ entries: [Entry]) -> [Entry] {
        entries.sorted { lhs, rhs in
            let left = lhs.start ?? Coordinate(row: Int.max, col: Int.max)
            let right = rhs.start ?? Coordinate(row: Int.max, col: Int.max)
            if left.row != right.row {
                return left.row < right.row
            }
            if left.col != right.col {
                return left.col < right.col
            }
            return lhs.number < rhs.number
        }
    }

    static func firstFillableCell(
        width: Int,
        height: Int,
        blackCells: Set<Coordinate>
    ) -> Coordinate? {
        for row in 0..<height {
            for col in 0..<width {
                let cell = Coordinate(row: row, col: col)
                if !blackCells.contains(cell) {
                    return cell
                }
            }
        }
        return nil
    }

    static func entryContainingCell(_ entries: [Entry], cell: Coordinate) -> (entryIndex: Int, cellIndex: Int)? {
        for (entryIndex, entry) in entries.enumerated() {
            if let cellIndex = entry.cells.firstIndex(of: cell) {
                return (entryIndex, cellIndex)
            }
        }
        return nil
    }

    static func initialState(
        acrossEntries: [Entry],
        downEntries: [Entry],
        width: Int,
        height: Int,
        blackCells: Set<Coordinate>
    ) -> NavigationState? {
        let orderedAcross = orderedEntries(acrossEntries)
        let orderedDown = orderedEntries(downEntries)
        guard let startCell = firstFillableCell(width: width, height: height, blackCells: blackCells) else {
            return nil
        }
        guard let match = entryContainingCell(orderedAcross, cell: startCell) else {
            return nil
        }
        _ = orderedDown
        return NavigationState(phase: .across, entryIndex: match.entryIndex, cellIndex: match.cellIndex)
    }

    static func cellForState(
        _ state: NavigationState,
        acrossEntries: [Entry],
        downEntries: [Entry]
    ) -> Coordinate? {
        let entry = entriesForPhase(state.phase, acrossEntries: acrossEntries, downEntries: downEntries)[safe: state.entryIndex]
        return entry?.cells[safe: state.cellIndex]
    }

    static func advanceState(
        _ state: NavigationState,
        acrossEntries: [Entry],
        downEntries: [Entry],
        width: Int,
        height: Int,
        blackCells: Set<Coordinate>
    ) -> NavigationState? {
        let orderedAcross = orderedEntries(acrossEntries)
        let orderedDown = orderedEntries(downEntries)

        switch state.phase {
        case .across:
            guard let entry = orderedAcross[safe: state.entryIndex] else {
                return nil
            }
            if state.cellIndex + 1 < entry.cells.count {
                return NavigationState(phase: .across, entryIndex: state.entryIndex, cellIndex: state.cellIndex + 1)
            }
            if state.entryIndex + 1 < orderedAcross.count {
                return NavigationState(phase: .across, entryIndex: state.entryIndex + 1, cellIndex: 0)
            }
            guard let startCell = firstFillableCell(width: width, height: height, blackCells: blackCells) else {
                return nil
            }
            guard let match = entryContainingCell(orderedDown, cell: startCell) else {
                return nil
            }
            return NavigationState(phase: .down, entryIndex: match.entryIndex, cellIndex: match.cellIndex)
        case .down:
            guard let entry = orderedDown[safe: state.entryIndex] else {
                return nil
            }
            if state.cellIndex + 1 < entry.cells.count {
                return NavigationState(phase: .down, entryIndex: state.entryIndex, cellIndex: state.cellIndex + 1)
            }
            if state.entryIndex + 1 < orderedDown.count {
                return NavigationState(phase: .down, entryIndex: state.entryIndex + 1, cellIndex: 0)
            }
            return nil
        }
    }

    static func hintTarget(
        state: NavigationState,
        acrossEntries: [Entry],
        downEntries: [Entry],
        lockedCells: Set<Coordinate>,
        width: Int,
        height: Int,
        blackCells: Set<Coordinate>
    ) -> Coordinate? {
        guard let currentCell = cellForState(state, acrossEntries: acrossEntries, downEntries: downEntries) else {
            return nil
        }
        if !lockedCells.contains(currentCell) {
            return currentCell
        }
        guard let nextState = advanceState(
            state,
            acrossEntries: acrossEntries,
            downEntries: downEntries,
            width: width,
            height: height,
            blackCells: blackCells
        ) else {
            return nil
        }
        return cellForState(nextState, acrossEntries: acrossEntries, downEntries: downEntries)
    }

    private static func entriesForPhase(
        _ phase: NavigationPhase,
        acrossEntries: [Entry],
        downEntries: [Entry]
    ) -> [Entry] {
        switch phase {
        case .across:
            return orderedEntries(acrossEntries)
        case .down:
            return orderedEntries(downEntries)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }
        return self[index]
    }
}
