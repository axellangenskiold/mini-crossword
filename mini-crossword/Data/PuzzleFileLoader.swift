import Foundation

struct PuzzleFileLoader {
    enum LoaderError: LocalizedError {
        case notFound
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "Puzzle file could not be found."
            case .decodingFailed:
                return "Puzzle file could not be decoded."
            }
        }
    }

    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadPuzzle(named fileName: String) throws -> Puzzle {
        let trimmed = fileName.replacingOccurrences(of: ".json", with: "")
        let candidates = [
            bundle.url(forResource: trimmed, withExtension: "json", subdirectory: "Puzzles"),
            bundle.url(forResource: trimmed, withExtension: "json", subdirectory: "Resources/Puzzles"),
            bundle.url(forResource: trimmed, withExtension: "json", subdirectory: nil)
        ]

        let urls = candidates.compactMap { $0 }
        if let url = urls.first {
            return try decodePuzzle(from: url)
        }

        let scanCandidates = [
            bundle.urls(forResourcesWithExtension: "json", subdirectory: "Puzzles") ?? [],
            bundle.urls(forResourcesWithExtension: "json", subdirectory: "Resources/Puzzles") ?? [],
            bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        ]
        .flatMap { $0 }

        if let url = scanCandidates.first(where: { $0.lastPathComponent == fileName }) {
            return try decodePuzzle(from: url)
        }

        throw LoaderError.notFound
    }

    func loadFallbackPuzzle() throws -> Puzzle {
        let loader = PuzzleBundleLoader(bundle: bundle)
        guard let puzzle = try loader.loadPuzzles().first else {
            throw LoaderError.notFound
        }
        return puzzle
    }

    private func decodePuzzle(from url: URL) throws -> Puzzle {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Puzzle.self, from: data)
        } catch {
            throw LoaderError.decodingFailed
        }
    }
}
