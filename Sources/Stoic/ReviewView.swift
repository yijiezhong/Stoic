import SwiftUI
import Charts
import SwiftData
import StoicCore

struct ReviewView: View {
    @Query(sort: [SortDescriptor(\Interval.startedAt, order: .reverse)])
    private var intervals: [Interval]

    @State private var detailTitle: String?

    private var weekFocusIntervals: [Interval] {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return intervals.filter { !$0.isRest && week.contains($0.startedAt) }
    }

    private var review: WeeklyReviewResult {
        WeeklyReview.analyze(
            records: intervals.map {
                ReviewRecord(
                    startedAt: $0.startedAt,
                    duration: $0.duration,
                    isRest: $0.isRest,
                    taskTitle: $0.task?.title,
                    interruptionCount: $0.interruptionCount
                )
            }
        )
    }

    var body: some View {
        Group {
            if review.sourceRecords == 0 {
                ContentUnavailableView(
                    L10n.t("review.empty"),
                    systemImage: "calendar.badge.clock",
                    description: Text(L10n.t("review.emptyHint"))
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        summaryRow
                        dailyChart
                        peakAndChange
                        topTasks
                        Text(L10n.format("review.source", review.sourceRecords))
                            .font(.system(size: 14))
                            .foregroundStyle(Color.black)
                    }
                    .padding(16)
                }
            }
        }
    }

    private func openDetail(_ title: String) {
        detailTitle = title
    }

    private var summaryRow: some View {
        HStack(spacing: 24) {
            Button { openDetail(L10n.t("review.focus")) } label: {
                metric(L10n.t("review.focus"), format(review.totalFocusSeconds))
            }
            .buttonStyle(.plain)
            Button { openDetail(L10n.t("review.pomodoros")) } label: {
                metric(L10n.t("review.pomodoros"), "\(review.pomodoros)")
            }
            .buttonStyle(.plain)
            Button { openDetail(L10n.t("review.activeDays")) } label: {
                metric(L10n.t("review.activeDays"), "\(review.activeDays)")
            }
            .buttonStyle(.plain)
            Button { openDetail(L10n.t("review.interruptions")) } label: {
                metric(L10n.t("review.interruptions"), "\(review.interruptions)")
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private var dailyChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.t("review.daily"))
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.black)
            Chart(review.dailyFocus, id: \.day) { item in
                BarMark(
                    x: .value("Day", item.day, unit: .day),
                    y: .value("Minutes", item.seconds / 60)
                )
                .foregroundStyle(Color.orange.gradient)
                .cornerRadius(3)
            }
            .frame(height: 150)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Color.black)
            Text(value)
                .font(.system(size: 14).monospacedDigit())
        }
    }

    private var peakAndChange: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("review.peakHour"))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.black)
                if let hour = review.peakHour {
                    Text(L10n.format("review.peakFormat", hour, hour + 1))
                        .font(.system(size: 14).monospacedDigit())
                } else {
                    Text("—")
                        .font(.system(size: 14))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("review.change"))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.black)
                Text(changeText)
                    .font(.system(size: 14).monospacedDigit())
            }
            Spacer()
        }
    }

    private var changeText: String {
        guard let ratio = review.changeRatio else { return "—" }
        let percent = Int((ratio * 100).rounded())
        if percent == 0 { return L10n.t("review.flat") }
        return percent > 0
            ? L10n.format("review.up", percent)
            : L10n.format("review.down", abs(percent))
    }

    private var topTasks: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.t("review.topTasks"))
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.black)
            ForEach(Array(review.topTasks.enumerated()), id: \.offset) { _, share in
                HStack {
                    Text(share.title)
                    Spacer()
                    Text(format(share.seconds))
                        .monospacedDigit()
                        .foregroundStyle(Color.black)
                }
                .font(.system(size: 14))
            }
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds.rounded() / 60)
        if minutes < 60 { return "\(minutes) 分钟" }
        return "\(minutes / 60) 小时 \(minutes % 60) 分"
    }
}
