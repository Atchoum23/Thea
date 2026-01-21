import SwiftUI

// MARK: - Liquid Glass Style Support for iOS 26+
//
// Apple's Liquid Glass design language was introduced in iOS 26 (2025).
// This file provides conditional support for Liquid Glass effects while
// maintaining backwards compatibility with older OS versions.
//
// Reference: https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views

/// View modifier that conditionally applies Liquid Glass effect on iOS 26+
struct LiquidGlassModifier: ViewModifier {
    var isInteractive: Bool = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .capsule)
        } else {
            // Fallback for older OS versions - use material background
            content
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
    }
}

/// View modifier for rounded rectangle glass effect
struct RoundedGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

/// View modifier for circular glass effect
struct CircularGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .circle)
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies Liquid Glass effect with capsule shape on iOS 26+
    /// Falls back to ultraThinMaterial on older versions
    func liquidGlass() -> some View {
        modifier(LiquidGlassModifier())
    }

    /// Applies Liquid Glass effect with rounded rectangle shape on iOS 26+
    /// Falls back to ultraThinMaterial on older versions
    func liquidGlassRounded(cornerRadius: CGFloat = 16) -> some View {
        modifier(RoundedGlassModifier(cornerRadius: cornerRadius))
    }

    /// Applies Liquid Glass effect with circular shape on iOS 26+
    /// Falls back to ultraThinMaterial on older versions
    func liquidGlassCircle() -> some View {
        modifier(CircularGlassModifier())
    }

    /// Conditionally applies tint to Liquid Glass on iOS 26+
    @ViewBuilder
    func liquidGlassTint(_ color: Color) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.tint(color)
        } else {
            self
        }
    }
}

// MARK: - Glass Effect Container (iOS 26+)

/// A container that groups multiple Liquid Glass elements together
/// On iOS 26+, this ensures proper glass sampling behavior
/// On older versions, this is a transparent passthrough
struct GlassContainer<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer {
                content()
            }
        } else {
            content()
        }
    }
}

// MARK: - Adaptive Toolbar Style

/// Toolbar style that adapts to Liquid Glass on iOS 26+
struct AdaptiveToolbarStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            content
                .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
        } else {
            content
        }
        #else
        // macOS doesn't have navigationBar toolbar placement
        content
        #endif
    }
}

extension View {
    /// Applies adaptive toolbar styling for Liquid Glass
    func adaptiveToolbar() -> some View {
        modifier(AdaptiveToolbarStyle())
    }
}

// MARK: - Preview

#Preview("Liquid Glass Examples") {
    VStack(spacing: 20) {
        // Capsule glass
        Button("Capsule Glass Button") {}
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .liquidGlass()

        // Rounded rectangle glass
        VStack {
            Text("Card Content")
                .padding()
        }
        .frame(width: 200, height: 100)
        .liquidGlassRounded(cornerRadius: 20)

        // Circular glass
        Image(systemName: "star.fill")
            .font(.title)
            .padding(20)
            .liquidGlassCircle()
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
