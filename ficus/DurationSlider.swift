//
//  DurationSlider.swift
//  Snapping duration slider: blue fill, section dots below the track, current value beside it.
//

import SwiftUI

struct DurationSlider: View {
    @Binding var duration: TimeInterval
    @Environment(\.layoutDirection) private var layoutDirection

    /// 30 seconds, then every 5 minutes up to 2 hours.
    static let presets: [TimeInterval] = [30] + (1...24).map { TimeInterval($0 * 5 * 60) }
    /// Preset indices marked with a dot: the start, then every half hour.
    private let sectionIndices = [0, 6, 12, 18, 24]

    private let knobSize = CGSize(width: 40, height: 26)
    private let trackHeight: CGFloat = 6

    private var index: Int { Self.presets.firstIndex(of: duration) ?? 0 }
    private var progress: CGFloat { CGFloat(index) / CGFloat(Self.presets.count - 1) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                track
                sectionDots
            }

            Text(duration.hebrewLabel)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Palette.blue)
                .frame(minWidth: 76, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(.snappy, value: duration)
        }
        .padding(.horizontal, 28)
        .sensoryFeedback(.selection, trigger: duration)
        .accessibilityElement()
        .accessibilityLabel("משך הפוקוס")
        .accessibilityValue(duration.hebrewLabel)
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? 1 : -1
            duration = Self.presets[min(max(index + step, 0), Self.presets.count - 1)]
        }
    }

    // All horizontal placement uses leading padding, so it mirrors automatically in right-to-left.
    private var track: some View {
        GeometryReader { proxy in
            let usable = proxy.size.width - knobSize.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                    .frame(height: trackHeight)

                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "38A1FF"), Palette.blue], startPoint: .leading, endPoint: .trailing))
                    .frame(width: knobSize.width / 2 + progress * usable, height: trackHeight)

                Capsule()
                    .fill(.white)
                    .frame(width: knobSize.width, height: knobSize.height)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .padding(.leading, progress * usable)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    var fraction = (value.location.x - knobSize.width / 2) / usable
                    if layoutDirection == .rightToLeft { fraction = 1 - fraction }
                    let snapped = Int((min(max(fraction, 0), 1) * CGFloat(Self.presets.count - 1)).rounded())
                    duration = Self.presets[snapped]
                }
            )
        }
        .frame(height: knobSize.height)
    }

    private var sectionDots: some View {
        GeometryReader { proxy in
            let usable = proxy.size.width - knobSize.width
            ZStack(alignment: .leading) {
                ForEach(sectionIndices, id: \.self) { sectionIndex in
                    let fraction = CGFloat(sectionIndex) / CGFloat(Self.presets.count - 1)
                    Circle()
                        .fill(fraction <= progress ? Palette.blue : Color.secondary.opacity(0.35))
                        .frame(width: 5, height: 5)
                        .frame(width: knobSize.width)
                        .padding(.leading, fraction * usable)
                }
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}
