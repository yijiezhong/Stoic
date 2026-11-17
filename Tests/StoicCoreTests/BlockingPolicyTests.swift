import XCTest
@testable import StoicCore

final class BlockingPolicyTests: XCTestCase {
    func testHitsBlockedApp() {
        let hit = BlockingPolicy.firstBlocked(
            running: ["com.apple.finder", "com.tencent.xinWeChat"],
            blocked: ["com.tencent.xinWeChat"]
        )
        XCTAssertEqual(hit, "com.tencent.xinWeChat")
    }

    func testNoHitWhenListEmpty() {
        XCTAssertNil(BlockingPolicy.firstBlocked(running: ["a"], blocked: []))
    }

    func testParseTrimsAndDropsEmpty() {
        let set = BlockingPolicy.parseList(" a , b,, c ")
        XCTAssertEqual(set, ["a", "b", "c"])
    }

    func testWhitelistViolation() {
        let hit = BlockingPolicy.firstViolating(
            running: ["com.apple.finder", "com.zhizhi.stoic", "com.apple.Safari"],
            allowed: ["com.apple.Safari"],
            ignored: ["com.apple.finder", "com.zhizhi.stoic"]
        )
        XCTAssertNil(hit, "Finder 与自身被豁免，Safari 在白名单里")
    }

    func testWhitelistFlagsUnknownApp() {
        let hit = BlockingPolicy.firstViolating(
            running: ["com.apple.finder", "com.tencent.xinWeChat"],
            allowed: ["com.apple.Safari"],
            ignored: ["com.apple.finder"]
        )
        XCTAssertEqual(hit, "com.tencent.xinWeChat")
    }

    func testWhitelistEmptyMeansNoEnforcement() {
        XCTAssertNil(
            BlockingPolicy.firstViolating(running: ["a"], allowed: [], ignored: [])
        )
    }
}
