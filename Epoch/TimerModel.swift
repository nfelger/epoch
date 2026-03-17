import Foundation
import AppKit
import UserNotifications

enum TimerState { case inactive, running, finished }

@Observable @MainActor
final class TimerModel {
    var state: TimerState = .inactive
    var totalDuration: TimeInterval = 0
    var remaining: TimeInterval = 0
    var endDate: Date?

    private var countdownTimer: Timer?

    func start(duration: TimeInterval) {
        guard duration >= 60 else { return }
        countdownTimer?.invalidate()
        countdownTimer = nil
        state = .running
        totalDuration = duration
        remaining = duration
        endDate = Date.now.addingTimeInterval(duration)
        countdownTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    func cancel() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        state = .inactive
        remaining = 0
        endDate = nil
    }

    func adjustRemaining(to duration: TimeInterval) {
        guard state == .running else { return }
        if duration <= 0 {
            countdownTimer?.invalidate()
            countdownTimer = nil
            finishCountdown()
            return
        }
        endDate = Date.now.addingTimeInterval(duration)
        remaining = duration
    }

    private func tick() {
        guard state == .running, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining == 0 {
            countdownTimer?.invalidate()
            countdownTimer = nil
            finishCountdown()
        }
    }

    private func finishCountdown() {
        state = .finished
        if let sound = NSSound(named: "Glass") ?? NSSound(named: "Purr") {
            sound.play()
        } else {
            NSSound.beep()
        }
        scheduleNotification()
    }

    private func scheduleNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Timer finished"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }
}
