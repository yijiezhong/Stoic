import Foundation

/// 黑名单命中判断（纯函数，便于测试）。
public enum BlockingPolicy {
    public static func firstBlocked(running: [String], blocked: Set<String>) -> String? {
        guard !blocked.isEmpty else { return nil }
        return running.first { blocked.contains($0) }
    }

    /// 白名单：运行中的常规应用若不在允许集合内，返回第一个违例。
    public static func firstViolating(
        running: [String],
        allowed: Set<String>,
        ignored: Set<String>
    ) -> String? {
        guard !allowed.isEmpty else { return nil }
        return running.first { !allowed.contains($0) && !ignored.contains($0) }
    }

    public static func parseList(_ raw: String) -> Set<String> {
        Set(
            raw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
    }
}
