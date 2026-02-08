import Foundation

struct PuzzleProgress: Codable, Hashable {
    let puzzleId: String
    let filledGrid: [[String?]]
    let lockedCells: [Coordinate]
    let hintsUsed: Int
    let difficulty: Difficulty
    let isComplete: Bool

    var lockedCellSet: Set<Coordinate> {
        Set(lockedCells)
    }
}
