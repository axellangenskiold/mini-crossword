import Foundation

final class DailyChallengeViewModel: ObservableObject {
    @Published var eligibleDates: [Date] = []
    @Published var puzzlesByDate: [String: Puzzle] = [:]
    @Published var completedPuzzleDates: Set<String> = []
    @Published var selectedDate: Date = Date()
    @Published var loadError: String? = nil

    private let calendar: Calendar
    private let bundleLoader: PuzzleBundleLoader
    private let puzzleStore: PuzzleStoring
    private let progressStore: PuzzleProgressStoring

    init(
        calendar: Calendar = .current,
        bundleLoader: PuzzleBundleLoader = PuzzleBundleLoader(),
        puzzleStore: PuzzleStoring? = nil,
        progressStore: PuzzleProgressStoring? = nil
    ) {
        self.calendar = calendar
        self.bundleLoader = bundleLoader
        if let puzzleStore {
            self.puzzleStore = puzzleStore
        } else {
            self.puzzleStore = (try? FilePuzzleStore()) ?? InMemoryPuzzleStore()
        }
        if let progressStore {
            self.progressStore = progressStore
        } else {
            self.progressStore = (try? FilePuzzleProgressStore()) ?? InMemoryPuzzleProgressStore()
        }
    }

    func load(today: Date = Date()) {
        selectedDate = today
        let eligible = Eligibility.eligibleDates(today: today, calendar: calendar)
        eligibleDates = eligible

        do {
            let bundledPuzzles = try bundleLoader.loadPuzzles()
            let bundleByDate = Dictionary(uniqueKeysWithValues: bundledPuzzles.map { ($0.date, $0) })
            let fallbackPuzzle = bundledPuzzles.first

            var loaded: [String: Puzzle] = [:]
            var completedDates: Set<String> = []

            for date in eligible {
                let dateString = PuzzleDateFormatter.string(from: date)
                let stored = try puzzleStore.loadPuzzle(dateString: dateString)
                if stored == nil {
                    if let bundled = bundleByDate[dateString] {
                        try puzzleStore.savePuzzle(bundled)
                    } else if let fallback = fallbackPuzzle {
                        try puzzleStore.savePuzzle(fallback.withDate(dateString))
                    }
                }
                if let puzzle = try puzzleStore.loadPuzzle(dateString: dateString) {
                    loaded[dateString] = puzzle
                    if let progress = try progressStore.loadProgress(puzzleId: progressKey(for: puzzle)), progress.isComplete {
                        completedDates.insert(dateString)
                    }
                }
            }

            puzzlesByDate = loaded
            completedPuzzleDates = completedDates
            loadError = nil
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? "Failed to load puzzles"
        }
    }

    func puzzle(for date: Date) -> Puzzle? {
        puzzlesByDate[PuzzleDateFormatter.string(from: date)]
    }

    func isComplete(date: Date) -> Bool {
        guard let _ = puzzle(for: date) else {
            return false
        }
        return completedPuzzleDates.contains(PuzzleDateFormatter.string(from: date))
    }

    private func progressKey(for puzzle: Puzzle) -> String {
        "\(puzzle.id)_\(puzzle.date)"
    }
}

private final class InMemoryPuzzleStore: PuzzleStoring {
    private var storage: [String: Puzzle] = [:]

    func loadPuzzle(dateString: String) throws -> Puzzle? {
        storage[dateString]
    }

    func savePuzzle(_ puzzle: Puzzle) throws {
        storage[puzzle.date] = puzzle
    }
}

private struct InMemoryPuzzleProgressStore: PuzzleProgressStoring {
    func loadProgress(puzzleId: String) throws -> PuzzleProgress? {
        nil
    }

    func saveProgress(_ progress: PuzzleProgress) throws {
    }
}
