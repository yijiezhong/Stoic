import Foundation

/// 任务编辑的纯校验逻辑，便于单元测试。
public enum TaskDraft {
    public static func normalizedTitle(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func isValid(title: String) -> Bool {
        normalizedTitle(title) != nil
    }
}
