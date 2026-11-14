//
//  FicusLiveActivity.swift
//  FicusLiveActivity
//
//  Created by גיא אינהורן on 14/11/2026.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct FicusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            LockScreenView(state: context.state, isStale: context.isStale)
                .padding(16)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TreeRing(state: context.state).frame(width: 52, height: 52)
                }
                DynamicIslandExpandedRegion(.center) {
                    ClockText(state: context.state, size: 30)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FinishButton()
                }
            } compactLeading: {
                Image("tree").resizable().scaledToFit().frame(width: 20, height: 20)
            } compactTrailing: {
                ClockText(state: context.state, size: 14).frame(width: 44)
            } minimal: {
                Image("tree").resizable().scaledToFit().frame(width: 20, height: 20)
            }
            .keylineTint(.blue)
        }
    }
}

// MARK: - Lock Screen

/// Laid out right-to-left: the tree-in-a-ring on the right, the timer beside it, "זהו" on the left.
private struct LockScreenView: View {
    let state: FocusActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        HStack(spacing: 14) {
            TreeRing(state: state).frame(width: 60, height: 60)

            if isStale {
                Text("הסתיים").font(.title2.weight(.semibold))
            } else {
                ClockText(state: state, size: 40)
            }

            Spacer(minLength: 0)

            FinishButton()
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Pieces

/// The tree inside the circle of time. The ring fills on its own, driven by the system clock.
private struct TreeRing: View {
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        ZStack {
            ProgressView(timerInterval: state.start...state.end, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
            .tint(.blue)

            // The tree stays clear of the ring, with a visible gap.
            Image("tree").resizable().scaledToFit().padding(12)
        }
    }
}

private struct ClockText: View {
    let state: FocusActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        Group {
            if state.isCountdown {
                Text(timerInterval: state.start...state.end, pauseTime: nil, countsDown: true, showsHours: false)
            } else {
                Text(state.start, style: .timer)
            }
        }
        .font(.system(size: size, weight: .medium, design: .rounded).monospacedDigit())
        .foregroundStyle(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FinishButton: View {
    var body: some View {
        Button(intent: FinishFocusIntent()) {
            Text("זהו")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(.blue, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Lock Screen", as: .content, using: FocusActivityAttributes()) {
    FicusLiveActivity()
} contentStates: {
    FocusActivityAttributes.ContentState(start: .now.addingTimeInterval(-300), end: .now.addingTimeInterval(1200), isCountdown: true)
    FocusActivityAttributes.ContentState(start: .now.addingTimeInterval(-300), end: .now.addingTimeInterval(900), isCountdown: false)
}
