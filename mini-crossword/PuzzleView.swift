import SwiftUI

struct PuzzleView: View {
    let puzzle: Puzzle
    @State private var filledGrid: [[String?]]
    @State private var navigationState: NavigationState?
    @State private var difficulty: Difficulty = .easy

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
        VStack(spacing: 16) {
            headerControls

            PuzzleGridView(
                width: puzzle.width,
                height: puzzle.height,
                blackCells: Set(puzzle.blackCells),
                filledGrid: filledGrid,
                activeCell: activeCell
            )

            clueBar

            keyboard

            Spacer()
        }
        .padding()
        .navigationTitle("Puzzle")
    }

    private var headerControls: some View {
        HStack {
            Spacer()
            Button("Hint") {
            }
            .buttonStyle(.bordered)

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

            Text(currentClue)
                .font(.subheadline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { moveEntry(by: 1) }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.bordered)
        }
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
                .background(Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            Button {
                backspace()
            } label: {
                Image(systemName: "delete.left")
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
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
        guard let cell = activeCell else {
            return
        }
        filledGrid[cell.row][cell.col] = letter
        if let state = navigationState {
            navigationState = NavigationLogic.advanceState(
                state,
                acrossEntries: puzzle.entries.across,
                downEntries: puzzle.entries.down,
                width: puzzle.width,
                height: puzzle.height,
                blackCells: Set(puzzle.blackCells)
            )
        }
    }

    private func backspace() {
        guard let cell = activeCell else {
            return
        }
        if filledGrid[cell.row][cell.col] != nil {
            filledGrid[cell.row][cell.col] = nil
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
}

private struct PuzzleGridView: View {
    let width: Int
    let height: Int
    let blackCells: Set<Coordinate>
    let filledGrid: [[String?]]
    let activeCell: Coordinate?

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
                        isActive: cell == activeCell
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

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isBlack ? Color.black : Color.white)
                .overlay(
                    Rectangle()
                        .stroke(isActive ? Color.accentColor : Color.gray.opacity(0.4), lineWidth: isActive ? 2 : 1)
                )
            if let letter, !isBlack {
                Text(letter)
                    .font(.headline)
            }
        }
        .aspectRatio(1, contentMode: .fit)
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
