import SwiftUI
import StoicCore

struct TaskDetailView: View {
    @Bindable var task: TaskItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var titleDraft = ""
    @State private var errorMessage: String?
    @State private var hasDueDate = false
    @State private var dueDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(L10n.t("detail.section.basic")) {
                    TextField(L10n.t("detail.title"), text: $titleDraft)
                    TextField(L10n.t("detail.note"), text: $task.note, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section(L10n.t("detail.section.status")) {
                    Toggle(L10n.t("detail.important"), isOn: $task.isImportant)
                    Toggle(L10n.t("detail.urgent"), isOn: $task.isUrgent)
                    Stepper(
                        task.expectedIntervals < 0
                            ? L10n.t("detail.expectedUnset")
                            : L10n.format("detail.expected", task.expectedIntervals),
                        value: $task.expectedIntervals,
                        in: -1...100
                    )
                }

                Section(L10n.t("detail.section.time")) {
                    Toggle(L10n.t("detail.hasDue"), isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker(L10n.t("detail.dueDate"), selection: $dueDate, displayedComponents: .date)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 16))
                        .foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button(L10n.t("detail.cancel")) { dismiss() }
                Spacer()
                Button(L10n.t("detail.save")) { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 460, height: 480)
        .onAppear {
            titleDraft = task.title
            hasDueDate = task.dueDate != nil
            dueDate = task.dueDate ?? Date()
        }
    }

    private func save() {
        guard let title = TaskDraft.normalizedTitle(titleDraft) else {
            errorMessage = L10n.t("detail.emptyTitle")
            return
        }
        task.title = title
        task.dueDate = hasDueDate ? dueDate : nil
        try? context.save()
        dismiss()
    }
}
