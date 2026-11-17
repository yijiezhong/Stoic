import WidgetKit
import SwiftUI

private let appGroupID = "group.com.zhizhi.stoic"

struct StoicEntry: TimelineEntry {
    let date: Date
    let completedToday: Int
    let remaining: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> StoicEntry {
        StoicEntry(date: Date(), completedToday: 3, remaining: "25:00")
    }

    func getSnapshot(in context: Context, completion: @escaping (StoicEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StoicEntry>) -> Void) {
        let entry = currentEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> StoicEntry {
        let shared = UserDefaults(suiteName: appGroupID)
        let completed = shared?.integer(forKey: "widget.completedToday") ?? 0
        let remaining = shared?.string(forKey: "widget.remaining") ?? "25:00"
        return StoicEntry(date: Date(), completedToday: completed, remaining: remaining)
    }
}

struct StoicWidgetEntryView: View {
    var entry: StoicEntry

    var body: some View {
        Link(destination: URL(string: "stoic://toggle")!) {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 4) {
            Text("知止")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(entry.remaining)
                .font(.system(size: 28, weight: .light, design: .rounded))
                .monospacedDigit()
            Text("今日 \(entry.completedToday) 个")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

@main
struct StoicWidget: Widget {
    let kind = "StoicWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StoicWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("知止")
        .description("剩余时间与今日番茄数")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
