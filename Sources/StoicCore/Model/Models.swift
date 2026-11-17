import Foundation
import SwiftData

/// 任务。字段参考 Be Focused 的 PMTask，保留 legacyID 便于从旧数据导入与去重。
@Model
public final class TaskItem {
    @Attribute(.unique) public var id: UUID = UUID()
    public var title: String = ""
    public var note: String = ""
    public var createdAt: Date = Date()
    public var completedAt: Date?
    public var dueDate: Date?
    public var remindAt: Date?
    public var isImportant: Bool = false
    public var isUrgent: Bool = false
    public var repeatRule: Int = 0
    public var repeatInterval: Int = 1
    public var expectedIntervals: Int = -1
    public var isInbox: Bool = true
    public var sortIndex: Int = 0
    public var reminderID: String?
    public var legacyID: String?

    @Relationship(deleteRule: .cascade, inverse: \Interval.task)
    public var intervals: [Interval] = []

    public init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        dueDate: Date? = nil,
        remindAt: Date? = nil,
        isImportant: Bool = false,
        isUrgent: Bool = false,
        repeatRule: Int = 0,
        repeatInterval: Int = 1,
        expectedIntervals: Int = -1,
        isInbox: Bool = true,
        sortIndex: Int = 0,
        reminderID: String? = nil,
        legacyID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.dueDate = dueDate
        self.remindAt = remindAt
        self.isImportant = isImportant
        self.isUrgent = isUrgent
        self.repeatRule = repeatRule
        self.repeatInterval = repeatInterval
        self.expectedIntervals = expectedIntervals
        self.isInbox = isInbox
        self.sortIndex = sortIndex
        self.reminderID = reminderID
        self.legacyID = legacyID
    }
}

/// 一段番茄或休息记录。只写一次，不被运行态修改。
@Model
public final class Interval {
    @Attribute(.unique) public var id: UUID = UUID()
    public var startedAt: Date = Date()
    public var duration: TimeInterval = 0
    public var isRest: Bool = false
    public var roundIndex: Int = 0
    /// 0 = 未完成，3 = 完成，4 = 跳过（与 Be Focused 的既有取值对齐）。
    public var completionState: Int = 3
    public var interruptionCount: Int = 0
    /// 逗号分隔的原因码：distraction / taskSwitch / rest
    public var interruptionReasons: String = ""
    /// pomodoro / focus50 / focus90
    public var mode: String = "pomodoro"
    public var legacyID: String?
    public var task: TaskItem?

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        duration: TimeInterval,
        isRest: Bool,
        roundIndex: Int = 0,
        completionState: Int = 3,
        interruptionCount: Int = 0,
        interruptionReasons: String = "",
        mode: String = "pomodoro",
        legacyID: String? = nil,
        task: TaskItem? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.duration = duration
        self.isRest = isRest
        self.roundIndex = roundIndex
        self.completionState = completionState
        self.interruptionCount = interruptionCount
        self.interruptionReasons = interruptionReasons
        self.mode = mode
        self.legacyID = legacyID
        self.task = task
    }
}

/// 当日汇总（派生数据的缓存）。
@Model
public final class DaySummary {
    @Attribute(.unique) public var dayStart: Date = Date()
    public var completedWork: Int = 0
    public var completedRest: Int = 0
    public var focusedSeconds: Double = 0

    public init(dayStart: Date, completedWork: Int = 0, completedRest: Int = 0, focusedSeconds: Double = 0) {
        self.dayStart = dayStart
        self.completedWork = completedWork
        self.completedRest = completedRest
        self.focusedSeconds = focusedSeconds
    }
}

/// 单例设置行（key 固定为 "default"）。
@Model
public final class SettingsRecord {
    @Attribute(.unique) public var key: String = "default"
    public var workMinutes: Int = 25
    public var shortRestMinutes: Int = 5
    public var longRestMinutes: Int = 15
    public var segmentsPerRound: Int = 8
    public var autoStartNext: Bool = true
    public var showTimerInMenuBar: Bool = true
    public var playSound: Bool = true
    /// classic / soft / system / off
    public var soundPack: String = "classic"
    /// 工作段结束对齐到整点/半点
    public var alignToClock: Bool = true
    /// 逗号分隔的 bundle id，计时期间命中时提醒一次。
    public var blockedBundleIDs: String = ""
    /// off / blacklist / whitelist
    public var blockingMode: String = "off"

    public init() {}
}
