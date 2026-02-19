// TheaDesignSystem.swift
// Thea V2 - Omni-AI Design System
//
// Brand Identity: The Golden Spiral
// - Primary: Golden/amber spiral representing expanding intelligence
// - Core: Glowing white center representing consciousness
// - Background: Deep navy representing infinite possibility
//
// Design Philosophy: Intelligence made visible, warmth meets precision
//
// Created: February 3, 2026
// Updated: February 4, 2026 - Brand colors extracted from icon

import SwiftUI

// MARK: - View Modifiers

/// Adds layered depth with shadow
public struct LayeredDepthModifier: ViewModifier {
    let shadow: TheaShadow.Shadow
    let cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
    }
}

/// Hover lift effect for interactive cards
public struct HoverLiftModifier: ViewModifier {
    @State private var isHovered = false
    let maxLift: CGFloat

// periphery:ignore - Reserved: maxLift property reserved for future feature activation

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(
                color: .black.opacity(isHovered ? 0.15 : 0.08),
                radius: isHovered ? 16 : 8,
                y: isHovered ? 8 : 4
            )
            .animation(TheaAnimation.standard, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

/// Smooth entrance animation
public struct EntranceModifier: ViewModifier {
    @State private var appeared = false
    let delay: Double

    public func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                withAnimation(TheaAnimation.entrance.delay(delay)) {
                    appeared = true
                }
            }
    }
}

/// Pulsing glow for active/streaming states
public struct PulsingGlowModifier: ViewModifier {
    let color: Color
    let isActive: Bool

    @State private var glowOpacity: Double = 0.3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        content
            .shadow(
                color: isActive ? color.opacity(reduceMotion ? 0.5 : glowOpacity) : .clear,
                radius: 20
            )
            .onAppear {
                guard !reduceMotion, isActive else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.6
                }
            }
            .onChange(of: isActive) { _, active in
                guard !reduceMotion else { return }
                if active {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        glowOpacity = 0.6
                    }
                } else {
                    glowOpacity = 0.3
                }
            }
    }
}

/// Gradient border for highlighted elements
public struct GradientBorderModifier: ViewModifier {
    let gradient: LinearGradient
    let lineWidth: CGFloat
    let cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(gradient, lineWidth: lineWidth)
            )
    }
}

/// Frosted glass background
public struct FrostedGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?

    @Environment(\.colorScheme) private var colorScheme

    public func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        if let tint {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(tint.opacity(colorScheme == .dark ? 0.15 : 0.08))
                        }
                    }
            }
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply layered depth with shadow
    func layeredDepth(
        _ shadow: TheaShadow.Shadow = TheaShadow.subtle,
        cornerRadius: CGFloat = TheaRadius.md
    ) -> some View {
        modifier(LayeredDepthModifier(shadow: shadow, cornerRadius: cornerRadius))
    }

    /// Apply hover lift effect
    func hoverLift(maxLift: CGFloat = 4) -> some View {
        modifier(HoverLiftModifier(maxLift: maxLift))
    }

    /// Apply entrance animation
    func entranceAnimation(delay: Double = 0) -> some View {
        modifier(EntranceModifier(delay: delay))
    }

    /// Apply pulsing glow for active states
    func pulsingGlow(color: Color = .blue, isActive: Bool) -> some View {
        modifier(PulsingGlowModifier(color: color, isActive: isActive))
    }

    /// Apply gradient border
    func gradientBorder(
        _ gradient: LinearGradient,
        lineWidth: CGFloat = 1.5,
        cornerRadius: CGFloat = TheaRadius.md
    ) -> some View {
        modifier(GradientBorderModifier(gradient: gradient, lineWidth: lineWidth, cornerRadius: cornerRadius))
    }

    /// Apply frosted glass effect
    func frostedGlass(
        cornerRadius: CGFloat = TheaRadius.md,
        tint: Color? = nil
    ) -> some View {
        modifier(FrostedGlassModifier(cornerRadius: cornerRadius, tint: tint))
    }

    /// Apply Thea card styling
    func theaCard(
        padding: CGFloat = TheaSpacing.lg,
        cornerRadius: CGFloat = TheaRadius.lg
    ) -> some View {
        self
            .padding(padding)
            .frostedGlass(cornerRadius: cornerRadius)
            .layeredDepth(TheaShadow.subtle, cornerRadius: cornerRadius)
    }

    /// Apply floating action button styling
    func theaFloatingButton(
        tint: Color = .blue
    ) -> some View {
        self
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(
                Circle()
                    .fill(tint.gradient)
            )
            .layeredDepth(TheaShadow.medium, cornerRadius: 28)
            .hoverLift()
    }
}

