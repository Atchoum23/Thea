// TVColors.swift
// Thea TV — Design tokens for tvOS
//
// Mirrors the subset of Shared/UI/Theme/Colors.swift needed by tvOS views.
// The tvOS target does not include the full Shared/UI layer.

import SwiftUI

extension Color {
    // MARK: - Brand Colors

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static let theaPrimaryDefault = Color(hex: "0066FF")
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static let theaAccentDefault = Color(hex: "00D4AA")
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static let theaPurpleDefault = Color(hex: "8B5CF6")
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static let theaGoldDefault = Color(hex: "FFB84D")

    // MARK: - Semantic Colors

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static let theaSuccess = Color.green
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static let theaWarning = Color.orange
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static let theaError = Color.red
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static let theaInfo = Color.blue

    // MARK: - Chat Bubble Colors

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static let theaUserBubble = Color(hex: "0066FF")

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static var theaAssistantBubble: Color {
        Color.gray.opacity(0.2)
    }

    // MARK: - Gradients

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static let theaHeroGradientDefault = LinearGradient(
        colors: [theaPurpleDefault, theaPrimaryDefault, theaAccentDefault],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Hex Initializer

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
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

// MARK: - ShapeStyle Extension

extension ShapeStyle where Self == Color {
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static var theaPrimary: Color { Color.theaPrimaryDefault }
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static var theaAccent: Color { Color.theaAccentDefault }
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static var theaPurple: Color { Color.theaPurpleDefault }
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static var theaGold: Color { Color.theaGoldDefault }
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static var theaSuccess: Color { Color.theaSuccess }
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static var theaWarning: Color { Color.theaWarning }
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static var theaError: Color { Color.theaError }
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static var theaInfo: Color { Color.theaInfo }
}
