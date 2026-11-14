//
//  FocusActivity.swift
//  Live Activity contract shared by the app (which drives it) and the extension (which draws it).
//

import ActivityKit
import AppIntents
import Foundation

nonisolated struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the focus session started.
        var start: Date
        /// Countdown: when the session finishes. Count-up: when the tree is earned.
        var end: Date
        var isCountdown: Bool
    }
}

/// Set by the Live Activity's "זהו" button; the app consumes it as soon as its UI is up.
/// A flag (rather than a notification) so a cold launch triggered by the intent can't miss it.
@MainActor @Observable
final class FinishRequest {
    static let shared = FinishRequest()
    var isPending = false
}

struct FinishFocusIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "סיום פוקוס"
    static let supportedModes: IntentModes = .foreground(.immediate)

    func perform() async throws -> some IntentResult {
        await MainActor.run { FinishRequest.shared.isPending = true }
        return .result()
    }
}
