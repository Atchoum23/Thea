// LiquidGlassDesign.swift
// Thea V2
//
// Apple Liquid Glass design system implementation.
// Provides consistent glass effects across the app following Apple's design guidelines.
//
// USAGE:
//   Text("Hello")
//       .glassCard()
//
//   Button("Action") { }
//       .glassButton()
//
//   HStack { ... }
//       .glassNavigation()
//
// GUIDELINES:
// - Use glass for navigation layer (toolbars, tab bars, sidebars)
// - Never apply to content (lists, tables, media)
// - Use tints sparingly for semantic meaning
// - Ensure high contrast foreground colors
//
// CREATED: February 2, 2026
// REFERENCE: https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass

import SwiftUI

// MARK: - Glass Effect Availability Check

/// Check if Liquid Glass is available (iOS 26+, macOS 26+)
public var isLiquidGlassAvailable: Bool {
    if #available(iOS 26.0, macOS 26.0, watchOS 26.0, tvOS 26.0, *) {
        return true
    }
    return false
}

// MARK: - Glass Card Modifier

/// Applies a glass card effect with rounded corners
public struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var padding: CGFloat
    var tint: Color?

    public func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .padding(padding)
                .background {
                    if let tint {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.regularMaterial)
                            .glassEffect(.regular.tint(tint), in: RoundedRectangle(cornerRadius: cornerRadius))
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.regularMaterial)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
                    }
                }
        } else {
            // Fallback for older OS versions
            content
                .padding(padding)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.regularMaterial)
                }
        }
    }
}

// MARK: - Glass Button Modifier

/// Applies an interactive glass button effect
public struct GlassButtonModifier: ViewModifier {
    var tint: Color?
    var isProminent: Bool

    public func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .foregroundStyle(isProminent ? .white : .primary)
                .background {
                    if isProminent, let tint {
                        Capsule()
                            .fill(tint.gradient)
                            .glassEffect(.regular.tint(tint).interactive(), in: .capsule)
                    } else if let tint {
                        Capsule()
                            .fill(.regularMaterial)
                            .glassEffect(.regular.tint(tint).interactive(), in: .capsule)
                    } else {
                        Capsule()
                            .fill(.regularMaterial)
                            .glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
        } else {
            // Fallback
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .foregroundStyle(isProminent ? .white : .primary)
                .background {
                    if isProminent, let tint {
                        Capsule().fill(tint.gradient)
                    } else {
                        Capsule().fill(.regularMaterial)
                    }
                }
        }
    }
}

// MARK: - Glass Navigation Modifier

/// Applies glass effect for navigation elements (toolbars, sidebars)
public struct GlassNavigationModifier: ViewModifier {
    var edge: Edge

    public func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .background {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .glassEffect(.regular)
                        .ignoresSafeArea(edges: edgeSet)
                }
        } else {
            content
                .background(.ultraThinMaterial)
        }
    }

    private var edgeSet: Edge.Set {
        switch edge {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
}

// MARK: - Glass Toolbar Modifier

/// Applies glass effect specifically for toolbars
public struct GlassToolbarModifier: ViewModifier {
    public func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .toolbarBackgroundVisibility(.visible, for: .automatic)
                .toolbarBackground(.ultraThinMaterial, for: .automatic)
        } else {
            content
                .toolbarBackground(.visible, for: .automatic)
                .toolbarBackground(.ultraThinMaterial, for: .automatic)
        }
    }
}

// MARK: - Glass Icon Modifier

/// Applies glass effect to icon buttons
public struct GlassIconModifier: ViewModifier {
    var size: CGFloat
    var tint: Color?

