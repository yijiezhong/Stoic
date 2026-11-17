import Foundation
import MetricKit

/// 接收 MetricKit 的诊断载荷并保存到本地，不上传。
/// 崩溃诊断通常在下次启动时才送达。
final class DiagnosticsCollector: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = DiagnosticsCollector()

    private override init() {
        super.init()
        _ = Self.diagnosticsDirectory()
    }

    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let dir = Self.diagnosticsDirectory()
        for payload in payloads {
            let data = payload.jsonRepresentation()
            let stamp = Int(Date().timeIntervalSince1970)
            let suffix = UUID().uuidString.prefix(8)
            let name = "diagnostics-\(stamp)-\(suffix).json"
            try? data.write(to: dir.appendingPathComponent(name))
        }
    }

    private static func diagnosticsDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("StoicLogs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
