import Foundation

struct Entry: Codable, Hashable {
    let number: Int
    let cells: [Coordinate]
    let answer: String
    let clue: String

    var start: Coordinate? {
        cells.first
    }
}
