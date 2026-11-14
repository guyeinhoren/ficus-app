//
//  IslandView.swift
//  The isometric platform and its draggable, persisted trees.
//

import SwiftData
import SwiftUI

enum Island {
    static let width: CGFloat = 320
    /// Trees can be dragged anywhere within these ranges (offsets from the center),
    /// from the far corner cells down to the front ones.
    static let xRange: ClosedRange<CGFloat> = -140...140
    static let yRange: ClosedRange<CGFloat> = -120...55

    private static let slots: [CGPoint] = [
        CGPoint(x: -40, y: -55), CGPoint(x: 40, y: -35), CGPoint(x: -50, y: 10),
        CGPoint(x: 30, y: 15), CGPoint(x: -10, y: -20), CGPoint(x: 70, y: -10),
        CGPoint(x: -70, y: -25), CGPoint(x: 10, y: -65), CGPoint(x: -15, y: 35)
    ]

    /// Where the `slot`-th tree of a day is planted: hand-placed spots first, then scattered on the platform.
    static func spawnPoint(slot: Int) -> CGPoint {
        if slots.indices.contains(slot) { return slots[slot] }
        return CGPoint(x: .random(in: -85...85), y: .random(in: -60...40))
    }

    static func clamp(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, xRange.lowerBound), xRange.upperBound),
                y: min(max(point.y, yRange.lowerBound), yRange.upperBound))
    }
}

struct IslandView: View {
    let trees: [Tree]
    let namespace: Namespace.ID

    var body: some View {
        ZStack {
            Image("platform")
                .resizable()
                .scaledToFit()
                .frame(width: Island.width)

            ForEach(trees) { tree in
                DraggableTree(position: tree.position) { tree.position = $0 }
                    // The newest tree is the one the completion screen flies into.
                    .matchedGeometryEffect(id: tree.id == trees.last?.id ? "flying_tree_target" : AnyHashable(tree.id), in: namespace)
            }
        }
        // Tree positions are plain screen offsets; drag gestures are mirrored in right-to-left, so keep this left-to-right.
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// A tree that lifts, stretches and squashes while it is dragged, then reports where it landed.
private struct DraggableTree: View {
    let position: CGPoint
    let onMove: (CGPoint) -> Void

    @GestureState private var translation: CGSize = .zero
    @GestureState private var isDragging = false
    @State private var landings = 0

    var body: some View {
        Image("tree")
            .resizable()
            .scaledToFit()
            .frame(width: 48)
            .keyframeAnimator(initialValue: 0.0, trigger: landings) { view, squash in
                view.scaleEffect(x: 1 + squash, y: 1 - squash, anchor: .bottom)
            } keyframes: { _ in
                CubicKeyframe(0.2, duration: 0.1)
                SpringKeyframe(0.0, duration: 0.5, spring: .bouncy)
            }
            .scaleEffect(x: isDragging ? 0.95 : 1, y: isDragging ? 1.1 : 1, anchor: .bottom)
            .shadow(color: .black.opacity(isDragging ? 0.15 : 0), radius: isDragging ? 12 : 0, y: isDragging ? 15 : 0)
            .animation(.spring(duration: 0.3, bounce: 0.5), value: isDragging)
            .offset(x: position.x + translation.width, y: position.y + translation.height)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($translation) { value, state, _ in state = value.translation }
                    .updating($isDragging) { _, state, _ in state = true }
                    .onEnded { value in
                        let landed = CGPoint(x: position.x + value.translation.width,
                                             y: position.y + value.translation.height)
                        onMove(Island.clamp(landed))
                        landings += 1
                    }
            )
    }
}
