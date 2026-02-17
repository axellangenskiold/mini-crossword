import Foundation

struct ChallengeBundleLoader {
    enum LoaderError: LocalizedError {
        case missingResources
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .missingResources:
                return "No bundled challenges were found."
            case .decodingFailed:
                return "Bundled challenges could not be decoded."
            }
        }
    }

    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadChallenges() throws -> [ChallengeDefinition] {
        let candidates = [
            bundle.url(forResource: "challenges", withExtension: "json", subdirectory: "Challenges"),
            bundle.url(forResource: "challenges", withExtension: "json", subdirectory: "Resources/Challenges")
        ]

        guard let url = candidates.compactMap({ $0 }).first else {
            throw LoaderError.missingResources
        }

        do {
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(ChallengeCatalog.self, from: data)
            return catalog.challenges
        } catch {
            throw LoaderError.decodingFailed
        }
    }
}
