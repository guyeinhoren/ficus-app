//
//  DurationSlider.swift
//  Snapping duration slider: the system Slider, with the chosen time beside it.
//

import SwiftUI

struct DurationSlider: View {
    @Binding var duration: TimeInterval

    /// Every 5 minutes, from 5 minutes up to 2 hours.
    static let presets: [TimeInterval] = (1...24).map { TimeInterval($0 * 5 * 60) }
    /// The only marked values, as preset indices: 5 minutes, 1 hour, 2 hours.
    private let marks: [Double] = [0, 11, 23]
    /// How close (in presets) the thumb must get to a mark before it sticks to it.
    /// Kept under half a step so the neighbouring 5-minute values (e.g. 55 min, 1:05) stay selectable.
    private let magnetRange = 0.3

    /// Where the finger is, in preset indices. Between the marks `duration` follows it in 5-minute steps.
    @State private var position = 0.0

    /// What the thumb shows: the nearest mark when close to one, otherwise the nearest preset.
    private var snappedPosition: Double {
        if let mark = marks.first(where: { abs($0 - position) <= magnetRange }) { return mark }
        return position.rounded()
    }

    /// Fixed, so the slider keeps its length whatever the label says.
    @ScaledMetric(relativeTo: .subheadline) private var labelWidth: CGFloat = 88

    var body: some View {
        HStack(spacing: 14) {
            Text(duration.hebrewLabel)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.blue)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: labelWidth, alignment: .leading)
                .contentTransition(.numericText())
                .animation(.snappy, value: duration)

            // The thumb is bound to the snapped value, so the magnet is ours and works only at the marks.
            Slider(value: Binding(get: { snappedPosition }, set: { position = $0 }),
                   in: 0...Double(Self.presets.count - 1),
                   step: 1) {
                Text("משך הפוקוס")
            } tick: { value in
                marks.contains(value) ? SliderTick(value) : nil
            }
            .tint(.blue)
            .accessibilityValue(duration.hebrewLabel)
        }
        .padding(.horizontal, 32)
        .onAppear { position = Double(Self.presets.firstIndex(of: duration) ?? 0) }
        .onChange(of: snappedPosition) { _, new in
            duration = Self.presets[Int(new)]
        }
    }
}
