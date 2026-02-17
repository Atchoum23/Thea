// TVColors.swift
// Thea TV — Design tokens for tvOS
//
// Mirrors the subset of Shared/UI/Theme/Colors.swift needed by tvOS views.
// The tvOS target does not include the full Shared/UI layer.

import SwiftUI

extension Color {
    // MARK: - Brand Colors

    static let theaPrimaryDefault = Color(hex: "0066FF")
    static let theaAccentDefault = Color(hex: "00D4AA")
    static let theaPurpleDefault = Color(hex: "8B5CF6")
    static let theaGoldDefault = Color(hex: "FFB84D")

    // MARK: - Semantic Colors

    static let theaSuccess = Color.green
    static let theaWarning = Color.orange
    static let theaError = Color.red
    static let theaInfo = Color.blue

    // MARK: - Chat Bubble Colors

    static let theaUserBubble = Color(hex: "0066FF")

    static var theaAssistantBubble: Color {
        Color.gray.opacity(0.2)
    }

    // MARK: - Gradients

    static let theaHeroGradientDefault = LinearGradient(
        colors: [theaPurpleDefault, theaPrimaryDefault, theaAccentDefault],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Hex Initializer

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
