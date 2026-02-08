import Foundation

protocol PuzzleStoring {
    func loadPuzzle(dateString: String) throws -> Puzzle?
    func savePuzzle(_ puzzle: Puzzle) throws
}

struct FilePuzzleStore: PuzzleStoring {
    enum StoreError: Error {
        case missingDirectory
    }

    let rootURL: URL

    init(fileManager: FileManager = .default) throws {
        guard let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw StoreError.missingDirectory
        }
        let appRoot = root.appendingPathComponent("MiniCrossword", isDirectory: true)
        let puzzlesRoot = appRoot.appendingPathComponent("Puzzles", isDirectory: true)
        try fileManager.createDirectory(at: puzzlesRoot, withIntermediateDirectories: true)
        self.rootURL = puzzlesRoot
    }

    func loadPuzzle(dateString: String) throws -> Puzzle? {
        let url = puzzleURL(for: dateString)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Puzzle.self, from: data)
    }

    func savePuzzle(_ puzzle: Puzzle) throws {
        let url = puzzleURL(for: puzzle.date)
        let data = try JSONEncoder().encode(puzzle)
        try data.write(to: url, options: [.atomic])
    }

    private func puzzleURL(for dateString: String) -> URL {
        let safeDate = dateString.replacingOccurrences(of: "[^0-9-]", with: "", options: .regularExpression)
        return rootURL.appendingPathComponent("\(safeDate).json")
    }
}
