import AppIntents
import Foundation

struct StartTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Interval"
    static let description = IntentDescription("Starts the timer if it is not running.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppDelegate.shared?.intentStartTimer()
        return .result()
    }
}

struct PauseTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Work Interval"
    static let description = IntentDescription("Pauses the current interval; does nothing if none is running.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppDelegate.shared?.intentPauseTimer()
        return .result()
    }
}

struct SkipIntervalIntent: AppIntent {
    static let title: LocalizedStringResource = "Skip Interval"
    static let description = IntentDescription("Skips the current running or paused interval.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppDelegate.shared?.intentSkipInterval()
        return .result()
    }
}

struct ToggleTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Timer"
    static let description = IntentDescription("Starts, pauses or resumes the timer.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppDelegate.shared?.intentToggleTimer()
        return .result()
    }
}

struct AddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Task"
    static let description = IntentDescription("Adds a new task and optionally selects it.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Task Name", default: "New Task")
    var taskName: String

    @Parameter(title: "Select Task", default: false)
    var selectTask: Bool

    init() {}

    init(taskName: String, selectTask: Bool = false) {
        self.taskName = taskName
        self.selectTask = selectTask
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = AppDelegate.shared?.intentAddTask(named: taskName, selectAfterAdding: selectTask)
        return .result()
    }
}

struct CompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Task"
    static let description = IntentDescription("Marks the named task as completed.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Task Name")
    var taskName: String

    init() {}

    init(taskName: String) { self.taskName = taskName }

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = AppDelegate.shared?.intentCompleteTask(named: taskName)
        return .result()
    }
}

struct SelectTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Select Task"
    static let description = IntentDescription("Selects the named task; optionally creates it.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Task Name")
    var taskName: String

    @Parameter(title: "Create If Missing", default: false)
    var createIfMissing: Bool

    init() {}

    init(taskName: String, createIfMissing: Bool = false) {
        self.taskName = taskName
        self.createIfMissing = createIfMissing
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = AppDelegate.shared?.intentSelectTask(named: taskName, createIfMissing: createIfMissing)
        return .result()
    }
}

struct SelectedTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Selected Task"
    static let description = IntentDescription("Returns the currently selected task name.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let name = AppDelegate.shared?.intentSelectedTaskName() ?? ""
        return .result(value: name)
    }
}

struct TimerStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Timer Status"
    static let description = IntentDescription("Returns whether the timer is active, paused or not started.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let status = AppDelegate.shared?.intentTimerStatus() ?? "unknown"
        return .result(value: status)
    }
}

struct TimerTypeIntent: AppIntent {
    static let title: LocalizedStringResource = "Timer Type"
    static let description = IntentDescription("Returns whether the current interval is work or rest.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let type = AppDelegate.shared?.intentTimerType() ?? "unknown"
        return .result(value: type)
    }
}

struct TimerDurationIntent: AppIntent {
    static let title: LocalizedStringResource = "Timer Duration"
    static let description = IntentDescription("Returns minutes: total, elapsed or remaining.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Timing", default: "remaining")
    var timingType: String

    init() {}

    init(timingType: String) { self.timingType = timingType }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let minutes = AppDelegate.shared?.intentTimerMinutes(timingType) ?? 0
        return .result(value: minutes)
    }
}