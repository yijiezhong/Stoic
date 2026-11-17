import Foundation

/// 连续专注天数。今天还没开始时从昨天算，避免早上打开就显示 0。
public enum StreakCalculator {
    public static func streak(
        daysWithFocus: [Date],
        asOf today: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let daySet = Set(daysWithFocus.map { calendar.startOfDay(for: $0) })
        guard !daySet.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: today)
        if !daySet.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var count = 0
        while daySet.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}
