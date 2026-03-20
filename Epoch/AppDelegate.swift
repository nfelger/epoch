import AppKit
import SwiftUI
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let timerModel = TimerModel()

    private var flashTimer: Timer?
    private var flashCount = 0
    private var lastObservedState: TimerState = .inactive
    private var lastPopoverCloseTime: Date = .distantPast
    private let timerIcon = NSImage(systemSymbolName: "timer", accessibilityDescription: "Epoch")!

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        if timerModel.state == .running || timerModel.state == .finished {
            menu.addItem(NSMenuItem(title: "Cancel Timer", action: #selector(cancelTimer), keyEquivalent: ""))
            menu.addItem(.separator())
        }
        menu.addItem(NSMenuItem(title: "About Epoch", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Epoch",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        return menu
    }

    @objc func cancelTimer() {
        flashTimer?.invalidate()
        flashTimer = nil
        timerModel.cancel()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = timerIcon
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 174, height: 174)
        popover.behavior = .transient
        popover.delegate = self
        let contentView = PopoverContentView(model: timerModel)
        let controller = NSViewController()
        controller.view = FirstMouseHostingView(rootView: contentView)
        popover.contentViewController = controller

        observeModel()
    }

    @objc func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            buildContextMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Suppress re-open if the popover just closed via .transient dismiss
            guard Date.now.timeIntervalSince(lastPopoverCloseTime) > 0.2 else { return }
            statusItem.length = 72
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
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
        let frozen = popover.isShown
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
            flashTimer?.invalidate()
            flashTimer = nil
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
        flashTimer?.invalidate()
        flashCount = 0
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                self.flashCount += 1
                let inverted = self.flashCount.isMultiple(of: 2)
                let title = NSMutableAttributedString(string: " 0:00")
                let range = NSRange(location: 0, length: title.length)
                if inverted {
                    title.addAttribute(.foregroundColor, value: NSColor.white, range: range)
                    title.addAttribute(.backgroundColor, value: NSColor.systemRed, range: range)
                } else {
                    title.addAttribute(.foregroundColor, value: NSColor.systemRed, range: range)
                }
                title.addAttribute(.font, value: NSFont.menuBarFont(ofSize: 0), range: range)
                self.statusItem.button?.attributedTitle = title
                if self.flashCount >= 10 {
                    timer.invalidate()
                    self.flashTimer = nil
                    self.timerModel.cancel()
                }
            }
        }
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        lastPopoverCloseTime = Date.now
        syncStatusItemLength()
    }

    private func syncStatusItemLength() {
        if timerModel.state == .inactive {
            statusItem.length = NSStatusItem.squareLength
        } else {
            statusItem.length = NSStatusItem.variableLength
        }
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

/// NSHostingView subclass that allows immediate drag interaction without click-to-focus.
class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
