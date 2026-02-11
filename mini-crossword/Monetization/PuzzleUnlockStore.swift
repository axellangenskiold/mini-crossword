import Foundation

protocol PuzzleUnlockStoring {
    func loadUnlocks() throws -> Set<String>
    func saveUnlocks(_ ids: Set<String>) throws
}

struct FilePuzzleUnlockStore: PuzzleUnlockStoring {
    enum StoreError: Error {
        case missingDirectory
    }

    let fileURL: URL

    init(fileManager: FileManager = .default) throws {
        guard let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw StoreError.missingDirectory
        }
        let appRoot = root.appendingPathComponent("MiniCrossword", isDirectory: true)
        try fileManager.createDirectory(at: appRoot, withIntermediateDirectories: true)
        self.fileURL = appRoot.appendingPathComponent("unlocked_puzzles.json")
    }

    func loadUnlocks() throws -> Set<String> {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        let decoded = try JSONDecoder().decode([String].self, from: data)
        return Set(decoded)
    }

    func saveUnlocks(_ ids: Set<String>) throws {
        let data = try JSONEncoder().encode(Array(ids).sorted())
        try data.write(to: fileURL, options: [.atomic])
    }
}
