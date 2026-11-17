import Foundation

public struct ReviewRecord: Sendable {
    public let startedAt: Date
    public let duration: TimeInterval
    public let isRest: Bool
    public let taskTitle: String?
    public let interruptionCount: Int

    public init(startedAt: Date, duration: TimeInterval, isRest: Bool, taskTitle: String?, interruptionCount: Int) {
        self.startedAt = startedAt
        self.duration = duration
        self.isRest = isRest
        self.taskTitle = taskTitle
        self.interruptionCount = interruptionCount
    }
}

public struct TaskShare: Sendable, Equatable {
    public let title: String
    public let seconds: TimeInterval
}

public struct DailyFocus: Sendable, Equatable {
    public let day: Date
    public let seconds: TimeInterval
}

public struct WeeklyReviewResult: Sendable, Equatable {
    public let totalFocusSeconds: TimeInterval
    public let pomodoros: Int
    public let interruptions: Int
    public let peakHour: Int?
    public let peakHourSeconds: TimeInterval
    public let topTasks: [TaskShare]
    public let previousWeekSeconds: TimeInterval
    public let changeRatio: Double?
    public let activeDays: Int
    public let sourceRecords: Int
    public let dailyFocus: [DailyFocus]

    public var changeText: String? {
        guard let changeRatio else { return nil }
        let percent = Int((changeRatio * 100).rounded())
        if percent == 0 { return "持平" }
        return percent > 0 ? "↑ \(percent)%" : "↓ \(abs(percent))%"
    }
}

public enum WeeklyReview {
    public static func analyze(
        records: [ReviewRecord],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WeeklyReviewResult {
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)
        let previousWeek = thisWeek.flatMap {
            calendar.dateInterval(of: .weekOfYear, for: $0.start.addingTimeInterval(-1))
        }

        let focusRecords = records.filter { !$0.isRest }
        let thisWeekRecords = focusRecords.filter { record in
            guard let thisWeek else { return false }
            return thisWeek.contains(record.startedAt)
        }
        let previousWeekRecords = focusRecords.filter { record in
            guard let previousWeek else { return false }
            return previousWeek.contains(record.startedAt)
        }

        let total = thisWeekRecords.reduce(0) { $0 + $1.duration }
        let previous = previousWeekRecords.reduce(0) { $0 + $1.duration }

        var hourBuckets: [Int: TimeInterval] = [:]
        for record in thisWeekRecords {
            let hour = calendar.component(.hour, from: record.startedAt)
            hourBuckets[hour, default: 0] += record.duration
        }
        let peak = hourBuckets.max { $0.value < $1.value }

        var taskBuckets: [String: TimeInterval] = [:]
        for record in thisWeekRecords {
            let title = record.taskTitle ?? "未关联任务"
            taskBuckets[title, default: 0] += record.duration
        }
        let topTasks = taskBuckets
            .map { TaskShare(title: $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }
            .prefix(3)

        let days = Set(thisWeekRecords.map { calendar.startOfDay(for: $0.startedAt) })

        // 本周 7 天（含 0 值），供柱状图使用
        var dayBuckets: [Date: TimeInterval] = [:]
        if let thisWeek {
            var cursor = calendar.startOfDay(for: thisWeek.start)
            let end = calendar.startOfDay(for: thisWeek.end)
            while cursor < end {
                dayBuckets[cursor] = 0
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
        }
        for record in thisWeekRecords {
            let day = calendar.startOfDay(for: record.startedAt)
            dayBuckets[day, default: 0] += record.duration
        }
        let dailyFocus = dayBuckets
            .map { DailyFocus(day: $0.key, seconds: $0.value) }
            .sorted { $0.day < $1.day }

        let ratio: Double?
        if previous > 0 {
            ratio = (total - previous) / previous
        } else {
            ratio = nil
        }

        return WeeklyReviewResult(
            totalFocusSeconds: total,
            pomodoros: thisWeekRecords.count,
            interruptions: thisWeekRecords.reduce(0) { $0 + $1.interruptionCount },
            peakHour: peak?.key,
            peakHourSeconds: peak?.value ?? 0,
            topTasks: Array(topTasks),
            previousWeekSeconds: previous,
            changeRatio: ratio,
            activeDays: days.count,
            sourceRecords: thisWeekRecords.count,
            dailyFocus: dailyFocus
        )
    }
}
