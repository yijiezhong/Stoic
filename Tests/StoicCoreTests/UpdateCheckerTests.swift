import XCTest
@testable import StoicCore

final class UpdateCheckerTests: XCTestCase {
    func testNumericCompareNotLexical() {
        XCTAssertTrue(VersionCompare.isNewer("0.10.0", than: "0.9.0"), "10 应大于 9，而不是字符串比较")
        XCTAssertFalse(VersionCompare.isNewer("0.9.0", than: "0.10.0"))
    }

    func testEqualVersions() {
        XCTAssertEqual(VersionCompare.compare("0.1.0", "0.1.0"), 0)
        XCTAssertFalse(VersionCompare.isNewer("0.1.0", than: "0.1.0"))
    }

    func testDifferentLengths() {
        XCTAssertTrue(VersionCompare.isNewer("1.0", than: "0.9.9"))
        XCTAssertTrue(VersionCompare.isNewer("1.0.0.1", than: "1.0"))
        XCTAssertFalse(VersionCompare.isNewer("1.0", than: "1.0.0.1"))
    }

    func testPreReleaseSuffixIgnored() {
        XCTAssertEqual(VersionCompare.compare("1.2.0-beta", "1.2.0"), 0)
    }
}
