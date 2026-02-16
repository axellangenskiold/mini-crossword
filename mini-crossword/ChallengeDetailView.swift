import SwiftUI

struct ChallengeDetailView: View {
    let challenge: ChallengeDefinition
    @StateObject private var accessManager = AccessManager()
    @StateObject private var viewModel: ChallengeDetailViewModel
    @State private var selectedPuzzle: SelectedChallengePuzzle? = nil
    @State private var showAlreadyPlayed: Bool = false
    @State private var paywallTarget: ChallengePaywallTarget? = nil

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

            Circle()
                .fill(Theme.accent.opacity(0.14))
                .frame(width: 240, height: 240)
                .offset(x: -140, y: -260)

            RoundedRectangle(cornerRadius: 60, style: .continuous)
                .fill(Theme.accent.opacity(0.08))
                .frame(width: 220, height: 150)
                .rotationEffect(.degrees(-12))
                .offset(x: 150, y: 260)

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
                                if item.isComplete {
                                    showAlreadyPlayed = true
                                } else if item.isLocked {
                                    return
                                } else if accessManager.canAccess(puzzleKey: item.progressKey) {
                                    selectedPuzzle = SelectedChallengePuzzle(
                                        puzzle: item.puzzle,
                                        progressKey: item.progressKey,
                                        index: item.index
                                    )
                                } else {
                                    accessManager.clearError()
                                    paywallTarget = ChallengePaywallTarget(
                                        puzzle: item.puzzle,
                                        puzzleKey: item.progressKey,
                                        index: item.index
                                    )
                                }
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(item.isComplete ? Theme.complete.opacity(0.85) : Theme.card)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Theme.ink.opacity(0.12), lineWidth: 1)
                                        )
                                    if item.isLocked {
                                        Image(systemName: "lock.fill")
                                            .font(.headline)
                                            .foregroundStyle(Theme.muted)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    } else {
                                        Text("\(item.index + 1)")
                                            .font(Theme.bodyFont(size: 16))
                                            .fontWeight(.bold)
                                            .foregroundStyle(Theme.ink)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }
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
        .onChange(of: selectedPuzzle) {
            if selectedPuzzle == nil {
                viewModel.load(challenge: challenge)
            }
        }
        .onChange(of: paywallTarget) {
            if paywallTarget != nil {
                accessManager.warmUp()
                accessManager.prepareAd()
            }
        }
        .navigationDestination(item: $selectedPuzzle) { item in
            PuzzleView(puzzle: item.puzzle, progressKeyOverride: item.progressKey)
        }
        .overlay {
            if showAlreadyPlayed {
                AlreadyPlayedOverlay(onDismiss: { showAlreadyPlayed = false })
            }
            if let target = paywallTarget {
                PaywallOverlay(
                    title: "Unlock Puzzle",
                    message: "Watch an ad to unlock this puzzle permanently, or go Premium to unlock all challenges.",
                    premiumPrice: accessManager.premiumPrice,
                    isProcessing: accessManager.isProcessing,
                    errorMessage: accessManager.lastErrorMessage,
                    onWatchAd: {
                        Task {
                            let unlocked = await accessManager.unlockWithAd(puzzleKey: target.puzzleKey)
                                if unlocked {
                                    paywallTarget = nil
                                    selectedPuzzle = SelectedChallengePuzzle(
                                        puzzle: target.puzzle,
                                        progressKey: target.puzzleKey,
                                        index: target.index
                                    )
                                }
                            }
                        },
                    onGoPremium: {
                        Task {
                            let unlocked = await accessManager.purchasePremium()
                            if unlocked {
                                paywallTarget = nil
                                selectedPuzzle = SelectedChallengePuzzle(
                                    puzzle: target.puzzle,
                                    progressKey: target.puzzleKey,
                                    index: target.index
                                )
                            }
                        }
                    },
                    onRestore: {
                        Task {
                            await accessManager.restorePurchases()
                            if accessManager.isPremium {
                                paywallTarget = nil
                                selectedPuzzle = SelectedChallengePuzzle(
                                    puzzle: target.puzzle,
                                    progressKey: target.puzzleKey,
                                    index: target.index
                                )
                            }
                        }
                    },
                    onDismiss: { paywallTarget = nil }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .background(SwipeBackEnabler())
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
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
            var allPreviousComplete = true
            for index in 0..<challenge.puzzleCount {
                let key = ChallengeLogic.progressKey(challengeId: challenge.id, index: index)
                let isComplete = (try? progressStore.loadProgress(puzzleId: key))?.isComplete ?? false
                if isComplete {
                    completed += 1
                }
                let isLocked = !allPreviousComplete && !isComplete
                if !isComplete {
                    allPreviousComplete = false
                }
                items.append(
                    ChallengePuzzleItem(
                        id: key,
                        index: index,
                        puzzle: puzzle,
                        progressKey: key,
                        isComplete: isComplete,
                        isLocked: isLocked
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
    let isLocked: Bool
}

private struct SelectedChallengePuzzle: Identifiable, Hashable {
    let id = UUID()
    let puzzle: Puzzle
    let progressKey: String
    let index: Int
}

private struct ChallengePaywallTarget: Hashable, Identifiable {
    let id = UUID()
    let puzzle: Puzzle
    let puzzleKey: String
    let index: Int
}

private struct NoopChallengeProgressStore: PuzzleProgressStoring {
    func loadProgress(puzzleId: String) throws -> PuzzleProgress? {
        nil
    }

    func saveProgress(_ progress: PuzzleProgress) throws {
    }
}

private struct AlreadyPlayedOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            VStack(spacing: 12) {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .padding(6)
                            .background(Theme.card)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                Text("Already Played")
                    .font(Theme.titleFont(size: 22))
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.ink)
                Text("You have already played this puzzle.")
                    .font(Theme.bodyFont(size: 16))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.ink.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Theme.ink.opacity(0.12), radius: 18, x: 0, y: 8)
            .padding(24)
        }
    }
}
