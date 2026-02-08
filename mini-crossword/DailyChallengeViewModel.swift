import Foundation

final class DailyChallengeViewModel: ObservableObject {
    @Published var eligibleDates: [Date] = []
    @Published var puzzlesByDate: [String: Puzzle] = [:]
    @Published var completedPuzzleIds: Set<String> = []
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

            var loaded: [String: Puzzle] = [:]
            var completedIds: Set<String> = []

            for date in eligible {
                let dateString = PuzzleDateFormatter.string(from: date)
                let stored = try puzzleStore.loadPuzzle(dateString: dateString)
                if stored == nil, let bundled = bundleByDate[dateString] {
                    try puzzleStore.savePuzzle(bundled)
                }
                if let puzzle = try puzzleStore.loadPuzzle(dateString: dateString) {
                    loaded[dateString] = puzzle
                    if let progress = try progressStore.loadProgress(puzzleId: puzzle.id), progress.isComplete {
                        completedIds.insert(puzzle.id)
                    }
                }
            }

            puzzlesByDate = loaded
            completedPuzzleIds = completedIds
            loadError = nil
        } catch {
            loadError = "Failed to load puzzles"
        }
    }

    func puzzle(for date: Date) -> Puzzle? {
        puzzlesByDate[PuzzleDateFormatter.string(from: date)]
    }

    func isComplete(date: Date) -> Bool {
        guard let puzzle = puzzle(for: date) else {
            return false
        }
        return completedPuzzleIds.contains(puzzle.id)
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
