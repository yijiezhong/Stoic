import SwiftUI
import StoicCore

struct MainWindowView: View {
    @State private var selection: String = {
        ProcessInfo.processInfo.environment["STOIC_DEBUG_TAB"] ?? "tasks"
    }()

    private var tabs: [(id: String, title: String)] {
        [
            ("tasks", L10n.t("main.tab.tasks")),
            ("intervals", L10n.t("main.tab.records")),
            ("review", L10n.t("main.tab.review")),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            content
        }
        .font(.system(size: 16))
        .foregroundStyle(Color.black)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("stoicSwitchTab"))) { note in
            if let tab = note.object as? String { selection = tab }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(tabs, id: \.id) { tab in
                Button {
                    selection = tab.id
                } label: {
                    Text(tab.title)
                        .font(.system(size: 24, weight: selection == tab.id ? .semibold : .regular))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            selection == tab.id ? Color.black.opacity(0.07) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case "intervals": IntervalListView()
        case "review": ReviewView()
        default: TaskListView()
        }
    }
}
