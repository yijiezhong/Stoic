import Foundation

public struct ExportTask: Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var note: String
    public var createdAt: Date
    public var completedAt: Date?
    public var dueDate: Date?
    public var isImportant: Bool
    public var isUrgent: Bool
    public var expectedIntervals: Int
    public var sortIndex: Int
    public var legacyID: String?

    public init(
        id: UUID, title: String, note: String, createdAt: Date,
        completedAt: Date?, dueDate: Date?, isImportant: Bool, isUrgent: Bool,
        expectedIntervals: Int, sortIndex: Int, legacyID: String?
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.dueDate = dueDate
        self.isImportant = isImportant
        self.isUrgent = isUrgent
        self.expectedIntervals = expectedIntervals
        self.sortIndex = sortIndex
        self.legacyID = legacyID
    }
}

public struct ExportInterval: Codable, Equatable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var duration: TimeInterval
    public var isRest: Bool
    public var roundIndex: Int
    public var completionState: Int
    public var interruptionCount: Int
    public var interruptionReasons: String
    public var mode: String
    public var taskTitle: String?
    public var legacyID: String?

    public init(
        id: UUID, startedAt: Date, duration: TimeInterval, isRest: Bool,
        roundIndex: Int, completionState: Int, interruptionCount: Int,
        interruptionReasons: String, mode: String, taskTitle: String?, legacyID: String?
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
        self.taskTitle = taskTitle
        self.legacyID = legacyID
    }
}

public struct ExportSettings: Codable, Equatable, Sendable {
    public var workMinutes: Int
    public var shortRestMinutes: Int
    public var longRestMinutes: Int
    public var segmentsPerRound: Int
    public var autoStartNext: Bool

    public init(workMinutes: Int, shortRestMinutes: Int, longRestMinutes: Int, segmentsPerRound: Int, autoStartNext: Bool) {
        self.workMinutes = workMinutes
        self.shortRestMinutes = shortRestMinutes
        self.longRestMinutes = longRestMinutes
        self.segmentsPerRound = segmentsPerRound
        self.autoStartNext = autoStartNext
    }
}

public struct ExportPayload: Codable, Equatable, Sendable {
    public var version: Int
    public var exportedAt: Date
    public var tasks: [ExportTask]
    public var intervals: [ExportInterval]
    public var settings: ExportSettings?

    public init(version: Int = 1, exportedAt: Date, tasks: [ExportTask], intervals: [ExportInterval], settings: ExportSettings?) {
        self.version = version
        self.exportedAt = exportedAt
        self.tasks = tasks
        self.intervals = intervals
        self.settings = settings
    }
}

public enum DataExport {
    public static func encodeJSON(_ payload: ExportPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    public static func decodeJSON(_ data: Data) throws -> ExportPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExportPayload.self, from: data)
    }

    public static func encodeCSV(_ intervals: [ExportInterval]) -> String {
        var lines = ["startedAt,durationSeconds,isRest,mode,task,interruptions,completionState"]
        let formatter = ISO8601DateFormatter()
        for interval in intervals.sorted(by: { $0.startedAt < $1.startedAt }) {
            let fields = [
                formatter.string(from: interval.startedAt),
                String(format: "%.0f", interval.duration),
                interval.isRest ? "rest" : "work",
                interval.mode,
                escapeCSV(interval.taskTitle ?? ""),
                String(interval.interruptionCount),
                String(interval.completionState)
            ]
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func escapeCSV(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
