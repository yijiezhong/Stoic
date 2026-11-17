import XCTest
@testable import StoicCore

final class IntervalOverlapTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    func testNonOverlapping() {
        let exists = [(start: base, duration: 1_500.0)]
        let later = base.addingTimeInterval(2_000)
        XCTAssertFalse(IntervalOverlap.overlaps(start: later, duration: 1_500, against: exists))
    }

    func testOverlapping() {
        let exists = [(start: base, duration: 1_500.0)]
        let inside = base.addingTimeInterval(600)
        XCTAssertTrue(IntervalOverlap.overlaps(start: inside, duration: 300, against: exists))
    }

    func testTouchingBoundaryIsNotOverlap() {
        let exists = [(start: base, duration: 1_500.0)]
        let rightAfter = base.addingTimeInterval(1_500)
        XCTAssertFalse(IntervalOverlap.overlaps(start: rightAfter, duration: 300, against: exists))
    }

    func testZeroDurationNeverOverlaps() {
        let exists = [(start: base, duration: 1_500.0)]
        XCTAssertFalse(IntervalOverlap.overlaps(start: base, duration: 0, against: exists))
    }
}
