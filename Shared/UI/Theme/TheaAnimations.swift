import SwiftUI

// MARK: - Animation Presets

enum TheaAnimation {
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let gentleSpring = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let snappy = Animation.snappy(duration: 0.25)
    static let morphing = Animation.smooth(duration: 0.4)
    static let messageAppear = Animation.spring(response: 0.4, dampingFraction: 0.75)
    static let tabSwitch = Animation.easeInOut(duration: 0.25)

    /// Staggered animation for lists and grids
    static func staggered(index: Int, baseDelay: Double = 0.05) -> Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
        .delay(Double(index) * baseDelay)
    }
}

// MARK: - Reduce Motion Aware Animation

extension View {
    /// Applies animation only when reduce motion is not enabled
    func theaAnimation<V: Equatable>(
        _ animation: Animation,
        value: V,
        reduceMotion: Bool
    ) -> some View {
        self.animation(reduceMotion ? nil : animation, value: value)
    }
}