    public func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .font(.system(size: size * 0.5))
                .foregroundStyle(tint ?? .primary)
                .frame(width: size, height: size)
                .background {
                    if let tint {
                        Circle()
                            .fill(.regularMaterial)
                            .glassEffect(.regular.tint(tint).interactive(), in: .circle)
                    } else {
                        Circle()
                            .fill(.regularMaterial)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                }
        } else {
            content
                .font(.system(size: size * 0.5))
                .foregroundStyle(tint ?? .primary)
                .frame(width: size, height: size)
                .background {
                    Circle().fill(.regularMaterial)
                }
        }
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply a glass card effect
    /// - Parameters:
    ///   - cornerRadius: Corner radius of the card (default: 16)
    ///   - padding: Internal padding (default: 16)
    ///   - tint: Optional tint color for semantic meaning
    func glassCard(
        cornerRadius: CGFloat = 16,
        padding: CGFloat = 16,
        tint: Color? = nil
    ) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding, tint: tint))
    }

    /// Apply a glass button effect
    /// - Parameters:
    ///   - tint: Optional tint color
    ///   - isProminent: Whether to use prominent (filled) style
    func glassButton(tint: Color? = nil, isProminent: Bool = false) -> some View {
        modifier(GlassButtonModifier(tint: tint, isProminent: isProminent))
    }

    /// Apply a glass navigation effect
    /// - Parameter edge: Which edge the navigation element is on
    func glassNavigation(edge: Edge = .top) -> some View {
        modifier(GlassNavigationModifier(edge: edge))
    }

    /// Apply glass toolbar styling
    func glassToolbar() -> some View {
        modifier(GlassToolbarModifier())
    }

    /// Apply glass icon button effect
    /// - Parameters:
    ///   - size: Size of the icon button (default: 44)
    ///   - tint: Optional tint color
    func glassIcon(size: CGFloat = 44, tint: Color? = nil) -> some View {
        modifier(GlassIconModifier(size: size, tint: tint))
    }
}

// MARK: - Glass Morph Container View

/// A container that groups glass elements for morphing support.
/// Note: GlassEffectContainer requires iOS 26+/macOS 26+ SDK. This provides a fallback.
public struct GlassMorphContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    public init(spacing: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        // GlassEffectContainer requires iOS 26+/macOS 26+ SDK
        // For now, just render content directly
        // When SDK is updated, replace with:
        // GlassEffectContainer(spacing: spacing) { content }
        VStack(spacing: spacing) {
            content
        }
    }
}

// MARK: - Conditional Glass Modifier

/// Applies glass effect only when available and condition is met
public struct ConditionalGlassModifier: ViewModifier {
    var isEnabled: Bool
    var cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        if isEnabled, #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.regularMaterial)
                }
        }
    }
}

public extension View {
    /// Conditionally apply glass effect
    func glassEffect(if condition: Bool, cornerRadius: CGFloat = 12) -> some View {
        modifier(ConditionalGlassModifier(isEnabled: condition, cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Color Palette

/// Semantic colors that work well with Liquid Glass
public extension Color {
    /// Primary action color for glass elements
    static let glassAccent = Color.blue

    /// Success state color for glass elements
    static let glassSuccess = Color.green

    /// Warning state color for glass elements
    static let glassWarning = Color.orange

    /// Error state color for glass elements
    static let glassError = Color.red

    /// Subtle highlight for glass elements
    static let glassHighlight = Color.purple.opacity(0.8)
}

// MARK: - Accessibility Support

/// Check if user prefers reduced transparency
@MainActor
public var prefersReducedTransparency: Bool {
    #if os(iOS)
    return UIAccessibility.isReduceTransparencyEnabled
    #elseif os(macOS)
    return NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    #else
    return false
    #endif
}

/// Applies appropriate glass effect respecting accessibility settings
public struct AccessibleGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    public func body(content: Content) -> some View {
        if reduceTransparency {
            // Use solid background instead of glass
            content
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        #if os(macOS)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        #else
                        .fill(Color(.systemBackground))
                        #endif
                }
        } else if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                }
        }
    }
}

public extension View {
    /// Apply glass effect that respects accessibility settings
    func accessibleGlass() -> some View {
        modifier(AccessibleGlassModifier())
    }
}

// MARK: - Preview

#Preview("Glass Components") {
    VStack(spacing: 20) {
        Text("Glass Card")
            .glassCard()

        Button("Glass Button") { }
            .glassButton(tint: .blue)

        Button("Prominent Button") { }
            .glassButton(tint: .blue, isProminent: true)

        HStack(spacing: 16) {
            Image(systemName: "heart.fill")
                .glassIcon(tint: .red)

            Image(systemName: "star.fill")
                .glassIcon(tint: .yellow)

            Image(systemName: "bell.fill")
                .glassIcon()
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
