import SwiftUI

/// iPadOS target home view.
/// Wraps the canonical `IPadHomeView` from the iOS target to ensure
/// both targets share the same iPad experience.
@MainActor
struct iPadOSHomeView: View {
    var body: some View {
        IPadHomeView()
    }
}
