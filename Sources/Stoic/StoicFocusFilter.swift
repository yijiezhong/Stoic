import AppIntents
import Foundation

/// 系统专注模式与知止的联动。
/// 注意：macOS 不提供 app 主动切换系统专注的 API，所以这里是「系统专注变化 → 知止联动」。
struct StoicFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "知止专注联动"
    static let description = IntentDescription("系统专注模式切换时，自动开始或暂停知止的计时。")

    @Parameter(title: "进入专注时开始计时", default: true)
    var autoStart: Bool

    init() {}

    init(autoStart: Bool) {
        self.autoStart = autoStart
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "知止",
            subtitle: autoStart ? "进入专注时开始计时" : "进入专注时暂停计时"
        )
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if autoStart {
            AppDelegate.shared?.intentStartTimer()
        } else {
            AppDelegate.shared?.intentPauseTimer()
        }
        return .result()
    }
}