import XCTest
@testable import StoicCore

final class RemindersAccessMappingTests: XCTestCase {
    func testMapping() {
        XCTAssertEqual(RemindersAccessMapping.map(0), .notDetermined)
        XCTAssertEqual(RemindersAccessMapping.map(1), .restricted)
        XCTAssertEqual(RemindersAccessMapping.map(2), .denied)
        XCTAssertEqual(RemindersAccessMapping.map(3), .authorized)
        XCTAssertEqual(RemindersAccessMapping.map(4), .authorized)
        XCTAssertEqual(RemindersAccessMapping.map(5), .authorized)
        XCTAssertEqual(RemindersAccessMapping.map(99), .notDetermined)
    }

    func testDeniedHasFallbackText() {
        XCTAssertTrue(RemindersAccessState.denied.displayText.contains("降级"))
    }
}