// MARK: - Semantic Components

/// A dynamic response block container
public struct ResponseBlock<Content: View>: View {
    let type: ResponseBlockType
    let content: Content

    @State private var isExpanded = true
    @State private var isHovered = false

    public init(
        type: ResponseBlockType,
        @ViewBuilder content: () -> Content
    ) {
        self.type = type
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Block header (collapsible for some types)
            if shouldShowHeader {
                HStack {
                    Image(systemName: type.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if isCollapsible {
                        Button {
                            withAnimation(TheaAnimation.standard) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, TheaSpacing.md)
                .padding(.vertical, TheaSpacing.sm)
                .background(Color.primary.opacity(0.03))
            }

            // Block content
            if isExpanded {
                content
                    .padding(TheaSpacing.md)
            }
        }
        .frostedGlass(cornerRadius: TheaRadius.md, tint: blockTint)
        .layeredDepth(cornerRadius: TheaRadius.md)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var shouldShowHeader: Bool {
        switch type {
        case .text, .success: return false
        default: return true
        }
    }

    private var isCollapsible: Bool {
        switch type {
        case .thinking, .code, .dataTable, .timeline: return true
        default: return false
        }
    }

    private var blockTint: Color? {
        switch type {
        case .warning: return .orange
        case .success: return .green
        case .thinking: return .purple
        case .code: return .indigo
        default: return nil
        }
    }
}

/// Quick action button with THEA golden styling
public struct TheaQuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var isPressed = false

    public init(title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: TheaSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, TheaSpacing.md)
            .padding(.vertical, TheaSpacing.sm)
            .foregroundStyle(TheaBrandColors.gold)
            .frostedGlass(cornerRadius: TheaRadius.pill, tint: TheaBrandColors.gold)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(TheaAnimation.micro, value: isPressed)
    }
}

// MARK: - THEA Button Styles

/// Primary golden button - prominent actions
public struct TheaPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(TheaBrandColors.deepNavy)
            .padding(.horizontal, TheaSpacing.lg)
            .padding(.vertical, TheaSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: TheaRadius.md)
                    .fill(isEnabled ? TheaBrandColors.spiralGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
            )
            .shadow(color: isEnabled ? TheaBrandColors.gold.opacity(0.3) : .clear, radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Secondary outlined button
public struct TheaSecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(TheaBrandColors.gold)
            .padding(.horizontal, TheaSpacing.lg)
            .padding(.vertical, TheaSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: TheaRadius.md)
                    .stroke(TheaBrandColors.gold, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Ghost button - minimal
public struct TheaGhostButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(TheaBrandColors.gold)
            .padding(.horizontal, TheaSpacing.md)
            .padding(.vertical, TheaSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: TheaRadius.sm)
                    .fill(configuration.isPressed ? TheaBrandColors.gold.opacity(0.1) : Color.clear)
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// Streaming indicator with THEA branding
public struct TheaStreamingIndicatorView: View {
    // periphery:ignore - Reserved: modelName property reserved for future feature activation
    let modelName: String?

    @State private var dotOpacity: [Double] = [1, 0.5, 0.2]

    public init(modelName: String? = nil) {
        self.modelName = modelName
    }

    public var body: some View {
        HStack(spacing: TheaSpacing.sm) {
            // THEA animated icon
            TheaSpiralIconView(size: 20, isThinking: true, showGlow: false)

            // Animated dots
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(TheaBrandColors.gold)
                        .frame(width: 6, height: 6)
                        .opacity(dotOpacity[index])
                }
            }
            .onAppear {
                animateDots()
            }

            Text("THEA is thinking...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, TheaSpacing.md)
        .padding(.vertical, TheaSpacing.sm)
        .frostedGlass(cornerRadius: TheaRadius.pill, tint: TheaBrandColors.gold)
    }

    private func animateDots() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [self] _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.3)) {
                    let last = dotOpacity.removeLast()
                    dotOpacity.insert(last, at: 0)
                }
            }
        }
    }
}

