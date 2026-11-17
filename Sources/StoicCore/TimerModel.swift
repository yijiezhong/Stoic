import Foundation
import Observation

/// 可注入时钟：单调时间用于运行中计时，墙钟只用于重启恢复与记录。
public protocol Clock: Sendable {
    var uptime: TimeInterval { get }
    var now: Date { get }
}

public struct SystemClock: Clock {
    public init() {}
    public var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }
    public var now: Date { Date() }
}

/// 番茄计时状态机。
/// 运行中的剩余时间只由单调时钟差值计算；重启时用墙钟把已流逝时间折算回单调偏移。
@MainActor
@Observable
public final class TimerModel {
    public enum Phase: String, Sendable {
        case idle
        case running
        case paused
        case completed
    }

    public enum SegmentKind: String, Sendable {
        case work
        case rest
    }

    /// 工作段模式：番茄 25 分钟，或 50/90 分钟的专注块。
    public enum WorkingMode: String, Sendable, CaseIterable {
        case pomodoro
        case focus50
        case focus90

        public var minutes: Int {
            switch self {
            case .pomodoro: return 25
            case .focus50: return 50
            case .focus90: return 90
            }
        }
    }

    public struct Configuration: Sendable {
        public var workDuration: TimeInterval
        /// 工作段结束时对齐到整点或半点（不足 5 分钟则不对齐）。
        /// 默认关闭；产品默认由 SettingsRecord.alignToClock 传入。
        public var alignToClock: Bool = false
        public var shortRestDuration: TimeInterval
        public var longRestDuration: TimeInterval
        public var segmentsPerRound: Int
        public var autoStartNext: Bool

        public init(
            workDuration: TimeInterval = 25 * 60,
            shortRestDuration: TimeInterval = 5 * 60,
            longRestDuration: TimeInterval = 15 * 60,
            segmentsPerRound: Int = 8,
            autoStartNext: Bool = true
        ) {
            self.workDuration = workDuration
            self.shortRestDuration = shortRestDuration
            self.longRestDuration = longRestDuration
            self.segmentsPerRound = segmentsPerRound
            self.autoStartNext = autoStartNext
        }
    }

    public private(set) var phase: Phase = .idle
    public private(set) var kind: SegmentKind = .work
    public private(set) var roundIndex: Int = 0
    public private(set) var duration: TimeInterval = 0
    public private(set) var taskTitle: String?
    public var config: Configuration

    /// 已结束的一段，用于落库。
    public struct FinishedSegment: Sendable {
        public let kind: SegmentKind
        public let startedAt: Date?
        public let duration: TimeInterval
        public let taskID: UUID?
        public let taskTitle: String?
        public let interruptionCount: Int
        public let interruptionReasons: String
        public let mode: String
    }

    /// 段结束回调（参数：刚结束的段、是否自然完成）。
    public var onSegmentFinished: (@MainActor (FinishedSegment, Bool) -> Void)?

    /// 当前选中、将被用于下一段的任务。
    public private(set) var selectedTaskID: UUID?
    public private(set) var selectedTaskTitle: String?

    /// 正在进行的段绑定的任务（开始段时锁定，运行中切换不影响它）。
    public private(set) var currentTaskID: UUID?
    public private(set) var currentTaskTitle: String?

    /// 本段内被打断的次数（点一次「被打断」+1）。
    public private(set) var interruptions: Int = 0
    public private(set) var interruptionReasonCodes: [String] = []
    public private(set) var workingMode: WorkingMode = .pomodoro

    private let clock: Clock
    private let store: SnapshotStore?
    private var startedUptime: TimeInterval?
    private var pauseStartedUptime: TimeInterval?
    private var pausedAccum: TimeInterval = 0
    private var startedWall: Date?
    private var pauseStartedWall: Date?
    private var didAttemptRestore = false

    public init(
        config: Configuration = Configuration(),
        clock: Clock = SystemClock(),
        store: SnapshotStore? = nil,
        taskTitle: String? = nil
    ) {
        self.config = config
        self.clock = clock
        self.store = store
        self.taskTitle = taskTitle
        self.selectedTaskTitle = taskTitle
        self.duration = config.workDuration
        restoreIfNeeded()
    }

    // MARK: - 派生状态

