import SwiftUI

struct DailyChallengeView: View {
    @StateObject private var viewModel = DailyChallengeViewModel()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
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

                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("Daily Challenge")
                            .font(Theme.titleFont(size: 34))
                            .foregroundStyle(Theme.ink)
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
                                ForEach(weekdaySymbols, id: \.self) { symbol in
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
                                            destination: day.puzzle.map { PuzzleView(puzzle: $0) }
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

                    if let todayPuzzle = viewModel.puzzle(for: Date()) {
                        NavigationLink {
                            PuzzleView(puzzle: todayPuzzle)
                        } label: {
                            HStack {
                                Text("Today’s Puzzle")
                                    .font(Theme.bodyFont(size: 18))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Theme.accent, Theme.accent.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Theme.accent.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                    } else {
                        Text("Today’s Puzzle")
                            .font(Theme.bodyFont(size: 18))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.inactive)
                            .foregroundStyle(Theme.muted)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if let error = viewModel.loadError {
                        Text(error)
                            .font(Theme.bodyFont(size: 14))
                            .foregroundStyle(.red)
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .onAppear { viewModel.load() }
            .toolbar(.hidden, for: .navigationBar)
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
            let puzzle = isEnabled ? viewModel.puzzle(for: date) : nil
            return CalendarDay(
                date: date,
                dayNumber: day,
                isEnabled: isEnabled,
                isToday: isToday,
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
}

private struct CalendarDay {
    let date: Date
    let dayNumber: Int
    let isEnabled: Bool
    let isToday: Bool
    let puzzle: Puzzle?
}

private struct CalendarCell: Identifiable {
    let id = UUID()
    let day: CalendarDay?

    static let empty = CalendarCell(day: nil)
}

private struct CalendarDayCell<Destination: View>: View {
    let day: Int
    let isEnabled: Bool
    let isToday: Bool
    let isComplete: Bool
    let destination: Destination?

    var body: some View {
        Group {
            if let destination {
                NavigationLink {
                    destination
                } label: {
                    cellBody
                }
                .disabled(!isEnabled)
            } else {
                cellBody
                    .opacity(isEnabled ? 1.0 : 0.4)
            }
        }
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
                    .stroke(isToday ? Theme.accent : Color.clear, lineWidth: 1.5)
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
