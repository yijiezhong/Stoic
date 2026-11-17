import AppKit
import StoicCore

/// 休息期的全屏倒计时遮罩。
@MainActor
final class RestOverlayWindow {
    private var window: NSWindow?
    private var timeLabel: NSTextField?
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
        
        win.isReleasedWhenClosed = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        win.ignoresMouseEvents = false

        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.74).cgColor

        let big = NSTextField(labelWithString: model.menuBarText)
        big.font = NSFont.monospacedDigitSystemFont(ofSize: 168, weight: .bold)
        big.textColor = .white
        big.alignment = .center
        big.frame = NSRect(x: 0, y: frame.height / 2 - 60, width: frame.width, height: 200)
        container.addSubview(big)
        self.timeLabel = big

        let sub = NSTextField(labelWithString: model.isLongRest ? "长休息中" : "休息中")
        sub.font = NSFont.systemFont(ofSize: 30, weight: .medium)
        sub.textColor = NSColor.white.withAlphaComponent(0.85)
        sub.alignment = .center
        sub.frame = NSRect(x: 0, y: frame.height / 2 - 120, width: frame.width, height: 40)
        container.addSubview(sub)
        self.subtitle = sub

        let buttonWidth: CGFloat = 200
        let gap: CGFloat = 20
        let totalWidth = buttonWidth * 2 + gap
        let buttonY = frame.height / 2 - 220

        let startButton = makeOverlayButton(title: L10n.t("overlay.startWork"), action: #selector(startWorkTapped))
        startButton.frame = NSRect(x: (frame.width - totalWidth) / 2, y: buttonY, width: buttonWidth, height: 52)
        container.addSubview(startButton)

        let keepButton = makeOverlayButton(title: L10n.t("overlay.keepResting"), action: #selector(keepRestingTapped))
        keepButton.frame = NSRect(x: (frame.width - totalWidth) / 2 + buttonWidth + gap, y: buttonY, width: buttonWidth, height: 52)
        container.addSubview(keepButton)

        win.contentView = container
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
        win.makeKey()
        NSLog("[Stoic] overlay win=\(win.windowNumber) active=\(NSApp.isActive) frame=\(win.frame) visible=\(win.isVisible) level=\(win.level.rawValue) screens=\(NSScreen.screens.count)")
        window = win

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLabels() }
        }
    }

    private func refreshLabels() {
        guard let model else { return }
        timeLabel?.stringValue = model.menuBarText
        subtitle?.stringValue = model.isLongRest ? "长休息中" : "休息中"
    }

    private func makeOverlayButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 22, weight: .medium)
        button.contentTintColor = .white
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.20).cgColor
        button.layer?.cornerRadius = 10
        return button
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
        NSApp.setActivationPolicy(.accessory)
        timer?.invalidate()
        timer = nil
        window?.orderOut(nil)
        window?.close()
        window = nil
        timeLabel = nil
        subtitle = nil
    }
}
