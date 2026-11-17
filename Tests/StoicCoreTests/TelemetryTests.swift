import XCTest
@testable import StoicCore

final class TelemetryTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let suite = "telemetry-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testDisabledByDefaultAndIgnoresEvents() {
        let telemetry = Telemetry(defaults: freshDefaults())
        XCTAssertFalse(telemetry.isEnabled, "默认必须关闭")
        telemetry.record(.launch)
        XCTAssertEqual(telemetry.snapshot().counts, [:], "关闭时不记录")
    }

    func testCountsWhenEnabled() {
        let telemetry = Telemetry(defaults: freshDefaults())
        telemetry.isEnabled = true
        telemetry.record(.launch)
        telemetry.record(.segmentCompleted)
        telemetry.record(.segmentCompleted)
        XCTAssertEqual(telemetry.snapshot().counts["launch"], 1)
        XCTAssertEqual(telemetry.snapshot().counts["segmentCompleted"], 2)
    }

    func testFlushDoesNothingWhenDisabled() async {
        let telemetry = Telemetry(defaults: freshDefaults())
        let sent = await telemetry.flushIfEnabled(to: URL(string: "https://example.com/collect"))
        XCTAssertFalse(sent, "关闭时不应发生上报")
    }

    func testDisablingResetsCounters() {
        let telemetry = Telemetry(defaults: freshDefaults())
        telemetry.isEnabled = true
        telemetry.record(.launch)
        telemetry.isEnabled = false
        XCTAssertEqual(telemetry.snapshot().counts, [:])
    }
}
