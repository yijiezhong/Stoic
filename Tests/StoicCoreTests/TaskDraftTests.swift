import XCTest
@testable import StoicCore

final class TaskDraftTests: XCTestCase {
    func testBlankTitleRejected() {
        XCTAssertFalse(TaskDraft.isValid(title: ""))
        XCTAssertFalse(TaskDraft.isValid(title: "   "))
        XCTAssertFalse(TaskDraft.isValid(title: "\n\t "))
        XCTAssertNil(TaskDraft.normalizedTitle("   "))
    }

    func testTitleIsTrimmed() {
        XCTAssertEqual(TaskDraft.normalizedTitle("  写周报  "), "写周报")
        XCTAssertTrue(TaskDraft.isValid(title: "写周报"))
    }
}
