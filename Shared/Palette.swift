//
//  Palette.swift
//  Shared between the iOS app, the Live Activity and (later) the macOS app.
//

import SwiftUI

extension Color {
    /// Creates a color from a `RGB`, `RRGGBB` or `AARRGGBB` hex string.
    init(hex: String) {
        let digits = hex.filter(\.isHexDigit)
        var value: UInt64 = 0
        Scanner(string: digits).scanHexInt64(&value)

        let a, r, g, b: UInt64
        switch digits.count {
        case 3:
            (a, r, g, b) = (255, (value >> 8) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, value >> 16, value >> 8 & 0xFF, value & 0xFF)
        case 8:
            (a, r, g, b) = (value >> 24, value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

/// The app's brand colors.
enum Palette {
    static let sky = Color(hex: "0091FF")
    static let blue = Color(hex: "007AFF")
    static let royal = Color(hex: "0E3BC7")
    static let navy = Color(hex: "09006D")

    /// Sky → navy, used for the timer digits and the progress ring.
    static let focusGradient = LinearGradient(colors: [sky, navy], startPoint: .topLeading, endPoint: .bottomTrailing)
}
