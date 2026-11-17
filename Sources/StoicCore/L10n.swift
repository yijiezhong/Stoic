import Foundation

/// 轻量本地化层：文案集中在 Resources 的语言表里，视图不再散落中英文字面量。
/// 语言显式按系统首选语言选择，避免 SPM/Xcode 资源 bundle 的本地化推断偏差。
public enum L10n {
    private static let localizedBundle: Bundle = {
        let preferred = Locale.preferredLanguages.first ?? "zh-Hans"
        let code = preferred.hasPrefix("zh") ? "zh-Hans" : "en"
        if let path = Bundle.module.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return Bundle.module
    }()

    public static func t(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: localizedBundle, value: key, comment: "")
    }

    public static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), locale: Locale.current, arguments: args)
    }
}
