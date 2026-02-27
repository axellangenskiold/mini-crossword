import SwiftUI
import Foundation

struct ChallengeDetailView: View {
    let challenge: ChallengeDefinition
    @ObservedObject var accessManager: AccessManager
    @StateObject private var viewModel: ChallengeDetailViewModel
    @State private var selectedPuzzle: SelectedChallengePuzzle? = nil
    @State private var showAlreadyPlayed: Bool = false
    @State private var paywallTarget: ChallengePaywallTarget? = nil
    @State private var didAutoScroll: Bool = false

    @Environment(\.dismiss) private var dismiss

    init(
        challenge: ChallengeDefinition,
        accessManager: AccessManager,
        puzzleLoader: PuzzleFileLoader = PuzzleFileLoader(),
        progressStore: PuzzleProgressStoring? = nil
    ) {
        self.challenge = challenge
        self.accessManager = accessManager
        _viewModel = StateObject(
            wrappedValue: ChallengeDetailViewModel(
                puzzleLoader: puzzleLoader,
                progressStore: progressStore
            )
        )
    }

    private let scrollTopPadding: CGFloat = 60

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

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        Color.clear
                            .frame(height: 1)
                            .id("challenge_top")

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

                        ChallengeMapView(
                            items: viewModel.puzzleItems,
                            challengeId: challenge.id,
                            onSelect: handleSelection
                        )

