import SwiftUI
import AppKit
import SwiftData
import StoicCore
import UserNotifications
import Carbon.HIToolbox
import WidgetKit
import UniformTypeIdentifiers

@main
struct StoicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

extension Notification.Name {
    static let stoicOpenTaskList = Notification.Name("stoicOpenTaskList")
    static let stoicPickTask = Notification.Name("stoicPickTask")
    static let stoicOpenSettings = Notification.Name("stoicOpenSettings")
    static let stoicOpenAbout = Notification.Name("stoicOpenAbout")
    static let stoicOpenReports = Notification.Name("stoicOpenReports")
    static let stoicExportJSON = Notification.Name("stoicExportJSON")
    static let stoicExportCSV = Notification.Name("stoicExportCSV")
    static let stoicSettingsChanged = Notification.Name("stoicSettingsChanged")
    static let stoicIntervalsChanged = Notification.Name("stoicIntervalsChanged")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?
    private enum Keys {
        static let cleanExit = "stoic.cleanExit"
    }

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let model = TimerModel(store: UserDefaultsStore())
    private var ticker: Timer?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private let defaults = UserDefaults.standard
    private var shortcutStatus = "unregistered"
    private var blockedIDs: Set<String> = []
    private var blockingMode = "off"
    private var soundPack = "classic"
    private var alertedBlockedThisSegment = false
    private var tickCount = 0
    private var restOverlay: RestOverlayWindow?
    private var restOverlayCheckedForSegment = false
    private var taskWindow: NSWindow?
    private lazy var container: ModelContainer? = {
        if let path = ProcessInfo.processInfo.environment["STOIC_DEBUG_STORE"], !path.isEmpty {
            return try? StoicStore.makeContainer(storeURL: URL(fileURLWithPath: path))
        }
        return try? StoicStore.makeContainer()
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = model.menuBarText
            button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        let panel = PanelView().environment(model)
        if let container {
            popover.contentViewController = NSHostingController(rootView: panel.modelContainer(container))
        } else {
            popover.contentViewController = NSHostingController(rootView: panel)
        }
        popover.behavior = .transient
        popover.animates = false

        model.onSegmentFinished = { [weak self] segment, completed in
            guard completed else { return }
            Telemetry.shared.record(.segmentCompleted)
            self?.recordInterval(segment)
            self?.updateWidgetData(reload: true)
            self?.playChime(for: segment.kind)
            self?.postNotification(for: segment.kind)
        }

        setupMainMenu()
        let wantsLogin = UserDefaults.standard.object(forKey: "stoic.launchAtLogin") as? Bool ?? true
        if wantsLogin != LaunchAtLogin.isEnabled {
            _ = LaunchAtLogin.setEnabled(wantsLogin)
        }
        DiagnosticsCollector.shared.start()
        setupShortcuts()
        applyStoredSettings()
        loadBlockedIDs()
        writeStateFile()
        handleUncleanExitIfNeeded()

        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.model.tick()
                self.refreshTitle()
                self.updateRestOverlay()
                self.tickCount += 1
                if self.tickCount % 120 == 0 {
                    self.updateWidgetData(reload: false)
                }
                if self.model.phase != .running {
                    self.alertedBlockedThisSegment = false
                } else if self.tickCount % 4 == 0 {
                    self.checkBlockedApps()
                }
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openTaskList),
            name: .stoicOpenTaskList,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pickTask),
            name: .stoicPickTask,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSettings),
            name: .stoicOpenSettings,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showAbout),
            name: .stoicOpenAbout,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openReports),
            name: .stoicOpenReports,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(exportJSON),
            name: .stoicExportJSON,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(exportCSV),
            name: .stoicExportCSV,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadSettings),
            name: .stoicSettingsChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleIntervalsChanged),
            name: .stoicIntervalsChanged,
            object: nil
        )

        Telemetry.shared.record(.launch)
        seedIfRequested()
        refreshTitle()
        writeDiagnostics()

        if ProcessInfo.processInfo.environment["STOIC_DEBUG_OPEN_PANEL"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showPopover()
            }
        }
        if ProcessInfo.processInfo.environment["STOIC_DEBUG_OPEN_TASKS"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.openTaskList()
            }
        }
        if ProcessInfo.processInfo.environment["STOIC_DEBUG_OPEN_ABOUT"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.showAbout() }
        }
        if ProcessInfo.processInfo.environment["STOIC_DEBUG_OPEN_SETTINGS"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.showSettings() }
        }
        if ProcessInfo.processInfo.environment["STOIC_DEBUG_FAST"] == "1" {
            model.config.workDuration = 2
            model.config.shortRestDuration = 2
            model.config.autoStartNext = false
            writeDiagnostics()
        }
        if ProcessInfo.processInfo.environment["STOIC_DEBUG_AUTOSTART"] == "1" {
            model.start()
            refreshTitle()
            writeDiagnostics()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "stoic" {
            switch url.host {
            case "toggle":
                model.toggle()
                refreshTitle()
                writeDiagnostics()
            case "start":
                model.start()
                refreshTitle()
            default:
                break
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        defaults.set(true, forKey: Keys.cleanExit)
        GlobalShortcut.shared.unregisterAll()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        let aboutItem = NSMenuItem(title: L10n.t("menu.about"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        let settingsItem = NSMenuItem(title: L10n.t("menu.settings"), action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        let quitItem = NSMenuItem(title: L10n.t("menu.quit"), action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(aboutItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(settingsItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(quitItem)
        appItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    // MARK: - Intent 入口

    func intentStartTimer() {
        model.start()
        refreshTitle()
        writeDiagnostics()
    }

    func intentPauseTimer() {
        model.pause()
        refreshTitle()
        writeDiagnostics()
    }

    func intentSkipInterval() {
        model.skip()
        refreshTitle()
        writeDiagnostics()
    }

    func intentToggleTimer() {
        model.toggle()
        refreshTitle()
        writeDiagnostics()
    }

    func intentTimerStatus() -> String {
        switch model.phase {
        case .running: return "running"
        case .paused: return "paused"
        case .idle: return "idle"
        case .completed: return "completed"
        }
    }

    func intentTimerType() -> String {
        model.kind == .work ? "work" : "rest"
    }

    func intentTimerMinutes(_ kind: String) -> Int {
        switch kind {
        case "total": return Int(model.duration / 60)
        case "elapsed": return Int((model.duration - model.remaining) / 60)
        default: return Int(model.remaining / 60)
        }
    }

    func intentSelectedTaskName() -> String? {
        model.selectedTaskTitle
    }

    func intentSelectTask(named name: String, createIfMissing: Bool) -> Bool {
        guard let container else { return false }
        let context = ModelContext(container)
        let all = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        if let matched = all.first(where: { $0.title == name }) {
            model.selectTask(id: matched.id, title: matched.title)
            return true
        }
        guard createIfMissing else { return false }
        let nextIndex = (all.map(\.sortIndex).max() ?? 0) + 1
        let task = TaskItem(title: name, sortIndex: nextIndex)
        context.insert(task)
        try? context.save()
        model.selectTask(id: task.id, title: task.title)
        return true
    }

    func intentAddTask(named name: String, selectAfterAdding: Bool) -> Bool {
        guard let container else { return false }
        let context = ModelContext(container)
        let all = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let nextIndex = (all.map(\.sortIndex).max() ?? 0) + 1
        let task = TaskItem(title: name, sortIndex: nextIndex)
        context.insert(task)
        try? context.save()
        if selectAfterAdding {
            model.selectTask(id: task.id, title: task.title)
        }
        return true
    }

    func intentCompleteTask(named name: String) -> Bool {
        guard let container else { return false }
        let context = ModelContext(container)
        let all = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        guard let matched = all.first(where: { $0.title == name }) else { return false }
        matched.completedAt = Date()
        try? context.save()
        return true
    }

    // MARK: - 设置

    private func applyStoredSettings() {
        guard let container else { return }
        let context = ModelContext(container)
        guard let record = (try? context.fetch(FetchDescriptor<SettingsRecord>()))?.first else { return }
        var config = TimerModel.Configuration()
        config.workDuration = TimeInterval(record.workMinutes * 60)
        config.alignToClock = record.alignToClock

        soundPack = record.soundPack
        config.shortRestDuration = TimeInterval(record.shortRestMinutes * 60)
        config.longRestDuration = TimeInterval(record.longRestMinutes * 60)
        config.segmentsPerRound = record.segmentsPerRound
        config.autoStartNext = record.autoStartNext
        model.apply(config: config)
    }

    private func updateWidgetData(reload: Bool) {
        guard let shared = UserDefaults(suiteName: "group.com.zhizhi.stoic") else { return }
        shared.set(model.menuBarText, forKey: "widget.remaining")
        if let container {
            let context = ModelContext(container)
            let all = (try? context.fetch(FetchDescriptor<Interval>())) ?? []
            let today = all.filter {
                !$0.isRest && $0.completionState == 3 && Calendar.current.isDateInToday($0.startedAt)
            }.count
            shared.set(today, forKey: "widget.completedToday")
        }
        if reload {
            WidgetCenter.shared.reloadAllTimelines()
        }
        writeStateFile()
    }

    /// 供浏览器扩展的 native host 读取。
    private func writeStateFile() {
        let state: [String: Any] = [
            "focusing": model.phase == .running,
            "remaining": model.menuBarText,
            "blockedHosts": Array(blockedIDs),
            "updatedAt": Date().timeIntervalSince1970
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted]) else { return }
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/StoicState.json")
        try? data.write(to: url, options: .atomic)
    }

    private func loadBlockedIDs() {
        guard let container else { return }
        let context = ModelContext(container)
        guard let record = (try? context.fetch(FetchDescriptor<SettingsRecord>()))?.first else {
            blockedIDs = []
            return
        }
        blockedIDs = BlockingPolicy.parseList(record.blockedBundleIDs)
        blockingMode = record.blockingMode
    }

    private func checkBlockedApps() {
        guard model.phase == .running, !alertedBlockedThisSegment else { return }
        guard blockingMode != "off", !blockedIDs.isEmpty else { return }

        let all = NSWorkspace.shared.runningApplications
        let bundleIDs = all.compactMap { $0.bundleIdentifier }

        let hit: String?
        let isWhitelist: Bool
        switch blockingMode {
        case "blacklist":
            hit = BlockingPolicy.firstBlocked(running: bundleIDs, blocked: blockedIDs)
            isWhitelist = false
        case "whitelist":
            let regular = all
                .filter { $0.activationPolicy == .regular }
                .compactMap { $0.bundleIdentifier }
            hit = BlockingPolicy.firstViolating(
                running: regular,
                allowed: blockedIDs,
                ignored: ["com.zhizhi.stoic", "com.apple.finder", "com.apple.dock"]
            )
            isWhitelist = true
        default:
            hit = nil
            isWhitelist = false
        }

        guard let hit else { return }
        alertedBlockedThisSegment = true
        let name = NSRunningApplication.runningApplications(withBundleIdentifier: hit).first?.localizedName ?? hit
        postBlockedReminder(appName: name, whitelist: isWhitelist)
        NSSound(named: "Funk")?.play()
    }

    private func postBlockedReminder(appName: String, whitelist: Bool = false) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = L10n.t(whitelist ? "notify.whitelistTitle" : "notify.blockedTitle")
            content.body = L10n.format(whitelist ? "notify.whitelistBody" : "notify.blockedBody", appName)
            center.add(UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            ))
        }
    }

    @objc private func reloadSettings() {
        applyStoredSettings()
        loadBlockedIDs()
        writeStateFile()
        writeDiagnostics()
    }

    @objc private func handleIntervalsChanged() {
        writeDiagnostics()
    }

    // MARK: - 记录落库

    private func recordInterval(_ segment: TimerModel.FinishedSegment) {
        guard let container else { return }
        let context = ModelContext(container)
        var owningTask: TaskItem?
        if let taskID = segment.taskID {
            let descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.id == taskID }
            )
            owningTask = (try? context.fetch(descriptor))?.first
        }
        let interval = Interval(
            startedAt: segment.startedAt ?? Date().addingTimeInterval(-segment.duration),
            duration: segment.duration,
            isRest: segment.kind == .rest,
            roundIndex: model.roundIndex,
            completionState: 3,
            interruptionCount: segment.interruptionCount,
            interruptionReasons: segment.interruptionReasons,
            mode: segment.mode,
            task: owningTask
        )
        context.insert(interval)
        try? context.save()
    }

    // MARK: - 选择任务

    @objc private func pickTask() {
        guard let container else { return }
        let context = ModelContext(container)
        let tasks = (try? context.fetch(
            FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\TaskItem.sortIndex)])
        )) ?? []

        let menu = NSMenu()
        let none = NSMenuItem(title: L10n.t("panel.noTask"), action: #selector(menuSelectNoTask), keyEquivalent: "")
        none.target = self
        menu.addItem(none)
        menu.addItem(.separator())
        for task in tasks.prefix(40) {
            let item = NSMenuItem(title: task.title, action: #selector(menuSelectTask(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = task.id
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func menuSelectTask(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        model.selectTask(id: id, title: sender.title)
        writeDiagnostics()
    }

    @objc private func menuSelectNoTask() {
        model.selectTask(id: nil, title: nil)
        writeDiagnostics()
    }

    // MARK: - 调试种子

    private func seedIfRequested() {
        guard let raw = ProcessInfo.processInfo.environment["STOIC_DEBUG_SEED"],
              let count = Int(raw), count > 0,
              let container else { return }
        let context = ModelContext(container)
        let existing = (try? context.fetchCount(FetchDescriptor<TaskItem>())) ?? 0
        if existing > 0 {
            selectFirstTaskIfNeeded(context: context)
            writeDiagnostics()
            return
        }
        for index in 0..<count {
            let task = TaskItem(
                title: "测试任务 \(index + 1)",
                isImportant: index % 7 == 0,
                sortIndex: index
            )
            context.insert(task)
        }
        try? context.save()

        selectFirstTaskIfNeeded(context: context)
        seedTodayIntervalsIfNeeded(context: context)
        writeDiagnostics()
    }

    private func seedTodayIntervalsIfNeeded(context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Interval>())) ?? 0
        guard existing == 0 else { return }
        guard let task = (try? context.fetch(
            FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\TaskItem.sortIndex)])
        ))?.first else { return }

        let today = Calendar.current.startOfDay(for: Date())
        for index in 0..<3 {
            let start = today.addingTimeInterval(TimeInterval(9 * 3600 + index * 1800))
            context.insert(Interval(
                startedAt: start,
                duration: 1_500,
                isRest: false,
                completionState: 3,
                task: task
            ))
            context.insert(Interval(
                startedAt: start.addingTimeInterval(1_500),
                duration: 300,
                isRest: true,
                completionState: 3,
                task: task
            ))
        }
        try? context.save()
    }

    private func selectFirstTaskIfNeeded(context: ModelContext) {
        if let first = (try? context.fetch(
            FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\TaskItem.sortIndex)])
        ))?.first {
            model.selectTask(id: first.id, title: first.title)
        }
    }

    // MARK: - 任务窗口

    @objc private func showSettings() {
        guard let container else { return }
        if settingsWindow == nil {
            let root = SettingsWindowView().modelContainer(container)
            let window = NSWindow(contentViewController: NSHostingController(rootView: root))
            window.title = L10n.t("menu.settings")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        if aboutWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: AboutView()))
            window.title = L10n.t("menu.about")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            aboutWindow = window
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openReports() {
        openTaskList()
        NotificationCenter.default.post(name: Notification.Name("stoicSwitchTab"), object: "review")
    }

    @objc private func exportCSV() {
        guard let container else { return }
        let context = ModelContext(container)
        let all = (try? context.fetch(FetchDescriptor<Interval>())) ?? []
        let payload = all.map { item in
            ExportInterval(
                id: item.id,
                startedAt: item.startedAt,
                duration: item.duration,
                isRest: item.isRest,
                roundIndex: item.roundIndex,
                completionState: item.completionState,
                interruptionCount: item.interruptionCount,
                interruptionReasons: item.interruptionReasons,
                mode: item.mode,
                taskTitle: item.task?.title,
                legacyID: item.legacyID
            )
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "stoic-intervals.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? DataExport.encodeCSV(payload).write(to: url, atomically: true, encoding: .utf8)
    }

    @objc private func exportJSON() {
        guard let container else { return }
        let context = ModelContext(container)
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let intervals = (try? context.fetch(FetchDescriptor<Interval>())) ?? []
        let settings = (try? context.fetch(FetchDescriptor<SettingsRecord>()))?.first

        let payload = ExportPayload(
            exportedAt: Date(),
            tasks: tasks.map {
                ExportTask(
                    id: $0.id, title: $0.title, note: $0.note, createdAt: $0.createdAt,
                    completedAt: $0.completedAt, dueDate: $0.dueDate,
                    isImportant: $0.isImportant, isUrgent: $0.isUrgent,
                    expectedIntervals: $0.expectedIntervals, sortIndex: $0.sortIndex,
                    legacyID: $0.legacyID
                )
            },
            intervals: intervals.map {
                ExportInterval(
                    id: $0.id, startedAt: $0.startedAt, duration: $0.duration, isRest: $0.isRest,
                    roundIndex: $0.roundIndex, completionState: $0.completionState,
                    interruptionCount: $0.interruptionCount, interruptionReasons: $0.interruptionReasons,
                    mode: $0.mode, taskTitle: $0.task?.title, legacyID: $0.legacyID
                )
            },
            settings: settings.map {
                ExportSettings(
                    workMinutes: $0.workMinutes, shortRestMinutes: $0.shortRestMinutes,
                    longRestMinutes: $0.longRestMinutes, segmentsPerRound: $0.segmentsPerRound,
                    autoStartNext: $0.autoStartNext
                )
            }
        )
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "stoic-export.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? DataExport.encodeJSON(payload) else { return }
        try? data.write(to: url)
    }

    @objc private func openTaskList() {
        guard let container else {
            NSSound.beep()
            return
        }
        if let window = taskWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let rootView = MainWindowView().modelContainer(container)
        let window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
        window.title = L10n.t("tasks.title")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 560))
        window.isReleasedWhenClosed = false
        window.center()
        taskWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - 快捷键

    private func setupShortcuts() {
        let cmdShift = UInt32(cmdKey | shiftKey)
        let toggle = GlobalShortcut.shared.register(
            keyCode: UInt32(kVK_ANSI_R),
            modifiers: cmdShift,
            id: 1
        ) { [weak self] in
            self?.model.toggle()
            self?.refreshTitle()
        }
        let skip = GlobalShortcut.shared.register(
            keyCode: UInt32(kVK_ANSI_B),
            modifiers: cmdShift,
            id: 2
        ) { [weak self] in
            self?.model.skip()
            self?.refreshTitle()
        }
        shortcutStatus = "toggle=\(toggle) skip=\(skip)"
    }

    // MARK: - 异常退出恢复

    private func handleUncleanExitIfNeeded() {
        let wasClean = defaults.bool(forKey: Keys.cleanExit)
        defaults.set(false, forKey: Keys.cleanExit)

        guard !wasClean else { return }
        guard model.phase == .running || model.phase == .paused else { return }
        if ProcessInfo.processInfo.environment["STOIC_SKIP_RESTORE_PROMPT"] == "1" { return }

        let alert = NSAlert()
        alert.messageText = L10n.t("quit.title")
        alert.informativeText = L10n.t("quit.message")
        alert.addButton(withTitle: L10n.t("quit.continue"))
        alert.addButton(withTitle: L10n.t("quit.discard"))
        alert.alertStyle = .warning
        if alert.runModal() == .alertSecondButtonReturn {
            model.discardRestoredState()
            refreshTitle()
        }
    }

    // MARK: - 状态项

    private func updateRestOverlay() {
        if model.kind == .rest, model.phase == .running {
            if !restOverlayCheckedForSegment {
                restOverlayCheckedForSegment = true
                let wantsOverlay = UserDefaults.standard.object(forKey: "stoic.restOverlay") as? Bool ?? true
                let exceptions = RestGuard.activeExceptions()
                if wantsOverlay && exceptions.isEmpty {
                    // TODO: 全屏遮罩运行时崩溃（objc_release 过度释放），先只记录不弹窗
                    NSLog("[Stoic] rest overlay wanted but disabled (pending crash fix)")
                } else {
                    NSLog("[Stoic] rest overlay skipped: exceptions=\(exceptions)")
                }
            }
        } else if model.kind != .rest {
            restOverlayCheckedForSegment = false
            if let overlay = restOverlay {
                overlay.hide()
                restOverlay = nil
            }
        }
    }

    private func showRestOverlay() {
        let overlay = RestOverlayWindow()
        overlay.show(
            model: model,
            onStartWork: { [weak self] in
                self?.restOverlay?.hide()
                self?.restOverlay = nil
                self?.model.skip()
            },
            onKeepResting: { [weak self] in
                self?.restOverlay?.hide()
                self?.restOverlay = nil
            }
        )
        restOverlay = overlay
    }

    private func debugShowRestOverlay() {
        showRestOverlay()
    }

    private func writeDiagnostics() {
        let text = """
        statusItem=\(statusItem != nil)
        title=\(statusItem?.button?.title ?? "nil")
        visible=\(statusItem?.isVisible ?? false)
        phase=\(model.phase.rawValue)
        kind=\(model.kind.rawValue)
        remaining=\(String(format: "%.1f", model.remaining))
        roundIndex=\(model.roundIndex)
        shortcuts=\(shortcutStatus)
        taskWindow=\(taskWindow != nil)
        store=\(container != nil)
        login=\(LaunchAtLogin.statusText)
        blocked=\(blockedIDs.count) mode=\(blockingMode)
        task=\(model.currentTaskTitle ?? "none")
        selected=\(model.selectedTaskTitle ?? "none")
        """
        try? text.write(toFile: "/tmp/stoic-status.log", atomically: true, encoding: .utf8)
    }

    @objc private func refreshTitle() {
        statusItem?.button?.title = model.menuBarText
    }

    @objc private func handleClick(_ sender: Any?) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showStatusMenu()
            return
        }
        requestNotificationAuthorizationIfNeeded()
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - 右键菜单

    private func showStatusMenu() {
        let menu = NSMenu()

        let toggle = NSMenuItem(
            title: model.phase == .running ? L10n.t("menu.pause") : L10n.t("menu.start"),
            action: #selector(menuToggle),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        let skip = NSMenuItem(title: L10n.t("menu.skip"), action: #selector(menuSkip), keyEquivalent: "")
        skip.target = self
        menu.addItem(skip)

        menu.addItem(.separator())

        let tasks = NSMenuItem(title: L10n.t("menu.tasks"), action: #selector(openTaskList), keyEquivalent: "t")
        tasks.target = self
        menu.addItem(tasks)

        let open = NSMenuItem(title: L10n.t("menu.open"), action: #selector(menuOpen), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: L10n.t("menu.quit"), action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func menuToggle() {
        model.toggle()
        refreshTitle()
        writeDiagnostics()
    }

    @objc private func menuSkip() {
        model.skip()
        refreshTitle()
    }

    @objc private func menuOpen() {
        showPopover()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    // MARK: - 声音与通知

    private func playChime(for kind: TimerModel.SegmentKind) {
        switch soundPack {
        case "classic":
            playSoundFile("woodblock")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.playSoundFile("rest-chime")
            }
        case "soft":
            playSoundFile("soft-tick")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.playSoundFile("soft-chime")
            }
        case "system":
            NSSound(named: NSSound.Name(kind == .work ? "Glass" : "Ping"))?.play()
        default:
            break
        }
    }

    private func playSoundFile(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let sound = NSSound(contentsOf: url, byReference: false) else { return }
        sound.volume = 0.95
        sound.play()
    }

    private func requestNotificationAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    private func postNotification(for kind: TimerModel.SegmentKind) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = kind == .work ? L10n.t("notify.workEnd") : L10n.t("notify.restEnd")
            content.body = kind == .work ? L10n.t("notify.workBody") : L10n.t("notify.restBody")
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
