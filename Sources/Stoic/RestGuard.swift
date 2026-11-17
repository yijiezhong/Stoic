import Foundation
import AppKit
import CoreAudio

/// 休息期是否要弹全屏倒计时的判断逻辑。
public enum RestGuard {
    /// 麦克风是否被占用（会议中通常如此）。
    public static func isMicrophoneInUse() -> Bool {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        guard status == noErr, deviceID != 0 else { return false }

        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let runningStatus = AudioObjectGetPropertyData(
            deviceID, &runningAddress, 0, nil, &size, &running
        )
        return runningStatus == noErr && running != 0
    }

    /// 微信是否在前台。
    public static func isWeChatFrontmost() -> Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.tencent.xinWeChat"
    }

    /// Keynote 是否正在播放演示。
    public static func isKeynotePresenting() -> Bool {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.iWork.Keynote")
        guard !running.isEmpty else { return false }
        let script = NSAppleScript(source: "tell application \"Keynote\" to get playing of front document")
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        guard error == nil, let result else { return false }
        return result.booleanValue
    }

    /// 返回命中的例外原因；为空表示可以弹遮罩。
    public static func activeExceptions() -> [String] {
        var reasons: [String] = []
        if isMicrophoneInUse() { reasons.append("meeting") }
        if isWeChatFrontmost() { reasons.append("wechat") }
        if isKeynotePresenting() { reasons.append("keynote") }
        return reasons
    }
}
