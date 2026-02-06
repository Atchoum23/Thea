//
//  DesignSystemStubs.swift
//  Thea
//
//  Stub implementations for design system components
//  when TheaDesignSystem.swift is excluded
//

import SwiftUI

// MARK: - TheaSpiralIconView Stub

public struct TheaSpiralIconView: View {
    let size: CGFloat
    var isThinking: Bool = false
    var showGlow: Bool = true

    public init(size: CGFloat = 40, isThinking: Bool = false, showGlow: Bool = true) {
        self.size = size
        self.isThinking = isThinking
        self.showGlow = showGlow
    }

    public var body: some View {
        Image(systemName: isThinking ? "sparkles" : "sparkle")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .foregroundStyle(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .rotationEffect(.degrees(isThinking ? 360 : 0))
            .animation(isThinking ? .linear(duration: 2).repeatForever(autoreverses: false) : .default, value: isThinking)
    }
}

// MARK: - TheaBrandColors Stub

public enum TheaBrandColors {
    // Core brand colors
    public static let primaryPurple = Color.purple
    public static let secondaryBlue = Color.blue
    public static let accentCyan = Color.cyan

    // Gradient definitions
    public static let coreGradient = LinearGradient(
        colors: [.purple, .blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let coreGlowGradient = RadialGradient(
        colors: [.purple.opacity(0.5), .clear],
        center: .center,
        startRadius: 0,
        endRadius: 50
    )

    public static let subtleGradient = LinearGradient(
        colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - TheaButtonStyle Stub

public struct TheaButtonStyle: ButtonStyle {
    var isPrimary: Bool = true

    public init(isPrimary: Bool = true) {
        self.isPrimary = isPrimary
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isPrimary ? TheaBrandColors.coreGradient : nil)
            .foregroundStyle(isPrimary ? .white : .primary)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}
