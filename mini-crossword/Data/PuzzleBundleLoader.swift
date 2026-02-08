import Foundation

struct PuzzleBundleLoader {
    enum LoaderError: Error {
        case missingResources
    }

    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadPuzzles() throws -> [Puzzle] {
        let candidates = [
            bundle.urls(forResourcesWithExtension: "json", subdirectory: "Puzzles") ?? [],
            bundle.urls(forResourcesWithExtension: "json", subdirectory: "Resources/Puzzles") ?? []
        ].flatMap { $0 }

        guard !candidates.isEmpty else {
            throw LoaderError.missingResources
        }

        let decoder = JSONDecoder()
        return try candidates.sorted { $0.lastPathComponent < $1.lastPathComponent }.map { url in
            let data = try Data(contentsOf: url)
            return try decoder.decode(Puzzle.self, from: data)
        }
    }
}
