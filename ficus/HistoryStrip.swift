//
//  HistoryStrip.swift
//  A horizontally scrolling line chart of trees per day. Swipe to move through the days, tap a day to show it.
//

import SwiftUI

struct HistoryStrip: View {
    /// Focused time per day.
    let durations: [Int32: TimeInterval]
    let today: Int32
    @Binding var selectedDay: Int32

    private let columnWidth: CGFloat = 60
    private let plotHeight: CGFloat = 80
    private let labelHeight: CGFloat = 30
    private let topInset: CGFloat = 26

    /// Today first, then going back; at least two weeks, reaching back to the first recorded tree.
    private var days: [Int32] {
        let first = durations.keys.min() ?? today
        let span = min(max(Int(today - first) + 1, 14), 365)
        return (0..<span).map { today - Int32($0) }
    }

    /// The chart is at least two hours tall, so a short day doesn't look like a full one.
    private var peak: TimeInterval { max(durations.values.max() ?? 0, 2 * 3600) }

    var body: some View {
        let days = days
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    DayColumn(
                        day: day,
                        isToday: day == today,
                        duration: durations[day, default: 0],
                        dotY: dotY(for: durations[day, default: 0]),
                        isSelected: day == selectedDay,
                        height: topInset + plotHeight + labelHeight
                    ) {
                        withAnimation(.spring(duration: 0.35, bounce: 0.3)) { selectedDay = day }
                    }
                    .frame(width: columnWidth)
                }
            }
            .background { chartLine(days: days) }
        }
        // Today sits at the left edge and the past extends to the right.
        .environment(\.layoutDirection, .leftToRight)
        .defaultScrollAnchor(.leading)
        .contentMargins(.horizontal, 24, for: .scrollContent)
        .frame(height: topInset + plotHeight + labelHeight)
        .sensoryFeedback(.selection, trigger: selectedDay)
    }

    private func dotY(for duration: TimeInterval) -> CGFloat {
        topInset + plotHeight * (1 - CGFloat(duration / peak))
    }

    private func chartLine(days: [Int32]) -> some View {
        Canvas { context, size in
            let points = days.enumerated().map { index, day in
                CGPoint(x: (CGFloat(index) + 0.5) * columnWidth, y: dotY(for: durations[day, default: 0]))
            }
            guard let first = points.first, let last = points.last else { return }
            let baseline = topInset + plotHeight

            var line = Path()
            line.move(to: first)
            points.dropFirst().forEach { line.addLine(to: $0) }

            var area = line
            area.addLine(to: CGPoint(x: last.x, y: baseline))
            area.addLine(to: CGPoint(x: first.x, y: baseline))
            area.closeSubpath()

            context.fill(area, with: .linearGradient(
                Gradient(colors: [Color(hex: "03A9F4").opacity(0.22), .clear]),
                startPoint: CGPoint(x: 0, y: topInset), endPoint: CGPoint(x: 0, y: baseline)))

            var stems = Path()
            for point in points {
                stems.move(to: point)
                stems.addLine(to: CGPoint(x: point.x, y: baseline + 6))
            }
            context.stroke(stems, with: .color(.secondary.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 3]))

            context.stroke(line, with: .linearGradient(
                Gradient(colors: [Color(hex: "03A9F4"), Color(hex: "4FC3F7")]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)),
                style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct DayColumn: View {
    let day: Int32
    let isToday: Bool
    let duration: TimeInterval
    let dotY: CGFloat
    let isSelected: Bool
    let height: CGFloat
    let onTap: () -> Void

    private let accent = Color(hex: "03A9F4")

    var body: some View {
        ZStack {
            Text(duration.hoursMinutesString)
                .font(.system(isSelected ? .footnote : .caption, design: .rounded, weight: isSelected ? .bold : .medium).monospacedDigit())
                .foregroundStyle(isSelected ? accent : .secondary)
                .position(x: 30, y: dotY - (isSelected ? 22 : 17))

            dot.position(x: 30, y: dotY)

            Text(isToday ? "היום" : Hebrew.weekday(of: Day.date(of: day)))
                .font(.footnote.weight(isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? accent : Palette.navy.opacity(0.6))
                .position(x: 30, y: height - 12)
        }
        .frame(height: height)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement()
        .accessibilityLabel(isToday ? "היום" : Day.date(of: day).formatted(.dateTime.weekday(.wide).day().month()))
        .accessibilityValue("\(duration.hoursMinutesString) שעות")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder private var dot: some View {
        if isSelected {
            Circle()
                .fill(.white)
                .frame(width: 18, height: 18)
                .shadow(color: accent.opacity(0.3), radius: 4)
                .overlay { Circle().stroke(accent, lineWidth: 4).frame(width: 14, height: 14) }
        } else {
            Circle().fill(accent.opacity(0.55)).frame(width: 8, height: 8)
        }
    }
}
