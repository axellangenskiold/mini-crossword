import SwiftUI

struct DailyChallengeView: View {
    @StateObject private var viewModel = DailyChallengeViewModel()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(monthTitle())
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(spacing: 8) {
                    HStack {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                                    .frame(height: 36)
                            }
                        }
                    }
                }

                if let todayPuzzle = viewModel.puzzle(for: Date()) {
                    NavigationLink {
                        PuzzleView(puzzle: todayPuzzle)
                    } label: {
                        Text("Today’s Puzzle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                } else {
                    Text("Today’s Puzzle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.3))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let error = viewModel.loadError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Daily Challenge")
            .onAppear { viewModel.load() }
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
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(backgroundColor)
            .foregroundStyle(isEnabled ? .primary : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isToday ? Color.accentColor : Color.clear, lineWidth: 1)
            )
    }

    private var backgroundColor: Color {
        if isComplete {
            return Color.green.opacity(0.7)
        }
        return Color.white
    }
}