                        if let error = viewModel.loadError {
                            Text(error)
                                .font(Theme.bodyFont(size: 14))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                    .padding(.top, scrollTopPadding)
                }
                .onChange(of: viewModel.puzzleItems.count) { _ in
                    autoScrollIfNeeded(proxy: proxy)
                }
            }

            topBar
                .padding(.top, 16)
                .padding(.leading, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }

        .task {
            accessManager.warmUp(preloadAds: false)
            accessManager.refreshUnlocks()
        }
        .onAppear {
            accessManager.refreshUnlocks()
            viewModel.load(challenge: challenge)
            Task {
                await accessManager.load()
            }
        }
        .onChange(of: selectedPuzzle) {
            if selectedPuzzle == nil {
                viewModel.load(challenge: challenge)
            }
        }
        .onChange(of: paywallTarget) {
            if paywallTarget != nil {
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
                    isAdProcessing: accessManager.isAdProcessing,
                    isPremiumProcessing: accessManager.isPurchaseProcessing,
                    isRestoreProcessing: accessManager.isRestoreProcessing,
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

    private func handleSelection(_ item: ChallengePuzzleItem) {
        if item.isComplete {
            showAlreadyPlayed = true
            return
        }
        if item.isLocked {
            return
        }
        Task {
            if accessManager.canAccess(puzzleKey: item.progressKey) {
                selectedPuzzle = SelectedChallengePuzzle(
                    puzzle: item.puzzle,
                    progressKey: item.progressKey,
                    index: item.index
                )
                return
            }
            await accessManager.load()
            if accessManager.canAccess(puzzleKey: item.progressKey) {
                selectedPuzzle = SelectedChallengePuzzle(
                    puzzle: item.puzzle,
                    progressKey: item.progressKey,
                    index: item.index
                )
                return
            }
            accessManager.clearError()
            paywallTarget = ChallengePaywallTarget(
                puzzle: item.puzzle,
                puzzleKey: item.progressKey,
                index: item.index
            )
        }
    }

    private func autoScrollIfNeeded(proxy: ScrollViewProxy) {
        guard !didAutoScroll else { return }
        let completed = viewModel.puzzleItems.filter { $0.isComplete }.count
        guard completed > 0 else { return }
        didAutoScroll = true
        DispatchQueue.main.async {
            guard let target = nextPlayableIndex() else { return }
            withAnimation(.easeInOut(duration: 0.6)) {
                proxy.scrollTo("node_\(target)_anchor", anchor: .top)
            }
        }
    }

    private func nextPlayableIndex() -> Int? {
        guard !viewModel.puzzleItems.isEmpty else { return nil }
        if let lastUnlocked = viewModel.puzzleItems.lastIndex(where: { !$0.isLocked }) {
            return lastUnlocked
        }
        return viewModel.puzzleItems.indices.first
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


private struct ChallengeMapView: View {
    let items: [ChallengePuzzleItem]
    let challengeId: String
    let onSelect: (ChallengePuzzleItem) -> Void

    @State private var filledDots: [Int: Int] = [:]
    @State private var unlockedVisualIndices: Set<Int> = []
    @State private var glowingNodes: Set<Int> = []
    @State private var lastCompletedCount: Int = 0

    private var completedCount: Int {
        items.filter { $0.isComplete }.count
    }

    private var baseUnlockedIndices: Set<Int> {
        Set(items.enumerated().compactMap { $0.element.isLocked ? nil : $0.offset })
    }

    var body: some View {
        let totalHeight = ChallengeMapLayout.totalHeight(count: items.count)
        GeometryReader { proxy in
            let layout = ChallengeMapLayout(count: items.count, width: proxy.size.width, seed: challengeId.hashValue)
            ZStack {
                ForEach(0..<max(items.count - 1, 0), id: \.self) { segmentIndex in
                    ChallengeMapSegmentView(
                        layout: layout,
                        segmentIndex: segmentIndex,
                        filledCount: filledDotsCount(for: segmentIndex)
                    )
                }

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let position = layout.nodePosition(for: index)
                    let anchorY = max(ChallengeMapLayout.topPadding, position.y - 100)
                    let isVisuallyUnlocked = unlockedVisualIndices.isEmpty ? baseUnlockedIndices.contains(index) : unlockedVisualIndices.contains(index)
                    Color.clear
                        .frame(width: 1, height: 1)
                        .position(x: position.x, y: anchorY)
                        .id("node_\(index)_anchor")
                    ChallengeMapNode(
                        index: index,
                        item: item,
                        isUnlocked: isVisuallyUnlocked,
                        isGlowing: glowingNodes.contains(index)
                    )
                    .position(position)
                    .id("node_\(index)")
                    .onTapGesture {
                        onSelect(item)
                    }
                }
            }
            .frame(width: proxy.size.width, height: totalHeight)
        }
        .frame(height: totalHeight)
        .onAppear {
            syncInitialState()
        }
        .onChange(of: items.map { $0.isComplete }) { _ in
            handleCompletionChange()
        }
        .onChange(of: items.count) { _ in
            syncInitialState()
        }
    }

    private func syncInitialState() {
        let unlocked = baseUnlockedIndices
        unlockedVisualIndices = unlocked
        filledDots = [:]
        for segmentIndex in 0..<max(completedCount, 0) {
            if segmentIndex < max(items.count - 1, 0) {
                filledDots[segmentIndex] = ChallengeMapLayout.dotCount
            }
        }
        lastCompletedCount = completedCount
    }

    private func handleCompletionChange() {
        let newCount = completedCount
        guard newCount >= 0 else { return }
        if newCount <= lastCompletedCount {
            syncInitialState()
            return
        }

        var unlocked = baseUnlockedIndices
        for segmentIndex in lastCompletedCount..<newCount {
            let nextIndex = segmentIndex + 1
            if nextIndex < items.count {
                unlocked.remove(nextIndex)
            }
        }
        unlockedVisualIndices = unlocked

        for segmentIndex in lastCompletedCount..<newCount {
            animateCompletion(for: segmentIndex)
        }
        lastCompletedCount = newCount
    }

    private func animateCompletion(for segmentIndex: Int) {
        glowNode(segmentIndex)
        guard segmentIndex < items.count - 1 else { return }
        let dotCount = ChallengeMapLayout.dotCount
        filledDots[segmentIndex] = 0
        for dotIndex in 1...dotCount {
            let delay = Double(dotIndex) * 0.05
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.12)) {
                    filledDots[segmentIndex] = dotIndex
                }
            }
        }
        let nextIndex = segmentIndex + 1
        let unlockDelay = Double(dotCount) * 0.05 + 0.2
        if nextIndex < items.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + unlockDelay) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    _ = unlockedVisualIndices.insert(nextIndex)
                }
            }
        }
    }

    private func glowNode(_ index: Int) {
        withAnimation(.easeInOut(duration: 0.4)) {
            _ = glowingNodes.insert(index)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.4)) {
                _ = glowingNodes.remove(index)
            }
        }
    }

    private func filledDotsCount(for segmentIndex: Int) -> Int {
        if let filled = filledDots[segmentIndex] {
            return filled
        }
        if segmentIndex < completedCount {
            return ChallengeMapLayout.dotCount
        }
        return 0
    }
}

private struct ChallengeMapNode: View {
    let index: Int
    let item: ChallengePuzzleItem
    let isUnlocked: Bool
    let isGlowing: Bool

