//
//  SettingsView.swift
//

import SwiftUI

/// UserDefaults keys shared by the settings screen and the home screen.
enum SettingsKey {
    static let showHistory = "showHistoryGraph"
    static let countdownMode = "countdownMode"
    static let soundOnFinish = "soundOnFinish"
    static let minTreeSeconds = "minTreeSeconds"
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.showHistory) private var showHistory = true
    @AppStorage(SettingsKey.countdownMode) private var countdownMode = false
    @AppStorage(SettingsKey.soundOnFinish) private var soundOnFinish = true
    @AppStorage(SettingsKey.minTreeSeconds) private var minTreeSeconds = 20 * 60.0

    private let minTreeOptions: [TimeInterval] = [30, 5 * 60, 10 * 60, 20 * 60, 30 * 60]

    var body: some View {
        NavigationStack {
            Form {
                Section("פוקוס") {
                    Toggle("הצגת גרף היסטוריית שעות", isOn: $showHistory)
                    Toggle("מצב ספירה לאחור", isOn: $countdownMode)
                    if countdownMode {
                        Toggle("צליל בסיום", isOn: $soundOnFinish)
                    }
                    Picker("זמן מינימלי לעץ", selection: $minTreeSeconds) {
                        ForEach(minTreeOptions, id: \.self) { Text($0.hebrewLabel).tag($0) }
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

    private struct TreeCard: View {
        let entry: Entry

        var body: some View {
            VStack(spacing: 10) {
                Image("tree")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
                    .opacity(entry.price == nil ? 1 : 0.8)
                    .padding(.top, 14)

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
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
            .accessibilityElement(children: .combine)
        }
    }

    private struct RealTreeCard: View {
        var body: some View {
            Image("kkl_planting")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 156)
                .overlay { Color.black.opacity(0.12) }
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 4) {
                        Text("קק״ל").font(.caption2.weight(.bold))
                        Image("kkl_logo").resizable().scaledToFit().frame(width: 12, height: 12)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Palette.blue.opacity(0.92), in: .rect(cornerRadius: 8))
                    .padding(10)
                }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 8) {
                        Text("עץ אמיתי")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
                        Button("לפרטים") {}
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.glass)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                    }
                    .padding(.bottom, 10)
                }
                .clipShape(.rect(cornerRadius: 24))
        }
    }
}

#Preview {
    SettingsView().environment(\.layoutDirection, .rightToLeft)
}
