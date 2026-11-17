import SwiftUI
import StoicCore

struct MainWindowView: View {
    @State private var selection: String = {
        ProcessInfo.processInfo.environment["STOIC_DEBUG_TAB"] ?? "tasks"
    }()

    var body: some View {
        TabView(selection: $selection) {
            TaskListView()
                .tabItem { Label(L10n.t("main.tab.tasks"), systemImage: "checklist") }
                .tag("tasks")
            IntervalListView()
                .tabItem { Label(L10n.t("main.tab.records"), systemImage: "chart.bar") }
                .tag("intervals")
            ReviewView()
                .tabItem { Label(L10n.t("main.tab.review"), systemImage: "chart.line.uptrend.xyaxis") }
                .tag("review")
        }
        .font(.system(size: 16))
        .foregroundStyle(Color.black)
        .padding(.top, 4)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("stoicSwitchTab"))) { note in
            if let tab = note.object as? String { selection = tab }
        }
    }
}
