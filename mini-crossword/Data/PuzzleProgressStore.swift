import Foundation

protocol PuzzleProgressStoring {
    func loadProgress(puzzleId: String) throws -> PuzzleProgress?
    func saveProgress(_ progress: PuzzleProgress) throws
}

struct FilePuzzleProgressStore: PuzzleProgressStoring {
    enum StoreError: Error {
        case missingDirectory
    }

    let rootURL: URL

    init(fileManager: FileManager = .default) throws {
        guard let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw StoreError.missingDirectory
        }
        let appRoot = root.appendingPathComponent("MiniCrossword", isDirectory: true)
        try fileManager.createDirectory(at: appRoot, withIntermediateDirectories: true)
        self.rootURL = appRoot
    }

    func loadProgress(puzzleId: String) throws -> PuzzleProgress? {
        let url = progressURL(for: puzzleId)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PuzzleProgress.self, from: data)
    }

    func saveProgress(_ progress: PuzzleProgress) throws {
        let url = progressURL(for: progress.puzzleId)
        let data = try JSONEncoder().encode(progress)
        try data.write(to: url, options: [.atomic])
    }

    private func progressURL(for puzzleId: String) -> URL {
        let safeId = puzzleId.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
        return rootURL.appendingPathComponent("\(safeId).json")
    }
}
