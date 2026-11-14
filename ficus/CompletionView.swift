//
//  CompletionView.swift
//  Shown when a tree has been earned.
//

import SwiftUI

struct CompletionView: View {
    let namespace: Namespace.ID
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "3FE5F9"), Palette.royal, Color(hex: "020B4E")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("עץ אלון")
                        .font(.system(size: 68, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                    Text("צמח יפה מאוד")
                        .font(.title3.weight(.medium))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .opacity(appeared ? 1 : 0)
                .padding(.top, 40)

                Spacer()

                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 250, height: 250)
                        .scaleEffect(appeared ? 1 : 6)

                    Image("tree")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 145, height: 145)
                        // Identifies the tree that flies onto the island when this screen is dismissed.
                        .matchedGeometryEffect(id: "flying_tree_target", in: namespace)
                }
                .frame(width: 280, height: 280)

                Spacer()

                Button("תודה", action: onDismiss)
                    .font(.title3.weight(.semibold))
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .controlSize(.extraLarge)
                    .tint(.white)
                    .foregroundStyle(Palette.navy)
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.82, dampingFraction: 0.76)) { appeared = true }
        }
    }
}
