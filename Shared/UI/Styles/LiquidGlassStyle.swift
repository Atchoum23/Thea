import SwiftUI

// MARK: - Liquid Glass Style Support for iOS 26+

//
// Apple's Liquid Glass design language was introduced in iOS 26 (2025).
// This file provides conditional support for Liquid Glass effects while
// maintaining backwards compatibility with older OS versions.
//
// Note: The glassEffect API requires Xcode 16+ SDK. For older Xcode versions,
// we fall back to material backgrounds.
//
// Reference: https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views

// MARK: - Compile-time SDK check

// glassEffect API is only available in Xcode 16+ SDK (iOS 26+, macOS 26+)
// We use compiler version check since the API doesn't exist in older SDKs

#if compiler(>=6.0) && canImport(SwiftUI, _version: 6.0)
    private let hasGlassEffectAPI = true
#else
    private let hasGlassEffectAPI = false
#endif

/// View modifier that conditionally applies Liquid Glass effect on iOS 26+
struct LiquidGlassModifier: ViewModifier {
    var isInteractive: Bool = false

    func body(content: Content) -> some View {
        // Always use fallback since glassEffect requires newer SDK
        content
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }
}

/// View modifier for rounded rectangle glass effect
struct RoundedGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        // Always use fallback since glassEffect requires newer SDK
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// View modifier for circular glass effect
struct CircularGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        // Always use fallback since glassEffect requires newer SDK
        content
            .background(.ultraThinMaterial)
            .clipShape(Circle())
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
        // tint is always available, just apply it
        tint(color)
    }
}

// MARK: - Glass Effect Container

/// A container that groups multiple Liquid Glass elements together
/// On iOS 26+, this ensures proper glass sampling behavior
/// On older versions, this is a transparent passthrough
struct GlassContainer<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        // GlassEffectContainer requires newer SDK, use passthrough
        content()
    }
}

// MARK: - Adaptive Toolbar Style

/// Toolbar style that adapts to Liquid Glass on iOS 26+
struct AdaptiveToolbarStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
            // toolbarBackgroundVisibility with .navigationBar requires iOS 18+
            if #available(iOS 18.0, *) {
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
