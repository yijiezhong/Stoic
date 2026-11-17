import XCTest
@testable import StoicCore

final class StreakCalculatorTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func day(_ offset: Int, from base: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: base)!
    }

    func testConsecutiveDaysIncludingToday() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let days = [day(0, from: today), day(-1, from: today), day(-2, from: today)]
        XCTAssertEqual(StreakCalculator.streak(daysWithFocus: days, asOf: today, calendar: calendar), 3)
    }

    func testGapBreaksStreak() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let days = [day(0, from: today), day(-1, from: today), day(-3, from: today)]
        XCTAssertEqual(StreakCalculator.streak(daysWithFocus: days, asOf: today, calendar: calendar), 2)
    }

    func testTodayMissingFallsBackToYesterday() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let days = [day(-1, from: today), day(-2, from: today)]
        XCTAssertEqual(StreakCalculator.streak(daysWithFocus: days, asOf: today, calendar: calendar), 2)
    }

    func testNoRecords() {
        XCTAssertEqual(StreakCalculator.streak(daysWithFocus: [], asOf: Date(), calendar: calendar), 0)
    }
}
