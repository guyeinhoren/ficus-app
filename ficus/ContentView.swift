//
//  ContentView.swift
//  ficus
//
//  Created by גיא אינהורן on 04/10/2025.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(FocusSession.self) private var session

    @Query(sort: [SortDescriptor(\Tree.day), SortDescriptor(\Tree.slot)]) private var trees: [Tree]

    @AppStorage(SettingsKey.showHistory) private var showHistory = true
    @AppStorage(SettingsKey.countdownMode) private var countdownMode = false
    @AppStorage(SettingsKey.soundOnFinish) private var soundOnFinish = true
    @AppStorage(SettingsKey.minTreeSeconds) private var minTreeSeconds = 20 * 60.0

    @State private var today = Day.today
    @State private var shownDay = Day.today
    @State private var selectedDuration: TimeInterval = 30
    @State private var showCompletion = false
    @State private var showAbandonAlert = false
    @State private var showSettings = false

    /// Shared with `CompletionView` so the earned tree flies onto the island.
    @Namespace private var treeNamespace

    private var isRunning: Bool { session.isRunning }

    private var treesByDay: [Int32: [Tree]] { Dictionary(grouping: trees, by: \.day) }

    var body: some View {
        let byDay = treesByDay
        let shownTrees = byDay[shownDay, default: []]

        ZStack {
            home(byDay: byDay, shownTrees: shownTrees)
                // Kept in place (just hidden) so the completion tree can land exactly on the island.
                .opacity(showCompletion ? 0 : 1)

            if showCompletion {
                CompletionView(namespace: treeNamespace) {
                    withAnimation(.spring(response: 0.88, dampingFraction: 0.76)) { showCompletion = false }
                }
                .transition(.opacity)
            }
        }
        .alert("לוותר על העץ?", isPresented: $showAbandonAlert) {
            Button("המשך בפוקוס", role: .cancel) {}
            Button("וותר על העץ", role: .destructive) {
                withAnimation(.spring) { _ = session.end() }
            }
        } message: {
            Text("אם תצא עכשיו, העץ שאתה מגדל כרגע יינבל ולא יתווסף למשטח שלך.")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // Countdown sessions finish on their own; this survives suspension because it is date-based.
        .task(id: session.run) { await watchCountdown() }
        .task { await watchCalendarDay() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshDay() }
        }
        .onChange(of: FinishRequest.shared.isPending, initial: true) { _, isPending in
            guard isPending else { return }
            FinishRequest.shared.isPending = false
            finishTapped()
        }
    }

    // MARK: Home screen

    private func home(byDay: [Int32: [Tree]], shownTrees: [Tree]) -> some View {
        VStack(spacing: 0) {
            topArea(counts: byDay.mapValues(\.count))

            Spacer()

            headline(treeCount: shownTrees.count)
                .frame(height: 100)

            Spacer(minLength: 20)

            Group {
                if let run = session.run {
                    TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
                        FocusRingView(progress: run.progress(at: timeline.date))
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    IslandView(trees: shownTrees, namespace: treeNamespace)
                        .shadow(color: Color(hex: "68CDE3").opacity(0.12), radius: 30, y: 15)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 250)

            Spacer()

            if !isRunning && countdownMode {
                DurationSlider(duration: $selectedDuration)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            mainButton
                .padding(.bottom, 20)

            if !isRunning {
                Button("הגדרות") { showSettings = true }
                    .font(.headline)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .tint(Palette.navy)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isRunning)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: countdownMode)
    }

    @ViewBuilder
    private func topArea(counts: [Int32: Int]) -> some View {
        if !isRunning && showHistory {
            HistoryStrip(counts: counts, today: today, selectedDay: $shownDay)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        } else {
            Color.clear.frame(height: 40)
        }
    }

    @ViewBuilder
    private func headline(treeCount: Int) -> some View {
        if let run = session.run {
            TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
                Text(run.displayedTime(at: timeline.date).clockString)
                    .font(.system(size: 82, weight: .medium, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(LinearGradient(colors: [Palette.sky, Palette.navy], startPoint: .top, endPoint: .bottom))
            }
            .transition(.scale.combined(with: .opacity))
        } else {
            VStack(spacing: 6) {
                Text(Hebrew.plantedSummary(count: treeCount, day: shownDay))
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.secondary)
                if !countdownMode {
                    Text("זמן מינימלי לעץ: \(minTreeSeconds.hebrewLabel)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var mainButton: some View {
        if isRunning {
            Button("זהו", action: finishTapped)
                .font(.title2.weight(.bold))
                .buttonStyle(.glass)
                .tint(Palette.blue)
                .padding(.horizontal, 32)
        } else {
            Button(action: start) {
                Text("פוקוס")
                    .font(.largeTitle.weight(.bold))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.blue)
        }
    }

    // MARK: Actions

    private func start() {
        session.start(
            duration: countdownMode ? selectedDuration : minTreeSeconds,
            isCountdown: countdownMode,
            notifyOnFinish: soundOnFinish
        )
    }

    /// "זהו": plant if the tree has been earned, otherwise ask before giving up.
    private func finishTapped() {
        guard let run = session.run else { return }
        if run.hasEarnedTree(at: .now) {
            plantTree(chime: false)
        } else {
            showAbandonAlert = true
        }
    }

    private func plantTree(chime: Bool) {
        guard session.end() != nil else { return }
        let slot = trees.filter { $0.day == today }.count
        modelContext.insert(Tree(day: today, slot: slot, position: Island.spawnPoint(slot: slot)))
        if chime { FocusChime.play() }

        withAnimation(.spring(response: 0.85, dampingFraction: 0.78)) {
            shownDay = today
            showAbandonAlert = false
            showCompletion = true
        }
    }

    private func watchCountdown() async {
        guard let run = session.run, run.isCountdown else { return }
        let wait = run.end.timeIntervalSinceNow
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
        guard !Task.isCancelled else { return }
        // Chime only if we are watching it end; otherwise the notification already played it.
        let finishedJustNow = -run.end.timeIntervalSinceNow < 2
        plantTree(chime: soundOnFinish && scenePhase == .active && finishedJustNow)
    }

    // MARK: Calendar

    private func watchCalendarDay() async {
        for await _ in NotificationCenter.default.notifications(named: .NSCalendarDayChanged) {
            refreshDay()
        }
    }

    private func refreshDay() {
        let now = Day.today
        guard now != today else { return }
        if shownDay == today { shownDay = now }
        today = now
    }
}

#Preview {
    ContentView()
        .environment(FocusSession())
        .modelContainer(for: Tree.self, inMemory: true)
        .environment(\.layoutDirection, .rightToLeft)
}
