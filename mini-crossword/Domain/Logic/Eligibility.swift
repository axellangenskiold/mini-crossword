import Foundation

enum Eligibility {
    static func eligibleDates(today: Date, calendar: Calendar = .current) -> [Date] {
        let components = calendar.dateComponents([.year, .month], from: today)
        guard let startOfMonth = calendar.date(from: components) else {
            return []
        }
        let todayDay = calendar.component(.day, from: today)
        return (1...todayDay).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset - 1, to: startOfMonth)
        }
    }

    static func isEligible(date: Date, today: Date, calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.year, .month], from: today)
        guard let startOfMonth = calendar.date(from: components) else {
            return false
        }
        return date >= startOfMonth && date <= today
    }
}