    private var nodeFill: Color {
        if item.isComplete {
            return Theme.complete
        }
        return Theme.card
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(nodeFill)
                .overlay(
                    Circle()
                        .stroke(Theme.ink.opacity(0.15), lineWidth: 1)
                )
                .frame(width: ChallengeMapLayout.nodeSize, height: ChallengeMapLayout.nodeSize)
                .shadow(color: Theme.ink.opacity(0.08), radius: 8, x: 0, y: 4)
                .animation(.easeInOut(duration: 0.35), value: item.isComplete)

            if item.isComplete {
                Text("\(index + 1)")
                    .font(Theme.bodyFont(size: 16))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .transition(.opacity)
            } else if item.isLocked || !isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.muted)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("\(index + 1)")
                    .font(Theme.bodyFont(size: 16))
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.ink)
                    .transition(.scale.combined(with: .opacity))
            }

            if isGlowing {
                Circle()
                    .stroke(Theme.complete.opacity(0.7), lineWidth: 6)
                    .frame(width: ChallengeMapLayout.nodeSize + 16, height: ChallengeMapLayout.nodeSize + 16)
                    .blur(radius: 2)
                    .opacity(0.9)
                    .transition(.opacity)
            }
        }
    }
}

private struct ChallengeMapSegmentView: View {
    let layout: ChallengeMapLayout
    let segmentIndex: Int
    let filledCount: Int

    var body: some View {
        let points = layout.segmentDots(for: segmentIndex)
        ZStack {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                Circle()
                    .fill(index < filledCount ? Theme.ink : Theme.muted.opacity(0.4))
                    .frame(width: ChallengeMapLayout.dotSize, height: ChallengeMapLayout.dotSize)
                    .position(point)
            }
        }
    }
}

private struct ChallengeMapLayout {
    static let topPadding: CGFloat = 40
    static let bottomPadding: CGFloat = 70
    static let verticalSpacing: CGFloat = 120
    static let nodeSize: CGFloat = 54
    static let dotSize: CGFloat = 6
    static let dotCount: Int = 14

    let count: Int
    let width: CGFloat
    let seed: Int

    static func totalHeight(count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return topPadding + bottomPadding + CGFloat(count - 1) * verticalSpacing
    }

    func nodePosition(for index: Int) -> CGPoint {
        let baseX = width / 2
        let offset = xOffset(for: index)
        let y = Self.topPadding + CGFloat(index) * Self.verticalSpacing
        return CGPoint(x: baseX + offset, y: y)
    }

    func segmentDots(for segmentIndex: Int) -> [CGPoint] {
        guard segmentIndex + 1 < count else { return [] }
        let start = nodePosition(for: segmentIndex)
        let end = nodePosition(for: segmentIndex + 1)
        let control = controlPoint(from: start, to: end, index: segmentIndex)
        return (0..<Self.dotCount).map { step in
            let t = (Double(step) + 1) / Double(Self.dotCount + 1)
            return quadraticPoint(t: t, start: start, control: control, end: end)
        }
    }

    private func xOffset(for index: Int) -> CGFloat {
        let amplitude = min(120, width * 0.25)
        let phase = Double(seed % 97) * 0.1
        let value = sin(Double(index) * 1.2 + phase)
        return CGFloat(value) * amplitude
    }

    private func controlPoint(from start: CGPoint, to end: CGPoint, index: Int) -> CGPoint {
        let midX = (start.x + end.x) / 2
        let midY = (start.y + end.y) / 2
        let curve = CGFloat(cos(Double(index) * 0.8 + Double(seed % 31))) * 40
        return CGPoint(x: midX + curve, y: midY)
    }

    private func quadraticPoint(t: Double, start: CGPoint, control: CGPoint, end: CGPoint) -> CGPoint {
        let t1 = 1 - t
        let x = t1 * t1 * Double(start.x) + 2 * t1 * t * Double(control.x) + t * t * Double(end.x)
        let y = t1 * t1 * Double(start.y) + 2 * t1 * t * Double(control.y) + t * t * Double(end.y)
        return CGPoint(x: x, y: y)
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
            let puzzleFiles = challenge.puzzleFiles ?? [challenge.puzzleFile]
            let puzzleFolder = challenge.puzzleFolder
            var puzzleCache: [String: Puzzle] = [:]
            let fallbackPuzzle = try? puzzleLoader.loadFallbackPuzzle()

            func loadPuzzle(named fileName: String) throws -> Puzzle {
                if let cached = puzzleCache[fileName] {
                    return cached
                }
                let puzzle: Puzzle
                if let folder = puzzleFolder, !folder.isEmpty {
                    let subdirectory = "Challenges/\(folder)"
                    puzzle = try puzzleLoader.loadPuzzle(named: fileName, subdirectory: subdirectory)
                } else {
                    puzzle = try puzzleLoader.loadPuzzle(named: fileName)
                }
                puzzleCache[fileName] = puzzle
                return puzzle
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

                let fileName = index < puzzleFiles.count ? puzzleFiles[index] : (puzzleFiles.last ?? challenge.puzzleFile)
                let puzzle: Puzzle
                do {
                    puzzle = try loadPuzzle(named: fileName)
                } catch {
                    if let fallbackPuzzle {
                        puzzle = fallbackPuzzle
                    } else {
                        throw error
                    }
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