    public var remaining: TimeInterval {
        switch phase {
        case .idle, .completed:
            return duration
        case .running:
            let elapsed = (clock.uptime - (startedUptime ?? clock.uptime)) - pausedAccum
            return max(0, duration - elapsed)
        case .paused:
            let frozen = (pauseStartedUptime ?? clock.uptime) - (startedUptime ?? clock.uptime)
            return max(0, duration - (frozen - pausedAccum))
        }
    }

    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / duration))
    }

    public var menuBarText: String {
        let seconds = max(0, Int(remaining.rounded(.up)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    public var isLongRestDue: Bool {
        roundIndex > 0 && roundIndex % max(1, config.segmentsPerRound) == 0
    }

    /// 当前是第几段（工作段从 1 开始；休息段沿用刚完成的工作段序号）。
    public var segmentNumber: Int {
        let perRound = max(1, config.segmentsPerRound)
        let base = (roundIndex % perRound) + (kind == .work && roundIndex > 0 ? 1 : 0)
        return min(max(base, 1), perRound)
    }

    public var isLongRest: Bool {
        kind == .rest && isLongRestDue
    }

    // MARK: - 动作

    public func start() {
        switch phase {
        case .running:
            return
        case .paused:
            resume()
        case .idle:
            beginSegment(kind: kind, alignFirst: true)
        case .completed:
            beginSegment(kind: kind)
        }
    }

    public func pause() {
        guard phase == .running else { return }
        pauseStartedUptime = clock.uptime
        pauseStartedWall = clock.now
        phase = .paused
        persist()
    }

    public func resume() {
        guard phase == .paused, let pausedAt = pauseStartedUptime else { return }
        pausedAccum += clock.uptime - pausedAt
        pauseStartedUptime = nil
        pauseStartedWall = nil
        phase = .running
        persist()
    }

    public func toggle() {
        switch phase {
        case .running: pause()
        case .paused: resume()
        case .idle, .completed: start()
        }
    }

    /// 应用新配置；空闲/完成态下立即刷新待开始时段的时长。
    public func apply(config newConfig: Configuration) {
        config = newConfig
        guard phase == .idle || phase == .completed else { return }
        duration = newConfig.workDuration
        kind = .work
        currentTaskID = selectedTaskID
        currentTaskTitle = selectedTaskTitle
        taskTitle = selectedTaskTitle
        persist()
    }

    /// 选择下一段要归属的任务。运行中的段不受影响（开始段时已锁定）。
    public func selectTask(id: UUID?, title: String?) {
        selectedTaskID = id
        selectedTaskTitle = title
        if phase == .idle || phase == .completed {
            currentTaskID = id
            currentTaskTitle = title
            taskTitle = title
        }
        persist()
    }

    /// 切换工作模式（番茄 / 专注 50 / 专注 90）。运行中不允许切换，避免改动当前段。
    public func setWorkingMode(_ mode: WorkingMode) {
        guard phase == .idle || phase == .completed else { return }
        workingMode = mode
        config.workDuration = TimeInterval(mode.minutes * 60)
        kind = .work
        duration = config.workDuration
        persist()
    }

    /// 记录一次「被打断」，不暂停计时。reason 取 distraction / taskSwitch / rest。
    public func markInterrupted(reason: String) {
        guard phase == .running || phase == .paused else { return }
        interruptions += 1
        interruptionReasonCodes.append(reason)
        persist()
    }

    public func skip() {
        guard phase == .running || phase == .paused else { return }
        finishSegment(completed: false, autoStart: true)
    }

    /// 放弃上次恢复出来的状态，回到干净的 idle。
    public func discardRestoredState() {
        phase = .idle
        kind = .work
        roundIndex = 0
        duration = config.workDuration
        startedUptime = nil
        startedWall = nil
        pauseStartedUptime = nil
        pauseStartedWall = nil
        pausedAccum = 0
        store?.clear()
    }

    public func tick() {
        guard phase == .running, remaining <= 0 else { return }
        finishSegment(completed: true, autoStart: config.autoStartNext)
    }

    // MARK: - 内部

    private func beginSegment(kind newKind: SegmentKind, alignFirst: Bool = false) {
        kind = newKind
        if newKind == .work, config.alignToClock, alignFirst {
            duration = ClockAlignment.firstWorkDuration(
                from: clock.now,
                restDuration: config.shortRestDuration
            )
        } else {
            duration = duration(for: newKind)
        }
        currentTaskID = selectedTaskID
        currentTaskTitle = selectedTaskTitle
        taskTitle = selectedTaskTitle
        interruptions = 0
        interruptionReasonCodes = []
        startedUptime = clock.uptime
        startedWall = clock.now
        pauseStartedUptime = nil
        pauseStartedWall = nil
        pausedAccum = 0
        phase = .running
        persist()
    }

    private func duration(for kind: SegmentKind) -> TimeInterval {
        switch kind {
        case .work:
            return config.workDuration
        case .rest:
            return isLongRestDue ? config.longRestDuration : config.shortRestDuration
        }
    }

    private func finishSegment(completed: Bool, autoStart: Bool) {
        let finishedKind = kind
        let finishedWasLongRest = finishedKind == .rest && isLongRestDue
        let finished = FinishedSegment(
            kind: finishedKind,
            startedAt: startedWall,
            duration: duration,
            taskID: currentTaskID,
            taskTitle: currentTaskTitle,
            interruptionCount: interruptions,
            interruptionReasons: interruptionReasonCodes.joined(separator: ","),
            mode: workingMode.rawValue
        )
        phase = .completed
        if finishedKind == .work {
            roundIndex += 1
        }
        let nextKind: SegmentKind = (finishedKind == .work) ? .rest : .work
        kind = nextKind
        duration = duration(for: nextKind)
        startedUptime = nil
        startedWall = nil
        pauseStartedUptime = nil
        pauseStartedWall = nil
        pausedAccum = 0
        persist()
        onSegmentFinished?(finished, completed)
        if completed && autoStart {
            // 长休息会打破 30 分钟周期，之后的工作段要重新对齐到整点/半点
            beginSegment(kind: nextKind, alignFirst: nextKind == .work && finishedWasLongRest)
        }
    }

    // MARK: - 持久化

    private func persist() {
        guard let store else { return }
        let snapshot = TimerSnapshot(
            phase: phase.rawValue,
            kind: kind.rawValue,
            roundIndex: roundIndex,
            duration: duration,
            taskTitle: taskTitle,
            startedWall: startedWall,
            pausedAccum: pausedAccum,
            pauseStartedWall: pauseStartedWall,
            savedAt: clock.now,
            taskID: currentTaskID
        )
        store.save(snapshot)
    }

    private func restoreIfNeeded() {
        guard !didAttemptRestore, let store, let snapshot = store.load() else { return }
        didAttemptRestore = true
        guard let restoredPhase = Phase(rawValue: snapshot.phase) else { return }
        kind = SegmentKind(rawValue: snapshot.kind) ?? .work
        roundIndex = snapshot.roundIndex
        duration = snapshot.duration
        taskTitle = snapshot.taskTitle ?? taskTitle
        selectedTaskTitle = snapshot.taskTitle
        selectedTaskID = snapshot.taskID
        currentTaskID = snapshot.taskID
        currentTaskTitle = snapshot.taskTitle

        switch restoredPhase {
        case .running:
            guard let started = snapshot.startedWall else {
                phase = .idle
                return
            }
            let elapsed = clock.now.timeIntervalSince(started) - snapshot.pausedAccum
            if elapsed >= snapshot.duration {
                // 停机期间已经到点：按「已完成」处理，下一段等待开始。
                phase = .completed
                if kind == .work { roundIndex += 1 }
                kind = (kind == .work) ? .rest : .work
                duration = self.duration(for: kind)
                store.clear()
            } else {
                startedUptime = clock.uptime - elapsed
                startedWall = started
                pausedAccum = snapshot.pausedAccum
                phase = .running
            }
        case .paused:
            guard let started = snapshot.startedWall else {
                phase = .idle
                return
            }
            let elapsedToPause = (snapshot.pauseStartedWall ?? snapshot.savedAt)
                .timeIntervalSince(started) - snapshot.pausedAccum
            startedUptime = clock.uptime - elapsedToPause
            startedWall = started
            pauseStartedUptime = clock.uptime
            pauseStartedWall = snapshot.pauseStartedWall ?? snapshot.savedAt
            pausedAccum = snapshot.pausedAccum
            phase = .paused
        case .idle, .completed:
            phase = restoredPhase
        }
    }
}
