import SwiftUI
import SwiftData
import StoicCore

struct IntervalEditorView: View {
    @Bindable var interval: Interval
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var allIntervals: [Interval]
    @Query(sort: [SortDescriptor(\TaskItem.createdAt)])
    private var allTasks: [TaskItem]

    @State private var start = Date()
    @State private var minutes = 25
    @State private var completionState = 3
    @State private var selectedTaskID: UUID?
    @State private var warning: String?
    @State private var warningAcknowledged = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                DatePicker(
                    L10n.t("editor.start"),
                    selection: $start,
                    displayedComponents: [.date, .hourAndMinute]
                )
                Stepper(L10n.format("editor.duration", minutes), value: $minutes, in: 1...180)
                Picker(L10n.t("editor.task"), selection: $selectedTaskID) {
                    Text(L10n.t("records.untitledTask")).tag(UUID?.none)
                    ForEach(allTasks) { task in
                        Text(task.title).tag(Optional(task.id))
                    }
                }
                Picker(L10n.t("editor.state"), selection: $completionState) {
                    Text(L10n.t("editor.complete")).tag(3)
                    Text(L10n.t("editor.skipped")).tag(4)
                }
                if let warning {
                    Text(warning)
                        .font(.system(size: 16))
                        .foregroundStyle(.orange)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button(L10n.t("editor.cancel")) { dismiss() }
                Spacer()
                Button(L10n.t("editor.save")) { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 420, height: 380)
        .onAppear {
            start = interval.startedAt
            minutes = max(1, Int((interval.duration / 60).rounded()))
            completionState = interval.completionState
            selectedTaskID = interval.task?.id
        }
    }

    private func save() {
        let duration = TimeInterval(minutes * 60)
        let others = allIntervals
            .filter { $0.id != interval.id }
            .map { (start: $0.startedAt, duration: $0.duration) }

        if !warningAcknowledged,
           IntervalOverlap.overlaps(start: start, duration: duration, against: others) {
            warning = L10n.t("editor.overlap")
            warningAcknowledged = true
            return
        }

        interval.startedAt = start
        interval.duration = duration
        interval.completionState = completionState
        interval.task = allTasks.first { $0.id == selectedTaskID }
        try? context.save()
        NotificationCenter.default.post(name: .stoicIntervalsChanged, object: nil)
        dismiss()
    }
}
