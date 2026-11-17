import Foundation
import SwiftData

public struct ImportedTask: Sendable, Equatable {
    public var legacyID: String
    public var title: String
    public var note: String
    public var createdAt: Date
    public var completedAt: Date?
    public var dueDate: Date?
    public var isImportant: Bool
    public var isUrgent: Bool
    public var expectedIntervals: Int
    public var isInbox: Bool
}

public struct ImportedInterval: Sendable, Equatable {
    public var legacyID: String
    public var parentTaskID: String?
    public var startedAt: Date
    public var duration: TimeInterval
    public var isRest: Bool
    public var roundIndex: Int
    public var completionState: Int
}

public struct ImportSummary: Sendable, Equatable {
    public var parsedTasks: Int
    public var parsedIntervals: Int
    public var insertedTasks: Int
    public var insertedIntervals: Int
    public var skippedDuplicates: Int
}

public enum BeFocusedImportError: Error, Sendable {
    case unreadable(String)
    case notADictionary
}

/// 只读解析 Be Focused 的 groupStorage.plist（单棵对象树）。
public enum BeFocusedParser {
    public static func parse(plistAt url: URL) throws -> (tasks: [ImportedTask], intervals: [ImportedInterval]) {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BeFocusedImportError.unreadable(error.localizedDescription)
        }
        guard let root = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw BeFocusedImportError.notADictionary
        }

        var tasks: [ImportedTask] = []
        var intervals: [ImportedInterval] = []
        walk(root) { object in
            guard let className = object["className"] as? String else { return }
            switch className {
            case "PMTask":
                guard let id = object["id"] as? String, id != "PMDefaultTask" else { return }
                tasks.append(makeTask(id: id, object: object))
            case "PMPomodoro":
                guard let id = object["id"] as? String else { return }
                intervals.append(makeInterval(id: id, object: object))
            default:
                break
            }
        }
        return (tasks, intervals)
    }

    private static func walk(_ node: Any, visit: ([String: Any]) -> Void) {
        if let dict = node as? [String: Any] {
            visit(dict)
            for value in dict.values {
                walk(value, visit: visit)
            }
        } else if let array = node as? [Any] {
            for item in array {
                walk(item, visit: visit)
            }
        }
    }

    private static func makeTask(id: String, object: [String: Any]) -> ImportedTask {
        ImportedTask(
            legacyID: id,
            title: string(object["title"]),
            note: string(object["note"]),
            createdAt: date(object["creationTime"]) ?? Date(timeIntervalSince1970: 0),
            completedAt: date(object["completionTime"]),
            dueDate: date(object["dueDate"]),
            isImportant: bool(object["isImportant"]),
            isUrgent: bool(object["isUrgent"]),
            expectedIntervals: int(object["expectedIntervals"]),
            isInbox: bool(object["isInbox"])
        )
    }

    private static func makeInterval(id: String, object: [String: Any]) -> ImportedInterval {
        ImportedInterval(
            legacyID: id,
            parentTaskID: object["parentTaskID"] as? String,
            startedAt: date(object["startTimeStamp"]) ?? Date(timeIntervalSince1970: 0),
            duration: double(object["commonTimeInterval"]),
            isRest: bool(object["isRest"]),
            roundIndex: int(object["roundIndex"]),
            completionState: int(object["completionState"])
        )
    }

    private static func string(_ value: Any?) -> String {
        (value as? String) ?? ""
    }

    private static func bool(_ value: Any?) -> Bool {
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        return false
    }

    private static func int(_ value: Any?) -> Int {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        return 0
    }

    private static func double(_ value: Any?) -> Double {
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        return 0
    }

    /// 旧数据用 Unix 秒；0 / 负数表示「未设置」。
    private static func date(_ value: Any?) -> Date? {
        let seconds = double(value)
        guard seconds > 0 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}

@MainActor
public final class BeFocusedImporter {
    public init() {}

    public func importAll(from url: URL, into container: ModelContainer) throws -> ImportSummary {
        let parsed = try BeFocusedParser.parse(plistAt: url)
        let context = ModelContext(container)

        var taskByLegacyID: [String: TaskItem] = [:]
        for task in try context.fetch(FetchDescriptor<TaskItem>()) {
            if let legacy = task.legacyID { taskByLegacyID[legacy] = task }
        }

        // Be Focused 的 PMDefaultTask 是「Other」；已删除任务的 interval 也归到这里，
        // 保证每条记录都有归属，而不是变成孤儿数据。
        let otherLegacyID = "__other__"
        var otherTask = taskByLegacyID[otherLegacyID]
        if otherTask == nil {
            let other = TaskItem(title: "其他", isInbox: true, legacyID: otherLegacyID)
            context.insert(other)
            taskByLegacyID[otherLegacyID] = other
            otherTask = other
        }

        var insertedTasks = 0
        for parsedTask in parsed.tasks where taskByLegacyID[parsedTask.legacyID] == nil {
            let item = TaskItem(
                title: parsedTask.title,
                note: parsedTask.note,
                createdAt: parsedTask.createdAt,
                completedAt: parsedTask.completedAt,
                dueDate: parsedTask.dueDate,
                isImportant: parsedTask.isImportant,
                isUrgent: parsedTask.isUrgent,
                expectedIntervals: parsedTask.expectedIntervals,
                isInbox: parsedTask.isInbox,
                legacyID: parsedTask.legacyID
            )
            context.insert(item)
            taskByLegacyID[parsedTask.legacyID] = item
            insertedTasks += 1
        }

        var seenIntervals = Set<String>()
        for interval in try context.fetch(FetchDescriptor<Interval>()) {
            if let legacy = interval.legacyID { seenIntervals.insert(legacy) }
        }

        var insertedIntervals = 0
        var skipped = 0
        for parsedInterval in parsed.intervals {
            if seenIntervals.contains(parsedInterval.legacyID) {
                skipped += 1
                continue
            }
            let owningTask = parsedInterval.parentTaskID.flatMap { taskByLegacyID[$0] } ?? otherTask
            let item = Interval(
                startedAt: parsedInterval.startedAt,
                duration: parsedInterval.duration,
                isRest: parsedInterval.isRest,
                roundIndex: parsedInterval.roundIndex,
                completionState: parsedInterval.completionState,
                legacyID: parsedInterval.legacyID,
                task: owningTask
            )
            context.insert(item)
            seenIntervals.insert(parsedInterval.legacyID)
            insertedIntervals += 1
        }

        try context.save()

        return ImportSummary(
            parsedTasks: parsed.tasks.count,
            parsedIntervals: parsed.intervals.count,
            insertedTasks: insertedTasks,
            insertedIntervals: insertedIntervals,
            skippedDuplicates: skipped
        )
    }
}
