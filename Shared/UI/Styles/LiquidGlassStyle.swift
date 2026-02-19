import SwiftUI

// MARK: - Liquid Glass Style Support for iOS 26+
//
// Apple's Liquid Glass design language (WWDC 2025).
// Uses real .glassEffect() API on iOS 26+ with .ultraThinMaterial fallback.
//
// IMPORTANT: Liquid Glass is for the NAVIGATION layer only.
// Never apply it to content (lists, tables, media).

// MARK: - Capsule Glass Modifier

// periphery:ignore - Reserved: LiquidGlassModifier type — reserved for future feature activation
struct LiquidGlassModifier: ViewModifier {
    var isInteractive: Bool = false

    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, watchOS 26, tvOS 26, visionOS 26, *) {
            content
                .glassEffect(.regular.interactive(isInteractive))
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        // periphery:ignore - Reserved: LiquidGlassModifier type reserved for future feature activation
        }
    }
}

// MARK: - Rounded Rectangle Glass Modifier

struct RoundedGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = TheaCornerRadius.lg

    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, watchOS 26, tvOS 26, visionOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - Circular Glass Modifier

// periphery:ignore - Reserved: CircularGlassModifier type — reserved for future feature activation
struct CircularGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, watchOS 26, tvOS 26, visionOS 26, *) {
            content
                .glassEffect(.regular, in: .circle)
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
    // periphery:ignore - Reserved: CircularGlassModifier type reserved for future feature activation
    }
}

// MARK: - Simple Glass Card Modifier

// periphery:ignore - Reserved: SimpleGlassCardModifier type — reserved for future feature activation
struct SimpleGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = TheaCornerRadius.card
    var padding: CGFloat = TheaSpacing.lg

    func body(content: Content) -> some View {
        let innerRadius = TheaCornerRadius.concentric(outer: cornerRadius, padding: padding)
        if #available(iOS 26, macOS 26, watchOS 26, tvOS 26, visionOS 26, *) {
            content
                .padding(padding)
                // periphery:ignore - Reserved: SimpleGlassCardModifier type reserved for future feature activation
                .glassEffect(.regular, in: .rect(cornerRadius: innerRadius))
        } else {
            content
                .padding(padding)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: innerRadius))
        }
    }
}

// MARK: - Soft Edge Modifier

// periphery:ignore - Reserved: SoftEdgeModifier type — reserved for future feature activation
struct SoftEdgeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content
                .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        } else {
            content
        }
    // periphery:ignore - Reserved: SoftEdgeModifier type reserved for future feature activation
    }
}

// MARK: - View Extensions

extension View {
    /// Applies Liquid Glass effect with capsule shape
    // periphery:ignore - Reserved: liquidGlass(interactive:) instance method — reserved for future feature activation
    func liquidGlass(interactive: Bool = false) -> some View {
        modifier(LiquidGlassModifier(isInteractive: interactive))
    }

    /// Applies Liquid Glass effect with rounded rectangle shape
    func liquidGlassRounded(cornerRadius: CGFloat = TheaCornerRadius.lg) -> some View {
        modifier(RoundedGlassModifier(cornerRadius: cornerRadius))
    // periphery:ignore - Reserved: liquidGlass(interactive:) instance method reserved for future feature activation
    }

    /// Applies Liquid Glass effect with circular shape
    // periphery:ignore - Reserved: liquidGlassCircle() instance method — reserved for future feature activation
    func liquidGlassCircle() -> some View {
        modifier(CircularGlassModifier())
    }

    /// Applies Liquid Glass to a card with concentric radius
    // periphery:ignore - Reserved: liquidGlassCard(cornerRadius:padding:) instance method — reserved for future feature activation
    func liquidGlassCard(
        // periphery:ignore - Reserved: liquidGlassCircle() instance method reserved for future feature activation
        cornerRadius: CGFloat = TheaCornerRadius.card,
        padding: CGFloat = TheaSpacing.lg
    ) -> some View {
        modifier(SimpleGlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    // periphery:ignore - Reserved: liquidGlassCard(cornerRadius:padding:) instance method reserved for future feature activation
    }

    /// Applies soft scroll-edge effects replacing hard dividers
    // periphery:ignore - Reserved: softEdges() instance method — reserved for future feature activation
    func softEdges() -> some View {
        modifier(SoftEdgeModifier())
    }

    // periphery:ignore - Reserved: softEdges() instance method reserved for future feature activation
    /// Conditionally applies tint to Liquid Glass
    @ViewBuilder
    func liquidGlassTint(_ color: Color) -> some View {
        self.tint(color)
    }
// periphery:ignore - Reserved: liquidGlassTint(_:) instance method reserved for future feature activation
}

// MARK: - Glass Effect Container

// periphery:ignore - Reserved: GlassContainer type — reserved for future feature activation
struct GlassContainer<Content: View>: View {
    let content: () -> Content

// periphery:ignore - Reserved: GlassContainer type reserved for future feature activation

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        if #available(iOS 26, macOS 26, watchOS 26, tvOS 26, visionOS 26, *) {
            GlassEffectContainer {
                content()
            }
        } else {
            content()
        }
    }
}

// MARK: - Adaptive Toolbar Style

struct AdaptiveToolbarStyle: ViewModifier {
    // periphery:ignore - Reserved: AdaptiveToolbarStyle type reserved for future feature activation
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            content
                .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

extension View {
    // periphery:ignore - Reserved: adaptiveToolbar() instance method reserved for future feature activation
    func adaptiveToolbar() -> some View {
        modifier(AdaptiveToolbarStyle())
    }
}

// Preview moved to separate file to avoid macro conflicts
