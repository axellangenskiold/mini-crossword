import Foundation

struct PuzzleBundleLoader {
    enum LoaderError: LocalizedError {
        case missingResources
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .missingResources:
                return "No bundled puzzles were found."
            case .decodingFailed:
                return "Bundled puzzles could not be decoded."
            }
        }
    }

    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadPuzzles() throws -> [Puzzle] {
        let candidates = [
            bundle.urls(forResourcesWithExtension: "json", subdirectory: "Puzzles") ?? [],
            bundle.urls(forResourcesWithExtension: "json", subdirectory: "Resources/Puzzles") ?? [],
            bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        ]
        .flatMap { $0 }
        .filter { $0.lastPathComponent.hasPrefix("puzzle_") }

        guard !candidates.isEmpty else {
            throw LoaderError.missingResources
        }

        let decoder = JSONDecoder()
        do {
            return try candidates.sorted { $0.lastPathComponent < $1.lastPathComponent }.map { url in
                let data = try Data(contentsOf: url)
                return try decoder.decode(Puzzle.self, from: data)
            }
        } catch {
            throw LoaderError.decodingFailed
        }
    }
}
