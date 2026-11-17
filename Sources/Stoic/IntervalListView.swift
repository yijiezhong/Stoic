import SwiftUI
import SwiftData
import StoicCore

struct IntervalListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Interval.startedAt, order: .reverse)])
    private var intervals: [Interval]

    @Query(sort: [SortDescriptor(\TaskItem.createdAt)])
    private var allTasks: [TaskItem]

    @State private var editingInterval: Interval?

    private var todayIntervals: [Interval] {
        intervals.filter { Calendar.current.isDateInToday($0.startedAt) }
    }

    private var completedWork: Int {
        todayIntervals.filter { !$0.isRest && $0.completionState == 3 }.count
    }

    private var streak: Int {
        StreakCalculator.streak(
            daysWithFocus: intervals.filter { !$0.isRest }.map { $0.startedAt }
        )
    }

    private var focusedSeconds: TimeInterval {
        todayIntervals
            .filter { !$0.isRest && $0.completionState == 3 }
            .reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        VStack(spacing: 0) {
            summary
            Divider()
            list
            Divider()
            footer
        }
    }

    private var summary: some View {
        HStack(spacing: 20) {
            metric(L10n.t("records.completed"), "\(completedWork)")
            metric(L10n.t("records.focus"), format(focusedSeconds))
            metric(L10n.t("records.count"), "\(todayIntervals.count)")
            metric(
                L10n.t("records.interruptions"),
                "\(interruptionBreakdown.total)",
                detail: interruptionBreakdown.detail.isEmpty ? nil : interruptionBreakdown.detail
            )
            metric(L10n.t("records.streak"), "\(streak)")
            metric(
                L10n.t("records.focusBlocks"),
                "\(todayIntervals.filter { !$0.isRest && $0.mode != "pomodoro" }.count)"
            )
            Spacer()
        }
        .padding(12)
    }

    private func metric(_ title: String, _ value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Color.black)
            Text(value)
                .font(.system(size: 16).monospacedDigit())
            if let detail {
                Text(detail)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.black)
            }
        }
    }

    private var interruptionBreakdown: (total: Int, detail: String) {
        let codes = todayIntervals
            .flatMap { $0.interruptionReasons.split(separator: ",") }
            .map(String.init)
        let distraction = codes.filter { $0 == "distraction" }.count
        let taskSwitch = codes.filter { $0 == "taskSwitch" }.count
        let rest = codes.filter { $0 == "rest" }.count
        let total = todayIntervals.reduce(0) { $0 + $1.interruptionCount }
        guard total > 0 else { return (0, "") }
        return (total, L10n.format("records.interruptionsBreakdown", distraction, taskSwitch, rest))
    }

    private var list: some View {
        List {
            ForEach(todayIntervals) { interval in
                row(interval)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .contextMenu {
                        Button(L10n.t("records.edit")) { editingInterval = interval }
                        Divider()
                        Button(L10n.t("tasks.delete"), role: .destructive) { delete(interval) }
                    }
            }
        }
        .listStyle(.inset)
        .overlay {
            if todayIntervals.isEmpty {
                ContentUnavailableView(
                    L10n.t("records.empty"),
                    systemImage: "chart.bar",
                    description: Text(L10n.t("records.emptyHint"))
                )
            }
        }
        .sheet(item: $editingInterval) { interval in
            IntervalEditorView(interval: interval)
        }
    }

    private func row(_ interval: Interval) -> some View {
        HStack(spacing: 10) {
            Text(interval.startedAt, format: .dateTime.hour().minute())
                .font(.system(size: 16).monospacedDigit())
                .foregroundStyle(Color.black)

            Image(systemName: interval.isRest ? "cup.and.saucer" : "timer")
                .foregroundStyle(interval.isRest ? Color.green : Color.orange)
                .font(.system(size: 16))

            Menu {
                Button(L10n.t("records.untitledTask")) { assign(interval, task: nil) }
                Divider()
                ForEach(allTasks) { task in
                    Button(task.title) { assign(interval, task: task) }
                }
            } label: {
                Text(interval.task?.title ?? L10n.t("records.untitledTask"))
                    .lineLimit(1)
                    .foregroundStyle(Color.black)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            Text(format(interval.duration))
                .font(.system(size: 16).monospacedDigit())

            if interval.completionState == 4 {
                Text(L10n.t("records.skipped"))
                    .font(.system(size: 16))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { editingInterval = interval }
    }

    private func assign(_ interval: Interval, task: TaskItem?) {
        interval.task = task
        try? context.save()
        NotificationCenter.default.post(name: .stoicIntervalsChanged, object: nil)
    }

    private var footer: some View {
        HStack {
            Text(L10n.t("records.editHint"))
                .font(.system(size: 16))
                .foregroundStyle(Color.black)
            Spacer()
            Button(L10n.t("records.edit")) {
                if let first = todayIntervals.first { editingInterval = first }
            }
            .disabled(todayIntervals.isEmpty)
        }
        .padding(10)
    }

    private func delete(_ interval: Interval) {
        context.delete(interval)
        try? context.save()
    }

    private func format(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds.rounded() / 60)
        if minutes < 60 { return L10n.format("records.minutes", minutes) }
        return L10n.format("records.hoursMinutes", minutes / 60, minutes % 60)
    }
}
