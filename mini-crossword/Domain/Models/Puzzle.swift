import Foundation

struct Puzzle: Codable, Hashable, Identifiable {
    let id: String
    let date: String
    let width: Int
    let height: Int
    let blackCells: [Coordinate]
    let gridSolution: [[String?]]
    let entries: PuzzleEntries
    let gridPreview: [String]?

    var blackCellSet: Set<Coordinate> {
        Set(blackCells)
    }
}
