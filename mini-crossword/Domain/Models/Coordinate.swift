import Foundation

struct Coordinate: Hashable, Codable {
    let row: Int
    let col: Int

    init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let row = try container.decode(Int.self)
        let col = try container.decode(Int.self)
        self.init(row: row, col: col)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(row)
        try container.encode(col)
    }
}
