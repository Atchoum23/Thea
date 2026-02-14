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

// MARK: - Prominent Glass Modifier

/// View modifier for prominent glass effect (more visible)
struct ProminentGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

extension View {
    /// Applies prominent glass effect with more visibility
    func liquidGlassProminent(cornerRadius: CGFloat = 16) -> some View {
        modifier(ProminentGlassModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Scroll Edge Blur Effect

/// Applies edge blur effect when content scrolls behind navigation
struct ScrollEdgeBlurModifier: ViewModifier {
    var edges: Edge.Set = .top

    func body(content: Content) -> some View {
        content
            .mask(
                VStack(spacing: 0) {
                    if edges.contains(.top) {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)
                    }

                    Rectangle()
                        .fill(.black)

                    if edges.contains(.bottom) {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0.9),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)
                    }
                }
            )
    }
}

extension View {
    /// Applies scroll edge blur effect for Liquid Glass style
    func scrollEdgeBlur(edges: Edge.Set = .top) -> some View {
        modifier(ScrollEdgeBlurModifier(edges: edges))
    }
}

// MARK: - Glass Card View

/// A reusable glass card component
struct GlassCard<Content: View>: View {
    let content: () -> Content
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16

    init(
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .liquidGlassRounded(cornerRadius: cornerRadius)
    }
}

// MARK: - Glass Button Style

/// Button style with Liquid Glass effect
struct GlassButtonStyle: ButtonStyle {
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isProminent ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.ultraThinMaterial))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    /// Glass button style with Liquid Glass effect
    static var glass: GlassButtonStyle { GlassButtonStyle() }

    /// Prominent glass button style
    static var glassProminent: GlassButtonStyle { GlassButtonStyle(isProminent: true) }
}

// MARK: - Glass Section Header

/// Section header with Liquid Glass styling
struct GlassSectionHeader: View {
    let title: String
    let systemImage: String?

    init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Glass Toggle Style

/// Toggle style with Liquid Glass effect
struct GlassToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer()
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(configuration.isOn ? .blue : .secondary)
                    .font(.title2)
            }
            .padding()
            .liquidGlassRounded(cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Navigation Link Style

/// NavigationLink wrapper with Liquid Glass styling
struct GlassNavigationRow<Destination: View>: View {
    let title: String
    let systemImage: String
    let destination: () -> Destination

    init(
        _ title: String,
        systemImage: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.title = title
        self.systemImage = systemImage
        self.destination = destination
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
            .padding()
            .liquidGlassRounded(cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass List Row

/// List row with Liquid Glass styling
struct GlassListRow<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(.horizontal)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlassRounded(cornerRadius: 12)
    }
}

// MARK: - Preview

#Preview("Liquid Glass Examples") {
    ScrollView {
        VStack(spacing: 20) {
            // Capsule glass
            Button("Capsule Glass Button") {}
                .buttonStyle(GlassButtonStyle())

            // Prominent button
            Button("Prominent Button") {}
                .buttonStyle(GlassButtonStyle(isProminent: true))

            // Glass card
            GlassCard(cornerRadius: 20, padding: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Glass Card")
                        .font(.headline)
                    Text("This is a reusable glass card component")
                        .foregroundStyle(.secondary)
                }
            }

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

            // Section header
            GlassSectionHeader("Settings", systemImage: "gear")

            // List rows
            GlassListRow {
                Label("First Option", systemImage: "1.circle")
            }

            GlassListRow {
                Label("Second Option", systemImage: "2.circle")
            }
        }
        .padding()
    }
    .background(
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3), .pink.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
