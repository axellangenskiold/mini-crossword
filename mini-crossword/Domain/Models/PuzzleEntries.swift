import Foundation

struct PuzzleEntries: Codable, Hashable {
    let across: [Entry]
    let down: [Entry]
}
