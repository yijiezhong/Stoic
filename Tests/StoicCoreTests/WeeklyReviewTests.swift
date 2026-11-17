import XCTest
@testable import StoicCore

final class WeeklyReviewTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }()

    /// 固定一个周三作为「本周」参照点
    private var now: Date {
        DateComponents(calendar: calendar, year: 2026, month: 3, day: 11, hour: 18).date!
    }

    private func record(dayOffset: Int, hour: Int, minutes: Int, task: String?, interruptions: Int = 0) -> ReviewRecord {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: now)!
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        return ReviewRecord(
            startedAt: date,
            duration: TimeInterval(minutes * 60),
            isRest: false,
            taskTitle: task,
            interruptionCount: interruptions
        )
    }

    func testTotalsAndActiveDays() {
        let records = [
            record(dayOffset: 0, hour: 9, minutes: 25, task: "写作"),
            record(dayOffset: -1, hour: 10, minutes: 50, task: "写作"),
            record(dayOffset: -2, hour: 14, minutes: 25, task: "复习"),
        ]
        let result = WeeklyReview.analyze(records: records, now: now, calendar: calendar)

        XCTAssertEqual(result.pomodoros, 3)
        XCTAssertEqual(result.totalFocusSeconds, 100 * 60, accuracy: 0.001)
        XCTAssertEqual(result.activeDays, 3)
        XCTAssertEqual(result.sourceRecords, 3)
    }

    func testPeakHour() {
        let records = [
            record(dayOffset: 0, hour: 9, minutes: 25, task: "写作"),
            record(dayOffset: -1, hour: 9, minutes: 50, task: "写作"),
            record(dayOffset: -2, hour: 15, minutes: 25, task: "复习"),
        ]
        let result = WeeklyReview.analyze(records: records, now: now, calendar: calendar)
        XCTAssertEqual(result.peakHour, 9)
        XCTAssertEqual(result.peakHourSeconds, 75 * 60, accuracy: 0.001)
    }

    func testTopTasksOrdering() throws {
        let records = [
            record(dayOffset: 0, hour: 9, minutes: 25, task: "写作"),
            record(dayOffset: -1, hour: 9, minutes: 25, task: "复习"),
            record(dayOffset: -2, hour: 9, minutes: 25, task: "复习"),
        ]
        let result = WeeklyReview.analyze(records: records, now: now, calendar: calendar)
        let top = try XCTUnwrap(result.topTasks.first)
        XCTAssertEqual(top.title, "复习")
        XCTAssertEqual(top.seconds, 50 * 60, accuracy: 0.001)
    }

    func testPreviousWeekComparison() {
        let records = [
            record(dayOffset: 0, hour: 9, minutes: 50, task: "写作"),
            record(dayOffset: -7, hour: 9, minutes: 25, task: "写作"),
        ]
        let result = WeeklyReview.analyze(records: records, now: now, calendar: calendar)
        XCTAssertEqual(result.previousWeekSeconds, 25 * 60, accuracy: 0.001)
        XCTAssertEqual(result.changeRatio ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.changeText, "↑ 100%")
    }

    func testDailyFocusHasSevenDaysWithZeroFill() {
        let records = [
            record(dayOffset: 0, hour: 9, minutes: 50, task: "写作"),
            record(dayOffset: -2, hour: 9, minutes: 25, task: "复习"),
        ]
        let result = WeeklyReview.analyze(records: records, now: now, calendar: calendar)

        XCTAssertEqual(result.dailyFocus.count, 7, "本周应补齐 7 天")
        XCTAssertEqual(result.dailyFocus.reduce(0) { $0 + $1.seconds }, 75 * 60, accuracy: 0.001)
        let nonEmpty = result.dailyFocus.filter { $0.seconds > 0 }
        XCTAssertEqual(nonEmpty.count, 2)
    }

    func testRestRecordsIgnored() {
        let rest = ReviewRecord(
            startedAt: now,
            duration: 300,
            isRest: true,
            taskTitle: nil,
            interruptionCount: 0
        )
        let result = WeeklyReview.analyze(records: [rest], now: now, calendar: calendar)
        XCTAssertEqual(result.pomodoros, 0)
        XCTAssertEqual(result.totalFocusSeconds, 0)
    }
}
