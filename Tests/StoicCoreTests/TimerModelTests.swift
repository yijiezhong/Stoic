import XCTest
@testable import StoicCore

final class FakeClock: Clock, @unchecked Sendable {
    var uptime: TimeInterval = 1_000
    var now: Date = Date(timeIntervalSince1970: 1_700_000_000)
}

@MainActor
final class TimerModelTests: XCTestCase {
    private func wall(_ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return DateComponents(calendar: calendar, year: 2026, month: 3, day: 11, hour: hour, minute: minute).date!
    }

    func testWorkAfterLongRestRealignsToNextMark() {
        let clock = FakeClock()
        let model = TimerModel(clock: clock)
        var config = model.config
        config.alignToClock = true
        config.autoStartNext = true
        config.segmentsPerRound = 1
        config.shortRestDuration = 300
        config.longRestDuration = 900
        model.apply(config: config)

        clock.now = wall(9, 0)
        model.start()
        XCTAssertEqual(model.duration, 25 * 60, "9:00 start: 30 - 5 = 25")

        clock.uptime += 25 * 60
        clock.now = clock.now.addingTimeInterval(25 * 60)
        model.tick()
        XCTAssertEqual(model.kind, .rest, "work finished -> long rest")

        clock.uptime += 15 * 60
        clock.now = clock.now.addingTimeInterval(15 * 60)
        model.tick()
        XCTAssertEqual(model.kind, .work)
        XCTAssertEqual(model.duration, 15 * 60, "9:40 start: 20 to 10:00 minus 5 rest = 15")
    }

    func testCountdownUsesMonotonicClockAndIgnoresWallClock() {
        let clock = FakeClock()
        let model = TimerModel(clock: clock)
        model.start()
        XCTAssertEqual(model.phase, .running)

        clock.uptime += 60
        XCTAssertEqual(model.remaining, 25 * 60 - 60, accuracy: 0.001)

        clock.now = clock.now.addingTimeInterval(3_600)
        XCTAssertEqual(model.remaining, 25 * 60 - 60, accuracy: 0.001)
    }

    func testPauseFreezesRemaining() {
        let clock = FakeClock()
        let model = TimerModel(clock: clock)
        model.start()
        clock.uptime += 30
        model.pause()
        let frozen = model.remaining
        clock.uptime += 120
        XCTAssertEqual(model.remaining, frozen, accuracy: 0.001)
        model.resume()
        clock.uptime += 10
        XCTAssertEqual(model.remaining, frozen - 10, accuracy: 0.001)
    }

    func testWorkCompletionAutoStartsRest() {
        let clock = FakeClock()
        var config = TimerModel.Configuration()
        config.autoStartNext = true
        let model = TimerModel(config: config, clock: clock)
        model.start()
        clock.uptime += config.workDuration
        model.tick()

        XCTAssertEqual(model.roundIndex, 1)
        XCTAssertEqual(model.kind, .rest)
        XCTAssertEqual(model.phase, .running)
        XCTAssertEqual(model.duration, config.shortRestDuration, accuracy: 0.001)
    }

    func testLongRestAfterConfiguredSegments() {
        let clock = FakeClock()
        var config = TimerModel.Configuration()
        config.segmentsPerRound = 2
        config.autoStartNext = false
        let model = TimerModel(config: config, clock: clock)

        model.start()
        clock.uptime += config.workDuration
        model.tick()
        XCTAssertEqual(model.roundIndex, 1)
        XCTAssertEqual(model.kind, .rest)

        model.start()
        clock.uptime += config.shortRestDuration
        model.tick()
        XCTAssertEqual(model.kind, .work)

        model.start()
        clock.uptime += config.workDuration
        model.tick()
        XCTAssertEqual(model.roundIndex, 2)
        XCTAssertEqual(model.duration, config.longRestDuration, accuracy: 0.001)
    }

    func testSkipAdvancesRound() {
        let clock = FakeClock()
        let model = TimerModel(clock: clock)
        model.start()
        clock.uptime += 10
        model.skip()
        XCTAssertEqual(model.roundIndex, 1)
        XCTAssertEqual(model.kind, .rest)
    }

