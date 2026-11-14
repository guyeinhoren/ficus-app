//
//  FocusRingView.swift
//  The ring and growing tree shown while a session is running.
//

import SwiftUI

struct FocusRingView: View {
    let progress: Double
    @State private var breathing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 6)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Image("tree")
                .resizable()
                .scaledToFit()
                .frame(width: 135, height: 135)
                // The tree grows from 25% to 100% with the session.
                .scaleEffect(0.25 + progress * 0.75)
                .scaleEffect(breathing ? 1.05 : 1, anchor: .bottom)
        }
        .frame(width: 250, height: 250)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever()) { breathing = true }
        }
        .accessibilityElement()
        .accessibilityLabel("התקדמות הפוקוס")
        .accessibilityValue(progress.formatted(.percent.precision(.fractionLength(0))))
    }
}
