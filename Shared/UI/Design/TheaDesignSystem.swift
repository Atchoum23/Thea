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

// MARK: - Brand Colors (Extracted from THEA Icon)

/// THEA's brand palette - the golden spiral identity
public enum TheaBrandColors {
    // MARK: - Primary (The Golden Spiral)

    /// Primary gold - heart of the spiral
    public static let gold = Color(hex: "F5A623")

    /// Deep amber - outer spiral
    public static let amber = Color(hex: "FF8C00")

    /// Warm orange - energy accent
    public static let warmOrange = Color(hex: "FF7518")

    /// Light gold - highlights
    public static let lightGold = Color(hex: "FFD93D")

    /// Core glow - intelligent center
    public static let coreGlow = Color(hex: "FFFAEB")

    // MARK: - Background (The Deep Canvas)

    /// Deep navy - primary dark bg
    public static let deepNavy = Color(hex: "1A1A2E")

    /// Charcoal blue - secondary dark bg
    public static let charcoalBlue = Color(hex: "16213E")

    /// Midnight - darkest
    public static let midnight = Color(hex: "0F0F1A")

    /// Soft dark - elevated surfaces
    public static let softDark = Color(hex: "232340")

    // MARK: - Light Mode

    /// Warm white - primary light bg
    public static let warmWhite = Color(hex: "FEFDFB")

    /// Cream - secondary light bg
    public static let cream = Color(hex: "FFF9F0")

    // MARK: - Semantic

    public static let success = Color(hex: "4CAF50")
    public static let warning = Color(hex: "FFC107")
    public static let error = Color(hex: "E57373")
    public static let info = Color(hex: "64B5F6")

    // MARK: - Gradients

    /// The signature THEA spiral gradient
    public static let spiralGradient = LinearGradient(
        colors: [lightGold, gold, amber, warmOrange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Thinking/pulsing gradient
    public static let thinkingGradient = LinearGradient(
        colors: [gold.opacity(0.8), amber, gold.opacity(0.8)],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Core glow radial gradient
    public static let coreGlowGradient = RadialGradient(
        colors: [coreGlow, gold.opacity(0.6), gold.opacity(0)],
        center: .center,
        startRadius: 0,
        endRadius: 50
    )

    /// Background gradient
    public static let backgroundGradient = LinearGradient(
        colors: [deepNavy, charcoalBlue, midnight],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Adaptive Helpers

    public static func adaptiveBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? deepNavy : warmWhite
    }

    public static func adaptiveSurface(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? softDark : cream
    }

    public static func adaptiveText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : Color(hex: "2D2D3A")
    }
}

// MARK: - Design Tokens

/// Core spacing values
public enum TheaSpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48
    public static let jumbo: CGFloat = 48
}

/// Core corner radii
public enum TheaRadius {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 28
    public static let pill: CGFloat = 999
}

/// Corner radius tokens (alias used by DesignTokens consumers on macOS)
public enum TheaCornerRadius {
    public static let sm: CGFloat = TheaRadius.sm
    public static let md: CGFloat = TheaRadius.md
    public static let lg: CGFloat = TheaRadius.lg
    public static let xl: CGFloat = TheaRadius.xl
    public static let card: CGFloat = 24
    public static let capsule: CGFloat = .infinity

