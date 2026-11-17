import Foundation
@preconcurrency import EventKit

public enum RemindersAccessState: String, Sendable {
    case notDetermined
    case denied
    case restricted
    case authorized

    public var displayText: String {
        switch self {
        case .notDetermined: return "尚未授权"
        case .denied: return "已拒绝（同步降级为纯本地）"
        case .restricted: return "系统受限"
        case .authorized: return "已授权"
        }
    }
}

/// 把 EKAuthorizationStatus 映射成业务状态；独立出来便于测试。
/// 原始值：0 notDetermined, 1 restricted, 2 denied, 3 authorized, 4 fullAccess, 5 writeOnly
public enum RemindersAccessMapping {
    public static func map(_ rawValue: Int) -> RemindersAccessState {
        switch rawValue {
        case 0: return .notDetermined
        case 1: return .restricted
        case 2: return .denied
        case 3, 4, 5: return .authorized
        default: return .notDetermined
        }
    }
}

public struct LocalReminderTask: Sendable {
    public var id: UUID
    public var title: String
    public var note: String
    public var dueDate: Date?
    public var reminderID: String?

    public init(id: UUID, title: String, note: String, dueDate: Date?, reminderID: String?) {
        self.id = id
        self.title = title
        self.note = note
        self.dueDate = dueDate
        self.reminderID = reminderID
    }
}

public struct RemindersSyncResult: Sendable {
    public var exported: Int = 0
    public var updated: Int = 0
    public var imported: Int = 0
    public var error: String?
}

public final class RemindersSyncService: @unchecked Sendable {
    private let store = EKEventStore()

    public init() {}

    public var accessState: RemindersAccessState {
        RemindersAccessMapping.map(EKEventStore.authorizationStatus(for: .reminder).rawValue)
    }

    public func requestAccess() async -> RemindersAccessState {
        do {
            _ = try await store.requestFullAccessToReminders()
        } catch {
            // 统一按真实状态返回
        }
        return accessState
    }

    @MainActor
    public func sync(
        tasks: [LocalReminderTask],
        applyReminderID: (UUID, String?) -> Void,
        createTaskFromReminder: (String, String, Date?) -> Void
    ) async -> RemindersSyncResult {
        var result = RemindersSyncResult()
        guard accessState == .authorized else {
            result.error = accessState.displayText
            return result
        }
        guard let calendar = store.defaultCalendarForNewReminders() else {
            result.error = "没有可用的默认提醒列表"
            return result
        }

        for task in tasks {
            if let reminderID = task.reminderID,
               let existing = store.calendarItem(withIdentifier: reminderID) as? EKReminder {
                existing.title = task.title
                existing.notes = task.note
                existing.dueDateComponents = task.dueDate.map {
                    Calendar.current.dateComponents([.year, .month, .day], from: $0)
                }
                do {
                    try store.save(existing, commit: false)
                    result.updated += 1
                } catch {
                    result.error = error.localizedDescription
                }
                continue
            }

            let reminder = EKReminder(eventStore: store)
            reminder.title = task.title
            reminder.notes = task.note
            reminder.calendar = calendar
            reminder.dueDateComponents = task.dueDate.map {
                Calendar.current.dateComponents([.year, .month, .day], from: $0)
            }
            do {
                try store.save(reminder, commit: false)
                applyReminderID(task.id, reminder.calendarItemIdentifier)
                result.exported += 1
            } catch {
                result.error = error.localizedDescription
            }
        }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: [calendar]
        )
        let snapshots = await fetchReminderSnapshots(matching: predicate)
        let localTitles = Set(tasks.map { $0.title })
        for snapshot in snapshots {
            guard !snapshot.title.isEmpty else { continue }
            if !localTitles.contains(snapshot.title) {
                createTaskFromReminder(snapshot.title, snapshot.notes, snapshot.due)
                result.imported += 1
            }
        }

        try? store.commit()
        return result
    }

    private struct ReminderSnapshot: Sendable {
        let title: String
        let notes: String
        let due: Date?
    }

    private func fetchReminderSnapshots(matching predicate: NSPredicate) async -> [ReminderSnapshot] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let snapshots = (reminders ?? []).map { reminder in
                    ReminderSnapshot(
                        title: reminder.title ?? "",
                        notes: reminder.notes ?? "",
                        due: reminder.dueDateComponents?.date
                    )
                }
                continuation.resume(returning: snapshots)
            }
        }
    }
}
