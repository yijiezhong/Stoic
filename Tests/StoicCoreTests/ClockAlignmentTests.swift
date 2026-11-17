import XCTest
@testable import StoicCore

final class ClockAlignmentTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func date(hour: Int, minute: Int, second: Int = 0) -> Date {
        DateComponents(calendar: calendar, year: 2026, month: 3, day: 11, hour: hour, minute: minute, second: second).date!
    }

    func testNextMarkIsHalfHour() {
        XCTAssertEqual(ClockAlignment.secondsToNextMark(from: date(hour: 9, minute: 7), calendar: calendar), 23 * 60)
        XCTAssertEqual(ClockAlignment.secondsToNextMark(from: date(hour: 9, minute: 0), calendar: calendar), 30 * 60)
        XCTAssertEqual(ClockAlignment.secondsToNextMark(from: date(hour: 9, minute: 31), calendar: calendar), 29 * 60)
    }

    func testFirstWorkSubtractsRestSoNextPomodoroStartsOnMark() {
        // 9:02 + 23 分钟工作 = 9:25，休息 5 分钟 → 9:30 第二个番茄开始
        let work = ClockAlignment.firstWorkDuration(
            from: date(hour: 9, minute: 2),
            restDuration: 5 * 60,
            calendar: calendar
        )
        XCTAssertEqual(work, 23 * 60)
    }

    func testOnTheHourGivesStandardPomodoro() {
        let work = ClockAlignment.firstWorkDuration(
            from: date(hour: 9, minute: 0),
            restDuration: 5 * 60,
            calendar: calendar
        )
        XCTAssertEqual(work, 25 * 60)
    }

    func testTooLittleRoomExtendsToFollowingMark() {
        // 9:28 距 9:30 只有 2 分钟，减掉 5 分钟休息会变负数 → 顺延到 10:00
        let work = ClockAlignment.firstWorkDuration(
            from: date(hour: 9, minute: 28),
            restDuration: 5 * 60,
            calendar: calendar
        )
        XCTAssertEqual(work, 27 * 60)
    }
}
