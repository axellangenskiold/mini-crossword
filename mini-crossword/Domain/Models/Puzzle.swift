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

    func withDate(_ date: String) -> Puzzle {
        Puzzle(
            id: id,
            date: date,
            width: width,
            height: height,
            blackCells: blackCells,
            gridSolution: gridSolution,
            entries: entries,
            gridPreview: gridPreview
        )
    }
}
