import SwiftUI
import StoicCore

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    /// 中文走苹方，西文走系统配套字体（SF Pro）。
    private func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    var body: some View {
        VStack(spacing: 18) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
            }

            VStack(spacing: 6) {
                Text("知止 Stoic")
                    .font(font(24, weight: .semibold))
                Text("知所先后，止于至善")
                    .font(font(16))
            }

            Rectangle()
                .fill(Color.black.opacity(0.12))
                .frame(height: 1)
                .padding(.vertical, 4)

            VStack(spacing: 12) {
                row("版本", "\(version) (\(build))")
                row("数据", "仅本地")
                row("系统", "macOS 14+")
            }

            Link(destination: URL(string: "https://github.com/")!) {
                Text("项目主页")
                    .font(font(16))
                    .underline()
            }

            Text("© 2026 钟义杰")
                .font(font(16))
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 32)
        .padding(.vertical, 32)
        .frame(width: 400)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .frame(width: 72, alignment: .trailing)
            Text("  ")
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(font(16))
    }
}
