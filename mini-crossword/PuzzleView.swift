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
                headerControls

                PuzzleGridView(
                    width: puzzle.width,
                    height: puzzle.height,
                    blackCells: Set(puzzle.blackCells),
                    filledGrid: filledGrid,
                    activeCell: activeCell,
                    lockedCells: lockedCells
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
        }
        .navigationTitle("Puzzle")
        .alert(completionMessage, isPresented: $showCompletionAlert) {
            Button("OK") {
                if completionMessage == "Congratulations, you did it!" {
                    dismiss()
                }
            }
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

            Picker("Difficulty", selection: $difficulty) {
                ForEach(Difficulty.allCases, id: \.self) { value in
                    Text(value.rawValue.capitalized).tag(value)
                }
            }
            .pickerStyle(.menu)
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

    private func moveEntry(by offset: Int) {
        guard let state = navigationState else {
            return
        }
        let entries = entriesForPhase(state.phase)
        let nextIndex = state.entryIndex + offset
        guard entries.indices.contains(nextIndex) else {
            return
        }
        navigationState = NavigationState(phase: state.phase, entryIndex: nextIndex, cellIndex: 0)
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
}

private struct PuzzleGridView: View {
    let width: Int
    let height: Int
    let blackCells: Set<Coordinate>
    let filledGrid: [[String?]]
    let activeCell: Coordinate?
    let lockedCells: Set<Coordinate>

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: width)
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(0..<height, id: \.self) { row in
                ForEach(0..<width, id: \.self) { col in
                    let cell = Coordinate(row: row, col: col)
                    let isBlack = blackCells.contains(cell)
                    GridCellView(
                        letter: filledGrid[safe: row]?[safe: col] ?? nil,
                        isBlack: isBlack,
                        isActive: cell == activeCell,
                        isLocked: lockedCells.contains(cell)
                    )
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
        return Theme.card
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
