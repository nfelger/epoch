import AppKit
import SwiftUI
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: NSPanel!
    var overlayPanel: NSPanel!
    var overlayBackground: NSVisualEffectView!
    let timerModel = TimerModel()

    private var flashTimer: Timer?
    private var lastObservedState: TimerState = .inactive
    private var lastPanelCloseTime: Date = .distantPast
    private var eventMonitor: Any?
    private let timerIcon = NSImage(systemSymbolName: "timer", accessibilityDescription: "Epoch")!
    private var hasShownOverlayOnce = false
    private var showTimerOverlay: Bool {
        get {
            UserDefaults.standard.object(forKey: "showTimerOverlay") == nil
                || UserDefaults.standard.bool(forKey: "showTimerOverlay")
        }
        set { UserDefaults.standard.set(newValue, forKey: "showTimerOverlay") }
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        if timerModel.state == .running || timerModel.state == .finished {
            menu.addItem(NSMenuItem(title: "Cancel Timer", action: #selector(cancelTimer), keyEquivalent: ""))
            menu.addItem(.separator())
        }
        let overlayItem = NSMenuItem(
            title: "Show Timer Overlay", action: #selector(toggleOverlaySetting), keyEquivalent: ""
        )
        overlayItem.state = showTimerOverlay ? .on : .off
        menu.addItem(overlayItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "About Epoch", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Epoch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        ))
        return menu
    }

    @objc func cancelTimer() {
        stopFlashAnimation()
        hideOverlay()
        timerModel.cancel()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
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
        setupPopoverPanel()
        setupOverlayPanel()
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
        if timerModel.state == .running || timerModel.state == .finished {
            if overlayPanel.isVisible {
                hideOverlay()
            } else if showTimerOverlay {
                showOverlay()
            } else {
                if panel.isVisible { hidePanel() } else {
                    guard Date.now.timeIntervalSince(lastPanelCloseTime) > 0.2 else { return }
                    showPanel()
                }
            }
        } else {
            if panel.isVisible { hidePanel() } else {
                guard Date.now.timeIntervalSince(lastPanelCloseTime) > 0.2 else { return }
                showPanel()
            }
        }
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
        updateOverlayOpacity()
    }

    private func handleStateTransitions() {
        let currentState = timerModel.state
        let previousState = lastObservedState
        lastObservedState = currentState
        if currentState == .running, previousState != .running {
            requestNotificationPermissionIfNeeded()
            showOverlay()
            hidePanel()
        }
        if currentState == .finished, previousState != .finished {
            playCompletionSound()
            scheduleCompletionNotification()
            startFlashSequence()
            updateOverlayOpacity()
        }
        if currentState == .inactive, previousState != .inactive {
            if previousState == .finished { stopFlashAnimation() }
            hideOverlay()
            hasShownOverlayOnce = false
        }
    }
}

// MARK: - Panel Management

extension AppDelegate {
    private func setupPopoverPanel() {
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
        let visualEffect = makeVibrancyView(size: panelSize)
        let hostingView = FirstMouseHostingView(rootView: PopoverContentView(model: timerModel))
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.autoresizingMask = [.width, .height]
        visualEffect.addSubview(hostingView)
        panel.contentView = visualEffect
    }

    private func setupOverlayPanel() {
        let panelSize = NSSize(width: 174, height: 174)
        let newPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.titlebarAppearsTransparent = true
        newPanel.titleVisibility = .hidden
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isMovableByWindowBackground = true
        newPanel.animationBehavior = .utilityWindow
        let container = NSView(frame: NSRect(origin: .zero, size: panelSize))
        let background = makeVibrancyView(size: panelSize)
        let overlayHostingView = FirstMouseHostingView(rootView: OverlayContentView(model: timerModel))
        overlayHostingView.frame = NSRect(origin: .zero, size: panelSize)
        overlayHostingView.autoresizingMask = [.width, .height]
        container.addSubview(background)
        container.addSubview(overlayHostingView)
        newPanel.contentView = container
        newPanel.delegate = self
        overlayPanel = newPanel
        overlayBackground = background
    }

    private func makeVibrancyView(size: NSSize) -> NSVisualEffectView {
        let view = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        view.layer?.masksToBounds = true
        return view
    }

    private func positionPanelBelowMenubar(_ targetPanel: NSPanel) {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonRectOnScreen = buttonWindow.convertToScreen(buttonRectInWindow)
        var panelX = buttonRectOnScreen.midX - targetPanel.frame.width / 2
        let panelY = buttonRectOnScreen.minY - targetPanel.frame.height - 6
        if let screen = buttonWindow.screen ?? NSScreen.main {
            panelX = max(screen.visibleFrame.minX, min(panelX, screen.visibleFrame.maxX - targetPanel.frame.width))
        }
        targetPanel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
    }

    private func showPanel() {
        positionPanelBelowMenubar(panel)
        // Freeze width to prevent the countdown text from resizing the button while the panel is open
        statusItem.length = 72
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

    private func hideOverlay() {
        overlayPanel.orderOut(nil)
    }

    private func showOverlay() {
        guard showTimerOverlay else { return }
        if !hasShownOverlayOnce {
            positionPanelBelowMenubar(overlayPanel)
            hasShownOverlayOnce = true
        }
        overlayPanel.orderFront(nil)
        updateOverlayOpacity()
    }

    @objc func toggleOverlaySetting() {
        showTimerOverlay.toggle()
        let timerActive = timerModel.state == .running || timerModel.state == .finished
        if showTimerOverlay, timerActive { showOverlay() } else { hideOverlay() }
    }

    private func updateOverlayOpacity() {
        overlayBackground.alphaValue = timerModel.state == .finished ? 1.0 : 0.5
    }

    private func syncStatusItemLength() {
        statusItem.length = timerModel.state == .inactive ? NSStatusItem.squareLength : NSStatusItem.variableLength
    }
}

// MARK: - Completion Effects

extension AppDelegate {
    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
        }
    }

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
