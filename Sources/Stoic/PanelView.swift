import SwiftUI
import SwiftData
import StoicCore

struct PanelView: View {
    @Environment(TimerModel.self) private var model
    @Environment(\.modelContext) private var context
    @State private var todayCompleted = 0

    private var accent: Color {
        if model.kind == .work { return Color(red: 0.91, green: 0.51, blue: 0.46) }
        return model.isLongRest
            ? Color(red: 0.29, green: 0.56, blue: 0.89)
            : Color(red: 0.36, green: 0.72, blue: 0.47)
    }

    private var taskLabel: String {
        model.selectedTaskTitle ?? model.currentTaskTitle ?? L10n.t("panel.noTask")
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            ring
            segmentLine
            footer
        }
        .font(.system(size: 16))
        .foregroundStyle(Color.black)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 300)
        .onAppear { refreshToday() }
        .onChange(of: model.segmentNumber) { _, _ in refreshToday() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: completeCurrentTask) {
                Image(systemName: taskLabel == L10n.t("panel.noTask") ? "circle" : "checkmark.circle")
                    .font(.system(size: 17))
                    .foregroundStyle(taskLabel == L10n.t("panel.noTask") ? Color.secondary.opacity(0.5) : accent)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .disabled(taskLabel == L10n.t("panel.noTask"))
            .help(L10n.t("panel.completeTask"))

            Spacer(minLength: 0)

            Menu {
                ForEach(openTasks, id: \.id) { task in
                    Button(task.title) { model.selectTask(id: task.id, title: task.title) }
                }
                if !openTasks.isEmpty { Divider() }
                Button(L10n.t("panel.noTask")) { model.selectTask(id: nil, title: nil) }
                Button(L10n.t("panel.newTask")) {
                    NotificationCenter.default.post(name: .stoicOpenTaskList, object: nil)
                }
            } label: {
                HStack(spacing: 4) {
                    Text(taskLabel)
                        .font(.system(size: 16))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(L10n.t("panel.pickTask"))

            Spacer(minLength: 0)

            Menu {
                Button(L10n.t("panel.pickTask")) {
                    NotificationCenter.default.post(name: .stoicPickTask, object: nil)
                }
                Button(L10n.format("panel.interrupted", model.interruptions)) {
                    model.markInterrupted(reason: "distraction")
                }
                Button(L10n.t("panel.skip")) { model.skip() }
                Divider()
                ForEach(TimerModel.WorkingMode.allCases, id: \.self) { mode in
                    Button(L10n.t("mode.\(mode.rawValue)")) { model.setWorkingMode(mode) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.black)
                    .frame(width: 20, height: 20)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.14), lineWidth: 5)
            Circle()
                .trim(from: 0, to: model.progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: model.progress)

            VStack(spacing: 10) {
                Text(model.menuBarText)
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.black)
                Button { model.toggle() } label: {
                    Image(systemName: model.phase == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(accent)
                        .frame(width: 42, height: 42)
                        .overlay(Circle().stroke(accent.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .keyboardShortcut(.space, modifiers: [])
            }
        }
        .frame(width: 196, height: 196)
    }

    private var segmentLine: some View {
        Text(L10n.format("panel.segmentDetail",
                         L10n.t("mode.\(model.workingMode.rawValue)"),
                         model.segmentNumber,
                         model.config.segmentsPerRound))
            .font(.system(size: 16))
    }

    private var footer: some View {
        HStack {
            Button {
                NotificationCenter.default.post(name: .stoicOpenTaskList, object: nil)
            } label: {
                Image(systemName: "list.bullet").font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .help(L10n.t("panel.taskList"))

            Spacer()

            Text(L10n.format("panel.today", todayCompleted, model.config.segmentsPerRound))
                .font(.system(size: 16))

            Spacer()

            Menu {
                Button(L10n.t("menu.reports")) {
                    NotificationCenter.default.post(name: .stoicOpenReports, object: nil)
                }
                Button(L10n.t("menu.exportCSV")) {
                    NotificationCenter.default.post(name: .stoicExportCSV, object: nil)
                }
                Divider()
                Button(L10n.t("menu.settings")) {
                    NotificationCenter.default.post(name: .stoicOpenSettings, object: nil)
                }
                Button(L10n.t("menu.about")) {
                    NotificationCenter.default.post(name: .stoicOpenAbout, object: nil)
                }
                Divider()
                Button(L10n.t("menu.quit")) {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "gearshape").font(.system(size: 13))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .focusEffectDisabled()
            .help(L10n.t("panel.settings"))
        }
        .padding(.top, 2)
    }


    private var openTasks: [TaskItem] {
        let all = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        return all
            .filter { $0.completedAt == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    private func refreshToday() {
        let all = (try? context.fetch(FetchDescriptor<Interval>())) ?? []
        todayCompleted = all.filter {
            !$0.isRest && $0.completionState == 3 && Calendar.current.isDateInToday($0.startedAt)
        }.count
    }

    private func completeCurrentTask() {
        guard let id = model.selectedTaskID ?? model.currentTaskID else { return }
        let all = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        guard let task = all.first(where: { $0.id == id }) else { return }
        task.completedAt = Date()
        try? context.save()
        model.selectTask(id: nil, title: nil)
    }
}
