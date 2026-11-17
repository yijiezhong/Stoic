import Foundation

/// 运行态的持久化快照。只存「恢复计时所需的最小集合」。
public struct TimerSnapshot: Codable, Sendable, Equatable {
    public var phase: String
    public var kind: String
    public var roundIndex: Int
    public var duration: TimeInterval
    public var taskTitle: String?
    public var startedWall: Date?
    public var pausedAccum: TimeInterval
    public var pauseStartedWall: Date?
    public var savedAt: Date
    public var taskID: UUID?

    public init(
        phase: String,
        kind: String,
        roundIndex: Int,
        duration: TimeInterval,
        taskTitle: String?,
        startedWall: Date?,
        pausedAccum: TimeInterval,
        pauseStartedWall: Date?,
        savedAt: Date,
        taskID: UUID? = nil
    ) {
        self.phase = phase
        self.kind = kind
        self.roundIndex = roundIndex
        self.duration = duration
        self.taskTitle = taskTitle
        self.startedWall = startedWall
        self.pausedAccum = pausedAccum
        self.pauseStartedWall = pauseStartedWall
        self.savedAt = savedAt
        self.taskID = taskID
    }
}

public protocol SnapshotStore: AnyObject, Sendable {
    func load() -> TimerSnapshot?
    func save(_ snapshot: TimerSnapshot)
    func clear()
}

public final class UserDefaultsStore: SnapshotStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(suiteName: String? = nil, key: String = "stoic.timer.snapshot") {
        if let suiteName, let custom = UserDefaults(suiteName: suiteName) {
            self.defaults = custom
        } else {
            self.defaults = .standard
        }
        self.key = key
    }

    public func load() -> TimerSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TimerSnapshot.self, from: data)
    }

    public func save(_ snapshot: TimerSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}

public final class InMemoryStore: SnapshotStore, @unchecked Sendable {
    public private(set) var snapshot: TimerSnapshot?
    public init(snapshot: TimerSnapshot? = nil) { self.snapshot = snapshot }
    public func load() -> TimerSnapshot? { snapshot }
    public func save(_ snapshot: TimerSnapshot) { self.snapshot = snapshot }
    public func clear() { snapshot = nil }
}
