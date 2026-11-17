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
    @State private var blockingMode = "off"
    @State private var blockedText = ""
    @AppStorage("stoic.telemetry.enabled") private var telemetryEnabled = false
    @AppStorage("stoic.sponsorURL") private var sponsorURL = ""
    @AppStorage("stoic.updateFeedURL") private var updateFeedURL = ""
    @State private var saved = false
    @State private var runningApps: [(name: String, id: String)] = []

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                generalTab.tabItem { Label(L10n.t("settings.tab.general"), systemImage: "gearshape") }
                intervalsTab.tabItem { Label(L10n.t("settings.tab.intervals"), systemImage: "timer") }
                notificationsTab.tabItem { Label(L10n.t("settings.tab.notifications"), systemImage: "bell") }
                blockingTab.tabItem { Label(L10n.t("settings.tab.blocking"), systemImage: "hand.raised") }
                dataTab.tabItem { Label(L10n.t("settings.tab.data"), systemImage: "externaldrive") }
            }
            .padding(14)

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
        .frame(width: 620, height: 480)
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
            Section(L10n.t("settings.section.updates")) {
                TextField(L10n.t("settings.updateFeed"), text: $updateFeedURL)
            }
            Section(L10n.t("settings.privacy")) {
                Toggle(L10n.t("settings.telemetry"), isOn: $telemetryEnabled)
                Text(L10n.t("settings.telemetryHint"))
                    .font(.system(size: 16))
                    .foregroundStyle(Color.black)
            }
        }
        .formStyle(.grouped)
    }

    private var intervalsTab: some View {
        Form {
            Section(L10n.t("settings.tab.intervals")) {
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
