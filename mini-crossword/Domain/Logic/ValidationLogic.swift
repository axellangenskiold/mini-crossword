import Foundation

enum ValidationLogic {
    static func isEntryComplete(_ entry: Entry, filledGrid: [[String?]]) -> Bool {
        for cell in entry.cells {
            guard let letter = gridLetter(in: filledGrid, at: cell), !letter.isEmpty else {
                return false
            }
        }
        return true
    }

    static func isEntryCorrect(_ entry: Entry, filledGrid: [[String?]], solutionGrid: [[String?]]) -> Bool {
        for cell in entry.cells {
            guard let filled = gridLetter(in: filledGrid, at: cell),
                  let solution = gridLetter(in: solutionGrid, at: cell),
                  !filled.isEmpty else {
                return false
            }
            if filled != solution {
                return false
            }
        }
        return true
    }

    static func isPuzzleComplete(
        width: Int,
        height: Int,
        blackCells: Set<Coordinate>,
        filledGrid: [[String?]]
    ) -> Bool {
        for row in 0..<height {
            for col in 0..<width {
                let cell = Coordinate(row: row, col: col)
                if blackCells.contains(cell) {
                    continue
                }
                guard let letter = gridLetter(in: filledGrid, at: cell), !letter.isEmpty else {
                    return false
                }
            }
        }
        return true
    }

    static func isPuzzleCorrect(
        width: Int,
        height: Int,
        blackCells: Set<Coordinate>,
        filledGrid: [[String?]],
        solutionGrid: [[String?]]
    ) -> Bool {
        for row in 0..<height {
            for col in 0..<width {
                let cell = Coordinate(row: row, col: col)
                if blackCells.contains(cell) {
                    continue
                }
                guard let filled = gridLetter(in: filledGrid, at: cell),
                      let solution = gridLetter(in: solutionGrid, at: cell),
                      !filled.isEmpty else {
                    return false
                }
                if filled != solution {
                    return false
                }
            }
        }
        return true
    }

    private static func gridLetter(in grid: [[String?]], at cell: Coordinate) -> String? {
        guard cell.row >= 0, cell.col >= 0 else {
            return nil
        }
        guard grid.indices.contains(cell.row) else {
            return nil
        }
        let row = grid[cell.row]
        guard row.indices.contains(cell.col) else {
            return nil
        }
        return row[cell.col]
    }
}
