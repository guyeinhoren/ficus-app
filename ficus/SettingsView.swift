//
//  SettingsView.swift
//

import FamilyControls
import SwiftUI

/// UserDefaults keys shared by the settings screen and the home screen.
enum SettingsKey {
    static let showHistory = "showHistoryGraph"
    static let countdownMode = "countdownMode"
    static let soundOnFinish = "soundOnFinish"
    static let minTreeSeconds = "minTreeSeconds"
    static let restrictApps = "restrictApps"
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.showHistory) private var showHistory = true
    @AppStorage(SettingsKey.countdownMode) private var countdownMode = false
    @AppStorage(SettingsKey.soundOnFinish) private var soundOnFinish = true
    @AppStorage(SettingsKey.minTreeSeconds) private var minTreeSeconds = 20 * 60.0
    @AppStorage(SettingsKey.restrictApps) private var restrictApps = false

    @State private var blockedSelection = AppBlocker.selection
    @State private var showingPicker = false

    private let minTreeOptions: [TimeInterval] = [5 * 60, 10 * 60, 20 * 60, 30 * 60]

    private var blockedCount: Int {
        blockedSelection.applicationTokens.count + blockedSelection.categoryTokens.count + blockedSelection.webDomainTokens.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("פוקוס") {
                    Toggle("הגבלת שימוש באפליקציות", isOn: $restrictApps)
                    if restrictApps {
                        Button {
                            showingPicker = true
                        } label: {
                            HStack {
                                Text("אפליקציות ואתרים מוגבלים")
                                Spacer()
                                Text("\(blockedCount)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    Toggle("גרף היסטוריית שעות", isOn: $showHistory)
                    Toggle("מצב ספירה לאחור", isOn: $countdownMode)
                    if countdownMode {
                        Toggle("צליל בסיום", isOn: $soundOnFinish)
                    }
                    if !countdownMode {
                        Picker("זמן מינימלי לעץ", selection: $minTreeSeconds) {
                            ForEach(minTreeOptions, id: \.self) { Text($0.hebrewLabel).tag($0) }
                        }
                    }
                }

                TreeGallery()
            }
            .animation(.default, value: countdownMode)
            .navigationTitle("הגדרות")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .familyActivityPicker(isPresented: $showingPicker, selection: $blockedSelection)
            .onChange(of: blockedSelection) { _, new in AppBlocker.selection = new }
            .onChange(of: restrictApps) { _, isOn in
                guard isOn else { return }
                Task {
                    // Without Screen Time access the restriction can't work, so switch it back off.
                    if await AppBlocker.requestAuthorization() == false { restrictApps = false }
                }
            }
            .onChange(of: soundOnFinish) { _, isOn in
                // A countdown can only chime while the app is closed through a notification sound.
                if isOn { Task { await FocusSession.requestNotificationAuthorization() } }
            }
        }
    }
}

// MARK: - Tree gallery

private struct TreeGallery: View {
    private struct Entry: Identifiable {
        let name: String
        let price: Int?   // nil = owned
        var id: String { name }
    }

    private let entries = [Entry(name: "אלון", price: nil), Entry(name: "קזוארינה", price: 200), Entry(name: "ארז", price: 200)]
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        Section {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(entries.prefix(1)) { TreeCard(entry: $0) }
                RealTreeCard()
                ForEach(entries.dropFirst()) { TreeCard(entry: $0) }
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            .listRowBackground(Color.clear)
        } header: {
            HStack {
                Text("עצים")
                Spacer()
                Label("11", systemImage: "trophy.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.background, in: .capsule)
            }
            .textCase(nil)
        }
    }

    /// Every card shares this exact square footprint, whatever its content.
    private struct SquareCard<Content: View, Background: View>: View {
        @ViewBuilder let background: Background
        @ViewBuilder let content: Content

        var body: some View {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .background { background }
                .overlay { content }
                .clipShape(.rect(cornerRadius: 24))
                .accessibilityElement(children: .combine)
        }
    }

    private struct TreeCard: View {
        let entry: Entry

        var body: some View {
            SquareCard {
                Color(.secondarySystemGroupedBackground)
            } content: {
                VStack(spacing: 10) {
                    Image("tree")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                        .opacity(entry.price == nil ? 1 : 0.8)

                    Text(entry.name)
                        .font(.headline)

                    if let price = entry.price {
                        Label("\(price)", systemImage: "trophy.fill")
                            .font(.footnote.weight(.bold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(.fill.tertiary, in: .capsule)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.footnote.weight(.bold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 6)
                            .background(.fill.tertiary, in: .capsule)
                    }
                }
            }
        }
    }

    private struct RealTreeCard: View {
        var body: some View {
            SquareCard {
                // Background views may not influence the card's size, so the photo is clipped to it.
                Color.clear.overlay {
                    Image("kkl_planting")
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .overlay { Color.black.opacity(0.25) }
            } content: {
                VStack(spacing: 4) {
                    Spacer()
                    Text("עץ אמיתי")
                        .font(.headline)
                    Text("בקרוב")
                        .font(.footnote.weight(.medium))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
                .padding(.bottom, 16)
            }
        }
    }
}

#Preview {
    SettingsView().environment(\.layoutDirection, .rightToLeft)
}
