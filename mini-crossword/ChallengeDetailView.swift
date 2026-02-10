import SwiftUI

struct ChallengeDetailView: View {
    let challenge: ChallengeDefinition
    @StateObject private var viewModel: ChallengeDetailViewModel
    @State private var selectedPuzzle: SelectedChallengePuzzle? = nil

    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    init(
        challenge: ChallengeDefinition,
        puzzleLoader: PuzzleFileLoader = PuzzleFileLoader(),
        progressStore: PuzzleProgressStoring? = nil
    ) {
        self.challenge = challenge
        _viewModel = StateObject(
            wrappedValue: ChallengeDetailViewModel(
                puzzleLoader: puzzleLoader,
                progressStore: progressStore
            )
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.backgroundTop, Theme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    topBar

                    VStack(alignment: .leading, spacing: 8) {
                        Text(challenge.name)
                            .font(Theme.titleFont(size: 28))
                            .foregroundStyle(Theme.ink)
                            .fontWeight(.bold)
                        HStack(spacing: 8) {
                            Text("\(viewModel.completedCount)/\(challenge.puzzleCount) complete")
                                .font(Theme.bodyFont(size: 14))
                                .foregroundStyle(Theme.muted)
                            if viewModel.isComplete {
                                Text("Complete")
                                    .font(Theme.bodyFont(size: 12))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Theme.complete)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(viewModel.puzzleItems) { item in
                            Button {
                                selectedPuzzle = SelectedChallengePuzzle(
                                    puzzle: item.puzzle,
                                    progressKey: item.progressKey,
                                    index: item.index
                                )
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(item.isComplete ? Theme.complete.opacity(0.85) : Theme.card)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Theme.ink.opacity(0.12), lineWidth: 1)
                                        )
                                    Text("\(item.index + 1)")
                                        .font(Theme.bodyFont(size: 16))
                                        .foregroundStyle(Theme.ink)
                                    if item.isComplete {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.white)
                                            .padding(6)
                                    }
                                }
                                .frame(height: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let error = viewModel.loadError {
                        Text(error)
                            .font(Theme.bodyFont(size: 14))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
        }
        .onAppear { viewModel.load(challenge: challenge) }
        .onChange(of: selectedPuzzle) { value in
            if value == nil {
                viewModel.load(challenge: challenge)
            }
        }
        .navigationDestination(item: $selectedPuzzle) { item in
            PuzzleView(puzzle: item.puzzle, progressKeyOverride: item.progressKey)
        }
        .navigationBarBackButtonHidden(true)
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .padding(8)
                    .background(Theme.card)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.ink.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

private final class ChallengeDetailViewModel: ObservableObject {
    @Published var puzzleItems: [ChallengePuzzleItem] = []
    @Published var completedCount: Int = 0
    @Published var isComplete: Bool = false
    @Published var loadError: String? = nil

    private let puzzleLoader: PuzzleFileLoader
    private let progressStore: PuzzleProgressStoring

    init(
        puzzleLoader: PuzzleFileLoader = PuzzleFileLoader(),
        progressStore: PuzzleProgressStoring? = nil
    ) {
        self.puzzleLoader = puzzleLoader
        if let progressStore {
            self.progressStore = progressStore
        } else {
            self.progressStore = (try? FilePuzzleProgressStore()) ?? NoopChallengeProgressStore()
        }
    }

    func load(challenge: ChallengeDefinition) {
        do {
            let puzzle: Puzzle
            do {
                puzzle = try puzzleLoader.loadPuzzle(named: challenge.puzzleFile)
            } catch {
                puzzle = try puzzleLoader.loadFallbackPuzzle()
            }

            var items: [ChallengePuzzleItem] = []
            var completed = 0
            for index in 0..<challenge.puzzleCount {
                let key = ChallengeLogic.progressKey(challengeId: challenge.id, index: index)
                let isComplete = (try? progressStore.loadProgress(puzzleId: key))?.isComplete ?? false
                if isComplete {
                    completed += 1
                }
                items.append(
                    ChallengePuzzleItem(
                        id: key,
                        index: index,
                        puzzle: puzzle,
                        progressKey: key,
                        isComplete: isComplete
                    )
                )
            }
            puzzleItems = items
            completedCount = completed
            isComplete = ChallengeLogic.isComplete(completedCount: completed, totalCount: challenge.puzzleCount)
            loadError = nil
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? "Failed to load challenge"
        }
    }
}

private struct ChallengePuzzleItem: Identifiable {
    let id: String
    let index: Int
    let puzzle: Puzzle
    let progressKey: String
    let isComplete: Bool
}

private struct SelectedChallengePuzzle: Identifiable, Hashable {
    let id = UUID()
    let puzzle: Puzzle
    let progressKey: String
    let index: Int
}

private struct NoopChallengeProgressStore: PuzzleProgressStoring {
    func loadProgress(puzzleId: String) throws -> PuzzleProgress? {
        nil
    }

    func saveProgress(_ progress: PuzzleProgress) throws {
    }
}
