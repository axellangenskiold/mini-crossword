import Foundation

final class ChallengeListViewModel: ObservableObject {
    @Published var challenges: [ChallengeSummary] = []
    @Published var loadError: String? = nil

    private let loader: ChallengeBundleLoader
    private let progressStore: PuzzleProgressStoring

    init(
        loader: ChallengeBundleLoader = ChallengeBundleLoader(),
        progressStore: PuzzleProgressStoring? = nil
    ) {
        self.loader = loader
        if let progressStore {
            self.progressStore = progressStore
        } else {
            self.progressStore = (try? FilePuzzleProgressStore()) ?? InMemoryChallengeProgressStore()
        }
    }

    func load() {
        do {
            let definitions = try loader.loadChallenges()
            var summaries: [ChallengeSummary] = []

            for definition in definitions {
                let completedCount = completedPuzzleCount(for: definition)
                let isComplete = ChallengeLogic.isComplete(
                    completedCount: completedCount,
                    totalCount: definition.puzzleCount
                )
                summaries.append(
                    ChallengeSummary(
                        id: definition.id,
                        name: definition.name,
                        puzzleFile: definition.puzzleFile,
                        puzzleCount: definition.puzzleCount,
                        completedCount: completedCount,
                        isComplete: isComplete
                    )
                )
            }

            challenges = ChallengeLogic.sortSummaries(summaries)
            loadError = nil
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? "Failed to load challenges"
        }
    }

    private func completedPuzzleCount(for definition: ChallengeDefinition) -> Int {
        guard definition.puzzleCount > 0 else {
            return 0
        }
        var count = 0
        for index in 0..<definition.puzzleCount {
            let key = ChallengeLogic.progressKey(challengeId: definition.id, index: index)
            if let progress = try? progressStore.loadProgress(puzzleId: key), progress.isComplete {
                count += 1
            }
        }
        return count
    }
}

private struct InMemoryChallengeProgressStore: PuzzleProgressStoring {
    func loadProgress(puzzleId: String) throws -> PuzzleProgress? {
        nil
    }

    func saveProgress(_ progress: PuzzleProgress) throws {
    }
}
