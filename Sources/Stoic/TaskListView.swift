import SwiftUI
import SwiftData
import StoicCore

struct TaskListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\TaskItem.sortIndex), SortDescriptor(\TaskItem.createdAt)])
    private var tasks: [TaskItem]

    @State private var search = ""
    @State private var editingTask: TaskItem?
    @State private var showCompleted = false

    private var visibleTasks: [TaskItem] {
        tasks.filter { task in
            let matchesSearch = search.isEmpty
                || task.title.localizedCaseInsensitiveContains(search)
                || task.note.localizedCaseInsensitiveContains(search)
            let matchesCompletion = showCompleted ? true : task.completedAt == nil
            return matchesSearch && matchesCompletion
        }
    }

    private var completedCount: Int {
        tasks.filter { $0.completedAt != nil }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 420)
        .sheet(item: $editingTask) { task in
            TaskDetailView(task: task)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.black)
            TextField(L10n.t("tasks.search"), text: $search)
                .textFieldStyle(.plain)

            Toggle(L10n.t("tasks.showCompleted"), isOn: $showCompleted)
                .toggleStyle(.checkbox)
                .font(.system(size: 16))

            Button {
                addTask()
            } label: {
                Label(L10n.t("tasks.new"), systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        .padding(12)
    }

    private var list: some View {
        List {
            ForEach(visibleTasks) { task in
                row(for: task)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
        }
        .listStyle(.inset)
        .overlay {
            if visibleTasks.isEmpty {
                ContentUnavailableView(
                    L10n.t("tasks.empty"),
                    systemImage: "checklist",
                    description: Text(L10n.t("tasks.emptyHint"))
                )
            }
        }
    }

    private func row(for task: TaskItem) -> some View {
        HStack(spacing: 10) {
            Button {
                toggleCompletion(task)
            } label: {
                Image(systemName: task.completedAt == nil ? "circle" : "checkmark.circle.fill")
                    .foregroundStyle(task.completedAt == nil ? Color.secondary : Color.green)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .strikethrough(task.completedAt != nil)
                .foregroundStyle(task.completedAt != nil ? .secondary : .primary)
                .lineLimit(1)

            if task.isImportant {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 16))
            }

            Spacer()

            let done = task.intervals.filter { !$0.isRest && $0.completionState == 3 }.count
            if done > 0 {
                Text("\(done)")
                    .font(.system(size: 16).monospacedDigit())
                    .foregroundStyle(Color.black)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingTask = task
        }
        .contextMenu {
            Button(L10n.t("tasks.edit")) { editingTask = task }
            Button(task.completedAt == nil ? L10n.t("tasks.markDone") : L10n.t("tasks.markUndone")) { toggleCompletion(task) }
            Divider()
            Button(L10n.t("tasks.delete"), role: .destructive) { delete(task) }
        }
    }

    private var footer: some View {
        HStack {
            Text(L10n.format("tasks.footer", tasks.count, completedCount))
                .font(.system(size: 16))
                .foregroundStyle(Color.black)
            Spacer()
            Text(L10n.t("tasks.newHint"))
                .font(.system(size: 16))
                .foregroundStyle(Color.black)
        }
        .padding(10)
    }

    private func addTask() {
        let nextIndex = (tasks.map(\.sortIndex).max() ?? 0) + 1
        let task = TaskItem(title: L10n.t("tasks.newTitle"), sortIndex: nextIndex)
        context.insert(task)
        try? context.save()
        editingTask = task
    }

    private func toggleCompletion(_ task: TaskItem) {
        task.completedAt = task.completedAt == nil ? Date() : nil
        try? context.save()
    }

    private func delete(_ task: TaskItem) {
        context.delete(task)
        try? context.save()
    }
}
