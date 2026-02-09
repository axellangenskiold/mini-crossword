import SwiftUI

struct PuzzleView: View {
    let puzzle: Puzzle
    @State private var filledGrid: [[String?]]
    @State private var navigationState: NavigationState?
    @State private var difficulty: Difficulty = .easy
    @State private var lockedCells: Set<Coordinate> = []
    @State private var hintsUsed: Int = 0
    @State private var showCompletionAlert: Bool = false
    @State private var completionMessage: String = ""
    @State private var completionIsCorrect: Bool = false

    @Environment(\.dismiss) private var dismiss

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        let empty = PuzzleView.makeEmptyGrid(width: puzzle.width, height: puzzle.height)
        _filledGrid = State(initialValue: empty)
        let blackCells = Set(puzzle.blackCells)
        let initial = NavigationLogic.initialState(
            acrossEntries: puzzle.entries.across,
            downEntries: puzzle.entries.down,
            width: puzzle.width,
            height: puzzle.height,
            blackCells: blackCells
        )
        _navigationState = State(initialValue: initial)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.backgroundTop, Theme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                topBar

                headerControls

                PuzzleGridView(
                    width: puzzle.width,
                    height: puzzle.height,
                    blackCells: Set(puzzle.blackCells),
                    filledGrid: filledGrid,
                    activeCell: activeCell,
                    lockedCells: lockedCells,
                    highlightedCells: highlightedCells,
                    onSelect: { cell in
                        selectCell(cell)
                    }
                )
                .padding(12)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Theme.ink.opacity(0.08), radius: 10, x: 0, y: 6)

                clueBar

                keyboard

                Spacer()
            }
            .padding()

            if showCompletionAlert {
                CompletionOverlay(
                    message: completionMessage,
                    isCorrect: completionIsCorrect,
                    onDismiss: {
                        showCompletionAlert = false
                        if completionIsCorrect {
                            dismiss()
                        }
                    }
                )
            }
        }
        .navigationTitle("Puzzle")
        .toolbar(.hidden, for: .navigationBar)
        .font(Theme.bodyFont(size: 16))
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .padding(8)
                    .background(Theme.card)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.ink.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("Crossword")
                    .font(Theme.titleFont(size: 22))
                    .fontWeight(.bold)
                Text(puzzle.date)
                    .font(Theme.bodyFont(size: 13))
                    .foregroundStyle(Theme.muted)
            }

            Spacer()
        }
    }

    private var headerControls: some View {
        HStack {
            Spacer()
            Button("Hint") {
                applyHint()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(!canUseHint)

            Menu {
                ForEach(Difficulty.allCases, id: \.self) { value in
                    Button(value.rawValue.capitalized) {
                        difficulty = value
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(difficulty.rawValue.capitalized)
                        .font(Theme.bodyFont(size: 15))
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Theme.ink.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    private var clueBar: some View {
        HStack(spacing: 12) {
            Button(action: { moveEntry(by: -1) }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)

            Text(currentClue)
                .font(Theme.bodyFont(size: 16))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { moveEntry(by: 1) }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
        }
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var keyboard: some View {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(letters, id: \.self) { letter in
                Button(String(letter)) {
                    enter(letter: String(letter))
                }
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .background(Theme.card)
                .foregroundStyle(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            Button {
                backspace()
            } label: {
                Image(systemName: "delete.left")
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(Theme.card)
            .foregroundStyle(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(12)
        .background(Theme.ink.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var activeCell: Coordinate? {
        guard let state = navigationState else {
            return nil
        }
        return NavigationLogic.cellForState(state, acrossEntries: puzzle.entries.across, downEntries: puzzle.entries.down)
    }

    private var currentClue: String {
        guard let state = navigationState else {
            return ""
        }
        let entries = entriesForPhase(state.phase)
        guard let entry = entries[safe: state.entryIndex] else {
            return ""
        }
        return entry.clue
    }

    private var highlightedCells: Set<Coordinate> {
        guard let state = navigationState else {
            return []
        }
        let entries = entriesForPhase(state.phase)
        guard let entry = entries[safe: state.entryIndex] else {
            return []
        }
        return Set(entry.cells)
    }

    private func moveEntry(by offset: Int) {
        guard let state = navigationState else {
            return
        }
        var phase = state.phase
        var entries = entriesForPhase(phase)
        var nextIndex = state.entryIndex + offset

        if nextIndex < 0 {
            if phase == .down {
                phase = .across
                entries = entriesForPhase(phase)
                nextIndex = entries.count - 1
            } else {
                return
            }
        } else if nextIndex >= entries.count {
            if phase == .across {
                phase = .down
                entries = entriesForPhase(phase)
                nextIndex = 0
            } else {
                return
            }
        }

        guard let entry = entries[safe: nextIndex] else {
            return
        }
        let focusIndex = focusIndexForEntry(entry)
        navigationState = NavigationState(phase: phase, entryIndex: nextIndex, cellIndex: focusIndex)
    }

    private func enter(letter: String) {
        guard let cell = nextEditableCell(from: navigationState) else {
            return
        }
        filledGrid[cell.row][cell.col] = letter
        if let state = navigationState {
            handleEntryCompletion(for: state)
            navigationState = advanceStateSkippingLocked(from: state)
        }
        handlePuzzleCompletion()
    }

    private func backspace() {
        guard let cell = activeCell else {
            return
        }
        if lockedCells.contains(cell) {
            navigationState = advanceStateSkippingLocked(from: navigationState)
            return
        }
        if filledGrid[cell.row][cell.col] != nil {
            filledGrid[cell.row][cell.col] = nil
        }
    }

    private func applyHint() {
        guard canUseHint else {
            return
        }
        guard let state = navigationState else {
            return
        }
        guard let targetState = hintTargetState(from: state) else {
            return
        }
        guard let targetCell = NavigationLogic.cellForState(
            targetState,
            acrossEntries: puzzle.entries.across,
            downEntries: puzzle.entries.down
        ) else {
            return
        }
        if let solution = puzzle.gridSolution[safe: targetCell.row]?[safe: targetCell.col] {
            filledGrid[targetCell.row][targetCell.col] = solution
            hintsUsed += 1
            lockedCells.insert(targetCell)
            if difficulty != .hard {
                handleEntryCompletion(for: targetState)
            }
            navigationState = advanceStateSkippingLocked(from: targetState)
            handlePuzzleCompletion()
        }
    }

    private func entriesForPhase(_ phase: NavigationPhase) -> [Entry] {
        switch phase {
        case .across:
            return NavigationLogic.orderedEntries(puzzle.entries.across)
        case .down:
            return NavigationLogic.orderedEntries(puzzle.entries.down)
        }
    }

    private static func makeEmptyGrid(width: Int, height: Int) -> [[String?]] {
        Array(repeating: Array(repeating: nil, count: width), count: height)
    }

    private var canUseHint: Bool {
        switch difficulty {
        case .easy:
            return true
        case .medium, .hard:
            return hintsUsed < 2
        }
    }

    private func hintTargetState(from state: NavigationState) -> NavigationState? {
        let blackCells = Set(puzzle.blackCells)
        guard let target = NavigationLogic.hintTarget(
            state: state,
            acrossEntries: puzzle.entries.across,
            downEntries: puzzle.entries.down,
            lockedCells: lockedCells,
            width: puzzle.width,
            height: puzzle.height,
            blackCells: blackCells
        ) else {
            return nil
        }

        var probe: NavigationState? = state
        while let current = probe {
            if NavigationLogic.cellForState(
                current,
                acrossEntries: puzzle.entries.across,
                downEntries: puzzle.entries.down
            ) == target {
                return current
            }
            probe = NavigationLogic.advanceState(
                current,
                acrossEntries: puzzle.entries.across,
                downEntries: puzzle.entries.down,
                width: puzzle.width,
                height: puzzle.height,
                blackCells: blackCells
            )
        }
        return nil
    }

    private func handleEntryCompletion(for state: NavigationState) {
        guard difficulty != .hard else {
            return
        }
        let entries = entriesForPhase(state.phase)
        guard let entry = entries[safe: state.entryIndex] else {
            return
        }
        if ValidationLogic.isEntryComplete(entry, filledGrid: filledGrid) &&
            ValidationLogic.isEntryCorrect(entry, filledGrid: filledGrid, solutionGrid: puzzle.gridSolution) {
            lockedCells.formUnion(entry.cells)
        }
    }

    private func handlePuzzleCompletion() {
        let blackCells = Set(puzzle.blackCells)
        if ValidationLogic.isPuzzleComplete(
            width: puzzle.width,
            height: puzzle.height,
            blackCells: blackCells,
            filledGrid: filledGrid
        ) {
            let isCorrect = ValidationLogic.isPuzzleCorrect(
                width: puzzle.width,
                height: puzzle.height,
                blackCells: blackCells,
                filledGrid: filledGrid,
                solutionGrid: puzzle.gridSolution
            )
            completionIsCorrect = isCorrect
            completionMessage = isCorrect ? "Congratulations, you did it!" : "Something is wrong."
            showCompletionAlert = true
        }
    }

    private func advanceStateSkippingLocked(from state: NavigationState?) -> NavigationState? {
        guard var current = state else {
            return nil
        }
        while true {
            guard let next = NavigationLogic.advanceState(
                current,
                acrossEntries: puzzle.entries.across,
                downEntries: puzzle.entries.down,
                width: puzzle.width,
                height: puzzle.height,
                blackCells: Set(puzzle.blackCells)
            ) else {
                return nil
            }
            current = next
            if let cell = NavigationLogic.cellForState(
                current,
                acrossEntries: puzzle.entries.across,
                downEntries: puzzle.entries.down
            ), !lockedCells.contains(cell) {
                return current
            }
        }
    }

    private func nextEditableCell(from state: NavigationState?) -> Coordinate? {
        guard let state else {
            return nil
        }
        guard let cell = NavigationLogic.cellForState(
            state,
            acrossEntries: puzzle.entries.across,
            downEntries: puzzle.entries.down
        ) else {
            return nil
        }
        if !lockedCells.contains(cell) {
            return cell
        }
        guard let nextState = advanceStateSkippingLocked(from: state) else {
            return nil
        }
        navigationState = nextState
        return NavigationLogic.cellForState(
            nextState,
            acrossEntries: puzzle.entries.across,
            downEntries: puzzle.entries.down
        )
    }

    private func selectCell(_ cell: Coordinate) {
        let acrossEntries = entriesForPhase(.across)
        let downEntries = entriesForPhase(.down)
        if let acrossIndex = entryIndex(for: cell, entries: acrossEntries) {
            if navigationState?.phase == .across {
                navigationState = NavigationState(phase: .across, entryIndex: acrossIndex, cellIndex: cellIndex(for: cell, entries: acrossEntries) ?? 0)
                return
            }
        }
        if let downIndex = entryIndex(for: cell, entries: downEntries) {
            navigationState = NavigationState(phase: .down, entryIndex: downIndex, cellIndex: cellIndex(for: cell, entries: downEntries) ?? 0)
            return
        }
        if let acrossIndex = entryIndex(for: cell, entries: acrossEntries) {
            navigationState = NavigationState(phase: .across, entryIndex: acrossIndex, cellIndex: cellIndex(for: cell, entries: acrossEntries) ?? 0)
        }
    }

    private func entryIndex(for cell: Coordinate, entries: [Entry]) -> Int? {
        entries.firstIndex { $0.cells.contains(cell) }
    }

    private func cellIndex(for cell: Coordinate, entries: [Entry]) -> Int? {
        for entry in entries {
            if let index = entry.cells.firstIndex(of: cell) {
                return index
            }
        }
        return nil
    }

    private func focusIndexForEntry(_ entry: Entry) -> Int {
        var lastFilled: Int? = nil
        for (index, cell) in entry.cells.enumerated() {
            if let letter = filledGrid[safe: cell.row]?[safe: cell.col],
               let value = letter,
               !value.isEmpty {
                lastFilled = index
            }
        }
        if let lastFilled {
            return min(lastFilled + 1, entry.cells.count - 1)
        }
        return 0
    }
}

private struct PuzzleGridView: View {
    let width: Int
    let height: Int
    let blackCells: Set<Coordinate>
    let filledGrid: [[String?]]
    let activeCell: Coordinate?
    let lockedCells: Set<Coordinate>
    let highlightedCells: Set<Coordinate>
    let onSelect: (Coordinate) -> Void

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: width)
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(0..<(width * height), id: \.self) { index in
                let row = index / width
                let col = index % width
                let cell = Coordinate(row: row, col: col)
                let isBlack = blackCells.contains(cell)
                GridCellView(
                    letter: filledGrid[safe: row]?[safe: col] ?? nil,
                    isBlack: isBlack,
                    isActive: cell == activeCell,
                    isLocked: lockedCells.contains(cell),
                    isHighlighted: highlightedCells.contains(cell)
                )
                .onTapGesture {
                    if !isBlack {
                        onSelect(cell)
                    }
                }
            }
        }
    }
}

private struct GridCellView: View {
    let letter: String?
    let isBlack: Bool
    let isActive: Bool
    let isLocked: Bool
    let isHighlighted: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(backgroundColor)
                .overlay(
                    Rectangle()
                        .stroke(isActive ? Theme.accent : Theme.ink.opacity(0.2), lineWidth: isActive ? 2 : 1)
                )
            if let letter, !isBlack {
                Text(letter)
                    .font(Theme.bodyFont(size: 18))
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.ink)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var backgroundColor: Color {
        if isBlack {
            return Theme.ink
        }
        if isLocked {
            return Theme.complete.opacity(0.85)
        }
        if isHighlighted {
            return Theme.highlight
        }
        return Theme.card
    }
}

private struct CompletionOverlay: View {
    let message: String
    let isCorrect: Bool
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Text(isCorrect ? "Solved" : "Try Again")
                    .font(Theme.titleFont(size: 24))
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.ink)
                Text(message)
                    .font(Theme.bodyFont(size: 16))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                Button(action: onDismiss) {
                    Text("OK")
                        .font(Theme.bodyFont(size: 16))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }
        return self[index]
    }
}
