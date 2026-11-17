import Foundation

/// 记录时间重叠检测（纯函数，便于测试）。
public enum IntervalOverlap {
    public static func overlaps(
        start: Date,
        duration: TimeInterval,
        against others: [(start: Date, duration: TimeInterval)]
    ) -> Bool {
        guard duration > 0 else { return false }
        let end = start.addingTimeInterval(duration)
        for other in others {
            guard other.duration > 0 else { continue }
            let otherEnd = other.start.addingTimeInterval(other.duration)
            if start < otherEnd && other.start < end {
                return true
            }
        }
        return false
    }
}
