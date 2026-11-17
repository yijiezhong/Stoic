import Foundation
import AppKit

/// 开机自动启动：用 LaunchAgent（SMAppService 需要有效签名，adhoc 下报 notFound）。
public enum LaunchAtLogin {
    private static let label = "com.zhizhi.stoic"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    public static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    public static var statusText: String {
        isEnabled ? "enabled" : "notRegistered"
    }

    @discardableResult
    public static func setEnabled(_ enabled: Bool) -> Bool {
        if enabled {
            writePlist()
            // 已在运行时不立即 bootstrap，避免出现第二个实例；下次登录生效。
            let running = !NSRunningApplication.runningApplications(withBundleIdentifier: label).isEmpty
            if !running {
                runLaunchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
            }
            return true
        } else {
            runLaunchctl(["bootout", "gui/\(getuid())/\(label)"])
            try? FileManager.default.removeItem(at: plistURL)
            return true
        }
    }

    private static func writePlist() {
        let exe = "/Applications/Stoic.app/Contents/MacOS/Stoic"
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array><string>\(exe)</string></array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
            <key>ProcessType</key>
            <string>Interactive</string>
        </dict>
        </plist>
        """
        let dir = plistURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? plist.write(to: plistURL, atomically: true, encoding: .utf8)
    }

    private static func runLaunchctl(_ args: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