    func testSelectTaskLocksCurrentSegment() {
        let clock = FakeClock()
        let model = TimerModel(clock: clock)
        let taskA = UUID()
        let taskB = UUID()

        model.selectTask(id: taskA, title: "写作")
        model.start()

        // 运行中切换：只影响下一段
        model.selectTask(id: taskB, title: "复习")
        XCTAssertEqual(model.selectedTaskID, taskB)

        var finished: TimerModel.FinishedSegment?
        model.onSegmentFinished = { segment, _ in finished = segment }

        clock.uptime += 60
        model.skip()

        XCTAssertEqual(finished?.taskID, taskA, "当前段应仍归属开始时的任务")
        XCTAssertEqual(model.selectedTaskID, taskB, "下一段应使用新选择")
    }

    func testWorkingModeChangesDurationOnlyWhenIdle() {
        let clock = FakeClock()
        let model = TimerModel(clock: clock)

        model.setWorkingMode(.focus50)
        XCTAssertEqual(model.workingMode, .focus50)
        XCTAssertEqual(model.duration, 50 * 60, accuracy: 0.001)

        model.start()
        model.setWorkingMode(.focus90)
        XCTAssertEqual(model.workingMode, .focus50, "运行中不应切换模式")
        XCTAssertEqual(model.duration, 50 * 60, accuracy: 0.001)
    }

    func testFinishedSegmentCarriesMode() throws {
        let clock = FakeClock()
        let model = TimerModel(clock: clock)
        model.setWorkingMode(.focus90)

        var finished: TimerModel.FinishedSegment?
        model.onSegmentFinished = { segment, _ in finished = segment }

        model.start()
        clock.uptime += 90 * 60
        model.tick()

        let segment = try XCTUnwrap(finished)
        XCTAssertEqual(segment.mode, "focus90")
        XCTAssertEqual(segment.duration, 90 * 60, accuracy: 0.001)
    }

    func testDiscardRestoredStateReturnsToCleanIdle() {
        let clock = FakeClock()
        let snapshot = TimerSnapshot(
            phase: "running",
            kind: "work",
            roundIndex: 3,
            duration: 1_500,
            taskTitle: nil,
            startedWall: clock.now.addingTimeInterval(-100),
            pausedAccum: 0,
            pauseStartedWall: nil,
            savedAt: clock.now
        )
        let store = InMemoryStore(snapshot: snapshot)
        let model = TimerModel(clock: clock, store: store)
        XCTAssertEqual(model.phase, .running)

        model.discardRestoredState()

        XCTAssertEqual(model.phase, .idle)
        XCTAssertEqual(model.roundIndex, 0)
        XCTAssertEqual(model.remaining, 25 * 60, accuracy: 0.001)
        XCTAssertNil(store.snapshot, "作废后应清掉持久化快照")
    }

    func testRestoreRunningTimerUsesWallClock() {
        let clock = FakeClock()
        let snapshot = TimerSnapshot(
            phase: "running",
            kind: "work",
            roundIndex: 2,
            duration: 1_500,
            taskTitle: "写作",
            startedWall: clock.now.addingTimeInterval(-60),
            pausedAccum: 0,
            pauseStartedWall: nil,
            savedAt: clock.now
        )
        let store = InMemoryStore(snapshot: snapshot)
        let model = TimerModel(clock: clock, store: store)

        XCTAssertEqual(model.phase, .running)
        XCTAssertEqual(model.remaining, 1_440, accuracy: 1)

        clock.uptime += 10
        XCTAssertEqual(model.remaining, 1_430, accuracy: 1)
    }

    func testRestoreExpiredTimerMovesToRestAsCompleted() {
        let clock = FakeClock()
        let snapshot = TimerSnapshot(
            phase: "running",
            kind: "work",
            roundIndex: 0,
            duration: 1_500,
            taskTitle: nil,
            startedWall: clock.now.addingTimeInterval(-2_000),
            pausedAccum: 0,
            pauseStartedWall: nil,
            savedAt: clock.now
        )
        let store = InMemoryStore(snapshot: snapshot)
        let model = TimerModel(clock: clock, store: store)

        XCTAssertEqual(model.phase, .completed)
        XCTAssertEqual(model.kind, .rest)
        XCTAssertEqual(model.roundIndex, 1)
    }
}
