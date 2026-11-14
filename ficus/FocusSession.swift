//
//  FocusSession.swift
//  The running focus session: persisted, date-based, mirrored to a Live Activity.
//

import ActivityKit
import AVFoundation
import SwiftUI
import UserNotifications

/// A focus session, described only by dates so it survives suspension and relaunch.
struct FocusRun: Codable, Equatable {
    let start: Date
    /// Countdown: the chosen length. Count-up: the minimum time that earns a tree.
    let target: TimeInterval
    let isCountdown: Bool

    var end: Date { start.addingTimeInterval(target) }

    func elapsed(at date: Date) -> TimeInterval { max(0, date.timeIntervalSince(start)) }
    func remaining(at date: Date) -> TimeInterval { max(0, target - elapsed(at: date)) }
    func progress(at date: Date) -> Double { min(1, elapsed(at: date) / target) }
    func hasEarnedTree(at date: Date) -> Bool { elapsed(at: date) >= target }

    /// The number shown on the clock: time left when counting down, time passed when counting up.
    func displayedTime(at date: Date) -> TimeInterval {
        isCountdown ? remaining(at: date) : elapsed(at: date)
    }
}

@MainActor @Observable
final class FocusSession {
    private(set) var run: FocusRun?
    var isRunning: Bool { run != nil }

    @ObservationIgnored private var activity: Activity<FocusActivityAttributes>?
    @ObservationIgnored private let defaults = UserDefaults.standard
    private static let runKey = "activeFocusRun"
    private static let notificationID = "focus-finished"

    init() {
        if let data = defaults.data(forKey: Self.runKey),
           let saved = try? JSONDecoder().decode(FocusRun.self, from: data) {
            run = saved
            activity = Activity<FocusActivityAttributes>.activities.first
            if activity == nil { startActivity(for: saved) }
        }
    }

    func start(duration: TimeInterval, isCountdown: Bool, notifyOnFinish: Bool) {
        guard run == nil else { return }
        let new = FocusRun(start: .now, target: duration, isCountdown: isCountdown)
        run = new
        persist()
        startActivity(for: new)
        if isCountdown && notifyOnFinish { scheduleFinishNotification(at: new.end) }
    }

    /// Ends the session and returns it (nil if none was running).
    @discardableResult
    func end() -> FocusRun? {
        defer {
            run = nil
            persist()
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
            let ending = activity
            activity = nil
            Task { await ending?.end(nil, dismissalPolicy: .immediate) }
        }
        return run
    }

    // MARK: Persistence

    private func persist() {
        defaults.set(run.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.runKey)
    }

    // MARK: Live Activity

    private func startActivity(for run: FocusRun) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = FocusActivityAttributes.ContentState(start: run.start, end: run.end, isCountdown: run.isCountdown)
        let content = ActivityContent(state: state, staleDate: run.isCountdown ? run.end : nil)
        activity = try? Activity.request(attributes: FocusActivityAttributes(), content: content)
    }

    // MARK: Finish notification (the only way to chime while the app is suspended)

    static func requestNotificationAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    private func scheduleFinishNotification(at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "העץ שלך צמח 🌳"
        content.body = "סיימת את זמן הפוקוס."
        content.sound = UNNotificationSound(named: UNNotificationSoundName(FocusChime.fileName))
        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

/// The soft chime played when a countdown ends while the app is on screen.
@MainActor
enum FocusChime {
    static let fileName = "finish_chime.caf"
    private static var player: AVAudioPlayer?

    static func play() {
        guard let url = Bundle.main.url(forResource: "finish_chime", withExtension: "caf") else { return }
        // `.ambient` respects the silent switch and mixes with other audio.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
