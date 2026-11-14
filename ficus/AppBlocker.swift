//
//  AppBlocker.swift
//  Restricts the apps and websites picked in Settings while a focus session runs (Screen Time API).
//

import FamilyControls
import ManagedSettings
import SwiftUI

@MainActor
enum AppBlocker {
    private static let selectionKey = "blockedAppsSelection"
    private static let store = ManagedSettingsStore()

    /// The user's picked apps, categories and websites, persisted as JSON.
    static var selection: FamilyActivitySelection {
        get {
            UserDefaults.standard.data(forKey: selectionKey)
                .flatMap { try? JSONDecoder().decode(FamilyActivitySelection.self, from: $0) }
                ?? FamilyActivitySelection()
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: selectionKey)
        }
    }

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: SettingsKey.restrictApps) }

    /// Asks for Screen Time access. Returns whether it was granted.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return true
        } catch {
            return false
        }
    }

    /// Shields the chosen apps and sites, if the setting is on and access was granted.
    static func block() {
        guard isEnabled, AuthorizationCenter.shared.authorizationStatus == .approved else { return }
        let selection = selection
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    }

    static func unblock() {
        store.clearAllSettings()
    }
}