// MARK: - THEA Typing Indicator

/// Golden typing dots
public struct TheaTypingIndicator: View {
    @State private var dotAnimations = [false, false, false]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(TheaBrandColors.gold)
                    .frame(width: 8, height: 8)
                    .scaleEffect(reduceMotion ? 1.0 : (dotAnimations[index] ? 1.2 : 0.8))
                    .opacity(dotAnimations[index] ? 1.0 : 0.5)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            animateDots()
        }
    }

    private func animateDots() {
        for index in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.2)
            ) {
                dotAnimations[index] = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("THEA Design System") {
    ScrollView(.vertical, showsIndicators: true) {
        VStack(spacing: TheaSpacing.xl) {
            // Brand Colors
            VStack(alignment: .leading, spacing: TheaSpacing.md) {
                Text("Brand Colors")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: TheaSpacing.sm) {
                    DesignColorSwatch(color: TheaBrandColors.gold, name: "Gold")
                    DesignColorSwatch(color: TheaBrandColors.amber, name: "Amber")
                    DesignColorSwatch(color: TheaBrandColors.warmOrange, name: "Orange")
                    DesignColorSwatch(color: TheaBrandColors.lightGold, name: "Light")
                }
            }

            // THEA Icons
            VStack(alignment: .leading, spacing: TheaSpacing.md) {
                Text("THEA Icon States")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: TheaSpacing.xxl) {
                    VStack {
                        TheaSpiralIconView(size: 50, isThinking: false)
                        Text("Idle").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack {
                        TheaSpiralIconView(size: 50, isThinking: true)
                        Text("Thinking").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack {
                        TheaTypingIndicator()
                        Text("Typing").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            // Buttons
            VStack(alignment: .leading, spacing: TheaSpacing.md) {
                Text("Buttons")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: TheaSpacing.md) {
                    Button("Primary") {}
                        .buttonStyle(TheaPrimaryButtonStyle())

                    Button("Secondary") {}
                        .buttonStyle(TheaSecondaryButtonStyle())

                    Button("Ghost") {}
                        .buttonStyle(TheaGhostButtonStyle())
                }
            }

            // Quick Actions
            VStack(alignment: .leading, spacing: TheaSpacing.md) {
                Text("Quick Actions")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: TheaSpacing.sm) {
                    TheaQuickActionButton(title: "Explain", icon: "lightbulb") {}
                    TheaQuickActionButton(title: "Expand", icon: "arrow.up.left.and.arrow.down.right") {}
                    TheaQuickActionButton(title: "Simplify", icon: "minus.circle") {}
                }
            }

            // Streaming Indicator
            VStack(alignment: .leading, spacing: TheaSpacing.md) {
                Text("Streaming")
                    .font(.headline)
                    .foregroundStyle(.white)

                TheaStreamingIndicatorView()
            }

            // Response Blocks
            VStack(alignment: .leading, spacing: TheaSpacing.md) {
                Text("Response Blocks")
                    .font(.headline)
                    .foregroundStyle(.white)

                ResponseBlock(type: .thinking) {
                    Text("THEA is analyzing context and selecting the optimal approach...")
                        .foregroundStyle(.secondary)
                }

                ResponseBlock(type: .success) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(TheaBrandColors.success)
                        Text("Task completed successfully!")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(TheaSpacing.xl)
    }
    .frame(width: 500, height: 800)
    .background(TheaBrandColors.backgroundGradient)
}

private struct DesignColorSwatch: View {
    let color: Color
    let name: String

    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: TheaRadius.sm)
                .fill(color)
                .frame(width: 60, height: 40)
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
#endif
