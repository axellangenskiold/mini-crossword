import Foundation

struct ChallengeCatalog: Codable {
    let challenges: [ChallengeDefinition]
}

struct ChallengeDefinition: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let puzzleFile: String
    let puzzleCount: Int
}

struct ChallengeSummary: Identifiable, Hashable {
    let id: String
    let name: String
    let puzzleFile: String
    let puzzleCount: Int
    let completedCount: Int
    let isComplete: Bool
}
