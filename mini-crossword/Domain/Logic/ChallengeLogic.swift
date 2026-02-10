import Foundation

enum ChallengeLogic {
    static func progressKey(challengeId: String, index: Int) -> String {
        "challenge_\(challengeId)_\(index)"
    }

    static func isComplete(completedCount: Int, totalCount: Int) -> Bool {
        totalCount > 0 && completedCount >= totalCount
    }

    static func sortSummaries(_ summaries: [ChallengeSummary]) -> [ChallengeSummary] {
        summaries.sorted { lhs, rhs in
            if lhs.isComplete != rhs.isComplete {
                return !lhs.isComplete
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
