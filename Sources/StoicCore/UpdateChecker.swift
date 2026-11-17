import Foundation

public struct UpdateInfo: Codable, Sendable, Equatable {
    public let version: String
    public let url: String
    public let notes: String?

    public init(version: String, url: String, notes: String? = nil) {
        self.version = version
        self.url = url
        self.notes = notes
    }
}

/// 语义化版本比较（只处理数字段，忽略预发布后缀）。
public enum VersionCompare {
    public static func compare(_ lhs: String, _ rhs: String) -> Int {
        let left = segments(lhs)
        let right = segments(rhs)
        let count = max(left.count, right.count)
        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l > r ? 1 : -1 }
        }
        return 0
    }

    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        compare(candidate, current) > 0
    }

    private static func segments(_ version: String) -> [Int] {
        version
            .split(separator: "-")
            .first
            .map(String.init)?
            .split(separator: ".")
            .map { Int($0) ?? 0 } ?? []
    }
}

public enum UpdateError: Error, Sendable {
    case badURL
    case badPayload
}

public struct UpdateChecker: Sendable {
    public init() {}

    /// 读取远端 JSON：{ "version": "0.2.0", "url": "https://…/Stoic-0.2.0.dmg", "notes": "…" }
    public func fetch(from url: URL) async throws -> UpdateInfo {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let info = try? JSONDecoder().decode(UpdateInfo.self, from: data) else {
            throw UpdateError.badPayload
        }
        guard URL(string: info.url)?.scheme == "https" else {
            throw UpdateError.badURL
        }
        return info
    }
}
