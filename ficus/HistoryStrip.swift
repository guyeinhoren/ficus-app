//
//  HistoryStrip.swift
//  A horizontally scrolling line chart of trees per day. Swipe to move through the days, tap a day to show it.
//

import SwiftUI

struct HistoryStrip: View {
    /// Trees planted per day.
    let counts: [Int32: Int]
    let today: Int32
    @Binding var selectedDay: Int32

    private let columnWidth: CGFloat = 60
    private let plotHeight: CGFloat = 80
    private let labelHeight: CGFloat = 30
    private let topInset: CGFloat = 26

    /// Oldest first; at least two weeks, reaching back to the first recorded tree.
    private var days: [Int32] {
        let first = counts.keys.min() ?? today
        let span = min(max(Int(today - first) + 1, 14), 365)
        return (0..<span).map { today - Int32(span - 1 - $0) }
    }

    private var peak: Int { max(counts.values.max() ?? 0, 5) }

    var body: some View {
        let days = days
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    DayColumn(
                        day: day,
                        isToday: day == today,
                        count: counts[day, default: 0],
                        dotY: dotY(for: counts[day, default: 0]),
                        isSelected: day == selectedDay,
                        height: topInset + plotHeight + labelHeight
                    ) {
                        withAnimation(.spring(duration: 0.35, bounce: 0.3)) { selectedDay = day }
                    }
                    .frame(width: columnWidth)
                }
            }
            .background { chartLine(days: days) }
            .scrollTargetLayout()
        }
        // The strip is drawn left-to-right (oldest → today); it opens on today at the right edge.
        .environment(\.layoutDirection, .leftToRight)
        .defaultScrollAnchor(.trailing)
        .scrollTargetBehavior(.viewAligned)
        .frame(height: topInset + plotHeight + labelHeight)
        .sensoryFeedback(.selection, trigger: selectedDay)
    }

    private func dotY(for count: Int) -> CGFloat {
        topInset + plotHeight * (1 - CGFloat(count) / CGFloat(peak))
    }

    private func chartLine(days: [Int32]) -> some View {
        Canvas { context, size in
            let points = days.enumerated().map { index, day in
                CGPoint(x: (CGFloat(index) + 0.5) * columnWidth, y: dotY(for: counts[day, default: 0]))
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
    let count: Int
    let dotY: CGFloat
    let isSelected: Bool
    let height: CGFloat
    let onTap: () -> Void

    private let accent = Color(hex: "03A9F4")

    var body: some View {
        ZStack {
            VStack(spacing: 3) {
                Text("\(count)")
                    .font(.system(isSelected ? .footnote : .caption, design: .rounded, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? accent : .secondary)
                dot
            }
            .position(x: 30, y: dotY - (isSelected ? 14 : 10))

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
        .accessibilityValue("\(count) עצים")
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
