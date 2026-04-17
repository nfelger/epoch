import AppKit
import SwiftUI
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: NSPanel!
    var overlayPanel: NSPanel!
    let timerModel = TimerModel()

    private var flashTimer: Timer?
    private var lastObservedState: TimerState = .inactive
    private var lastPanelCloseTime: Date = .distantPast
    private var eventMonitor: Any?
    private let timerIcon = NSImage(systemSymbolName: "timer", accessibilityDescription: "Epoch")!

    private var showTimerOverlay: Bool {
        get {
            if UserDefaults.standard.object(forKey: "showTimerOverlay") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "showTimerOverlay")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "showTimerOverlay")
        }
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        if timerModel.state == .running || timerModel.state == .finished {
            menu.addItem(NSMenuItem(title: "Cancel Timer", action: #selector(cancelTimer), keyEquivalent: ""))
            menu.addItem(.separator())
        }

        let overlayItem = NSMenuItem(
            title: "Show Timer Overlay",
            action: #selector(toggleOverlaySetting),
            keyEquivalent: ""
        )
        overlayItem.state = showTimerOverlay ? .on : .off
        menu.addItem(overlayItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "About Epoch", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Epoch",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        return menu
    }

    @objc func toggleOverlaySetting() {
        showTimerOverlay.toggle()
        if showTimerOverlay {
            if timerModel.state == .running || timerModel.state == .finished {
                showOverlay()
            }
        } else {
            hideOverlay()
        }
    }

    private func showOverlay() {
        overlayPanel.makeKeyAndOrderFront(nil)
    }

    @objc func cancelTimer() {
        stopFlashAnimation()
        timerModel.cancel()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = timerIcon
            button.action = #selector(togglePanel)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let panelSize = NSSize(width: 174, height: 174)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .popUpMenu

        let visualEffect = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true

        let hostingView = FirstMouseHostingView(rootView: PopoverContentView(model: timerModel))
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.autoresizingMask = [.width, .height]
        visualEffect.addSubview(hostingView)
        panel.contentView = visualEffect

        // Overlay panel
        let overlayPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        overlayPanel.titlebarAppearsTransparent = true
        overlayPanel.titleVisibility = .hidden
        overlayPanel.backgroundColor = .clear
        overlayPanel.isOpaque = false
        overlayPanel.hasShadow = true
        overlayPanel.level = .floating
        overlayPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlayPanel.isMovableByWindowBackground = true
        overlayPanel.animationBehavior = .utilityWindow

        let overlayVisualEffect = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
        overlayVisualEffect.material = .popover
        overlayVisualEffect.blendingMode = .behindWindow
        overlayVisualEffect.state = .active
        overlayVisualEffect.wantsLayer = true
        overlayVisualEffect.layer?.cornerRadius = 12
        overlayVisualEffect.layer?.masksToBounds = true

        let overlayHostingView = FirstMouseHostingView(rootView: OverlayContentView(model: timerModel))
        overlayHostingView.frame = NSRect(origin: .zero, size: panelSize)
        overlayHostingView.autoresizingMask = [.width, .height]
        overlayVisualEffect.addSubview(overlayHostingView)
        overlayPanel.contentView = overlayVisualEffect
        overlayPanel.delegate = self
        self.overlayPanel = overlayPanel

        observeModel()
    }

    @objc func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc func togglePanel() {
        guard let button = statusItem.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            buildContextMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
            return
        }
        if panel.isVisible {
            hidePanel()
        } else {
            guard Date.now.timeIntervalSince(lastPanelCloseTime) > 0.2 else { return }
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }

        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonRectOnScreen = buttonWindow.convertToScreen(buttonRectInWindow)

        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height
        var panelX = buttonRectOnScreen.midX - panelWidth / 2
        let panelY = buttonRectOnScreen.minY - panelHeight - 6

        if let screen = buttonWindow.screen ?? NSScreen.main {
            panelX = max(screen.visibleFrame.minX, min(panelX, screen.visibleFrame.maxX - panelWidth))
        }

        // Freeze width to prevent the countdown text from resizing the button while the panel is open
        statusItem.length = 72
        panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hidePanel()
        }
    }

    private func hidePanel() {
        panel.orderOut(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        lastPanelCloseTime = Date.now
        syncStatusItemLength()
    }

    // MARK: - Model Observation

    private func observeModel() {
        withObservationTracking {
            updateStatusItem()
            handleStateTransitions()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeModel()
            }
        }
    }

    private func updateStatusItem() {
        let frozen = panel.isVisible
        switch timerModel.state {
        case .inactive:
            if !frozen { statusItem.length = NSStatusItem.squareLength }
            statusItem.button?.image = timerIcon
            statusItem.button?.title = ""
        case .running:
            let total = Int(timerModel.remaining)
            let hrs = total / 3600
            let mins = (total % 3600) / 60
            let secs = total % 60
            let label = hrs > 0
                ? String(format: "%d:%02d:%02d", hrs, mins, secs)
                : String(format: "%d:%02d", mins, secs)
            if !frozen { statusItem.length = NSStatusItem.variableLength }
            statusItem.button?.image = nil
            statusItem.button?.title = " \(label)"
        case .finished:
            if !frozen { statusItem.length = NSStatusItem.variableLength }
            statusItem.button?.image = nil
        }
    }

    private func handleStateTransitions() {
        let currentState = timerModel.state
        let previousState = lastObservedState
        lastObservedState = currentState

        if currentState == .running, previousState != .running {
            requestNotificationPermissionIfNeeded()
        }
        if currentState == .finished, previousState != .finished {
            playCompletionSound()
            scheduleCompletionNotification()
            startFlashSequence()
        }
        if currentState == .inactive, previousState == .finished {
            stopFlashAnimation()
        }
    }

    private func hideOverlay() {
        overlayPanel.orderOut(nil)
    }

    private func syncStatusItemLength() {
        if timerModel.state == .inactive {
            statusItem.length = NSStatusItem.squareLength
        } else {
            statusItem.length = NSStatusItem.variableLength
        }
    }

    // MARK: - Notification Permission

    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
        }
    }

    // MARK: - Completion Effects

    private func playCompletionSound() {
        let soundPath = "/System/Library/Components/CoreAudio.component" +
            "/Contents/SharedSupport/SystemSounds/system/burn complete.aif"
        let burnComplete = NSSound(contentsOfFile: soundPath, byReference: true)
        if let sound = burnComplete ?? NSSound(named: "Glass") ?? NSSound(named: "Purr") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func scheduleCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Timer finished"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    // MARK: - Flash Sequence

    private func startFlashSequence() {
        stopFlashAnimation()

        if !panel.isVisible { statusItem.length = NSStatusItem.squareLength }
        statusItem.button?.title = ""

        let config = NSImage.SymbolConfiguration.preferringMulticolor()
        let steps = 6
        let interval = 0.175
        let totalTicks = Int(8.0 / interval)
        var tick = 0

        flashTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                let variableValue = Double(tick % steps) / Double(steps - 1)
                let image = NSImage(
                    systemSymbolName: "rainbow",
                    variableValue: variableValue,
                    accessibilityDescription: nil
                )?.withSymbolConfiguration(config)
                image?.isTemplate = false
                self.statusItem.button?.image = image
                tick += 1
                if tick >= totalTicks {
                    timer.invalidate()
                    self.flashTimer = nil
                    self.timerModel.cancel()
                }
            }
        }
    }

    private func stopFlashAnimation() {
        flashTimer?.invalidate()
        flashTimer = nil
    }
}

extension AppDelegate: @preconcurrency UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner, .sound])
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === overlayPanel {
            hideOverlay()
            return false
        }
        return true
    }
}

/// NSHostingView subclass that allows immediate drag interaction without click-to-focus.
class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
