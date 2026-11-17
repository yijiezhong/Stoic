import AppKit
import StoicCore

/// 休息期的全屏倒计时遮罩（纯 AppKit，避免 SwiftUI 托管窗口的生命周期问题）。
@MainActor
final class RestOverlayWindow {
    private var window: NSWindow?
    private var label: NSTextField?
    private var subtitle: NSTextField?
    private var timer: Timer?
    private weak var model: TimerModel?
    private var onStartWork: (() -> Void)?
    private var onKeepResting: (() -> Void)?

    var isVisible: Bool { window != nil }

    func show(model: TimerModel, onStartWork: @escaping () -> Void, onKeepResting: @escaping () -> Void) {
        guard window == nil else { return }
        self.model = model
        self.onStartWork = onStartWork
        self.onKeepResting = onKeepResting

        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let win = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        win.level = .screenSaver
        win.isOpaque = false
        win.backgroundColor = .clear
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.74).cgColor

        let timeLabel = NSTextField(labelWithString: model.menuBarText)
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 168, weight: .bold)
        timeLabel.textColor = .white
        timeLabel.alignment = .center
        timeLabel.frame = NSRect(x: 0, y: frame.height / 2 - 60, width: frame.width, height: 200)
        container.addSubview(timeLabel)
        self.label = timeLabel

        let sub = NSTextField(labelWithString: model.isLongRest ? "长休息中" : "休息中")
        sub.font = NSFont.systemFont(ofSize: 30, weight: .medium)
        sub.textColor = NSColor.white.withAlphaComponent(0.85)
        sub.alignment = .center
        sub.frame = NSRect(x: 0, y: frame.height / 2 - 130, width: frame.width, height: 40)
        container.addSubview(sub)
        self.subtitle = sub

        let buttonWidth: CGFloat = 200
        let gap: CGFloat = 20
        let totalWidth = buttonWidth * 2 + gap
        let buttonY = frame.height / 2 - 230

        let startButton = NSButton(title: L10n.t("overlay.startWork"), target: self, action: #selector(startWorkTapped))
        startButton.bezelStyle = .rounded
        startButton.font = NSFont.systemFont(ofSize: 22, weight: .medium)
        startButton.frame = NSRect(x: (frame.width - totalWidth) / 2, y: buttonY, width: buttonWidth, height: 52)
        container.addSubview(startButton)

        let keepButton = NSButton(title: L10n.t("overlay.keepResting"), target: self, action: #selector(keepRestingTapped))
        keepButton.bezelStyle = .rounded
        keepButton.font = NSFont.systemFont(ofSize: 22, weight: .medium)
        keepButton.frame = NSRect(x: (frame.width - totalWidth) / 2 + buttonWidth + gap, y: buttonY, width: buttonWidth, height: 52)
        container.addSubview(keepButton)

        win.contentView = container
        win.makeKeyAndOrderFront(nil)
        window = win

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshLabels() }
        }
    }

    private func refreshLabels() {
        guard let model else { return }
        label?.stringValue = model.menuBarText
        subtitle?.stringValue = model.isLongRest ? "长休息中" : "休息中"
    }

    @objc private func startWorkTapped() {
        hide()
        onStartWork?()
    }

    @objc private func keepRestingTapped() {
        hide()
        onKeepResting?()
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        window?.orderOut(nil)
        window?.close()
        window = nil
        label = nil
        subtitle = nil
    }
}
