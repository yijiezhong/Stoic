import Foundation

public enum TelemetryEvent: String, Codable, Sendable, CaseIterable {
    case launch
    case segmentCompleted
    case segmentSkipped
    case importCompleted
}

/// 聚合计数，不含任何个人数据。
public struct TelemetrySummary: Codable, Equatable, Sendable {
    public var counts: [String: Int] = [:]
    public var lastFlush: Date?

    public init(counts: [String: Int] = [:], lastFlush: Date? = nil) {
        self.counts = counts
        self.lastFlush = lastFlush
    }
}

/// 匿名遥测：默认关闭；开启后只累计聚合计数，flush 时上报一个 JSON。
public final class Telemetry: @unchecked Sendable {
    public static let shared = Telemetry()

    private let defaultsKey = "stoic.telemetry.enabled"
    private let summaryKey = "stoic.telemetry.summary"
    private let defaults: UserDefaults
    private var summary: TelemetrySummary

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: summaryKey),
           let decoded = try? JSONDecoder().decode(TelemetrySummary.self, from: data) {
            summary = decoded
        } else {
            summary = TelemetrySummary()
        }
    }

    public var isEnabled: Bool {
        get { defaults.bool(forKey: defaultsKey) }
        set {
            defaults.set(newValue, forKey: defaultsKey)
            if !newValue {
                reset()
            }
        }
    }

    public func record(_ event: TelemetryEvent) {
        guard isEnabled else { return }
        summary.counts[event.rawValue, default: 0] += 1
        persist()
    }

    public func snapshot() -> TelemetrySummary {
        summary
    }

    /// 关闭时不发起任何网络请求，直接返回 false。
    @discardableResult
    public func flushIfEnabled(to url: URL?) async -> Bool {
        guard isEnabled, let url else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        request.httpBody = try? JSONEncoder().encode(summary)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return false
            }
            summary.lastFlush = Date()
            persist()
            return true
        } catch {
            return false
        }
    }

    public func reset() {
        summary = TelemetrySummary()
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(summary) else { return }
        defaults.set(data, forKey: summaryKey)
    }
}
