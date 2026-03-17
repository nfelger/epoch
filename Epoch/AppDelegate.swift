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
    private let timerIcon = NSImage(systemSymbolName: "timer", accessibilityDescription: "Epoch")!

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
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 240, height: 280)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(model: timerModel)
        )

        observeModel()
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
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
        switch timerModel.state {
        case .inactive:
            statusItem.length = NSStatusItem.squareLength
            statusItem.button?.image = timerIcon
            statusItem.button?.title = ""
        case .running:
            let m = Int(timerModel.remaining) / 60
            let s = Int(timerModel.remaining) % 60
            let label = m >= 60
                ? String(format: "%d:%02d", m / 60, m % 60)
                : String(format: "%d:%02d", m, s)
            statusItem.length = 56
            statusItem.button?.image = nil
            statusItem.button?.title = " \(label)"
        case .finished:
            break
        }
    }

    private func handleStateTransitions() {
        if timerModel.state == .running {
            requestNotificationPermissionIfNeeded()
            if popover.isShown {
                DispatchQueue.main.async { [weak self] in
                    self?.popover.close()
                }
            }
        }
        if timerModel.state == .finished {
            startFlashSequence()
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

    // MARK: - Flash Sequence

    private func startFlashSequence() {
        flashTimer?.invalidate()
        flashCount = 0
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.125, repeats: true) { [weak self] t in
            MainActor.assumeIsolated {
                guard let self else { t.invalidate(); return }
                self.flashCount += 1
                self.statusItem.button?.image = self.flashCount.isMultiple(of: 2) ? self.timerIcon : nil
                if self.flashCount >= 16 {
                    t.invalidate()
                    self.flashTimer = nil
                    self.timerModel.cancel()
                }
            }
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
