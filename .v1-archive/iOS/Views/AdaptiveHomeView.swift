import SwiftUI

/// Adaptive home view that switches between iPhone and iPad layouts
/// - iPhone: Uses TabView for compact navigation
/// - iPad: Uses NavigationSplitView for three-column layout
@MainActor
struct AdaptiveHomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Determines if the current device should use iPad layout
    /// iPad in any orientation uses regular horizontal size class
    /// iPhone in landscape on larger phones may also be regular, but we check both
    private var shouldUseiPadLayout: Bool {
        // iPad always has regular horizontal size class
        // Also check if we're on a device with enough screen real estate
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    var body: some View {
        Group {
            if shouldUseiPadLayout {
                IPadHomeView()
            } else {
                iOSHomeView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: shouldUseiPadLayout)
    }
}

// MARK: - Preview

#Preview("iPhone") {
    AdaptiveHomeView()
        .environment(\.horizontalSizeClass, .compact)
        .environment(\.verticalSizeClass, .regular)
}

#Preview("iPad") {
    AdaptiveHomeView()
        .environment(\.horizontalSizeClass, .regular)
        .environment(\.verticalSizeClass, .regular)
}
