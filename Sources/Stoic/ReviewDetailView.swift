import SwiftUI
import SwiftData
import StoicCore

struct ReviewDetailView: View {
    let title: String
    let intervals: [Interval]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                Spacer()
                Button(L10n.t("detail.cancel")) { dismiss() }
            }
            .padding(12)

            Divider()

            if intervals.isEmpty {
                ContentUnavailableView(L10n.t("review.empty"), systemImage: "tray")
                    .frame(maxHeight: .infinity)
            } else {
                List(intervals) { interval in
                    HStack {
                        Text(interval.startedAt, format: .dateTime.month().day().hour().minute())
                            .font(.system(size: 16).monospacedDigit())
                            .foregroundStyle(Color.black)
                        Text(interval.task?.title ?? L10n.t("records.untitledTask"))
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(interval.duration / 60)) min")
                            .monospacedDigit()
                        if interval.interruptionCount > 0 {
                            Text("×\(interval.interruptionCount)")
                                .font(.system(size: 16))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 480, height: 420)
    }
}
