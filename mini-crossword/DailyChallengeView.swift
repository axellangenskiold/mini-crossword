import SwiftUI

struct DailyChallengeView: View {
    @StateObject private var viewModel = DailyChallengeViewModel()
    @StateObject private var challengeViewModel = ChallengeListViewModel()
    @State private var selectedPuzzle: SelectedPuzzle? = nil
    @State private var selectedChallenge: SelectedChallenge? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let challengeColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Theme.backgroundTop, Theme.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 260, height: 260)
                    .offset(x: 120, y: -220)

                RoundedRectangle(cornerRadius: 60, style: .continuous)
                    .fill(Theme.accent.opacity(0.08))
                    .frame(width: 220, height: 160)
                    .rotationEffect(.degrees(-18))
                    .offset(x: -140, y: 260)

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 6) {
                            Text("Daily Challenge")
                                .font(Theme.titleFont(size: 34))
                                .foregroundStyle(Theme.ink)
                                .fontWeight(.bold)
                            Text("Mini Crossword")
                                .font(Theme.bodyFont(size: 16))
                                .foregroundStyle(Theme.muted)
                                .textCase(.uppercase)
                                .tracking(2)
                        }

                        VStack(spacing: 12) {
                            Text(monthTitle())
                                .font(Theme.bodyFont(size: 20))
                                .foregroundStyle(Theme.ink)

                            VStack(spacing: 10) {
                                HStack {
                                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                                        Text(symbol)
                                            .font(Theme.bodyFont(size: 12))
                                            .foregroundStyle(Theme.muted)
                                            .frame(maxWidth: .infinity)
                                    }
                                }

                                LazyVGrid(columns: columns, spacing: 8) {
                                    ForEach(calendarCells(), id: \.id) { cell in
                                        if let day = cell.day {
                                            let isComplete = viewModel.isComplete(date: day.date)
                                            CalendarDayCell(
                                                day: day.dayNumber,
                                                isEnabled: day.isEnabled,
                                                isToday: day.isToday,
                                                isComplete: isComplete,
                                                isSelected: day.isSelected,
                                                onSelect: { viewModel.selectedDate = day.date }
                                            )
                                        } else {
                                            Color.clear
                                                .frame(height: 34)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
                            )
                            .shadow(color: Theme.ink.opacity(0.08), radius: 14, x: 0, y: 8)
                        }

                        Button(action: openSelectedPuzzle) {
                            HStack {
                                if isSelectedComplete {
                                    Text("Puzzle complete")
                                        .font(Theme.bodyFont(size: 18))
                                        .foregroundStyle(Theme.ink)
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.complete)
                                } else {
                                    Text("Play crossword")
                                        .font(Theme.bodyFont(size: 18))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(buttonBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Theme.accent.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        .disabled(viewModel.puzzle(for: viewModel.selectedDate) == nil || isSelectedComplete)
                        .opacity((viewModel.puzzle(for: viewModel.selectedDate) == nil || isSelectedComplete) ? 0.6 : 1.0)

                        if let error = viewModel.loadError {
                            Text(error)
                                .font(Theme.bodyFont(size: 14))
                                .foregroundStyle(.red)
                        }

                        challengeSection

                        if let error = challengeViewModel.loadError {
                            Text(error)
                                .font(Theme.bodyFont(size: 14))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
            .onAppear {
                viewModel.load()
                challengeViewModel.load()
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedPuzzle) { item in
                PuzzleView(puzzle: item.puzzle)
            }
            .navigationDestination(item: $selectedChallenge) { item in
                ChallengeDetailView(challenge: item.challenge)
            }
            .onChange(of: selectedPuzzle) { value in
                if value == nil {
                    viewModel.load()
                }
            }
            .onChange(of: selectedChallenge) { value in
                if value == nil {
                    challengeViewModel.load()
                }
            }
        }
        .font(Theme.bodyFont(size: 16))
    }

    private var isSelectedComplete: Bool {
        viewModel.isComplete(date: viewModel.selectedDate)
    }

    private var buttonBackground: some View {
        Group {
            if isSelectedComplete {
                Theme.complete.opacity(0.3)
            } else {
                LinearGradient(
                    colors: [Theme.accent, Theme.accent.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }

    private func monthTitle() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: Date())
    }

    private func calendarCells() -> [CalendarCell] {
        let calendar = Calendar.current
        let today = Date()
        let components = calendar.dateComponents([.year, .month], from: today)
        guard let firstOfMonth = calendar.date(from: components) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: firstOfMonth) - 1
        let range = calendar.range(of: .day, in: .month, for: today) ?? 1..<1
        let todayDay = calendar.component(.day, from: today)
        let days = range.map { day -> CalendarDay in
            let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) ?? today
            let isToday = day == todayDay
            let isEnabled = day <= todayDay
            let isSelected = calendar.isDate(date, inSameDayAs: viewModel.selectedDate)
            let puzzle = isEnabled ? viewModel.puzzle(for: date) : nil
            return CalendarDay(
                date: date,
                dayNumber: day,
                isEnabled: isEnabled,
                isToday: isToday,
                isSelected: isSelected,
                puzzle: puzzle
            )
        }

        var cells: [CalendarCell] = []
        if weekday > 0 {
            cells.append(contentsOf: Array(repeating: CalendarCell.empty, count: weekday))
        }
        cells.append(contentsOf: days.map { CalendarCell(day: $0) })
        return cells
    }

    private var challengeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Challenges")
                    .font(Theme.titleFont(size: 24))
                    .foregroundStyle(Theme.ink)
                    .fontWeight(.bold)
                Spacer()
            }

            LazyVGrid(columns: challengeColumns, spacing: 12) {
                ForEach(challengeViewModel.challenges, id: \.id) { challenge in
                    Button {
                        selectedChallenge = SelectedChallenge(challenge: ChallengeDefinition(
                            id: challenge.id,
                            name: challenge.name,
                            puzzleFile: challenge.puzzleFile,
                            puzzleCount: challenge.puzzleCount
                        ))
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(challenge.name)
                                .font(Theme.bodyFont(size: 18))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                            Spacer()
                            HStack {
                                Text("\(challenge.completedCount)/\(challenge.puzzleCount)")
                                    .font(Theme.bodyFont(size: 14))
                                    .foregroundStyle(Theme.muted)
                                Spacer()
                                if challenge.isComplete {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(Theme.complete)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                        .background(challengeBackground(isComplete: challenge.isComplete))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: Theme.ink.opacity(0.08), radius: 10, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 6)
    }

    private func challengeBackground(isComplete: Bool) -> some View {
        Group {
            if isComplete {
                Theme.complete.opacity(0.25)
            } else {
                Theme.card
            }
        }
    }
}

private struct CalendarDay {
    let date: Date
    let dayNumber: Int
    let isEnabled: Bool
    let isToday: Bool
    let isSelected: Bool
    let puzzle: Puzzle?
}

private struct CalendarCell: Identifiable {
    let id = UUID()
    let day: CalendarDay?

    static let empty = CalendarCell(day: nil)
}

private struct CalendarDayCell: View {
    let day: Int
    let isEnabled: Bool
    let isToday: Bool
    let isComplete: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            cellBody
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var cellBody: some View {
        Text("\(day)")
            .font(Theme.bodyFont(size: 14))
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(backgroundColor)
            .foregroundStyle(isEnabled ? Theme.ink : Theme.muted)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Theme.accent : (isToday ? Theme.accent.opacity(0.5) : Color.clear), lineWidth: isSelected ? 2 : 1.5)
            )
            .opacity(isEnabled ? 1.0 : 0.5)
    }

    private var backgroundColor: Color {
        if !isEnabled {
            return Theme.inactive.opacity(0.6)
        }
        if isComplete {
            return Theme.complete.opacity(0.8)
        }
        return Theme.card
    }
}

private struct SelectedPuzzle: Identifiable, Hashable {
    let id = UUID()
    let puzzle: Puzzle
}

private struct SelectedChallenge: Identifiable, Hashable {
    let id = UUID()
    let challenge: ChallengeDefinition
}

private extension DailyChallengeView {
    func openSelectedPuzzle() {
        guard let puzzle = viewModel.puzzle(for: viewModel.selectedDate) else {
            return
        }
        if viewModel.isComplete(date: viewModel.selectedDate) {
            return
        }
        selectedPuzzle = SelectedPuzzle(puzzle: puzzle)
    }
}