    public static func concentric(outer: CGFloat, padding: CGFloat) -> CGFloat {
        max(0, outer - padding)
    }
}

/// Size tokens for consistent component dimensions
public enum TheaSize {
    public static let minTouchTarget: CGFloat = 44
    public static let buttonHeight: CGFloat = 48
    public static let capsuleButtonHeight: CGFloat = 56
    public static let inputFieldMinHeight: CGFloat = 44
    public static let inputFieldMaxHeight: CGFloat = 200
    public static let sidebarMinWidth: CGFloat = 240
    public static let sidebarIdealWidth: CGFloat = 280
    public static let messageMaxWidth: CGFloat = 680
    public static let messageAvatarSize: CGFloat = 28
    public static let iconSmall: CGFloat = 16
    public static let iconMedium: CGFloat = 20
    public static let iconLarge: CGFloat = 24
    public static let iconXLarge: CGFloat = 32
    public static let tvMessageMaxWidth: CGFloat = 1000
    public static let tvMinTouchTarget: CGFloat = 66
}

/// Shadow definitions for layered depth
public enum TheaShadow {
    /// Subtle elevation for cards
    public static let subtle = Shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    /// Medium elevation for floating elements
    public static let medium = Shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
    /// Strong elevation for modals and popovers
    public static let strong = Shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 8)
    /// Glow effect for interactive elements
    public static let glow = Shadow(color: Color.blue.opacity(0.3), radius: 20, x: 0, y: 0)

    public struct Shadow: Sendable {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat
    }
}

/// Animation curves for smarter motion
public enum TheaAnimation {
    /// Quick micro-interaction (hover, tap feedback)
    public static let micro = Animation.easeOut(duration: 0.1)
    /// Standard interaction response
    public static let standard = Animation.easeInOut(duration: 0.2)
    /// Smooth content transitions
    public static let smooth = Animation.easeInOut(duration: 0.35)
    /// Elegant entrance animations
    public static let entrance = Animation.spring(response: 0.4, dampingFraction: 0.8)
    /// Bouncy feedback for success states
    public static let bouncy = Animation.spring(response: 0.3, dampingFraction: 0.6)

    // MARK: - Extended Presets

    /// Natural spring for general UI transitions
    public static let spring = Animation.spring(response: 0.35, dampingFraction: 0.85)
    /// Gentle spring for subtle movements
    public static let gentleSpring = Animation.spring(response: 0.5, dampingFraction: 0.8)
    /// Snappy animation for quick state changes
    public static let snappy = Animation.snappy(duration: 0.25)
    /// Morphing animation for shape/layout transitions
    public static let morphing = Animation.smooth(duration: 0.4)
    /// Message appear animation
    public static let messageAppear = Animation.spring(response: 0.4, dampingFraction: 0.75)
    /// Tab switch transition
    public static let tabSwitch = Animation.easeInOut(duration: 0.25)

    /// Staggered animation for lists and grids
    public static func staggered(index: Int, baseDelay: Double = 0.05) -> Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
            .delay(Double(index) * baseDelay)
    }
}

// MARK: - Adaptive Theme

/// Adaptive theme that changes based on context
public struct AdaptiveTheme: Equatable {
    public let mode: ThemeMode
    public let accentVariant: AccentVariant
    public let intensity: Intensity

    public enum ThemeMode: String, CaseIterable {
        case system
        case light
        case dark
        case midnight  // Extra dark for late night
    }

    public enum AccentVariant: String, CaseIterable {
        case ocean      // Blue-cyan gradient (default)
        case aurora     // Purple-green gradient
        case sunset     // Orange-pink gradient
        case forest     // Green-teal gradient
        case monochrome // Grayscale with subtle accent
    }

    public enum Intensity: String, CaseIterable {
        case subtle     // Minimal color, focus on content
        case balanced   // Default balanced approach
        case vibrant    // Rich, expressive colors
    }

    public init(
        mode: ThemeMode = .system,
        accentVariant: AccentVariant = .ocean,
        intensity: Intensity = .balanced
    ) {
        self.mode = mode
        self.accentVariant = accentVariant
        self.intensity = intensity
    }

    /// Primary accent color based on variant
    public var primaryAccent: Color {
        switch accentVariant {
        case .ocean: return Color(hex: "0066FF")
        case .aurora: return Color(hex: "8B5CF6")
        case .sunset: return Color(hex: "F97316")
        case .forest: return Color(hex: "10B981")
        case .monochrome: return Color(hex: "6B7280")
        }
    }

