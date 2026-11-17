import Foundation

/// 让番茄周期（工作 + 休息）的边界落在整点或半点。
public enum ClockAlignment {
    /// 距离下一个整点/半点的秒数（0 < 结果 <= 30 分钟）。
    public static func secondsToNextMark(
        from date: Date,
        calendar: Calendar = .current
    ) -> TimeInterval {
        let parts = calendar.dateComponents([.minute, .second], from: date)
        let minute = parts.minute ?? 0
        let second = parts.second ?? 0
        let intoHalfHour = minute % 30
        let elapsed = TimeInterval(intoHalfHour * 60 + second)
        return 30 * 60 - elapsed
    }

    /// 第一个工作段的时长：让「工作 + 休息」正好结束在下一个整点或半点，
    /// 从而保证第二个番茄的开始时间对齐。余量太少时顺延到再下一个整半点。
    public static func firstWorkDuration(
        from date: Date,
        restDuration: TimeInterval,
        calendar: Calendar = .current,
        minimumWork: TimeInterval = 5 * 60
    ) -> TimeInterval {
        let toMark = secondsToNextMark(from: date, calendar: calendar)
        let work = toMark - restDuration
        guard work >= minimumWork else {
            return toMark + 30 * 60 - restDuration
        }
        return work
    }
}
