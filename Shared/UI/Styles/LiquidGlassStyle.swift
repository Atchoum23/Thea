import SwiftUI

// MARK: - Liquid Glass Style Support for iOS 26+
//
// Apple's Liquid Glass design language (WWDC 2025).
// Uses real .glassEffect() API on iOS 26+ with .ultraThinMaterial fallback.
//
// IMPORTANT: Liquid Glass is for the NAVIGATION layer only.
// Never apply it to content (lists, tables, media).

// MARK: - Capsule Glass Modifier

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
    }
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = TheaCornerRadius.card
    var padding: CGFloat = TheaSpacing.lg

    func body(content: Content) -> some View {
        let innerRadius = TheaCornerRadius.concentric(outer: cornerRadius, padding: padding)
        if #available(iOS 26, macOS 26, watchOS 26, tvOS 26, visionOS 26, *) {
            content
                .padding(padding)
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

struct SoftEdgeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content
                .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        } else {
            content
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies Liquid Glass effect with capsule shape
    func liquidGlass(interactive: Bool = false) -> some View {
        modifier(LiquidGlassModifier(isInteractive: interactive))
    }

    /// Applies Liquid Glass effect with rounded rectangle shape
    func liquidGlassRounded(cornerRadius: CGFloat = TheaCornerRadius.lg) -> some View {
        modifier(RoundedGlassModifier(cornerRadius: cornerRadius))
    }

    /// Applies Liquid Glass effect with circular shape
    func liquidGlassCircle() -> some View {
        modifier(CircularGlassModifier())
    }

    /// Applies Liquid Glass to a card with concentric radius
    func liquidGlassCard(
        cornerRadius: CGFloat = TheaCornerRadius.card,
        padding: CGFloat = TheaSpacing.lg
    ) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    /// Applies soft scroll-edge effects replacing hard dividers
    func softEdges() -> some View {
        modifier(SoftEdgeModifier())
    }

    /// Conditionally applies tint to Liquid Glass
    @ViewBuilder
    func liquidGlassTint(_ color: Color) -> some View {
        self.tint(color)
    }
}

// MARK: - Glass Effect Container

struct GlassContainer<Content: View>: View {
    let content: () -> Content

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
    func adaptiveToolbar() -> some View {
        modifier(AdaptiveToolbarStyle())
    }
}

// MARK: - Preview

#Preview("Liquid Glass Examples") {
    VStack(spacing: 20) {
        Button("Capsule Glass") {}
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .liquidGlass()

        VStack {
            Text("Rounded Card")
                .padding()
        }
        .frame(width: 200, height: 80)
        .liquidGlassRounded(cornerRadius: TheaCornerRadius.xl)

        Image(systemName: "sparkles")
            .font(.title)
            .padding(20)
            .liquidGlassCircle()

        VStack(alignment: .leading, spacing: TheaSpacing.sm) {
            Text("Glass Card")
                .font(.headline)
            Text("With concentric radius")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(width: 240)
        .liquidGlassCard()
    }
    .padding()
    .background(
        LinearGradient(
            colors: [.blue, .purple, .pink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