    /// Secondary accent color for gradients
    public var secondaryAccent: Color {
        switch accentVariant {
        case .ocean: return Color(hex: "00D4AA")
        case .aurora: return Color(hex: "10B981")
        case .sunset: return Color(hex: "EC4899")
        case .forest: return Color(hex: "14B8A6")
        case .monochrome: return Color(hex: "9CA3AF")
        }
    }

    /// Hero gradient for key visual elements
    public var heroGradient: LinearGradient {
        LinearGradient(
            colors: [primaryAccent, secondaryAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Opacity multiplier based on intensity
    public var opacityMultiplier: Double {
        switch intensity {
        case .subtle: return 0.6
        case .balanced: return 1.0
        case .vibrant: return 1.2
        }
    }
}

// MARK: - Dynamic Response Blocks

/// Block types for AI responses (beyond pure chat)
public enum ResponseBlockType: String, CaseIterable, Identifiable {
    case text
    case code
    case thinking       // Extended thinking process
    case dataTable      // Structured data display
    case actionButtons  // Quick action suggestions
    case progressCard   // Task progress indicator
    case imageGallery   // Generated or referenced images
    case citation       // Source citation with preview
    case formInput      // Interactive form for clarification
    case chart          // Data visualization
    case timeline       // Step-by-step process
    case comparison     // Side-by-side comparison
    case summary        // Collapsible summary card
    case warning        // Important notice
    case success        // Completion confirmation

    public var id: String { rawValue }

    /// Icon for the block type
    public var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .thinking: return "brain"
        case .dataTable: return "tablecells"
        case .actionButtons: return "hand.tap"
        case .progressCard: return "chart.bar.fill"
        case .imageGallery: return "photo.on.rectangle"
        case .citation: return "quote.opening"
        case .formInput: return "rectangle.and.pencil.and.ellipsis"
        case .chart: return "chart.xyaxis.line"
        case .timeline: return "timeline.selection"
        case .comparison: return "arrow.left.arrow.right"
        case .summary: return "doc.text.magnifyingglass"
        case .warning: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }
}

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

// Use internal Color references
private let defaultPrimaryColor = Color(hex: "0066FF")

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
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Streaming indicator with THEA branding
public struct TheaStreamingIndicatorView: View {
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

// MARK: - THEA Spiral Icon

/// Animated spiral icon representing THEA's intelligence
public struct TheaSpiralIconView: View {
    let size: CGFloat
    var isThinking: Bool = false
    var showGlow: Bool = true

    @State private var rotation: Double = 0
    @State private var glowIntensity: Double = 0.5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(size: CGFloat = 40, isThinking: Bool = false, showGlow: Bool = true) {
        self.size = size
        self.isThinking = isThinking
        self.showGlow = showGlow
    }

    public var body: some View {
        ZStack {
            // Glow layer
            if showGlow {
                Circle()
                    .fill(TheaBrandColors.coreGlowGradient)
                    .frame(width: size * 1.5, height: size * 1.5)
                    .opacity(glowIntensity)
                    .blur(radius: size * 0.2)
            }

            // Spiral (using hurricane SF Symbol - closest to our spiral)
            Image(systemName: "hurricane")
                .font(.system(size: size * 0.6, weight: .medium))
                .foregroundStyle(TheaBrandColors.spiralGradient)
                .rotationEffect(.degrees(rotation))

            // Core glow dot
            Circle()
                .fill(TheaBrandColors.coreGlow)
                .frame(width: size * 0.15, height: size * 0.15)
                .shadow(color: TheaBrandColors.gold, radius: 4)
        }
        .frame(width: size, height: size)
        .onAppear {
            if isThinking {
                startThinkingAnimation()
            }
        }
        .onChange(of: isThinking) { _, newValue in
            if newValue {
                startThinkingAnimation()
            } else {
                stopThinkingAnimation()
            }
        }
    }

    private func startThinkingAnimation() {
        guard !reduceMotion else {
            glowIntensity = 0.7
            return
        }
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
    }

    private func stopThinkingAnimation() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5)) {
            glowIntensity = 0.5
            rotation = 0
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
    SwiftUI.ScrollView {
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
