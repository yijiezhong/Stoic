import SwiftUI
import SwiftData
import AppKit
import StoicCore

/// 独立设置窗口，按 Be Focused Pro 的分组方式组织。
struct SettingsWindowView: View {
    @Environment(\.modelContext) private var context

    @State private var workMinutes = 25
    @State private var shortRestMinutes = 5
    @State private var longRestMinutes = 15
    @State private var segmentsPerRound = 8
    @State private var autoStartNext = true
    @State private var playSound = true
    @State private var soundPack = "classic"
    @State private var alignToClock = true
    @State private var showInMenuBar = true
    @AppStorage("stoic.launchAtLogin") private var launchAtLogin = true
    @AppStorage("stoic.restOverlay") private var restOverlay = true
    @State private var blockingMode = "off"
    @State private var blockedText = ""
    @AppStorage("stoic.telemetry.enabled") private var telemetryEnabled = false
    @AppStorage("stoic.sponsorURL") private var sponsorURL = ""
    @AppStorage("stoic.updateFeedURL") private var updateFeedURL = ""
    @State private var saved = false
    @State private var runningApps: [(name: String, id: String)] = []
    @State private var selectedTab = "general"

    private let tabKeys: [(id: String, key: String)] = [
        ("general", "settings.tab.general"),
        ("intervals", "settings.tab.intervals"),
        ("notifications", "settings.tab.notifications"),
        ("blocking", "settings.tab.blocking"),
        ("data", "settings.tab.data"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            ScrollView {
                settingsContent
                    .padding(14)
            }

            Divider()
            HStack {
                Text(saved ? L10n.t("settings.saved") : "")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.black)
                Spacer()
                Button(L10n.t("settings.restoreDefaults")) { applyDefaults() }
                Button(L10n.t("settings.save")) { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .font(.system(size: 16))
        .foregroundStyle(Color.black)
        .frame(width: 620, height: 560)
        .onAppear {
            load()
            runningApps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .compactMap { app in
                    guard let id = app.bundleIdentifier, let name = app.localizedName else { return nil }
                    return (name, id)
                }
                .sorted { $0.name < $1.name }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(tabKeys, id: \.id) { tab in
                Button { selectedTab = tab.id } label: {
                    Text(L10n.t(tab.key))
                        .font(.system(size: 24, weight: selectedTab == tab.id ? .semibold : .regular))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            selectedTab == tab.id ? Color.black.opacity(0.07) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch selectedTab {
        case "intervals": intervalsTab
        case "notifications": notificationsTab
        case "blocking": blockingTab
        case "data": dataTab
        default: generalTab
        }
    }

    private var generalTab: some View {
        Form {
            Section(L10n.t("settings.section.appearance")) {
                Toggle(L10n.t("settings.launchAtLogin"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        _ = LaunchAtLogin.setEnabled(newValue)
                    }
                Toggle(L10n.t("settings.showInMenuBar"), isOn: $showInMenuBar)
                Toggle(L10n.t("settings.autoStart"), isOn: $autoStartNext)
            }
        }
        .formStyle(.grouped)
    }

    private var intervalsTab: some View {
        Form {
            Section(L10n.t("settings.tab.intervals")) {
                Toggle(L10n.t("settings.restOverlay"), isOn: $restOverlay)
                Text(L10n.t("settings.restOverlayHint"))
                    .foregroundStyle(.black)
                Stepper(L10n.format("settings.work", workMinutes), value: $workMinutes, in: 1...180)
                Stepper(L10n.format("settings.shortRest", shortRestMinutes), value: $shortRestMinutes, in: 1...60)
                Stepper(L10n.format("settings.longRest", longRestMinutes), value: $longRestMinutes, in: 1...120)
                Stepper(L10n.format("settings.segments", segmentsPerRound), value: $segmentsPerRound, in: 1...16)
                Toggle(L10n.t("settings.alignToClock"), isOn: $alignToClock)
                Text(L10n.t("settings.alignToClockHint"))
                    .font(.system(size: 16))
                    .foregroundStyle(Color.black)
            }
        }
        .formStyle(.grouped)
    }

    private var notificationsTab: some View {
        Form {
            Section(L10n.t("settings.reminder")) {
                Picker(L10n.t("settings.soundPack"), selection: $soundPack) {
                    Text(L10n.t("sound.classic")).tag("classic")
                    Text(L10n.t("sound.soft")).tag("soft")
                    Text(L10n.t("sound.system")).tag("system")
                    Text(L10n.t("sound.off")).tag("off")
                }
                Text(L10n.t("settings.soundHint"))
                    .font(.system(size: 16))
                    .foregroundStyle(Color.black)
            }
        }
        .formStyle(.grouped)
    }

    private var blockingTab: some View {
        Form {
            Section(L10n.t("settings.blocking")) {
                Picker(L10n.t("settings.blockingMode"), selection: $blockingMode) {
                    Text(L10n.t("mode.blocking.off")).tag("off")
                    Text(L10n.t("mode.blocking.blacklist")).tag("blacklist")
                    Text(L10n.t("mode.blocking.whitelist")).tag("whitelist")
                }
                TextField(
                    blockingMode == "whitelist"
                        ? L10n.t("settings.allowedApps")
                        : L10n.t("settings.blockedApps"),
                    text: $blockedText
                )
                Menu(L10n.t("settings.addRunningApp")) {
                    ForEach(runningApps, id: \.id) { app in
                        Button(app.name) { appendBlocked(app.id) }
                    }
                }
                Text(L10n.t("settings.blockingHint"))
                    .font(.system(size: 16))
                    .foregroundStyle(Color.black)
            }
        }
        .formStyle(.grouped)
    }

    private var dataTab: some View {
        Form {
            Section(L10n.t("settings.sync")) {
                Button(L10n.t("settings.syncNow")) {
                    NotificationCenter.default.post(name: .stoicSettingsChanged, object: nil)
                }
                Text(L10n.t("settings.syncHint"))
                    .font(.system(size: 16))
                    .foregroundStyle(Color.black)
            }
            Section(L10n.t("settings.data")) {
                HStack {
                    Button(L10n.t("settings.exportJSON")) {
                        NotificationCenter.default.post(name: .stoicExportJSON, object: nil)
                    }
                    Button(L10n.t("settings.exportCSV")) {
                        NotificationCenter.default.post(name: .stoicExportCSV, object: nil)
                    }
                }
                Text(L10n.t("settings.dataHint"))
                    .font(.system(size: 16))
                    .foregroundStyle(Color.black)
            }
            Section(L10n.t("settings.about")) {
                TextField(L10n.t("settings.sponsorURL"), text: $sponsorURL)
                Button(L10n.t("settings.support")) {
                    if let url = URL(string: sponsorURL.trimmingCharacters(in: .whitespaces)), url.scheme == "https" {
                        NSWorkspace.shared.open(url)
                    }
                }
                .disabled(sponsorURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .formStyle(.grouped)
    }

    private func appendBlocked(_ id: String) {
        var ids = blockedText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !ids.contains(id) else { return }
        ids.append(id)
        blockedText = ids.joined(separator: ", ")
    }

    private func load() {
        guard let record = (try? context.fetch(FetchDescriptor<SettingsRecord>()))?.first else { return }
        workMinutes = record.workMinutes
        shortRestMinutes = record.shortRestMinutes
        longRestMinutes = record.longRestMinutes
        segmentsPerRound = record.segmentsPerRound
        autoStartNext = record.autoStartNext
        playSound = record.playSound
        soundPack = record.soundPack
        alignToClock = record.alignToClock
        showInMenuBar = record.showTimerInMenuBar
        blockedText = record.blockedBundleIDs
        blockingMode = record.blockingMode
    }

    private func applyDefaults() {
        workMinutes = 25
        shortRestMinutes = 5
        longRestMinutes = 15
        segmentsPerRound = 8
        autoStartNext = true
        playSound = true
        alignToClock = true
        showInMenuBar = true
        blockedText = ""
        blockingMode = "off"
    }

    private func save() {
        let record = (try? context.fetch(FetchDescriptor<SettingsRecord>()))?.first ?? {
            let new = SettingsRecord()
            context.insert(new)
            return new
        }()
        record.workMinutes = workMinutes
        record.shortRestMinutes = shortRestMinutes
        record.longRestMinutes = longRestMinutes
        record.segmentsPerRound = segmentsPerRound
        record.autoStartNext = autoStartNext
        record.playSound = playSound
        record.soundPack = soundPack
        record.alignToClock = alignToClock
        record.showTimerInMenuBar = showInMenuBar
        _ = LaunchAtLogin.setEnabled(launchAtLogin)
        record.blockedBundleIDs = blockedText
        record.blockingMode = blockingMode
        try? context.save()
        NotificationCenter.default.post(name: .stoicSettingsChanged, object: nil)
        saved = true
    }
}
